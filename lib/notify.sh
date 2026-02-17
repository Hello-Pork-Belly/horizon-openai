#!/usr/bin/env bash
# lib/notify.sh
# Best-effort webhook notifications. Never hard-fail the main command.

notify__log_info() {
  if command -v log_info >/dev/null 2>&1; then
    log_info "$@"
  else
    echo "INFO: $*"
  fi
}

notify__log_warn() {
  if command -v log_warn >/dev/null 2>&1; then
    log_warn "$@"
  else
    echo "WARN: $*" >&2
  fi
}

notify__log_error() {
  if command -v log_error >/dev/null 2>&1; then
    log_error "$@"
  else
    echo "ERROR: $*" >&2
  fi
}

notify__log_debug() {
  if command -v log_debug >/dev/null 2>&1; then
    log_debug "$@"
  fi
}

notify__json_escape() {
  # Escape for JSON string values (single line)
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}

notify__status_color() {
  local st="${1:-INFO}"
  case "${st}" in
    SUCCESS) printf '%s' "#2eb886" ;;
    FAILURE) printf '%s' "#e01e5a" ;;
    WARN) printf '%s' "#ecb22e" ;;
    INFO|*) printf '%s' "#36c5f0" ;;
  esac
}

notify_send() {
  # Usage: notify_send <title> <message> [status]
  # Env:
  #   HZ_WEBHOOK_URL (required; if missing => warn and return 0)
  #   HZ_NOTIFY_PROJECT (optional label)
  #   HZ_NOTIFY_CHANNEL (optional label)
  local title="${1:-}"
  local message="${2:-}"
  local status="${3:-INFO}"

  local url="${HZ_WEBHOOK_URL:-}"
  if [[ -z "${url}" ]]; then
    notify__log_warn "notify: HZ_WEBHOOK_URL not set; skipping notification."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    notify__log_warn "notify: curl not found; skipping notification."
    return 0
  fi

  local color ts host proj chan
  color="$(notify__status_color "${status}")"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
  host="$(hostname 2>/dev/null || echo unknown)"
  proj="${HZ_NOTIFY_PROJECT:-horizon-openai}"
  chan="${HZ_NOTIFY_CHANNEL:-}"

  local jt jm js jhost jproj jchan jcolor
  jt="$(notify__json_escape "${title}")"
  jm="$(notify__json_escape "${message}")"
  js="$(notify__json_escape "${status}")"
  jhost="$(notify__json_escape "${host}")"
  jproj="$(notify__json_escape "${proj}")"
  jchan="$(notify__json_escape "${chan}")"
  jcolor="$(notify__json_escape "${color}")"

  # Generic JSON payload (webhook-agnostic)
  # NOTE: do not include secrets; caller responsibility.
  local payload
  payload=$(cat <<EOF_JSON
{"title":"${jt}","message":"${jm}","status":"${js}","color":"${jcolor}","ts":"${ts}","host":"${jhost}","project":"${jproj}","channel":"${jchan}"}
EOF_JSON
)

  notify__log_debug "notify: sending status=${status} to webhook (payload size=$(printf '%s' "${payload}" | wc -c | tr -d ' '))"

  # Best-effort: do not fail caller even if webhook fails.
  local http_code
  http_code="$(curl -sS -o /dev/null \
    -w '%{http_code}' \
    -X POST \
    -H 'Content-Type: application/json' \
    --data "${payload}" \
    "${url}" 2>/dev/null || true)"
  if ! [[ "${http_code}" =~ ^[0-9]{3}$ ]]; then
    http_code="000"
  fi

  if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
    notify__log_info "notify: delivered (http ${http_code})"
  else
    notify__log_warn "notify: failed to deliver (http ${http_code}); continuing."
  fi

  return 0
}
