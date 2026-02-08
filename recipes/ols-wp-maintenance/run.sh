#!/usr/bin/env bash
set -euo pipefail

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

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

SITE_FILE="${SITE_FILE:-inventory/sites/site-ols-wp-a.yml}"
HOST_FILE="${HOST_FILE:-inventory/hosts/host-ols-wp-a.yml}"
HUB_FILE="${HUB_FILE:-inventory/hosts/hub-ols-wp-a.yml}"

if [ ! -f "${SITE_FILE}" ] || [ ! -f "${HOST_FILE}" ] || [ ! -f "${HUB_FILE}" ]; then
  log_error "missing inventory file for maintenance plan rendering"
  exit "${RC_EXPECTED_FAIL}"
fi

site_id="$(awk -F ':' '/^site_id:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"
host_ref="$(awk -F ':' '/^host_ref:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"

log_info "recipe ols-wp-maintenance subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "inventory host=${host_ref} site=${site_id}"

echo "[INFO] plan.preflight: validate inventory and local prerequisites"
echo "[INFO] plan.permissions: stage owner/group/mode targets for runtime paths"
echo "[INFO] plan.certificate: stage certificate renewal precheck and postcheck"
echo "[INFO] plan.php_limits: stage worker and resource cap targets by ram tier"
echo "[INFO] plan.swap: stage swap sizing and activation checks"
echo "[INFO] plan.scheduler: stage cron and app scheduler policy"
echo "[INFO] plan.backup_restore: stage backup/restore drill with neutral storage target"
echo "[INFO] plan.site_health: stage health check targets and thresholds"
echo "[INFO] plan.rollback: stage rollback checklist and validation"

exit "${RC_SUCCESS}"
