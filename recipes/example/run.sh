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

log_info "recipe example subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
if [ "${HZ_DRY_RUN}" != "0" ]; then
  log_info "dry-run mode active; no system changes applied"
fi

exit "${RC_SUCCESS}"
