#!/usr/bin/env bash
set -euo pipefail

# lib/remote_runner.sh
# Phase 2: Transient Runner (agentless)
#
# Contract:
# - remote_execute_recipe <recipe> <target_input> [host_alias]
#   - target_input: alias (inventory/hosts/<alias>.yml) or user@host
#   - host_alias: optional, passed to remote hz install via --host
#
# Security:
# - Remote staging dir is 0700 under /tmp, and extraction uses umask 077.
# - Payload includes inventory (may contain secrets). Always cleaned unless HZ_REMOTE_KEEP=1.

hz_rr__shq() {
  # Single-quote escape for POSIX shell.
  # shellcheck disable=SC2001
  printf "'%s'" "$(printf '%s' "${1:-}" | sed "s/'/'\\\\''/g")"
}

hz_rr__mktemp_dir() {
  local d=""
  if command -v mktemp >/dev/null 2>&1; then
    d="$(mktemp -d 2>/dev/null || true)"
    if [[ -z "$d" ]]; then
      d="$(mktemp -d -t hz_payload 2>/dev/null || true)"
    fi
  fi
  if [[ -z "$d" ]]; then
    d="/tmp/hz_payload.$$.$RANDOM"
    mkdir -p "$d"
  fi
  printf '%s\n' "$d"
}

hz_rr__target_host() {
  local t="${1:-}"
  if [[ "$t" == *"@"* ]]; then
    printf '%s\n' "${t#*@}"
  else
    printf '%s\n' "$t"
  fi
}

hz_rr_is_local_target() {
  local host hn hnf
  host="$(hz_rr__target_host "${1:-}")"

  case "$host" in
    "" ) return 0 ;;
    localhost|127.0.0.1|::1) return 0 ;;
  esac

  hn="$(hostname 2>/dev/null || true)"
  [[ -n "$hn" && "$host" == "$hn" ]] && return 0

  hnf="$(hostname -f 2>/dev/null || true)"
  [[ -n "$hnf" && "$host" == "$hnf" ]] && return 0

  return 1
}

hz_rr_pack_payload() {
  # hz_rr_pack_payload <recipe> <out_tar_gz>
  local recipe="${1:-}"
  local out="${2:-}"
  local root
  root="$(hz_repo_root)"

  [[ -n "$recipe" ]] || { log_error "remote: missing recipe"; return 2; }
  [[ -n "$out" ]] || { log_error "remote: missing output tar path"; return 2; }

  [[ -f "${root}/bin/hz" ]] || { log_error "remote: missing bin/hz at repo root"; return 2; }
  [[ -d "${root}/lib" ]] || { log_error "remote: missing lib/"; return 2; }
  [[ -d "${root}/inventory" ]] || { log_error "remote: missing inventory/"; return 2; }
  [[ -d "${root}/recipes/${recipe}" ]] || { log_error "remote: missing recipes/${recipe}/"; return 2; }

  local -a paths=()
  paths+=( "bin/hz" )
  [[ -f "${root}/VERSION" ]] && paths+=( "VERSION" )
  paths+=( "lib" "inventory" )
  [[ -d "${root}/tools" ]] && paths+=( "tools" )
  paths+=( "recipes/${recipe}" )

  log_debug "remote: payload paths: ${paths[*]}"

  (
    cd "$root"
    tar -czf "$out" "${paths[@]}"
  )
}

remote_execute_recipe() {
  # remote_execute_recipe <recipe> <target_input> [host_alias]
  local recipe="${1:-}"
  local target_input="${2:-}"
  local host_alias="${3:-}"

  [[ -n "$recipe" ]] || { log_error "remote_execute_recipe: missing recipe"; return 2; }
  [[ -n "$target_input" ]] || { log_error "remote_execute_recipe: missing target"; return 2; }

  # Resolve target via inventory (alias -> user@host), and export HZ_SSH_KEY/HZ_SSH_ARGS.
  local target="$target_input"
  if declare -F inventory_resolve_target >/dev/null 2>&1; then
    inventory_resolve_target "$target_input" || return 1
    target="${HZ_RESOLVED_TARGET:-$target_input}"
  fi

  if hz_rr_is_local_target "$target"; then
    log_info "remote: target=${target} treated as local; running local install"
    export HZ_HOST="${host_alias:-}"
    hz_recipe_install "$recipe"
    return $?
  fi

  command -v ssh_exec >/dev/null 2>&1 || { log_error "remote: ssh_exec not found (need lib/transport/ssh.sh)"; return 2; }
  command -v ssh_copy >/dev/null 2>&1 || { log_error "remote: ssh_copy not found (need lib/transport/ssh.sh)"; return 2; }

  local run_id tmpdir tarball remote_base remote_tar remote_work
  run_id="$(date -u +%Y%m%dT%H%M%SZ)_$$_$RANDOM"
  tmpdir="$(hz_rr__mktemp_dir)"
  tarball="${tmpdir}/hz_payload_${run_id}.tar.gz"

  remote_base="/tmp/hz_run_${run_id}"
  remote_tar="${remote_base}/payload.tar.gz"
  remote_work="${remote_base}/work"

  log_info "remote: pack payload (recipe=${recipe})"
  hz_rr_pack_payload "$recipe" "$tarball" || { rm -rf "$tmpdir" || true; return 1; }

  log_info "remote: prepare remote staging dir (0700): ${remote_base}"
  if ! ssh_exec "$target" "mkdir -p -m 700 $(hz_rr__shq "$remote_base")"; then
    rm -rf "$tmpdir" || true
    return 1
  fi

  log_info "remote: ship payload -> ${target}:${remote_tar}"
  if ! ssh_copy "$target" "$tarball" "$remote_tar"; then
    ssh_exec "$target" "rm -rf $(hz_rr__shq "$remote_base")" >/dev/null 2>&1 || true
    rm -rf "$tmpdir" || true
    return 1
  fi

  # Build remote command. Avoid leaking secrets; do not print env values at INFO.
  local dry="${HZ_DRY_RUN:-0}"
  local lvl="${LOG_LEVEL:-INFO}"
  local dbg="${HZ_DEBUG:-0}"
  local keep="${HZ_REMOTE_KEEP:-0}"

  local install_cmd
  install_cmd="./bin/hz install $(hz_rr__shq "$recipe") --local-mode --headless"
  if [[ -n "${host_alias:-}" ]]; then
    install_cmd="${install_cmd} --host $(hz_rr__shq "$host_alias")"
  fi

  local script
  script="set -euo pipefail; umask 077; \
mkdir -p $(hz_rr__shq "$remote_work"); \
tar -xzf $(hz_rr__shq "$remote_tar") -C $(hz_rr__shq "$remote_work"); \
cd $(hz_rr__shq "$remote_work"); \
chmod +x ./bin/hz; \
export HZ_NO_RECORD=1; export HZ_REMOTE=1; \
export HZ_DRY_RUN=$(hz_rr__shq "$dry"); export LOG_LEVEL=$(hz_rr__shq "$lvl"); export HZ_DEBUG=$(hz_rr__shq "$dbg"); \
${install_cmd}; rc=\$?; "

  if [[ "$keep" == "1" ]]; then
    script="${script} echo \"remote: kept payload at ${remote_base}\" 1>&2; exit \$rc"
  else
    script="${script} rm -rf $(hz_rr__shq "$remote_base"); exit \$rc"
  fi

  local cmd
  cmd="bash -lc $(hz_rr__shq "$script")"

  log_info "remote: exec transient runner on target=${target} (dry_run=${dry})"
  # shellcheck disable=SC2029
  ssh_exec "$target" "$cmd"
  local rc=$?

  rm -rf "$tmpdir" || true
  return "$rc"
}
