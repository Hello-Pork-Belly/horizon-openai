#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
# shellcheck source=lib/baseline/loader.sh
. "${REPO_ROOT}/lib/baseline/loader.sh"

HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

log_info "diagnostics: start (dry_run=${HZ_DRY_RUN})"
log_info "diagnostics: repo_root=${REPO_ROOT}"

# Run checks. Each check must be non-fatal.
run_check() {
  local name="$1"
  shift
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would run check: ${name}"
    return 0
  fi
  if "$@"; then
    return 0
  fi
  log_warn "diagnostics: check failed: ${name} (continuing)"
  return 0
}

run_check "disk" baseline_check_disk
run_check "memory" baseline_check_memory
run_check "cpu_load" baseline_check_cpu_load

run_check "web_services" baseline_check_web_stack
run_check "data_services" baseline_check_data_stack

run_check "internet" baseline_check_internet
run_check "dns" baseline_check_dns

log_info "diagnostics: done"
