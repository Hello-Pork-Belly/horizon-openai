#!/usr/bin/env bash
set -euo pipefail

# ols-wp-maintenance recipe: dispatcher wrapper for maintenance operations.
# Contract-first: required_env enforced by hz before this script runs.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
# shellcheck source=../../lib/cli_core.sh
. "${REPO_ROOT}/lib/cli_core.sh"

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-install}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

WP_DOMAIN="${WP_DOMAIN:-}"
MAINTENANCE_ACTION="${MAINTENANCE_ACTION:-}"

BACKUP_DIR="${BACKUP_DIR:-}"
RESTORE_SRC="${RESTORE_SRC:-}"

find_tool() {
  # Args: list of basenames
  # Search priority:
  # 1) tools/web/<name>
  # 2) repo bounded find under tools/web (maxdepth)
  local name path
  for name in "$@"; do
    path="${REPO_ROOT}/tools/web/${name}"
    [[ -f "${path}" ]] && { echo "${path}"; return 0; }
  done

  # bounded fallback within tools/web
  for name in "$@"; do
    path="$(find "${REPO_ROOT}/tools/web" -maxdepth 2 -type f -name "${name}" 2>/dev/null | head -n 1 || true)"
    [[ -n "${path}" ]] && { echo "${path}"; return 0; }
  done

  return 1
}

run_tool() {
  # Args: tool_path, label
  local tool="$1" label="$2"

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would execute ${label}: ${tool}"
    return 0
  fi

  [[ -x "${tool}" ]] || chmod +x "${tool}" 2>/dev/null || true

  log_info "executing ${label}: ${tool}"
  bash "${tool}"
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

log_info "recipe=ols-wp-maintenance subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_debug "inputs: WP_DOMAIN=${WP_DOMAIN} MAINTENANCE_ACTION=${MAINTENANCE_ACTION}"

# Non-destructive helpers
if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  log_info "plan.preflight: validate inventory and local prerequisites"
  log_info "plan.permissions: stage owner/group/mode targets for runtime paths"
  log_info "plan.certificate: stage certificate renewal precheck and postcheck"
  log_info "plan.php_limits: stage worker and resource cap targets by ram tier"
  log_info "plan.swap: stage swap sizing and activation checks"
  log_info "plan.scheduler: stage cron and app scheduler policy"
  log_info "plan.backup_restore: stage backup/restore drill with neutral storage target"
  log_info "check: contract vars present (enforced by hz)"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "diagnostics" ]]; then
  log_info "plan.site_health: stage health check targets and thresholds"
  log_info "plan.rollback: stage rollback checklist and validation"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  log_info "status: MAINTENANCE_ACTION=${MAINTENANCE_ACTION}"
  exit "${RC_SUCCESS}"
fi

# Export shared vars for legacy tools
export WP_DOMAIN MAINTENANCE_ACTION
export BACKUP_DIR RESTORE_SRC

# Map hz dry-run into a common legacy convention
if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  export DRY_RUN=1
else
  export DRY_RUN=0
fi

action="${MAINTENANCE_ACTION}"

case "${action}" in
  backup)
    # Preferred legacy tool names (may vary; we search multiple)
    tool="$(find_tool \
      "setup-wp-backup-basic.sh" \
      "setup_wp_backup_basic.sh" \
      "setup-wp-backup.sh" \
      "setup_wp_backup.sh" \
      "wp-backup.sh" \
    || true)"
    if [[ -z "${tool}" ]] && [[ "${HZ_DRY_RUN}" != "0" ]]; then
      log_warn "backup tool not found under tools/web (expected setup-wp-backup-basic.sh or similar)"
      log_info "dry-run: would execute backup: <tool-not-found>"
      log_info "done: ols-wp-maintenance action=${action}"
      exit "${RC_SUCCESS}"
    fi
    [[ -n "${tool}" ]] || {
      log_error "backup tool not found under tools/web (expected setup-wp-backup-basic.sh or similar)"
      exit "${RC_EXPECTED_FAIL}"
    }
    run_tool "${tool}" "backup"
    ;;

  restore_pre)
    # Restore preflight / staging (placeholder wrapper)
    tool="$(find_tool \
      "setup-wp-restore-pre.sh" \
      "setup_wp_restore_pre.sh" \
      "wp-restore-pre.sh" \
    || true)"
    if [[ -z "${tool}" ]] && [[ "${HZ_DRY_RUN}" != "0" ]]; then
      log_warn "restore_pre tool not found under tools/web (expected setup-wp-restore-pre.sh or similar)"
      log_info "dry-run: would execute restore_pre: <tool-not-found>"
      log_info "done: ols-wp-maintenance action=${action}"
      exit "${RC_SUCCESS}"
    fi
    [[ -n "${tool}" ]] || {
      log_error "restore_pre tool not found under tools/web (expected setup-wp-restore-pre.sh or similar)"
      exit "${RC_EXPECTED_FAIL}"
    }
    run_tool "${tool}" "restore_pre"
    ;;

  cron)
    tool="$(find_tool \
      "gen-wp-cron.sh" \
      "gen_wp_cron.sh" \
      "setup-wp-cron.sh" \
      "setup_wp_cron.sh" \
    || true)"
    if [[ -z "${tool}" ]] && [[ "${HZ_DRY_RUN}" != "0" ]]; then
      log_warn "cron tool not found under tools/web (expected gen-wp-cron.sh or similar)"
      log_info "dry-run: would execute cron: <tool-not-found>"
      log_info "done: ols-wp-maintenance action=${action}"
      exit "${RC_SUCCESS}"
    fi
    [[ -n "${tool}" ]] || {
      log_error "cron tool not found under tools/web (expected gen-wp-cron.sh or similar)"
      exit "${RC_EXPECTED_FAIL}"
    }
    run_tool "${tool}" "cron"
    ;;

  ssl_renew)
    # Spec hint: reuse existing OLS-related tool if available.
    tool="$(find_tool \
      "ssl-renew.sh" \
      "ssl_renew.sh" \
      "setup-ssl-renew.sh" \
      "setup_ssl_renew.sh" \
      "setup_ols_native.sh" \
    || true)"
    if [[ -z "${tool}" ]] && [[ "${HZ_DRY_RUN}" != "0" ]]; then
      log_warn "ssl_renew tool not found under tools/web (expected setup_ols_native.sh or ssl-renew.sh)"
      log_info "dry-run: would execute ssl_renew: <tool-not-found>"
      log_info "done: ols-wp-maintenance action=${action}"
      exit "${RC_SUCCESS}"
    fi
    [[ -n "${tool}" ]] || {
      log_error "ssl_renew tool not found under tools/web (expected setup_ols_native.sh or ssl-renew.sh)"
      exit "${RC_EXPECTED_FAIL}"
    }
    run_tool "${tool}" "ssl_renew"
    ;;

  *)
    log_error "unknown MAINTENANCE_ACTION: ${action} (supported: backup, restore_pre, ssl_renew, cron)"
    exit "${RC_EXPECTED_FAIL}"
    ;;
esac

log_info "done: ols-wp-maintenance action=${action}"
exit "${RC_SUCCESS}"
