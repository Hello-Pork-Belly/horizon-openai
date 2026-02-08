#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

CHECK_DIRS=(scripts recipes modules upstream/oneclick)

echo "[check] shell syntax"
while IFS= read -r script_file; do
  bash -n "$script_file"
done < <(find "${CHECK_DIRS[@]}" -type f -name '*.sh' | sort)

if command -v shellcheck >/dev/null 2>&1; then
  echo "[check] shellcheck"
  while IFS= read -r script_file; do
    shellcheck "$script_file"
  done < <(find "${CHECK_DIRS[@]}" -type f -name '*.sh' | sort)
else
  echo "[check] shellcheck skipped (not installed)"
fi

if [ -x "scripts/check/inventory_validate.sh" ]; then
  echo "[check] inventory"
  bash scripts/check/inventory_validate.sh
else
  echo "[check] inventory skipped (validator not present)"
fi

if [ -x "scripts/check/interface_consistency.sh" ]; then
  echo "[check] interface"
  bash scripts/check/interface_consistency.sh
else
  echo "[check] interface skipped (checker not present)"
fi

if [ -x "scripts/check/lomp_lite_dryrun_check.sh" ]; then
  echo "[check] lomp-lite"
  bash scripts/check/lomp_lite_dryrun_check.sh
else
  echo "[check] lomp-lite skipped (checker not present)"
fi

if [ -x "scripts/check/ols_wp_dryrun_check.sh" ]; then
  echo "[check] ols-wp"
  bash scripts/check/ols_wp_dryrun_check.sh
else
  echo "[check] ols-wp skipped (checker not present)"
fi

if [ -x "scripts/check/ols_wp_maintenance_dryrun_check.sh" ]; then
  echo "[check] ols-wp-maintenance"
  bash scripts/check/ols_wp_maintenance_dryrun_check.sh
else
  echo "[check] ols-wp-maintenance skipped (checker not present)"
fi
if [ -x "scripts/check/hub_data_dryrun_check.sh" ]; then
  echo "[check] hub-data"
  bash scripts/check/hub_data_dryrun_check.sh
else
  echo "[check] hub-data skipped (checker not present)"
fi
if [ -x "scripts/check/security_host_dryrun_check.sh" ]; then
  echo "[check] security-host"
  bash scripts/check/security_host_dryrun_check.sh
else
  echo "[check] security-host skipped (checker not present)"
fi
if [ -x "scripts/check/lnmp_lite_dryrun_check.sh" ]; then
  echo "[check] lnmp-lite"
  bash scripts/check/lnmp_lite_dryrun_check.sh
else
  echo "[check] lnmp-lite skipped (checker not present)"
fi

if [ -x "scripts/check/masking_rules_check.sh" ]; then
  echo "[check] masking"
  bash scripts/check/masking_rules_check.sh
else
  echo "[check] masking skipped (checker not present)"
fi




if command -v shfmt >/dev/null 2>&1; then
  echo "[check] shfmt"
  shfmt -d scripts
else
  echo "[check] shfmt skipped (not installed)"
fi

echo "[check] smoke"
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]] && [[ "$(uname -s)" == "Linux" ]]; then
  bash scripts/clean_node.sh --dry-run
else
  echo "[check] smoke skipped (requires bash>=4 on Linux)"
fi

echo "[check] vendor-neutral"
bash scripts/check/vendor_neutral_gate.sh

echo "[check] PASS"
