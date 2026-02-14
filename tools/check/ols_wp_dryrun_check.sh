#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

output_install="$(HZ_DRY_RUN=1 bash bin/hz recipe ols-wp install)"
output_diag="$(HZ_DRY_RUN=2 bash bin/hz recipe ols-wp diagnostics)"

echo "${output_install}" | grep -q "plan.preflight"
echo "${output_install}" | grep -q "plan.web"
echo "${output_install}" | grep -q "plan.site"
echo "${output_diag}" | grep -q "plan.ops"

echo "ols wp dry-run check: PASS"
