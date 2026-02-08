#!/usr/bin/env bash
set -euo pipefail

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

log_info() { echo "[INFO] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"
HOST_FILE="${HOST_FILE:-inventory/hosts/host-ols-wp-a.yml}"

case "${HZ_SUBCOMMAND}" in
  install|status|check|upgrade|backup|restore|uninstall|diagnostics) ;;
  *) log_error "missing or invalid HZ_SUBCOMMAND"; exit "${RC_EXPECTED_FAIL}" ;;
esac
case "${HZ_DRY_RUN}" in
  0|1|2) ;;
  *) log_error "invalid HZ_DRY_RUN (expected 0|1|2)"; exit "${RC_EXPECTED_FAIL}" ;;
esac

if [ ! -f "${HOST_FILE}" ]; then
  log_error "missing inventory file for security plan rendering"
  exit "${RC_EXPECTED_FAIL}"
fi

host_id="$(awk -F ':' '/^id:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${HOST_FILE}")"

log_info "recipe security-host subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "inventory host=${host_id}"

echo "[INFO] plan.preflight: validate inventory and local prerequisites"
echo "[INFO] plan.bruteforce_guard: stage remote access guard policy"
echo "[INFO] plan.rootkit_scan: stage periodic scan and report plan"
echo "[INFO] plan.log_retention: stage log rotation and cap policy"
echo "[INFO] plan.alert_mail: stage notification route checks"
echo "[INFO] plan.thresholds: stage CPU/RAM/disk threshold checks"
echo "[INFO] plan.service_watch: stage service liveness checks"
echo "[INFO] plan.rollback: stage rollback checklist"

exit "${RC_SUCCESS}"
