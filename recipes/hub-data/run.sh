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

# Required (enforced by contract gate before run)
HUB_DB_ROOT_PASSWORD="${HUB_DB_ROOT_PASSWORD:-}"
HUB_REDIS_PASSWORD="${HUB_REDIS_PASSWORD:-}"

# Optional toggles/defaults
REDIS_ENABLED="${REDIS_ENABLED:-true}"
MARIADB_ENABLED="${MARIADB_ENABLED:-true}"
HUB_BIND_ADDR="${HUB_BIND_ADDR:-127.0.0.1}"

as_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) echo "true" ;;
    0|false|FALSE|no|NO|off|OFF|"") echo "false" ;;
    *) echo "false" ;;
  esac
}

emit_hub_plan_core() {
  log_info "plan.preflight: validate inventory and local prerequisites"
  log_info "plan.network_boundary: stage localhost-only bind for 3306 and 6379"
  log_info "plan.allowlist: stage host allowlist mapping from inventory"
  log_info "plan.tenant_db: stage one-site-one-db and one-site-one-user policy"
  log_info "plan.tenant_redis: stage per-site namespace isolation"
}

emit_hub_plan_ops() {
  log_info "plan.backup_restore: stage backup and restore drill to neutral target"
  log_info "plan.rollback: stage rollback checklist for hub-side changes"
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

svc_active() {
  local svc="$1"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet "$svc"
  else
    return 1
  fi
}

svc_restart() {
  local sudo_cmd="$1" svc="$2"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would restart service: ${svc}"
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    ${sudo_cmd} systemctl restart "$svc"
  else
    log_warn "systemctl not available; skipping restart for ${svc}"
  fi
}

redis_configure_secure() {
  local sudo_cmd="$1"
  local conf="/etc/redis/redis.conf"

  log_info "redis: secure defaults (bind=${HUB_BIND_ADDR}, protected-mode=yes, requirepass=***, no 0.0.0.0)"
  if [[ "${HUB_BIND_ADDR}" == "0.0.0.0" ]]; then
    log_error "refusing to configure redis bind=0.0.0.0 (unsafe). Set HUB_BIND_ADDR=127.0.0.1 (default)."
    return "${RC_EXPECTED_FAIL}"
  fi

  if [[ "${HZ_DRY_RUN}" == "0" ]]; then
    ${sudo_cmd} test -f "${conf}" || { log_error "redis config not found: ${conf}"; return "${RC_EXPECTED_FAIL}"; }
  fi

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would edit ${conf} (bind/protected-mode/requirepass)"
    return 0
  fi

  ${sudo_cmd} sed -i -E 's|^[[:space:]]*bind[[:space:]].*$|bind '"${HUB_BIND_ADDR}"' ::1|g' "${conf}" || true
  ${sudo_cmd} sed -i -E 's|^[[:space:]]*protected-mode[[:space:]].*$|protected-mode yes|g' "${conf}" || true

  if ${sudo_cmd} grep -Eq '^[[:space:]]*#?[[:space:]]*requirepass[[:space:]]+' "${conf}"; then
    ${sudo_cmd} sed -i -E 's|^[[:space:]]*#?[[:space:]]*requirepass[[:space:]]+.*$|requirepass '"${HUB_REDIS_PASSWORD}"'|g' "${conf}"
  else
    printf '\nrequirepass %s\n' "${HUB_REDIS_PASSWORD}" | ${sudo_cmd} tee -a "${conf}" >/dev/null
  fi
}

redis_verify() {
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would verify redis (redis-server --version, redis-cli -a *** ping)"
    return 0
  fi

  command -v redis-server >/dev/null 2>&1 || { log_error "redis-server not found"; return "${RC_EXPECTED_FAIL}"; }
  redis-server --version >/dev/null 2>&1 || true

  if command -v redis-cli >/dev/null 2>&1; then
    if redis-cli -a "${HUB_REDIS_PASSWORD}" ping 2>/dev/null | grep -q "PONG"; then
      log_info "redis: ping ok (auth)"
      return 0
    fi
    log_error "redis: ping failed (auth). Check password/config."
    return "${RC_EXPECTED_FAIL}"
  fi

  log_warn "redis-cli not available; skipping ping check"
  return 0
}

mariadb_configure_secure() {
  local sudo_cmd="$1"
  local conf="/etc/mysql/mariadb.conf.d/50-server.cnf"

  log_info "mariadb: secure defaults (bind-address=${HUB_BIND_ADDR}, no 0.0.0.0). Note: root password not auto-applied (ubuntu unix_socket risk)."
  if [[ "${HUB_BIND_ADDR}" == "0.0.0.0" ]]; then
    log_error "refusing to configure mariadb bind-address=0.0.0.0 (unsafe)."
    return "${RC_EXPECTED_FAIL}"
  fi

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would set bind-address in ${conf}"
    return 0
  fi

  ${sudo_cmd} test -f "${conf}" || { log_error "mariadb config not found: ${conf}"; return "${RC_EXPECTED_FAIL}"; }
  ${sudo_cmd} sed -i -E 's|^[[:space:]]*bind-address[[:space:]]*=.*$|bind-address = '"${HUB_BIND_ADDR}"'|g' "${conf}" || true

  if ! ${sudo_cmd} grep -Eq '^[[:space:]]*bind-address[[:space:]]*=' "${conf}"; then
    printf '\n[mysqld]\nbind-address = %s\n' "${HUB_BIND_ADDR}" | ${sudo_cmd} tee -a "${conf}" >/dev/null
  fi
}

mariadb_verify() {
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would verify mariadb (mariadb --version / mysql --version)"
    return 0
  fi

  if command -v mariadb >/dev/null 2>&1; then
    mariadb --version >/dev/null 2>&1 || true
    log_info "mariadb: binary present (mariadb)"
    return 0
  fi
  if command -v mysql >/dev/null 2>&1; then
    mysql --version >/dev/null 2>&1 || true
    log_info "mariadb: binary present (mysql)"
    return 0
  fi
  log_error "mariadb/mysql client not found"
  return "${RC_EXPECTED_FAIL}"
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

log_info "recipe=hub-data subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_debug "$(hz_mask_kv_line "HUB_DB_ROOT_PASSWORD=${HUB_DB_ROOT_PASSWORD}")"
log_debug "$(hz_mask_kv_line "HUB_REDIS_PASSWORD=${HUB_REDIS_PASSWORD}")"
log_debug "REDIS_ENABLED=$(as_bool "${REDIS_ENABLED}") MARIADB_ENABLED=$(as_bool "${MARIADB_ENABLED}") bind=${HUB_BIND_ADDR}"

# Hard safety gate: never allow 0.0.0.0 bind for mutating operations.
if [[ "${HUB_BIND_ADDR}" == "0.0.0.0" ]]; then
  case "${HZ_SUBCOMMAND}" in
    status|check|diagnostics) ;;
    *)
      log_error "refusing unsafe HUB_BIND_ADDR=0.0.0.0"
      exit "${RC_EXPECTED_FAIL}"
      ;;
  esac
fi

if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  emit_hub_plan_core
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  if pkg_installed redis-server; then
    log_info "status: redis installed=yes"
  else
    log_info "status: redis installed=no"
  fi
  if pkg_installed mariadb-server; then
    log_info "status: mariadb installed=yes"
  else
    log_info "status: mariadb installed=no"
  fi
  if svc_active redis-server; then
    log_info "status: redis active=yes"
  else
    log_info "status: redis active=no"
  fi
  if svc_active mariadb; then
    log_info "status: mariadb active=yes"
  else
    log_info "status: mariadb active=no"
  fi
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "diagnostics" ]]; then
  emit_hub_plan_ops
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  emit_hub_plan_core
  emit_hub_plan_ops
  log_info "dry-run: would install and configure redis/mariadb with safe bind boundary"
  log_info "dry-run: would install package: redis-server"
  log_info "dry-run: would install package: mariadb-server"
  log_info "dry-run: would restart services and verify versions/auth"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" != "install" ]]; then
  emit_hub_plan_core
  emit_hub_plan_ops
  log_warn "subcommand ${HZ_SUBCOMMAND} is plan-only in hub-data baseline"
  exit "${RC_SUCCESS}"
fi

sudo_cmd="$(ensure_root_or_sudo)" || exit "${RC_EXPECTED_FAIL}"
command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit "${RC_EXPECTED_FAIL}"; }
command -v dpkg >/dev/null 2>&1 || { log_error "dpkg not found"; exit "${RC_EXPECTED_FAIL}"; }

log_info "plan: install data services (redis + mariadb) with safe bind boundary (localhost by default)"
apt_update_once "${sudo_cmd}"

if [[ "$(as_bool "${REDIS_ENABLED}")" == "true" ]]; then
  apt_install_pkg "redis-server" "${sudo_cmd}"
  redis_configure_secure "${sudo_cmd}" || exit "${RC_EXPECTED_FAIL}"
  svc_restart "${sudo_cmd}" "redis-server"
  redis_verify || exit "${RC_EXPECTED_FAIL}"
else
  log_info "redis: disabled (REDIS_ENABLED=false)"
fi

if [[ "$(as_bool "${MARIADB_ENABLED}")" == "true" ]]; then
  apt_install_pkg "mariadb-server" "${sudo_cmd}"
  mariadb_configure_secure "${sudo_cmd}" || exit "${RC_EXPECTED_FAIL}"
  svc_restart "${sudo_cmd}" "mariadb"
  mariadb_verify || exit "${RC_EXPECTED_FAIL}"
else
  log_info "mariadb: disabled (MARIADB_ENABLED=false)"
fi

log_info "done: hub-data install completed (minimal, idempotent)"
exit "${RC_SUCCESS}"
