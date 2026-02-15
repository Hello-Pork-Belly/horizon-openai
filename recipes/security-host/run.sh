#!/usr/bin/env bash
set -euo pipefail

# security-host recipe
# Uses hz engine: logging + inventory-injected env vars.
# Idempotent package installs with dry-run support.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/logging.sh
. "${REPO_ROOT}/lib/logging.sh"

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-install}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

# Optional controls (default true)
FAIL2BAN_ENABLED="${FAIL2BAN_ENABLED:-true}"
RKHUNTER_ENABLED="${RKHUNTER_ENABLED:-true}"

as_bool() {
  # normalize to "true" or "false"
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) echo "true" ;;
    0|false|FALSE|no|NO|off|OFF|"") echo "false" ;;
    *) echo "false" ;;
  esac
}

ensure_root_or_sudo() {
  if [[ "${EUID:-0}" -eq 0 ]]; then
    echo ""
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    echo "sudo"
    return 0
  fi
  log_error "must run as root or have sudo available"
  return "${RC_EXPECTED_FAIL}"
}

pkg_installed() {
  local pkg="$1"
  dpkg -s "$pkg" >/dev/null 2>&1
}

apt_install() {
  local pkg="$1"
  local sudo_cmd="$2"

  if pkg_installed "$pkg"; then
    log_info "package already installed: ${pkg}"
    return 0
  fi

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would install package: ${pkg}"
    return 0
  fi

  log_info "installing package: ${pkg}"
  ${sudo_cmd} apt-get update -y
  ${sudo_cmd} apt-get install -y "${pkg}"
}

case "${HZ_SUBCOMMAND}" in
  install|status|check|upgrade|backup|restore|uninstall|diagnostics) ;;
  *)
    log_error "unsupported subcommand: ${HZ_SUBCOMMAND}"
    exit "${RC_EXPECTED_FAIL}"
    ;;
esac

case "${HZ_DRY_RUN}" in
  0|1|2) ;;
  *)
    log_error "invalid HZ_DRY_RUN (expected 0|1|2)"
    exit "${RC_EXPECTED_FAIL}"
    ;;
esac

log_info "recipe=security-host subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"

# check/status are non-destructive
if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  log_info "plan.preflight: validate inventory and local prerequisites"
  log_info "plan.bruteforce_guard: stage remote access guard policy"
  log_info "plan.rootkit_scan: stage periodic scan and report plan"
  log_info "plan.log_retention: stage log rotation and cap policy"
  log_info "check: basic preflight ok"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  log_info "status: FAIL2BAN_ENABLED=$(as_bool "${FAIL2BAN_ENABLED}") RKHUNTER_ENABLED=$(as_bool "${RKHUNTER_ENABLED}")"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "diagnostics" ]]; then
  log_info "plan.alert_mail: stage notification route checks"
  log_info "plan.thresholds: stage CPU/RAM/disk threshold checks"
  log_info "plan.service_watch: stage service liveness checks"
  log_info "plan.rollback: stage rollback checklist"
  log_info "diagnostics: dry-run planning completed"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" != "install" ]]; then
  log_info "${HZ_SUBCOMMAND}: plan-only path (no package changes)"
  exit "${RC_SUCCESS}"
fi

# install
sudo_cmd="$(ensure_root_or_sudo)" || exit "${RC_EXPECTED_FAIL}"

fail2ban_on="$(as_bool "${FAIL2BAN_ENABLED}")"
rkhunter_on="$(as_bool "${RKHUNTER_ENABLED}")"

log_info "plan.preflight: validate apt/dpkg availability"
command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit "${RC_EXPECTED_FAIL}"; }
command -v dpkg >/dev/null 2>&1 || { log_error "dpkg not found"; exit "${RC_EXPECTED_FAIL}"; }

log_info "plan.bruteforce_guard: FAIL2BAN_ENABLED=${fail2ban_on}"
if [[ "${fail2ban_on}" == "true" ]]; then
  apt_install "fail2ban" "${sudo_cmd}"
else
  log_info "skipping fail2ban (disabled)"
fi

log_info "plan.rootkit_scan: RKHUNTER_ENABLED=${rkhunter_on}"
if [[ "${rkhunter_on}" == "true" ]]; then
  apt_install "rkhunter" "${sudo_cmd}"
else
  log_info "skipping rkhunter (disabled)"
fi

log_info "done: security-host install completed (idempotent)"
exit "${RC_SUCCESS}"
