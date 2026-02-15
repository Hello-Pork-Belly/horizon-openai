#!/usr/bin/env bash
set -euo pipefail

# ols-wp recipe (Tier-1 wrapper)
# - Uses hz logging
# - Uses env vars enforced by contract.yml
# - Wraps legacy installer if present (do not rewrite the world yet)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../../lib/logging.sh
. "${REPO_ROOT}/lib/logging.sh"

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-install}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

# Required (enforced by contract before this runs):
WP_DOMAIN="${WP_DOMAIN:-}"
WP_EMAIL="${WP_EMAIL:-}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Optional:
WP_TITLE="${WP_TITLE:-WordPress Site}"
WP_ADMIN_USER="${WP_ADMIN_USER:-admin}"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-}"
PHP_VERSION="${PHP_VERSION:-8.2}"
OLS_ADMIN_USER="${OLS_ADMIN_USER:-admin}"
OLS_ADMIN_PASSWORD="${OLS_ADMIN_PASSWORD:-}"
OLS_WP_FORCE="${OLS_WP_FORCE:-false}"

as_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) echo "true" ;;
    0|false|FALSE|no|NO|off|OFF|"") echo "false" ;;
    *) echo "false" ;;
  esac
}

is_ols_installed() {
  [[ -x /usr/local/lsws/bin/lswsctrl ]] && return 0
  command -v lswsctrl >/dev/null 2>&1 && return 0
  return 1
}

is_ols_running() {
  # best-effort checks
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet lsws && return 0
  fi
  pgrep -f "openlitespeed|lshttpd" >/dev/null 2>&1 && return 0
  return 1
}

find_legacy_installer() {
  # Prefer stable, expected locations; then fallback to a bounded find.
  local -a candidates=(
    "${REPO_ROOT}/tools/web/install-ols-wp-standard.sh"
    "${REPO_ROOT}/tools/web/install_ols_wp_standard.sh"
    "${REPO_ROOT}/scripts/web/install-ols-wp-standard.sh"
    "${REPO_ROOT}/scripts/web/install_ols_wp_standard.sh"
    "${REPO_ROOT}/docs/archive/upstream/oneclick/install-ols-wp-standard.sh"
    "${REPO_ROOT}/docs/archive/upstream/oneclick/install_ols_wp_standard.sh"
  )

  local p
  for p in "${candidates[@]}"; do
    [[ -f "$p" ]] && { echo "$p"; return 0; }
  done

  # bounded search (avoid scanning entire history)
  p="$(find "${REPO_ROOT}" -maxdepth 6 -type f \( -name 'install-ols-wp-standard.sh' -o -name 'install_ols_wp_standard.sh' \) 2>/dev/null | head -n 1 || true)"
  [[ -n "$p" ]] && { echo "$p"; return 0; }

  return 1
}

print_effective_vars() {
  log_info "effective inputs (values masked when sensitive)"
  log_info "  WP_DOMAIN=${WP_DOMAIN}"
  log_info "  WP_EMAIL=${WP_EMAIL}"
  log_info "  PHP_VERSION=${PHP_VERSION}"
  log_info "  WP_TITLE=${WP_TITLE}"
  log_info "  WP_ADMIN_USER=${WP_ADMIN_USER}"
  log_debug "  $(hz_mask_kv_line "DB_PASSWORD=${DB_PASSWORD}")"
  log_debug "  $(hz_mask_kv_line "WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}")"
  log_debug "  $(hz_mask_kv_line "OLS_ADMIN_PASSWORD=${OLS_ADMIN_PASSWORD}")"
  log_debug "  OLS_WP_FORCE=$(as_bool "${OLS_WP_FORCE}")"
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

log_info "recipe=ols-wp subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"

# Non-destructive modes
if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  log_info "check: basic contract vars are present (already enforced by hz)"
  if is_ols_installed; then
    log_info "check: OLS appears installed"
  else
    log_warn "check: OLS not detected"
  fi
  if is_ols_running; then
    log_info "check: OLS appears running"
  else
    log_warn "check: OLS not running"
  fi
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  if is_ols_installed; then
    log_info "status: OLS installed=yes"
  else
    log_info "status: OLS installed=no"
  fi
  if is_ols_running; then
    log_info "status: OLS running=yes"
  else
    log_info "status: OLS running=no"
  fi
  exit "${RC_SUCCESS}"
fi

# For now: all other subcommands share the same "legacy entry point" mechanism.
print_effective_vars

log_info "plan.preflight: verify inventory schema and local prerequisites"
log_info "plan.web: stage OLS and WP package/config actions on host stack"
log_info "plan.site: stage virtual-host and app bootstrap actions for domain=${WP_DOMAIN:-<unset>}"
log_info "plan.data: stage database and cache reference wiring"
log_info "plan.ops: stage check/upgrade/backup/restore/uninstall/diagnostics workflows"

# Idempotency hint
if is_ols_installed; then
  log_info "preflight: OLS already installed"
  if [[ "$(as_bool "${OLS_WP_FORCE}")" != "true" ]]; then
    log_info "preflight: will still proceed (WP/site config may need apply). Set OLS_WP_FORCE=true to force reinstall semantics if supported."
  else
    log_warn "preflight: OLS_WP_FORCE=true (installer will be invoked even if installed)"
  fi
else
  log_info "preflight: OLS not detected (expected for fresh install)"
fi

legacy_installer="$(find_legacy_installer || true)"
if [[ -z "${legacy_installer}" ]]; then
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_warn "legacy installer not found (expected something like tools/web/install-ols-wp-standard.sh)"
    log_info "dry-run: legacy installer missing; execution skipped"
    exit "${RC_SUCCESS}"
  fi
  log_error "legacy installer not found (expected something like tools/web/install-ols-wp-standard.sh)"
  log_error "action: add/move the legacy installer into tools/web/ and re-run"
  exit "${RC_EXPECTED_FAIL}"
fi

log_info "legacy installer: ${legacy_installer}"

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  log_info "dry-run: would execute legacy installer with exported env vars"
  exit "${RC_SUCCESS}"
fi

# Export vars for legacy installer contract (keep names stable)
export WP_DOMAIN WP_EMAIL DB_PASSWORD
export WP_TITLE WP_ADMIN_USER WP_ADMIN_PASSWORD
export PHP_VERSION
export OLS_ADMIN_USER OLS_ADMIN_PASSWORD
export HZ_SUBCOMMAND HZ_DRY_RUN

log_info "executing legacy installer..."
bash "${legacy_installer}"
