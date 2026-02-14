#!/usr/bin/env bash
set -euo pipefail

OLS_CONF="${OLS_CONF:-/usr/local/lsws/conf/httpd_config.conf}"
DRY_RUN="${DRY_RUN:-0}"
DEFAULT_MAX_CONNECTIONS=2000
DEFAULT_INSTANCES=35

log_info() {
  printf '[INFO] %s\n' "$1"
}

log_warn() {
  printf '[WARN] %s\n' "$1"
}

log_error() {
  printf '[ERROR] %s\n' "$1" >&2
}

die() {
  log_error "$1"
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "This script must run as root. Example: sudo OLS_ADMIN_PASS=... bash tools/web/setup_ols_native.sh"
  fi
}

require_env() {
  if [[ -z "${OLS_ADMIN_PASS:-}" ]]; then
    die "OLS_ADMIN_PASS must be set in the environment."
  fi
}

ensure_backup() {
  if [[ ! -f "${OLS_CONF}.bak" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      log_info "[DRY-RUN] Would create backup at ${OLS_CONF}.bak"
    else
      cp "${OLS_CONF}" "${OLS_CONF}.bak"
      log_info "Backup created at ${OLS_CONF}.bak"
    fi
  fi
}

set_config_value() {
  local key="$1"
  local value="$2"

  if grep -Eq "^[[:space:]]*${key}([[:space:]]|$)" "${OLS_CONF}"; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      log_info "[DRY-RUN] Would set ${key} ${value} in ${OLS_CONF}"
    else
      sed -i -E "s|^\s*${key}\b.*|${key} ${value}|" "${OLS_CONF}"
      log_info "Set ${key} ${value} in ${OLS_CONF}"
    fi
  else
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      log_info "[DRY-RUN] Would append ${key} ${value} to ${OLS_CONF}"
    else
      printf '%s %s\n' "${key}" "${value}" >> "${OLS_CONF}"
      log_info "Appended ${key} ${value} to ${OLS_CONF}"
    fi
  fi
}

ensure_key_exists() {
  local key="$1"
  local value="$2"

  if grep -Eq "^[[:space:]]*${key}([[:space:]]|$)" "${OLS_CONF}"; then
    log_info "${key} already present; leaving current value unchanged."
  else
    ensure_backup
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      log_warn "[DRY-RUN] ${key} missing; would append default ${value}."
    else
      printf '%s %s\n' "${key}" "${value}" >> "${OLS_CONF}"
      log_warn "${key} missing; appended default ${value}."
    fi
  fi
}

require_root
require_env

if [[ ! -f "${OLS_CONF}" ]]; then
  die "OLS config not found at ${OLS_CONF}."
fi

ram_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [[ -z "${ram_mb}" ]]; then
  die "Unable to detect system memory."
fi

log_info "Detected RAM: ${ram_mb} MB"
log_info "Using OLS config: ${OLS_CONF}"

if [[ "${ram_mb}" -lt 1900 ]]; then
  log_warn "Low-memory system detected. Enforcing conservative OLS limits."
  ensure_backup
  set_config_value "maxConnections" "10"
  set_config_value "instances" "10"
else
  log_info "RAM threshold met; keeping default OLS limits."
  ensure_key_exists "maxConnections" "${DEFAULT_MAX_CONNECTIONS}"
  ensure_key_exists "instances" "${DEFAULT_INSTANCES}"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  log_info "[DRY-RUN] No changes were written."
else
  log_info "Current OLS limits:"
  grep -nE "^[[:space:]]*(maxConnections|instances)([[:space:]]|$)" "${OLS_CONF}" || log_warn "No OLS limit keys found."
fi
