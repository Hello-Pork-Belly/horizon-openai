#!/usr/bin/env bash
# lib/watch.sh
# Watchdog: periodic diagnose + notify + (optional) heal.

watch__log_info() {
  if command -v log_info >/dev/null 2>&1; then
    log_info "$@"
  else
    echo "INFO: $*"
  fi
}

watch__log_warn() {
  if command -v log_warn >/dev/null 2>&1; then
    log_warn "$@"
  else
    echo "WARN: $*" >&2
  fi
}

watch__log_error() {
  if command -v log_error >/dev/null 2>&1; then
    log_error "$@"
  else
    echo "ERROR: $*" >&2
  fi
}

watch__log_debug() {
  if command -v log_debug >/dev/null 2>&1; then
    log_debug "$@"
  fi
}

watch__repo_root() {
  if [[ -n "${REPO_ROOT:-}" ]]; then
    printf '%s\n' "${REPO_ROOT}"
  elif declare -F hz_repo_root >/dev/null 2>&1; then
    hz_repo_root
  else
    printf '%s\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
}

watch__mask_secrets() {
  # Best-effort masking for common secret-looking key-value snippets.
  local s="${1:-}"
  s="$(printf '%s' "${s}" | sed -E 's/([A-Za-z0-9_]*(PASS|PASSWORD|SECRET|KEY)[A-Za-z0-9_]*=)[^[:space:]]+/\1***REDACTED***/g')"
  printf '%s' "${s}"
}

watch__summarize() {
  # Keep one-line and capped length for notification payload.
  local s="${1:-}"
  s="${s//$'\n'/ }"
  s="${s//$'\r'/ }"
  s="${s//$'\t'/ }"
  s="$(printf '%s' "${s}" | sed -E 's/[[:space:]]+/ /g' | cut -c1-300)"
  printf '%s' "${s}"
}

watch__run_diagnose() {
  # Runs diagnose and captures stdout/stderr combined.
  # Returns diagnose exit code; echoes output to stdout.
  local out rc
  local repo_root
  repo_root="$(watch__repo_root)"

  out="$(
    HZ_NO_RECORD=1 "${repo_root}/bin/hz" diagnose 2>&1
  )" || rc=$?
  rc="${rc:-0}"

  printf '%s' "${out}"
  return "${rc}"
}

watch__try_heal_nginx() {
  if ! command -v systemctl >/dev/null 2>&1; then
    watch__log_warn "watch: systemctl not found; cannot heal nginx."
    return 1
  fi

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    watch__log_warn "watch: heal requires root privileges; skip nginx restart."
    return 1
  fi

  if ! systemctl list-unit-files 2>/dev/null | grep -qE '^nginx\.service'; then
    watch__log_warn "watch: nginx.service not installed; skip heal."
    return 1
  fi

  watch__log_info "watch: attempting heal: systemctl restart nginx"
  if systemctl restart nginx; then
    watch__log_info "watch: heal nginx: OK"
    return 0
  fi

  watch__log_warn "watch: heal nginx: FAILED"
  return 1
}

watch_run_cycle() {
  # Env:
  #   HZ_HEAL=1 enables healing
  local heal="${HZ_HEAL:-0}"
  local title_bad="${HZ_WATCH_TITLE_BAD:-Watchdog Alert}"

  watch__log_info "watch: running diagnose cycle..."

  local output rc
  output="$(watch__run_diagnose)" || rc=$?
  rc="${rc:-0}"

  if [[ "${rc}" -eq 0 ]]; then
    watch__log_info "watch: system healthy."
    return 0
  fi

  watch__log_warn "watch: system unhealthy (diagnose exit=${rc})."

  local masked summary
  masked="$(watch__mask_secrets "${output}")"
  summary="$(watch__summarize "${masked}")"

  # Notify (best-effort)
  if command -v notify_send >/dev/null 2>&1; then
    notify_send "${title_bad}" "System check failed (exit=${rc}): ${summary}" "FAILURE" || true
  else
    watch__log_warn "watch: notify_send not available; skipping notification."
  fi

  # Heal (explicit opt-in)
  if [[ "${heal}" == "1" ]]; then
    watch__log_info "watch: healing enabled (HZ_HEAL=1)."
    if printf '%s' "${output}" | grep -qiE 'nginx.*(stopped|inactive|not running|failed)'; then
      watch__try_heal_nginx || true
    else
      watch__log_info "watch: no known heal triggers matched; skip heal."
    fi
  else
    watch__log_info "watch: healing disabled (set HZ_HEAL=1 or use --heal)."
  fi

  return "${rc}"
}

watch_install_cron() {
  # Uses hz cron add to register watchdog.
  local schedule="${1:-*/5 * * * *}"
  local user="${2:-root}"
  local name="${3:-hz-watchdog}"
  local repo_root cmd

  repo_root="$(watch__repo_root)"
  cmd="cd ${repo_root} && ./bin/hz watch run"

  watch__log_info "watch: installing cron task name=${name} schedule='${schedule}' user=${user}"
  "${repo_root}/bin/hz" cron add --name "${name}" --schedule "${schedule}" --user "${user}" --cmd "${cmd}"
}
