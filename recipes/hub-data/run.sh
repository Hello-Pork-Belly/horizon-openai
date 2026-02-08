#!/usr/bin/env bash
set -euo pipefail

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"
SITE_FILE="${SITE_FILE:-inventory/sites/site-ols-wp-maint-a.yml}"
HUB_FILE="${HUB_FILE:-inventory/hosts/hub-ols-wp-a.yml}"

case "${HZ_SUBCOMMAND}" in
  install|status|check|upgrade|backup|restore|uninstall|diagnostics) ;;
  *) log_error "missing or invalid HZ_SUBCOMMAND"; exit "${RC_EXPECTED_FAIL}" ;;
esac
case "${HZ_DRY_RUN}" in
  0|1|2) ;;
  *) log_error "invalid HZ_DRY_RUN (expected 0|1|2)"; exit "${RC_EXPECTED_FAIL}" ;;
esac

if [ ! -f "${SITE_FILE}" ] || [ ! -f "${HUB_FILE}" ]; then
  log_error "missing inventory file for hub plan rendering"
  exit "${RC_EXPECTED_FAIL}"
fi

site_id="$(awk -F ':' '/^site_id:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"
hub_ref="$(awk -F ':' '/^hub_ref:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"

log_info "recipe hub-data subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "inventory hub=${hub_ref} site=${site_id}"

echo "[INFO] plan.preflight: validate inventory and local prerequisites"
echo "[INFO] plan.network_boundary: stage tailscale0-only bind for 3306 and 6379"
echo "[INFO] plan.allowlist: stage host allowlist mapping from inventory"
echo "[INFO] plan.tenant_db: stage one-site-one-db and one-site-one-user policy"
echo "[INFO] plan.tenant_redis: stage per-site namespace isolation"
echo "[INFO] plan.backup_restore: stage backup and restore drill to neutral target"
echo "[INFO] plan.rollback: stage rollback checklist for hub-side changes"

exit "${RC_SUCCESS}"
