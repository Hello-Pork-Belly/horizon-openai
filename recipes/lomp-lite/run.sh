#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
# shellcheck source=lib/cli_core.sh
. "${REPO_ROOT}/lib/cli_core.sh"

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-install}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

# Required (enforced by contract before run)
OLS_ADMIN_PASSWORD="${OLS_ADMIN_PASSWORD:-}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"

# Optional
PHP_VERSION="${PHP_VERSION:-8.2}"

emit_lomp_plan() {
  log_info "plan.preflight: validate inventory references and local prerequisites"
  log_info "plan.web: stage OpenLiteSpeed and PHP web actions"
  log_info "plan.data: stage MariaDB data actions"
  log_info "plan.site: stage initial site bootstrap defaults"
  log_info "plan.ops: stage backup/restore/status/diagnostics workflows"
  log_info "plan.rollback: keep previous configs and restore snapshots"
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

pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

apt_update_once() {
  local sudo_cmd="$1"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would run apt-get update"
    return 0
  fi
  ${sudo_cmd} apt-get update -y
}

apt_install_pkg() {
  local pkg="$1" sudo_cmd="$2"
  if pkg_installed "$pkg"; then
    log_info "package already installed: ${pkg}"
    return 0
  fi
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would install package: ${pkg}"
    return 0
  fi
  log_info "installing package: ${pkg}"
  ${sudo_cmd} apt-get install -y "${pkg}"
}

ols_version_check() {
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would check OpenLiteSpeed version"
    return 0
  fi
  # best-effort version check
  if command -v openlitespeed >/dev/null 2>&1; then
    openlitespeed -v >/dev/null 2>&1 || true
    log_info "OpenLiteSpeed binary present: openlitespeed"
    return 0
  fi
  if [[ -x /usr/local/lsws/bin/lshttpd ]]; then
    /usr/local/lsws/bin/lshttpd -v >/dev/null 2>&1 || true
    log_info "OpenLiteSpeed binary present: /usr/local/lsws/bin/lshttpd"
    return 0
  fi
  log_error "OpenLiteSpeed version check failed (binary not found)"
  return "${RC_EXPECTED_FAIL}"
}

ensure_litespeed_repo_if_needed() {
  # OpenLiteSpeed may not be in default Ubuntu repos; add official LiteSpeed repo if needed.
  # Uses https://repo.litespeed.sh helper (common in official guides).
  local sudo_cmd="$1"

  if apt-cache policy openlitespeed 2>/dev/null | grep -q "Candidate:"; then
    # Candidate line exists; may still be (none) but policy output differs; check:
    if apt-cache policy openlitespeed 2>/dev/null | grep -q "Candidate: (none)"; then
      :
    else
      log_debug "openlitespeed candidate appears available from apt"
      return 0
    fi
  fi

  log_warn "openlitespeed not available in current apt sources; would add LiteSpeed repository"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would run: wget -O - https://repo.litespeed.sh | ${sudo_cmd} bash"
    log_info "dry-run: would run apt-get update"
    return 0
  fi

  command -v wget >/dev/null 2>&1 || ${sudo_cmd} apt-get install -y wget
  wget -O - https://repo.litespeed.sh | ${sudo_cmd} bash
  apt_update_once "${sudo_cmd}"
}

case "${HZ_SUBCOMMAND}" in
  install|status|check|upgrade|backup|restore|uninstall|diagnostics) ;;
  *)
    log_error "missing or invalid HZ_SUBCOMMAND"
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

log_info "recipe=lomp-lite subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"

if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  log_info "check: contract vars present (enforced by hz)"
  emit_lomp_plan
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  if pkg_installed mariadb-server; then
    log_info "status: mariadb installed=yes"
  else
    log_info "status: mariadb installed=no"
  fi
  if pkg_installed openlitespeed; then
    log_info "status: openlitespeed installed=yes"
  else
    log_info "status: openlitespeed installed=no"
  fi
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "diagnostics" ]]; then
  emit_lomp_plan
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  emit_lomp_plan
  log_info "dry-run: would run apt-get update"
  log_info "dry-run: would install package: mariadb-server"
  log_info "dry-run: would install package: mariadb-client"
  log_info "dry-run: would install package: php-cli"
  log_info "dry-run: would ensure OpenLiteSpeed apt source"
  log_info "dry-run: would install package: openlitespeed"
  log_info "dry-run: would check OpenLiteSpeed version"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" != "install" ]]; then
  emit_lomp_plan
  log_warn "subcommand ${HZ_SUBCOMMAND} is plan-only in lomp-lite baseline"
  exit "${RC_SUCCESS}"
fi

sudo_cmd="$(ensure_root_or_sudo)" || exit "${RC_EXPECTED_FAIL}"

command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit "${RC_EXPECTED_FAIL}"; }
command -v dpkg >/dev/null 2>&1 || { log_error "dpkg not found"; exit "${RC_EXPECTED_FAIL}"; }

log_info "plan: minimal LOMP install (OpenLiteSpeed + MariaDB + PHP), no complex configuration"
log_debug "PHP_VERSION hint=${PHP_VERSION}"
log_debug "$(hz_mask_kv_line "OLS_ADMIN_PASSWORD=${OLS_ADMIN_PASSWORD}")"
log_debug "$(hz_mask_kv_line "DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}")"

apt_update_once "${sudo_cmd}"

# MariaDB (minimal)
apt_install_pkg "mariadb-server" "${sudo_cmd}"
apt_install_pkg "mariadb-client" "${sudo_cmd}"

# PHP minimal (do not overfit version)
apt_install_pkg "php-cli" "${sudo_cmd}"

# OpenLiteSpeed: ensure repo if needed, then install
ensure_litespeed_repo_if_needed "${sudo_cmd}"
apt_install_pkg "openlitespeed" "${sudo_cmd}"

# Version checks (DoD)
ols_version_check || exit "${RC_EXPECTED_FAIL}"

log_info "done: lomp-lite install completed (minimal)"
exit "${RC_SUCCESS}"
