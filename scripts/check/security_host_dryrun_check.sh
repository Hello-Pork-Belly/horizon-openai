#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

output_check="$(HZ_DRY_RUN=1 bash bin/hz recipe security-host check)"
output_diag="$(HZ_DRY_RUN=2 bash bin/hz recipe security-host diagnostics)"

echo "${output_check}" | grep -q "plan.preflight"
echo "${output_check}" | grep -q "plan.bruteforce_guard"
echo "${output_check}" | grep -q "plan.rootkit_scan"
echo "${output_check}" | grep -q "plan.log_retention"
echo "${output_diag}" | grep -q "plan.alert_mail"
echo "${output_diag}" | grep -q "plan.thresholds"
echo "${output_diag}" | grep -q "plan.service_watch"
echo "${output_diag}" | grep -q "plan.rollback"

echo "security host dry-run check: PASS"
