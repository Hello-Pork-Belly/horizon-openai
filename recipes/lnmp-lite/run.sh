#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=lib/cli_core.sh
. "${REPO_ROOT}/lib/cli_core.sh"

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-install}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
PHP_VERSION="${PHP_VERSION:-8.2}"

emit_lnmp_plan() {
  log_info "plan.preflight: validate inventory and local prerequisites"
  log_info "plan.web_nginx_php: stage Nginx and PHP-FPM web actions"
  log_info "plan.shared_hub_data: stage shared hub data service actions"
  log_info "plan.shared_maintenance: stage shared maintenance actions"
  log_info "plan.shared_security: stage shared security and alert actions"
  log_info "plan.rollback: stage rollback checklist"
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

nginx_version_check() {
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would run nginx -v"
    return 0
  fi
  command -v nginx >/dev/null 2>&1 || { log_error "nginx not found after install"; return "${RC_EXPECTED_FAIL}"; }
  nginx -v >/dev/null 2>&1 || true
  log_info "nginx present: $(command -v nginx)"
  return 0
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

log_info "recipe=lnmp-lite subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"

if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  emit_lnmp_plan
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  pkg_installed nginx && log_info "status: nginx installed=yes" || log_info "status: nginx installed=no"
  pkg_installed mariadb-server && log_info "status: mariadb installed=yes" || log_info "status: mariadb installed=no"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "diagnostics" ]]; then
  emit_lnmp_plan
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  emit_lnmp_plan
  log_info "dry-run: would run apt-get update"
  log_info "dry-run: would install package: nginx"
  log_info "dry-run: would install package: mariadb-server"
  log_info "dry-run: would install package: php-fpm"
  log_info "dry-run: would run nginx -v"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" != "install" ]]; then
  emit_lnmp_plan
  log_warn "subcommand ${HZ_SUBCOMMAND} is plan-only in lnmp-lite baseline"
  exit "${RC_SUCCESS}"
fi

sudo_cmd="$(ensure_root_or_sudo)" || exit "${RC_EXPECTED_FAIL}"

command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit "${RC_EXPECTED_FAIL}"; }
command -v dpkg >/dev/null 2>&1 || { log_error "dpkg not found"; exit "${RC_EXPECTED_FAIL}"; }

log_info "plan: minimal LNMP install (Nginx + MariaDB + PHP-FPM), no complex configuration"
log_debug "PHP_VERSION hint=${PHP_VERSION}"
log_debug "$(hz_mask_kv_line "DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}")"

apt_update_once "${sudo_cmd}"

apt_install_pkg "nginx" "${sudo_cmd}"
apt_install_pkg "mariadb-server" "${sudo_cmd}"
apt_install_pkg "php-fpm" "${sudo_cmd}"

nginx_version_check || exit "${RC_EXPECTED_FAIL}"

log_info "done: lnmp-lite install completed (minimal)"
exit "${RC_SUCCESS}"
