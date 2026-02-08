#!/usr/bin/env bash
set -euo pipefail

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"
SITE_FILE="${SITE_FILE:-inventory/sites/site-ols-wp-maint-a.yml}"

case "${HZ_SUBCOMMAND}" in
  install|status|check|upgrade|backup|restore|uninstall|diagnostics) ;;
  *) log_error "missing or invalid HZ_SUBCOMMAND"; exit "${RC_EXPECTED_FAIL}" ;;
esac
case "${HZ_DRY_RUN}" in
  0|1|2) ;;
  *) log_error "invalid HZ_DRY_RUN (expected 0|1|2)"; exit "${RC_EXPECTED_FAIL}" ;;
esac

if [ ! -f "${SITE_FILE}" ]; then
  log_error "missing inventory file for lnmp-lite plan rendering"
  exit "${RC_EXPECTED_FAIL}"
fi

site_id="$(awk -F ':' '/^site_id:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"

log_info "recipe lnmp-lite subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "inventory site=${site_id}"

echo "[INFO] plan.preflight: validate inventory and local prerequisites"
echo "[INFO] plan.web_nginx_php: stage Nginx and PHP-FPM web actions"
echo "[INFO] plan.shared_hub_data: stage shared hub data service actions"
echo "[INFO] plan.shared_maintenance: stage shared maintenance actions"
echo "[INFO] plan.shared_security: stage shared security and alert actions"
echo "[INFO] plan.rollback: stage rollback checklist"

exit "${RC_SUCCESS}"
