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
HUB_DOMAIN="${HUB_DOMAIN:-}"
HUB_ADMIN_EMAIL="${HUB_ADMIN_EMAIL:-}"

# Optional connectivity targets
HUB_DB_HOST="${HUB_DB_HOST:-127.0.0.1}"
HUB_DB_PORT="${HUB_DB_PORT:-3306}"
HUB_REDIS_HOST="${HUB_REDIS_HOST:-127.0.0.1}"
HUB_REDIS_PORT="${HUB_REDIS_PORT:-6379}"
HUB_DATA_STRICT="${HUB_DATA_STRICT:-true}"

as_bool() {
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

port_check() {
  # Args: host port label
  local host="$1" port="$2" label="$3"
  local strict
  strict="$(as_bool "${HUB_DATA_STRICT}")"

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would check ${label} connectivity: ${host}:${port}"
    return 0
  fi

  if command -v nc >/dev/null 2>&1; then
    if nc -z -w 2 "${host}" "${port}" >/dev/null 2>&1; then
      log_info "hub-data ok: ${label} reachable at ${host}:${port}"
      return 0
    fi
  else
    log_warn "nc not found; skipping ${label} reachability check"
    return 0
  fi

  if [[ "${strict}" == "true" ]]; then
    log_error "hub-data not reachable: ${label} at ${host}:${port} (HUB_DATA_STRICT=true)"
    return "${RC_EXPECTED_FAIL}"
  fi

  log_warn "hub-data not reachable: ${label} at ${host}:${port} (continuing; HUB_DATA_STRICT=false)"
  return 0
}

nginx_reload() {
  local sudo_cmd="$1"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would run nginx -t && systemctl reload nginx"
    return 0
  fi
  nginx -t
  if command -v systemctl >/dev/null 2>&1; then
    ${sudo_cmd} systemctl reload nginx
  else
    ${sudo_cmd} nginx -s reload || true
  fi
}

write_file_root() {
  # Args: sudo_cmd path content
  local sudo_cmd="$1" path="$2" content="$3"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would write file: ${path}"
    return 0
  fi
  printf '%s' "${content}" | ${sudo_cmd} tee "${path}" >/dev/null
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

log_info "recipe=hub-main subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "hub domain=${HUB_DOMAIN}"
log_debug "hub admin email=${HUB_ADMIN_EMAIL}"
log_debug "hub-data targets: db=${HUB_DB_HOST}:${HUB_DB_PORT} redis=${HUB_REDIS_HOST}:${HUB_REDIS_PORT} strict=$(as_bool "${HUB_DATA_STRICT}")"

if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  log_info "check: contract vars present (enforced by hz)"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  if pkg_installed nginx; then
    log_info "status: nginx installed=yes"
  else
    log_info "status: nginx installed=no"
  fi
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  log_info "dry-run: would install package: netcat-openbsd"
  log_info "dry-run: would check redis connectivity: ${HUB_REDIS_HOST}:${HUB_REDIS_PORT}"
  log_info "dry-run: would check mariadb connectivity: ${HUB_DB_HOST}:${HUB_DB_PORT}"
  log_info "dry-run: would install package: nginx"
  log_info "dry-run: would mkdir -p /var/www/horizon-hub"
  log_info "dry-run: would write /var/www/horizon-hub/index.html"
  log_info "dry-run: would write /etc/nginx/sites-available/horizon-hub.conf"
  log_info "dry-run: would enable site and reload nginx config"
  exit "${RC_SUCCESS}"
fi

sudo_cmd="$(ensure_root_or_sudo)" || exit "${RC_EXPECTED_FAIL}"
command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit "${RC_EXPECTED_FAIL}"; }
command -v dpkg >/dev/null 2>&1 || { log_error "dpkg not found"; exit "${RC_EXPECTED_FAIL}"; }

log_info "preflight: validate hub-data connectivity (redis/mariadb)"
# Install nc if absent (best-effort) to enable checks
apt_update_once "${sudo_cmd}"
apt_install_pkg "netcat-openbsd" "${sudo_cmd}"

port_check "${HUB_REDIS_HOST}" "${HUB_REDIS_PORT}" "redis" || exit "${RC_EXPECTED_FAIL}"
port_check "${HUB_DB_HOST}" "${HUB_DB_PORT}" "mariadb" || exit "${RC_EXPECTED_FAIL}"

log_info "plan: install nginx and configure hub vhost (http/80) with a minimal dashboard"
apt_install_pkg "nginx" "${sudo_cmd}"

# Dashboard content
index_dir="/var/www/horizon-hub"
index_file="${index_dir}/index.html"
site_avail="/etc/nginx/sites-available/horizon-hub.conf"
site_enabled="/etc/nginx/sites-enabled/horizon-hub.conf"

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  log_info "dry-run: would mkdir -p ${index_dir}"
else
  ${sudo_cmd} mkdir -p "${index_dir}"
fi

index_content="<!doctype html>
<html>
<head><meta charset=\"utf-8\"><title>Horizon Hub</title></head>
<body>
<h1>Welcome to Horizon Hub</h1>
<p>Domain: ${HUB_DOMAIN}</p>
<p>Admin: ${HUB_ADMIN_EMAIL}</p>
</body>
</html>
"
write_file_root "${sudo_cmd}" "${index_file}" "${index_content}"

nginx_conf="server {
  listen 80;
  server_name ${HUB_DOMAIN};

  root ${index_dir};
  index index.html;

  location / {
    try_files \$uri \$uri/ =404;
  }
}
"
write_file_root "${sudo_cmd}" "${site_avail}" "${nginx_conf}"

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  log_info "dry-run: would enable site: ln -sf ${site_avail} ${site_enabled}"
  log_info "dry-run: would remove default site if present"
else
  ${sudo_cmd} ln -sf "${site_avail}" "${site_enabled}"
  if [[ -e /etc/nginx/sites-enabled/default ]]; then
    ${sudo_cmd} rm -f /etc/nginx/sites-enabled/default
  fi
fi

nginx_reload "${sudo_cmd}"

# Optional: legacy monitor bootstrap (read-only; not required for DoD)
legacy_monitor="${REPO_ROOT}/archive/upstream-20260215/oneclick/modules/monitor/setup-healthcheck.sh"
if [[ -f "${legacy_monitor}" ]]; then
  log_debug "legacy monitor script detected (optional): ${legacy_monitor}"
fi

log_info "done: hub-main installed (nginx vhost + dashboard)."
exit "${RC_SUCCESS}"
