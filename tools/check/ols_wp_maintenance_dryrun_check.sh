#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

output_check="$(HZ_DRY_RUN=1 bash bin/hz recipe ols-wp-maintenance check)"
output_diag="$(HZ_DRY_RUN=2 bash bin/hz recipe ols-wp-maintenance diagnostics)"

echo "${output_check}" | grep -q "plan.preflight"
echo "${output_check}" | grep -q "plan.permissions"
echo "${output_check}" | grep -q "plan.certificate"
echo "${output_check}" | grep -q "plan.php_limits"
echo "${output_check}" | grep -q "plan.swap"
echo "${output_check}" | grep -q "plan.scheduler"
echo "${output_check}" | grep -q "plan.backup_restore"
echo "${output_diag}" | grep -q "plan.site_health"
echo "${output_diag}" | grep -q "plan.rollback"

echo "ols wp maintenance dry-run check: PASS"
