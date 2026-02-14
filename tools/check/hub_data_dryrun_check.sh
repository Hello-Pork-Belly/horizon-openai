#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

output_check="$(HZ_DRY_RUN=1 bash bin/hz recipe hub-data check)"
output_diag="$(HZ_DRY_RUN=2 bash bin/hz recipe hub-data diagnostics)"

echo "${output_check}" | grep -q "plan.preflight"
echo "${output_check}" | grep -q "plan.network_boundary"
echo "${output_check}" | grep -q "plan.allowlist"
echo "${output_check}" | grep -q "plan.tenant_db"
echo "${output_check}" | grep -q "plan.tenant_redis"
echo "${output_diag}" | grep -q "plan.backup_restore"
echo "${output_diag}" | grep -q "plan.rollback"

echo "hub data dry-run check: PASS"
