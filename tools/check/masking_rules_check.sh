#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
. "${ROOT_DIR}/scripts/lib/logging.sh"

assert_masked() {
  local line="$1"
  local output
  local raw="${line#*=}"
  output="$(hz_mask_kv_line "${line}")"
  if echo "${output}" | grep -Fq "${raw}"; then
    echo "masking rule failed for key: ${line%%=*}" >&2
    exit 1
  fi
}

assert_masked "FOO_KEY_ID=Alpha123456789"
assert_masked "BAR_SECRET_NAME=Beta123456789"
assert_masked "BAZ_TOKEN_X=Gamma123456789"
assert_masked "qux_key_name=Delta123456789"

echo "masking rules check: PASS"
