#!/usr/bin/env bash
set -euo pipefail

# loader.sh
# - Establish REPO_ROOT
# - Source logging/cli core (if present)
# - Source all baseline scripts (including legacy moved in), best-effort and non-fatal

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Prefer cli_core.sh (it usually wires logging); fallback to logging.sh
if [[ -f "${REPO_ROOT}/lib/cli_core.sh" ]]; then
  # shellcheck disable=SC1091
  # shellcheck source=lib/cli_core.sh
  . "${REPO_ROOT}/lib/cli_core.sh"
elif [[ -f "${REPO_ROOT}/lib/logging.sh" ]]; then
  # shellcheck disable=SC1091
  # shellcheck source=lib/logging.sh
  . "${REPO_ROOT}/lib/logging.sh"
else
  # Minimal no-op logger fallback (should not happen in this repo)
  log_info() { echo "[INFO] $*"; }
  log_warn() { echo "[WARN] $*"; }
  log_error() { echo "[ERROR] $*" >&2; }
  log_debug() { :; }
fi

HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

baseline_safe_source() {
  local f="$1"
  [[ -f "$f" ]] || return 0

  # Do not let legacy scripts kill the whole diagnose run.
  # shellcheck disable=SC1090
  if ! . "$f"; then
    log_warn "baseline: failed to source: ${f} (continuing)"
    return 0
  fi
  return 0
}

baseline_load_all() {
  local dir="${REPO_ROOT}/lib/baseline"
  local f

  [[ -d "${dir}" ]] || { log_warn "baseline: missing dir ${dir}"; return 0; }

  # Load our modern wrappers first (stable API), then legacy.
  for f in "${dir}/baseline_system.sh" "${dir}/baseline_services.sh" "${dir}/baseline_network.sh"; do
    baseline_safe_source "$f"
  done

  # Load all remaining baseline*.sh (including migrated legacy) excluding the three above + loader itself.
  for f in "${dir}"/baseline*.sh; do
    [[ -e "$f" ]] || break
    case "$f" in
      */baseline_system.sh|*/baseline_services.sh|*/baseline_network.sh) continue ;;
      */loader.sh) continue ;;
    esac
    baseline_safe_source "$f"
  done
}

baseline_load_all
