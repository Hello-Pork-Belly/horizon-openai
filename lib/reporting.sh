#!/usr/bin/env bash
# lib/reporting.sh
# Aggregated Reporting (JSONL + ASCII summary)
# Concurrency strategy: per-worker JSONL files merged at end (no locking).

report__repo_root() {
  if [[ -n "${REPO_ROOT:-}" ]]; then
    printf '%s\n' "$REPO_ROOT"
    return 0
  fi
  printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

report__records_day_dir() {
  local root y m d
  root="$(report__repo_root)"
  y="$(date +%Y)"
  m="$(date +%m)"
  d="$(date +%d)"
  printf '%s\n' "${root}/records/${y}/${m}/${d}"
}

report__sanitize() {
  local s="${1:-}"
  s="${s//\//_}"
  s="$(printf '%s' "$s" | tr -c 'A-Za-z0-9._-@' '_')"
  printf '%s\n' "$s"
}

report__json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}

report__log_info() {
  if command -v log_info >/dev/null 2>&1; then
    log_info "$@"
  else
    echo "INFO: $*"
  fi
}

report__log_warn() {
  if command -v log_warn >/dev/null 2>&1; then
    log_warn "$@"
  else
    echo "WARN: $*" >&2
  fi
}

report__log_error() {
  if command -v log_error >/dev/null 2>&1; then
    log_error "$@"
  else
    echo "ERROR: $*" >&2
  fi
}

report__log_debug() {
  if command -v log_debug >/dev/null 2>&1; then
    log_debug "$@"
  fi
}

report_session_init() {
  # Usage: report_session_init <label>
  local label="${1:-session}"
  local day_dir sid safe_label base

  day_dir="$(report__records_day_dir)"
  mkdir -p "${day_dir}"

  sid="$(date +%Y-%m-%d_%H%M%S)"
  safe_label="$(report__sanitize "${label}")"
  base="${day_dir}/${sid}_${safe_label}"

  export HZ_REPORT_SESSION_ID="${sid}"
  export HZ_REPORT_SESSION_DIR="${base}.d"
  export HZ_REPORT_FILE="${base}.report.jsonl"

  mkdir -p "${HZ_REPORT_SESSION_DIR}"
  chmod 700 "${HZ_REPORT_SESSION_DIR}" 2>/dev/null || true

  : > "${HZ_REPORT_FILE}"
  chmod 600 "${HZ_REPORT_FILE}" 2>/dev/null || true

  report__log_debug "report: session init dir=${HZ_REPORT_SESSION_DIR} file=${HZ_REPORT_FILE}"
}

report__worker_file() {
  local target="${1:-unknown}"
  local safe
  safe="$(report__sanitize "${target}")"
  printf '%s\n' "${HZ_REPORT_SESSION_DIR}/worker_${safe}.jsonl"
}

report_record_status() {
  # Usage: report_record_status <target> <status> <duration_s> <message>
  local target="${1:-}"
  local status="${2:-UNKNOWN}"
  local duration="${3:-0}"
  local message="${4:-}"

  if [[ -z "${HZ_REPORT_SESSION_DIR:-}" ]]; then
    report_session_init "${HZ_REPORT_LABEL:-session}"
  fi

  local wf ts esc_target esc_status esc_msg
  wf="$(report__worker_file "${target}")"
  ts="$(date +%s)"

  esc_target="$(report__json_escape "${target}")"
  esc_status="$(report__json_escape "${status}")"
  esc_msg="$(report__json_escape "${message}")"

  printf '{"ts":%s,"target":"%s","status":"%s","duration_s":%s,"message":"%s"}\n' \
    "${ts}" "${esc_target}" "${esc_status}" "${duration}" "${esc_msg}" >> "${wf}"
}

report_merge() {
  if [[ -z "${HZ_REPORT_SESSION_DIR:-}" ]]; then
    report__log_error "report_merge: missing HZ_REPORT_SESSION_DIR"
    return 2
  fi
  if [[ -z "${HZ_REPORT_FILE:-}" ]]; then
    report__log_error "report_merge: missing HZ_REPORT_FILE"
    return 2
  fi

  local tmp f
  tmp="$(mktemp 2>/dev/null || mktemp -t hz_report)"

  : > "${tmp}"
  for f in "${HZ_REPORT_SESSION_DIR}"/worker_*.jsonl; do
    [[ -f "${f}" ]] || continue
    cat "${f}" >> "${tmp}"
  done

  mv "${tmp}" "${HZ_REPORT_FILE}"
  chmod 600 "${HZ_REPORT_FILE}" 2>/dev/null || true
}

report_print_summary() {
  # Usage: report_print_summary <report_file>
  local file="${1:-}"
  [[ -f "${file}" ]] || {
    report__log_warn "report summary: missing file ${file}"
    return 0
  }

  local sep="------------------------------------------------------------"
  echo "${sep}"
  printf '%-16s %-9s %-9s %s\n' "TARGET" "STATUS" "DURATION" "MESSAGE"
  echo "${sep}"

  awk '
    BEGIN { total=0; ok=0; fail=0; }
    {
      t="-"; s="UNKNOWN"; d="0"; m="-";

      if (match($0, /"target":"[^"]*"/)) {
        t = substr($0, RSTART + 10, RLENGTH - 11);
      }
      if (match($0, /"status":"[^"]*"/)) {
        s = substr($0, RSTART + 10, RLENGTH - 11);
      }
      if (match($0, /"duration_s":[0-9]+/)) {
        d = substr($0, RSTART + 13, RLENGTH - 13);
      }
      if (match($0, /"message":"[^"]*"/)) {
        m = substr($0, RSTART + 11, RLENGTH - 12);
      }

      if (t=="") t="-";
      if (s=="") s="UNKNOWN";
      if (d=="") d=0;
      if (m=="") m="-";

      total++;
      if (s=="SUCCESS") ok++; else if (s=="FAILURE") fail++;

      printf "%-16s %-9s %-9s %s\n", t, s, d "s", m;
    }
    END {
      print "------------------------------------------------------------";
      printf "Total: %d, Success: %d, Failure: %d\n", total, ok, fail;
    }
  ' "${file}"

  report__log_info "Report file: ${file}"
}
