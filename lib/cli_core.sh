#!/bin/bash
set -euo pipefail

# Shared CLI core for hz.
# Pure bash; minimal dependencies; vendor-neutral.

hz_repo_root() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "$root"
}

hz_read_version() {
  local root version_file
  root="$(hz_repo_root)"
  version_file="${root}/VERSION"
  if [[ -f "$version_file" ]]; then
    # Trim trailing newline safely
    tr -d '\n' < "$version_file"
  else
    echo "0.0.0"
  fi
}

hz_ts_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

hz_log() {
  local level="$1"; shift || true
  echo "[$(hz_ts_utc)] [$level] $*"
}

hz_die() {
  hz_log "ERROR" "$*"
  return 1
}

hz_usage() {
  cat <<'EOF_USAGE'
hz - Horizon one-click CLI (single entry point)

Usage:
  hz help
  hz version
  hz check
  hz install <recipe>
  hz recipe list
  hz recipe <name> <subcommand>
  hz module list
  hz module <name> <subcommand>

Environment:
  HZ_DRY_RUN=0|1|2   (default: 0)

Notes:
  - hz check runs repository verification (CI-style).
  - hz install <recipe> maps to: hz recipe <recipe> install
EOF_USAGE
}

hz_validate_dry_run() {
  local v="${HZ_DRY_RUN:-0}"
  case "$v" in
    0|1|2) return 0 ;;
    *) hz_die "invalid HZ_DRY_RUN value: ${v} (expected 0|1|2)" ;;
  esac
}

hz_trim() {
  local s="$*"
  # shellcheck disable=SC2001
  s="$(echo "$s" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  echo "$s"
}

hz_get_contract_value() {
  local file="$1" key="$2"
  # Minimal YAML-ish parsing for "key: value" lines (as used by current contracts).
  awk -F ':' -v k="$key" '
    $1 ~ "^[[:space:]]*" k "$" {
      sub(/^[[:space:]]+/, "", $2)
      sub(/[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' "$file"
}

hz_supports_subcommand() {
  local supported_csv="$1" target="$2"
  local token
  IFS=',' read -r -a arr <<< "$supported_csv"
  for token in "${arr[@]}"; do
    token="$(hz_trim "$token")"
    [[ -n "$token" ]] || continue
    [[ "$token" == "$target" ]] && return 0
  done
  return 1
}

hz_list_targets() {
  local target_type="$1"
  local root base found manifest name
  root="$(hz_repo_root)"
  base="${root}/${target_type}"

  found=0
  [[ -d "$base" ]] || return 0

  while IFS= read -r manifest; do
    name="$(basename "$(dirname "$manifest")")"
    echo "$name"
    found=1
  done < <(find "$base" -mindepth 2 -maxdepth 2 -type f -name contract.yml | sort)

  if [[ "$found" -eq 0 ]]; then
    hz_log "WARN" "no ${target_type} contracts found"
  fi
}

hz_run_target() {
  local target_type="$1" name="$2" subcommand="$3"
  local root contract supported runner_rel runner_abs rc

  hz_validate_dry_run || return 1

  root="$(hz_repo_root)"
  contract="${root}/${target_type}/${name}/contract.yml"
  [[ -f "$contract" ]] || { hz_die "missing contract file: ${contract}"; return 1; }

  supported="$(hz_get_contract_value "$contract" "supported_subcommands")"
  runner_rel="$(hz_get_contract_value "$contract" "runner")"
  [[ -n "$supported" && -n "$runner_rel" ]] || { hz_die "invalid contract file: ${contract}"; return 1; }

  if ! hz_supports_subcommand "$supported" "$subcommand"; then
    hz_die "${target_type}/${name} does not support subcommand ${subcommand}"
    return 1
  fi

  runner_abs="${root}/${runner_rel}"
  [[ -f "$runner_abs" ]] || { hz_die "runner not found: ${runner_abs}"; return 2; }

  hz_log "INFO" "target=${target_type}/${name} subcommand=${subcommand} dry_run=${HZ_DRY_RUN:-0}"

  HZ_SUBCOMMAND="$subcommand" \
  HZ_TARGET_TYPE="$target_type" \
  HZ_TARGET_NAME="$name" \
  bash "$runner_abs" || {
    rc=$?
    # Preserve known exit codes; normalize others to 2 (exec fail)
    case "$rc" in
      1|2|3) return "$rc" ;;
      *) return 2 ;;
    esac
  }
}

hz_run_check() {
  local root check_script
  root="$(hz_repo_root)"

  # T-003 may move scripts/ -> tools/. Prefer tools/ if present.
  if [[ -f "${root}/tools/check/run.sh" ]]; then
    check_script="${root}/tools/check/run.sh"
  else
    check_script="${root}/scripts/check/run.sh"
  fi

  [[ -f "$check_script" ]] || { hz_die "check runner not found: ${check_script}"; return 2; }

  hz_log "INFO" "running checks via: ${check_script}"
  bash "$check_script"
}

hz_install_recipe() {
  local name="$1"
  [[ -n "$name" ]] || { hz_usage; return 1; }
  hz_run_target "recipes" "$name" "install"
}
