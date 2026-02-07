#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[check] shell syntax"
while IFS= read -r script_file; do
  bash -n "$script_file"
done < <(find scripts -type f -name '*.sh' | sort)

if command -v shellcheck >/dev/null 2>&1; then
  echo "[check] shellcheck"
  bash -c 'shopt -s globstar; shellcheck scripts/**/*.sh'
else
  echo "[check] shellcheck skipped (not installed)"
fi

if [ -x "scripts/check/inventory_validate.sh" ]; then
  echo "[check] inventory"
  bash scripts/check/inventory_validate.sh
else
  echo "[check] inventory skipped (validator not present)"
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
