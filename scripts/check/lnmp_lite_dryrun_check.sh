#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

output_check="$(HZ_DRY_RUN=1 bash bin/hz recipe lnmp-lite check)"
output_diag="$(HZ_DRY_RUN=2 bash bin/hz recipe lnmp-lite diagnostics)"

echo "${output_check}" | grep -q "plan.preflight"
echo "${output_check}" | grep -q "plan.web_nginx_php"
echo "${output_check}" | grep -q "plan.shared_hub_data"
echo "${output_check}" | grep -q "plan.shared_maintenance"
echo "${output_diag}" | grep -q "plan.shared_security"
echo "${output_diag}" | grep -q "plan.rollback"

echo "lnmp lite dry-run check: PASS"
