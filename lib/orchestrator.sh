#!/usr/bin/env bash
# lib/orchestrator.sh
# Parallel execution helper (Bash 3.2+ compatible)

orchestrate__log_info() { command -v log_info >/dev/null 2>&1 && log_info "$@" || echo "INFO: $*"; }
orchestrate__log_warn() { command -v log_warn >/dev/null 2>&1 && log_warn "$@" || echo "WARN: $*" >&2; }
orchestrate__log_error() { command -v log_error >/dev/null 2>&1 && log_error "$@" || echo "ERROR: $*" >&2; }
orchestrate__log_debug() { command -v log_debug >/dev/null 2>&1 && log_debug "$@" || true; }

orchestrate__is_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

# Wait until at least one PID finishes, reap it, record its exit code.
# Args:
#   1) tmpdir
#   2) name prefix (for rc files)
# Uses globals:
#   ORCH_PIDS[], ORCH_TARGETS[]
orchestrate__wait_any() {
  local tmpdir="$1"
  local prefix="$2"
  local i pid target rc
  while :; do
    for i in "${!ORCH_PIDS[@]}"; do
      pid="${ORCH_PIDS[$i]}"
      target="${ORCH_TARGETS[$i]}"
      if ! kill -0 "${pid}" 2>/dev/null; then
        rc=0
        wait "${pid}" || rc=$?
        printf '%s\n' "${rc}" > "${tmpdir}/${prefix}.${pid}.rc"
        orchestrate__log_debug "job finished target=${target} pid=${pid} rc=${rc}"
        unset 'ORCH_PIDS[i]'
        unset 'ORCH_TARGETS[i]'
        return 0
      fi
    done
    sleep 0.1
  done
}

# Execute in parallel with a callback worker.
# Usage:
#   orchestrate_execute "<targets space-separated>" <worker_fn> [worker_args...]
# Worker signature:
#   <worker_fn> <target> [worker_args...]
orchestrate_execute() {
  local targets="${1:-}"
  shift || true
  local worker="${1:-}"
  shift || true

  if [[ -z "${targets}" ]]; then
    orchestrate__log_error "orchestrate_execute: empty targets list"
    return 2
  fi
  if [[ -z "${worker}" ]]; then
    orchestrate__log_error "orchestrate_execute: missing worker function"
    return 2
  fi
  if ! type "${worker}" >/dev/null 2>&1; then
    orchestrate__log_error "orchestrate_execute: worker not found: ${worker}"
    return 2
  fi

  local max_jobs="${HZ_MAX_JOBS:-5}"
  if ! orchestrate__is_int "${max_jobs}" || [[ "${max_jobs}" -lt 1 ]]; then
    max_jobs=5
  fi

  local tmpdir
  tmpdir="$(mktemp -d 2>/dev/null || mktemp -d -t hz_orch)"
  chmod 700 "${tmpdir}" 2>/dev/null || true

  ORCH_PIDS=()
  ORCH_TARGETS=()

  orchestrate__log_info "Parallel orchestrator: targets=$(echo "${targets}" | wc -w | tr -d ' ') max_jobs=${max_jobs}"

  local running=0
  local target pid
  for target in ${targets}; do
    while [[ "${running}" -ge "${max_jobs}" ]]; do
      orchestrate__wait_any "${tmpdir}" "orch" || true
      running="${#ORCH_PIDS[@]}"
    done

    (
      "${worker}" "${target}" "$@"
    ) &
    pid=$!
    ORCH_PIDS+=("${pid}")
    ORCH_TARGETS+=("${target}")
    running="${#ORCH_PIDS[@]}"
    orchestrate__log_debug "job started target=${target} pid=${pid}"
  done

  while [[ "${#ORCH_PIDS[@]}" -gt 0 ]]; do
    orchestrate__wait_any "${tmpdir}" "orch" || true
  done

  local agg=0
  local f rc
  for f in "${tmpdir}"/orch.*.rc; do
    [[ -f "${f}" ]] || continue
    rc="$(cat "${f}" 2>/dev/null || echo 1)"
    if [[ "${rc}" != "0" ]]; then
      agg=1
    fi
  done

  rm -rf "${tmpdir}" 2>/dev/null || true

  if [[ "${agg}" -eq 0 ]]; then
    orchestrate__log_info "Parallel orchestrator: all targets succeeded"
  else
    orchestrate__log_warn "Parallel orchestrator: one or more targets failed"
  fi

  return "${agg}"
}
