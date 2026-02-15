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

# Required (contract gate)
BACKUP_ENDPOINT="${BACKUP_ENDPOINT:-}"
BACKUP_ACCESS_KEY_ID="${BACKUP_ACCESS_KEY_ID:-}"
BACKUP_SECRET_ACCESS_KEY="${BACKUP_SECRET_ACCESS_KEY:-}"
BACKUP_BUCKET="${BACKUP_BUCKET:-}"

# Optional
BACKUP_PROVIDER="${BACKUP_PROVIDER:-s3}"
BACKUP_REMOTE_NAME="${BACKUP_REMOTE_NAME:-remote}"
BACKUP_SOURCE="${BACKUP_SOURCE:-/var/www}"
BACKUP_SCHEDULE="${BACKUP_SCHEDULE:-}"

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
  if dpkg -s "$pkg" >/dev/null 2>&1; then
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

version_ge_150() {
  # Return 0 if rclone version >= 1.50 (best-effort parse)
  local v major minor
  v="$(rclone version 2>/dev/null | head -n 1 | awk '{print $2}' | sed 's/^v//')"
  major="${v%%.*}"
  minor="$(echo "$v" | cut -d. -f2)"
  [[ -n "${major}" && -n "${minor}" ]] || return 1
  if [[ "${major}" -gt 1 ]]; then return 0; fi
  if [[ "${major}" -lt 1 ]]; then return 1; fi
  [[ "${minor}" -ge 50 ]]
}

ensure_rclone() {
  local sudo_cmd="$1"

  # Try OS package first
  apt_update_once "${sudo_cmd}"
  apt_install_pkg "rclone" "${sudo_cmd}"

  if command -v rclone >/dev/null 2>&1; then
    if version_ge_150; then
      log_info "rclone ok (version >= 1.50)"
      return 0
    fi
    log_warn "rclone present but version appears old; will fallback to official installer"
  else
    log_warn "rclone not found after apt; will fallback to official installer"
  fi

  # Fallback: official installer (curl | bash). Only in non-dry-run.
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would install rclone via official installer: curl https://rclone.org/install.sh | bash"
    return 0
  fi

  apt_install_pkg "curl" "${sudo_cmd}"
  log_info "installing rclone via official installer"
  curl -fsSL https://rclone.org/install.sh | ${sudo_cmd} bash

  command -v rclone >/dev/null 2>&1 || { log_error "rclone install failed"; return "${RC_EXPECTED_FAIL}"; }
  log_info "rclone installed (fallback)"
  return 0
}

write_rclone_conf() {
  local home_dir conf_dir conf_file
  home_dir="${HOME:-/root}"
  conf_dir="${home_dir}/.config/rclone"
  conf_file="${conf_dir}/rclone.conf"

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would create ${conf_file} (mode 600)"
    return 0
  fi

  umask 077
  mkdir -p "${conf_dir}"

  # Only S3 in this task (per contract default/provider)
  if [[ "${BACKUP_PROVIDER}" != "s3" ]]; then
    log_error "unsupported BACKUP_PROVIDER: ${BACKUP_PROVIDER} (only s3 supported in T-015)"
    return "${RC_EXPECTED_FAIL}"
  fi

  # Config stanza (non-interactive). Keep minimal + compatible.
  # NOTE: We intentionally keep credentials in file (required by spec). File mode 600.
  cat >"${conf_file}" <<EOC
[${BACKUP_REMOTE_NAME}]
type = s3
provider = Other
env_auth = false
access_key_id = ${BACKUP_ACCESS_KEY_ID}
secret_access_key = ${BACKUP_SECRET_ACCESS_KEY}
endpoint = ${BACKUP_ENDPOINT}
acl = private
EOC

  chmod 600 "${conf_file}"
  log_info "rclone config written: ${conf_file} (600)"
  return 0
}

verify_remote() {
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would verify remote via: rclone lsd ${BACKUP_REMOTE_NAME}:"
    return 0
  fi

  # Verify credentials by listing top-level (buckets). Some providers may not allow listing;
  # if so, try listing bucket path as fallback.
  if rclone lsd "${BACKUP_REMOTE_NAME}:" >/dev/null 2>&1; then
    log_info "verify: rclone lsd ${BACKUP_REMOTE_NAME}: ok"
    return 0
  fi

  if rclone lsd "${BACKUP_REMOTE_NAME}:${BACKUP_BUCKET}" >/dev/null 2>&1; then
    log_info "verify: rclone lsd ${BACKUP_REMOTE_NAME}:${BACKUP_BUCKET} ok"
    return 0
  fi

  log_error "verify failed: cannot access remote/bucket with provided credentials"
  return "${RC_EXPECTED_FAIL}"
}

setup_cron_if_requested() {
  local sudo_cmd="$1"
  [[ -n "${BACKUP_SCHEDULE}" ]] || return 0

  local cron_file="/etc/cron.d/horizon-backup-rclone"
  local job
  job="${BACKUP_SCHEDULE} root rclone sync '${BACKUP_SOURCE}' '${BACKUP_REMOTE_NAME}:${BACKUP_BUCKET}' --fast-list --ignore-existing >>/var/log/horizon-backup-rclone.log 2>&1
"

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would write cron file ${cron_file}"
    log_info "dry-run: would ensure /var/log/horizon-backup-rclone.log exists (600)"
    return 0
  fi

  printf '%s' "${job}" | ${sudo_cmd} tee "${cron_file}" >/dev/null
  ${sudo_cmd} chmod 644 "${cron_file}"
  ${sudo_cmd} touch /var/log/horizon-backup-rclone.log
  ${sudo_cmd} chmod 600 /var/log/horizon-backup-rclone.log

  log_info "cron installed: ${cron_file}"
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

log_info "recipe=backup-rclone subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "provider=${BACKUP_PROVIDER} remote=${BACKUP_REMOTE_NAME} bucket=${BACKUP_BUCKET}"
log_debug "endpoint=${BACKUP_ENDPOINT}"
log_debug "$(hz_mask_kv_line "BACKUP_ACCESS_KEY_ID=${BACKUP_ACCESS_KEY_ID}")"
log_debug "$(hz_mask_kv_line "BACKUP_SECRET_ACCESS_KEY=${BACKUP_SECRET_ACCESS_KEY}")"

if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  log_info "check: contract vars present (enforced by hz)"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  if command -v rclone >/dev/null 2>&1; then
    log_info "status: rclone installed=yes"
  else
    log_info "status: rclone installed=no"
  fi
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  log_info "dry-run: would run apt-get update"
  log_info "dry-run: would install package: rclone"
  log_info "dry-run: would fallback to installer if rclone missing/old (<1.50)"
  log_info "dry-run: would create ~/.config/rclone/rclone.conf (600)"
  log_info "dry-run: would verify remote via: rclone lsd ${BACKUP_REMOTE_NAME}:"
  if [[ -n "${BACKUP_SCHEDULE}" ]]; then
    log_info "dry-run: would write cron file /etc/cron.d/horizon-backup-rclone"
  fi
  log_info "done: backup-rclone configured"
  exit "${RC_SUCCESS}"
fi

sudo_cmd="$(ensure_root_or_sudo)" || exit "${RC_EXPECTED_FAIL}"
command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit "${RC_EXPECTED_FAIL}"; }
command -v dpkg >/dev/null 2>&1 || { log_error "dpkg not found"; exit "${RC_EXPECTED_FAIL}"; }

ensure_rclone "${sudo_cmd}" || exit "${RC_EXPECTED_FAIL}"

write_rclone_conf || exit "${RC_EXPECTED_FAIL}"

verify_remote || exit "${RC_EXPECTED_FAIL}"

setup_cron_if_requested "${sudo_cmd}" || exit "${RC_EXPECTED_FAIL}"

log_info "done: backup-rclone configured"
exit "${RC_SUCCESS}"
