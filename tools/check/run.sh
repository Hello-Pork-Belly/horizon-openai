#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

CHECK_DIRS=(tools recipes modules archive/upstream-20260215/oneclick)

echo "[check] shell syntax"
while IFS= read -r script_file; do
  bash -n "$script_file"
done < <(find "${CHECK_DIRS[@]}" -type f -name '*.sh' | sort)

if command -v shellcheck >/dev/null 2>&1; then
  echo "[check] shellcheck"
  while IFS= read -r script_file; do
    if [[ "$script_file" == archive/upstream-20260215/oneclick/* ]]; then
      shellcheck -S error "$script_file"
    else
      shellcheck "$script_file"
    fi
  done < <(find "${CHECK_DIRS[@]}" -type f -name '*.sh' | sort)
else
  echo "[check] shellcheck skipped (not installed)"
fi

echo "== inventory check (tests) =="
bash tools/check/inventory_test.sh

echo "== inventory check (repo) =="
bash tools/check/inventory.sh

if [ -x "tools/check/interface_consistency.sh" ]; then
  echo "[check] interface"
  bash tools/check/interface_consistency.sh
else
  echo "[check] interface skipped (checker not present)"
fi

if [ -x "tools/check/lomp_lite_dryrun_check.sh" ]; then
  echo "[check] lomp-lite"
  bash tools/check/lomp_lite_dryrun_check.sh
else
  echo "[check] lomp-lite skipped (checker not present)"
fi

if [ -x "tools/check/ols_wp_dryrun_check.sh" ]; then
  echo "[check] ols-wp"
  bash tools/check/ols_wp_dryrun_check.sh
else
  echo "[check] ols-wp skipped (checker not present)"
fi

if [ -x "tools/check/ols_wp_maintenance_dryrun_check.sh" ]; then
  echo "[check] ols-wp-maintenance"
  bash tools/check/ols_wp_maintenance_dryrun_check.sh
else
  echo "[check] ols-wp-maintenance skipped (checker not present)"
fi
if [ -x "tools/check/hub_data_dryrun_check.sh" ]; then
  echo "[check] hub-data"
  bash tools/check/hub_data_dryrun_check.sh
else
  echo "[check] hub-data skipped (checker not present)"
fi
if [ -x "tools/check/security_host_dryrun_check.sh" ]; then
  echo "[check] security-host"
  bash tools/check/security_host_dryrun_check.sh
else
  echo "[check] security-host skipped (checker not present)"
fi
if [ -x "tools/check/lnmp_lite_dryrun_check.sh" ]; then
  echo "[check] lnmp-lite"
  bash tools/check/lnmp_lite_dryrun_check.sh
else
  echo "[check] lnmp-lite skipped (checker not present)"
fi

if [ -x "tools/check/masking_rules_check.sh" ]; then
  echo "[check] masking"
  bash tools/check/masking_rules_check.sh
else
  echo "[check] masking skipped (checker not present)"
fi




if command -v shfmt >/dev/null 2>&1; then
  echo "[check] shfmt"
  shfmt -d tools lib
else
  echo "[check] shfmt skipped (not installed)"
fi

echo "[check] smoke"
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]] && [[ "$(uname -s)" == "Linux" ]]; then
  bash tools/clean_node.sh --dry-run
else
  echo "[check] smoke skipped (requires bash>=4 on Linux)"
fi

echo "[check] vendor-neutral"
bash tools/check/vendor_neutral_gate.sh

echo "[check] PASS"
