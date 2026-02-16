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

orchestrate__int_or_default() {
  local v="${1:-}" d="${2:-}"
  if [[ "${v}" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "${v}"
  else
    printf '%s\n' "${d}"
  fi
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

        ORCH_LAST_PID="${pid}"
        ORCH_LAST_TARGET="${target}"
        ORCH_LAST_RC="${rc}"

        unset 'ORCH_PIDS[i]'
        unset 'ORCH_TARGETS[i]'
        return 0
      fi
    done
    sleep 0.1
  done
}

orchestrate__execute_parallel_once() {
  # Internal: run one batch in parallel (records per-target status via reporting.sh if enabled)
  # Args: <targets> <worker_fn> [worker_args...]
  local targets="${1:-}"
  shift || true
  local worker="${1:-}"
  shift || true

  if [[ -z "${targets}" ]]; then
    orchestrate__log_error "orchestrate: empty targets (batch)"
    return 2
  fi

  local max_jobs timeout_s
  max_jobs="$(orchestrate__int_or_default "${HZ_MAX_JOBS:-5}" "5")"
  if [[ "${max_jobs}" -lt 1 ]]; then max_jobs=5; fi

  timeout_s="$(orchestrate__int_or_default "${HZ_TIMEOUT:-300}" "300")"
  if [[ "${timeout_s}" -lt 1 ]]; then timeout_s=300; fi

  local tmpdir
  tmpdir="$(mktemp -d 2>/dev/null || mktemp -d -t hz_orch)"
  chmod 700 "${tmpdir}" 2>/dev/null || true

  ORCH_PIDS=()
  ORCH_TARGETS=()

  local batch_count=0 t
  for t in ${targets}; do batch_count=$((batch_count+1)); done

  orchestrate__log_info "Parallel batch: targets=${batch_count} max_jobs=${max_jobs} timeout=${timeout_s}s"

  local running=0
  local target pid

  for target in ${targets}; do
    if [[ "${ORCH_SIGNALLED:-0}" == "1" ]]; then
      orchestrate__log_warn "Interrupted: stop spawning new workers"
      break
    fi

    while [[ "${running}" -ge "${max_jobs}" ]]; do
      orchestrate__wait_any "${tmpdir}" "orch" || true
      ORCH_DONE_TARGETS=$(( ORCH_DONE_TARGETS + 1 ))
      printf '[%d/%d] %s rc=%d\n' "${ORCH_DONE_TARGETS}" "${ORCH_TOTAL_TARGETS}" "${ORCH_LAST_TARGET:-?}" "${ORCH_LAST_RC:-1}" >&2
      running="${#ORCH_PIDS[@]}"
      if [[ "${ORCH_SIGNALLED:-0}" == "1" ]]; then break; fi
    done

    (
      # Worker wrapper: measure duration + timeout + record JSONL
      local start end dur rc status msg
      local timedout=0

      start="$(date +%s)"
      rc=0

      if [[ "${timeout_s}" -gt 0 ]]; then
        # Portable watchdog timeout (no external deps)
        local flag="/tmp/hz_timeout_${RANDOM}_${RANDOM}.flag"
        rm -f "${flag}" 2>/dev/null || true

        "${worker}" "${target}" "$@" &
        local wpid=$!

        (
          sleep "${timeout_s}"
          if kill -0 "${wpid}" 2>/dev/null; then
            : > "${flag}"
            kill -TERM "${wpid}" 2>/dev/null || true
            sleep 1
            kill -KILL "${wpid}" 2>/dev/null || true
          fi
        ) &
        local watchdog=$!

        wait "${wpid}" || rc=$?
        kill "${watchdog}" 2>/dev/null || true
        wait "${watchdog}" 2>/dev/null || true

        if [[ -f "${flag}" ]]; then
          timedout=1
          rc=124
          rm -f "${flag}" 2>/dev/null || true
        fi
      else
        "${worker}" "${target}" "$@" || rc=$?
      fi

      end="$(date +%s)"
      dur=$(( end - start ))

      if [[ "${rc}" -eq 0 ]]; then
        status="SUCCESS"
        msg="${HZ_REPORT_CMD:-cmd} rc=0"
      else
        status="FAILURE"
        if [[ "${timedout}" -eq 1 ]]; then
          msg="Execution timed out"
          if command -v log_warn >/dev/null 2>&1; then
            log_warn "TIMEOUT target=${target} timeout=${timeout_s}s"
          fi
        else
          msg="${HZ_REPORT_CMD:-cmd} rc=${rc}"
        fi
      fi

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

  # Drain remaining
  while [[ "${#ORCH_PIDS[@]}" -gt 0 ]]; do
    orchestrate__wait_any "${tmpdir}" "orch" || true
    ORCH_DONE_TARGETS=$(( ORCH_DONE_TARGETS + 1 ))
    printf '[%d/%d] %s rc=%d\n' "${ORCH_DONE_TARGETS}" "${ORCH_TOTAL_TARGETS}" "${ORCH_LAST_TARGET:-?}" "${ORCH_LAST_RC:-1}" >&2
  done

  # Aggregate rc
  local agg=0 f r
  for f in "${tmpdir}"/orch.*.rc; do
    [[ -f "${f}" ]] || continue
    r="$(cat "${f}" 2>/dev/null || echo 1)"
    if [[ "${r}" != "0" ]]; then agg=1; fi
  done

  rm -rf "${tmpdir}" 2>/dev/null || true
  return "${agg}"
}

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

  # Global progress counters
  ORCH_TOTAL_TARGETS=0
  ORCH_DONE_TARGETS=0
  local x
  for x in ${targets}; do ORCH_TOTAL_TARGETS=$((ORCH_TOTAL_TARGETS+1)); done

  # Reporting session init (only when enabled)
  if [[ "${HZ_REPORT:-0}" == "1" ]] && command -v report_session_init >/dev/null 2>&1; then
    if [[ -z "${HZ_REPORT_SESSION_DIR:-}" || -z "${HZ_REPORT_FILE:-}" ]]; then
      report_session_init "${HZ_REPORT_LABEL:-orchestrator}" || true
    fi
  fi

  ORCH_SIGNALLED=0
  ORCH_SIGNAL=""

  local old_int old_term
  old_int="$(trap -p INT || true)"
  old_term="$(trap -p TERM || true)"

  orchestrate__kill_children() {
    local p
    if declare -p ORCH_PIDS >/dev/null 2>&1; then
      for p in "${ORCH_PIDS[@]}"; do
        kill -TERM "${p}" 2>/dev/null || true
      done
      sleep 0.2
      for p in "${ORCH_PIDS[@]}"; do
        kill -KILL "${p}" 2>/dev/null || true
      done
    fi
  }

  trap 'ORCH_SIGNALLED=1; ORCH_SIGNAL="INT"; orchestrate__log_warn "Received INT (Ctrl+C): stopping workers..."; orchestrate__kill_children' INT
  trap 'ORCH_SIGNALLED=1; ORCH_SIGNAL="TERM"; orchestrate__log_warn "Received TERM: stopping workers..."; orchestrate__kill_children' TERM

  local batch pause force
  batch="$(orchestrate__int_or_default "${HZ_ROLLING_BATCH:-0}" "0")"
  pause="$(orchestrate__int_or_default "${HZ_ROLLING_PAUSE:-0}" "0")"
  force="${HZ_FORCE:-0}"

  local overall_rc=0

  if [[ "${batch}" -le 0 ]]; then
    orchestrate__log_info "Orchestrator mode: full-parallel"
    orchestrate__execute_parallel_once "${targets}" "${worker}" "$@" || overall_rc=$?
  else
    orchestrate__log_info "Orchestrator mode: rolling batch=${batch} pause=${pause}s fail_fast=$( [[ "${force}" == "1" ]] && echo "no" || echo "yes" )"

    local -a all=()
    local t
    for t in ${targets}; do all+=("${t}"); done

    local total="${#all[@]}"
    local i=0

    while [[ "${i}" -lt "${total}" ]]; do
      if [[ "${ORCH_SIGNALLED}" == "1" ]]; then
        overall_rc=130
        break
      fi

      local end=$(( i + batch ))
      if [[ "${end}" -gt "${total}" ]]; then end="${total}"; fi

      local chunk=""
      local j
      for (( j=i; j<end; j++ )); do
        chunk+="${chunk:+ }${all[$j]}"
      done

      orchestrate__log_info "Rolling batch: $((i+1))..${end}/${total} -> ${chunk}"

      local rc=0
      orchestrate__execute_parallel_once "${chunk}" "${worker}" "$@" || rc=$?

      if [[ "${ORCH_SIGNALLED}" == "1" ]]; then
        overall_rc=130
        break
      fi

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

  # If interrupted, override rc to 130 (standard Ctrl+C)
  if [[ "${ORCH_SIGNALLED}" == "1" ]]; then
    overall_rc=130
  fi

  # Always merge + print summary if reporting enabled (partial report on interrupt)
  if [[ "${HZ_REPORT:-0}" == "1" ]] && command -v report_merge >/dev/null 2>&1; then
    report_merge || true
    command -v report_print_summary >/dev/null 2>&1 && report_print_summary "${HZ_REPORT_FILE:-}" || true
  fi

  # Restore traps
  if [[ -n "${old_int}" ]]; then eval "${old_int}"; else trap - INT; fi
  if [[ -n "${old_term}" ]]; then eval "${old_term}"; else trap - TERM; fi

  return "${overall_rc}"
}
