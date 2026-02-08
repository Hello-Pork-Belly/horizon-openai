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

SITE_FILE="${SITE_FILE:-inventory/sites/site-example.yml}"
HOST_FILE="${HOST_FILE:-inventory/hosts/host-example.yml}"
HUB_FILE="${HUB_FILE:-inventory/hosts/hub-example.yml}"

if [ ! -f "${SITE_FILE}" ] || [ ! -f "${HOST_FILE}" ] || [ ! -f "${HUB_FILE}" ]; then
  log_error "missing inventory file for plan rendering"
  exit "${RC_EXPECTED_FAIL}"
fi

site_id="$(awk -F ':' '/^site_id:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"
host_ref="$(awk -F ':' '/^host_ref:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"
hub_ref="$(awk -F ':' '/^hub_ref:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' "${SITE_FILE}")"

log_info "recipe ols-wp subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "inventory host=${host_ref} hub=${hub_ref} site=${site_id}"

if [ "${HZ_DRY_RUN}" = "0" ]; then
  log_info "apply mode is reserved; emitting plan-only output for repo-only baseline"
fi

echo "[INFO] plan.preflight: verify inventory schema and local prerequisites"
echo "[INFO] plan.web: stage OLS and WP package/config actions on host=${host_ref}"
echo "[INFO] plan.site: stage virtual-host and app bootstrap actions for site=${site_id}"
echo "[INFO] plan.data: stage database and cache reference wiring on hub=${hub_ref}"
echo "[INFO] plan.ops: stage check/upgrade/backup/restore/uninstall/diagnostics workflows"
echo "[INFO] plan.rollback: preserve prior configs and restore previous inventory snapshot"

exit "${RC_SUCCESS}"
