#!/usr/bin/env bash
# lib/orchestrator.sh
# Parallel execution helper (Bash 3.2+ compatible)

orchestrate__log_info() {
  if command -v log_info >/dev/null 2>&1; then
    log_info "$@"
  else
    echo "INFO: $*"
  fi
}

orchestrate__log_warn() {
  if command -v log_warn >/dev/null 2>&1; then
    log_warn "$@"
  else
    echo "WARN: $*" >&2
  fi
}

orchestrate__log_error() {
  if command -v log_error >/dev/null 2>&1; then
    log_error "$@"
  else
    echo "ERROR: $*" >&2
  fi
}

orchestrate__log_debug() {
  if command -v log_debug >/dev/null 2>&1; then
    log_debug "$@"
  fi
}

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

# --- T-027: Rolling execution wrapper -------------------------------------

orchestrate__int_or_default() {
  local v="${1:-}" d="${2:-}"
  if [[ "${v}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "${v}"
  else
    printf '%s\n' "${d}"
  fi
}

orchestrate__execute_parallel_once() {
  # Internal: run one batch in parallel (records per-target status when enabled).
  # Args: <targets> <worker_fn> [worker_args...]
  local targets="${1:-}"
  shift || true
  local worker="${1:-}"
  shift || true

  if [[ -z "${targets}" ]]; then
    orchestrate__log_error "orchestrate: empty targets (batch)"
    return 2
  fi

  local max_jobs="${HZ_MAX_JOBS:-5}"
  max_jobs="$(orchestrate__int_or_default "${max_jobs}" "5")"
  if [[ "${max_jobs}" -lt 1 ]]; then
    max_jobs=5
  fi

  local tmpdir
  tmpdir="$(mktemp -d 2>/dev/null || mktemp -d -t hz_orch)"
  chmod 700 "${tmpdir}" 2>/dev/null || true

  ORCH_PIDS=()
  ORCH_TARGETS=()

  orchestrate__log_info "Parallel batch: targets=$(echo "${targets}" | wc -w | tr -d ' ') max_jobs=${max_jobs}"

  local running=0
  local target pid
  for target in ${targets}; do
    while [[ "${running}" -ge "${max_jobs}" ]]; do
      orchestrate__wait_any "${tmpdir}" "orch" || true
      running="${#ORCH_PIDS[@]}"
    done

    (
      # Worker wrapper: measure duration and optionally emit one JSONL record.
      local start end dur rc status msg
      start="$(date +%s)"
      rc=0

      "${worker}" "${target}" "$@" || rc=$?

      end="$(date +%s)"
      dur=$(( end - start ))
      if [[ "${rc}" -eq 0 ]]; then
        status="SUCCESS"
      else
        status="FAILURE"
      fi

      msg="${HZ_REPORT_CMD:-cmd} rc=${rc}"

      if [[ "${HZ_REPORT:-0}" == "1" ]] && command -v report_record_status >/dev/null 2>&1; then
        report_record_status "${target}" "${status}" "${dur}" "${msg}" || true
      fi

      exit "${rc}"
    ) &
    pid=$!
    ORCH_PIDS+=("${pid}")
    ORCH_TARGETS+=("${target}")
    running="${#ORCH_PIDS[@]}"
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
  return "${agg}"
}

# Execute in parallel or rolling batches with a callback worker.
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

  # Reporting session init (enabled by caller)
  if [[ "${HZ_REPORT:-0}" == "1" ]] && command -v report_session_init >/dev/null 2>&1; then
    if [[ -z "${HZ_REPORT_SESSION_DIR:-}" || -z "${HZ_REPORT_FILE:-}" ]]; then
      report_session_init "${HZ_REPORT_LABEL:-orchestrator}" || true
    fi
  fi

  local batch pause force fail_fast_label overall_rc
  batch="$(orchestrate__int_or_default "${HZ_ROLLING_BATCH:-0}" "0")"
  pause="$(orchestrate__int_or_default "${HZ_ROLLING_PAUSE:-0}" "0")"
  force="${HZ_FORCE:-0}"
  overall_rc=0
  if [[ "${force}" == "1" ]]; then
    fail_fast_label="no"
  else
    fail_fast_label="yes"
  fi

  if [[ "${batch}" -le 0 ]]; then
    # T-026 behavior (full parallel)
    orchestrate__log_info "Orchestrator mode: full-parallel"
    orchestrate__execute_parallel_once "${targets}" "${worker}" "$@" || overall_rc=$?
  else
    orchestrate__log_info "Orchestrator mode: rolling batch=${batch} pause=${pause}s fail_fast=${fail_fast_label}"

    # Rolling batches
    local -a all=()
    local t
    for t in ${targets}; do
      all+=("${t}")
    done

    local total="${#all[@]}"
    local i=0

    while [[ "${i}" -lt "${total}" ]]; do
      local end=$(( i + batch ))
      if [[ "${end}" -gt "${total}" ]]; then
        end="${total}"
      fi

      local chunk=""
      local j
      for (( j=i; j<end; j++ )); do
        chunk+="${chunk:+ }${all[$j]}"
      done

      orchestrate__log_info "Rolling batch: $((i+1))..${end}/${total} -> ${chunk}"

      local rc=0
      orchestrate__execute_parallel_once "${chunk}" "${worker}" "$@" || rc=$?
      if [[ "${rc}" -ne 0 ]]; then
        overall_rc=1
        if [[ "${force}" == "1" ]]; then
          orchestrate__log_warn "Batch failed (rc=${rc}) but HZ_FORCE=1, continuing..."
        else
          orchestrate__log_error "Batch failed (rc=${rc}); stopping (fail-fast). Set HZ_FORCE=1 to continue."
          break
        fi
      fi

      i="${end}"
      if [[ "${i}" -lt "${total}" && "${pause}" -gt 0 ]]; then
        orchestrate__log_info "Pausing for ${pause}s before next batch..."
        sleep "${pause}"
      fi
    done
  fi

  if [[ "${HZ_REPORT:-0}" == "1" ]] && command -v report_merge >/dev/null 2>&1; then
    report_merge || true
    if command -v report_print_summary >/dev/null 2>&1; then
      report_print_summary "${HZ_REPORT_FILE:-}" || true
    fi
  fi

  if [[ "${overall_rc}" -eq 0 ]]; then
    if [[ "${batch}" -le 0 ]]; then
      orchestrate__log_info "Parallel orchestrator: all targets succeeded"
    else
      orchestrate__log_info "Rolling orchestrator: all targets succeeded"
    fi
  else
    if [[ "${batch}" -le 0 ]]; then
      orchestrate__log_warn "Parallel orchestrator: one or more targets failed"
    else
      orchestrate__log_warn "Rolling orchestrator: one or more targets failed"
    fi
  fi
  return "${overall_rc}"
}
