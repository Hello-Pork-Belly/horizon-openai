#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="${ROOT_DIR}/scripts/check/inventory.sh"
TMP_ROOT="$(mktemp -d)"

check_requirements() {
  local dep
  for dep in bash cat grep mktemp printf; do
    if ! command -v "${dep}" >/dev/null 2>&1; then
      echo "missing required command: ${dep}" >&2
      exit 1
    fi
  done
}

check_requirements

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

create_base_inventory() {
  local case_dir="$1"
  mkdir -p "${case_dir}/inventory/hosts" "${case_dir}/inventory/sites"

  cat > "${case_dir}/inventory/hosts/host-app.yml" <<'YML'
id: host-app
role: host
os: ubuntu-24.04
arch: x86_64
resources:
  cpu_bucket: 2c
  ram_bucket: 2g
  disk_bucket: small
tailscale:
  ip: 100.64.0.10
ssh:
  port: 22
YML

  cat > "${case_dir}/inventory/hosts/hub-main.yml" <<'YML'
id: hub-main
role: hub
os: ubuntu-24.04
arch: aarch64
resources:
  cpu_bucket: 4c
  ram_bucket: 24g
  disk_bucket: medium
tailscale:
  ip: 100.64.0.20
ssh:
  port: 22
YML

  cat > "${case_dir}/inventory/sites/site-lite.yml" <<'YML'
site_id: site-lite
domain: site-lite.example.test
slug: sitelite
stack: lomp
topology: lite
host_ref: host-app
hub_ref: hub-main
db:
  name: wp_sitelite
  user: wp_sitelite
redis:
  namespace: sitelite
YML
}

run_case() {
  local case_name="$1"
  local expected_rc="$2"
  local expected_pattern="$3"
  local expected_pattern_two="${4:-}"
  local case_dir="${TMP_ROOT}/${case_name}"
  local output_file="${case_dir}/output.log"
  local rc=0

  mkdir -p "${case_dir}"
  create_base_inventory "${case_dir}"

  case "${case_name}" in
    missing-key)
      cat > "${case_dir}/inventory/hosts/host-app.yml" <<'YML'
id: host-app
role: host
os: ubuntu-24.04
arch: x86_64
resources:
  cpu_bucket: 2c
  ram_bucket: 2g
  disk_bucket: small
tailscale:
  ip: 100.64.0.10
YML
      ;;
    bad-value)
      cat > "${case_dir}/inventory/sites/site-lite.yml" <<'YML'
site_id: site-lite
domain: site-lite.example.test
slug: sitelite
stack: invalid
topology: lite
host_ref: host-app
hub_ref: hub-main
db:
  name: wp_sitelite
  user: wp_sitelite
redis:
  namespace: sitelite
YML
      ;;
    missing-ref)
      cat > "${case_dir}/inventory/sites/site-lite.yml" <<'YML'
site_id: site-lite
domain: site-lite.example.test
slug: sitelite
stack: lomp
topology: lite
host_ref: unknown-host
hub_ref: hub-main
db:
  name: wp_sitelite
  user: wp_sitelite
redis:
  namespace: sitelite
YML
      ;;
    hub-ref-non-hub)
      cat > "${case_dir}/inventory/sites/site-lite.yml" <<'YML'
site_id: site-lite
domain: site-lite.example.test
slug: sitelite
stack: lomp
topology: lite
host_ref: host-app
hub_ref: host-app
db:
  name: wp_sitelite
  user: wp_sitelite
redis:
  namespace: sitelite
YML
      ;;
    bad-key-name)
      cat > "${case_dir}/inventory/sites/site-lite.yml" <<'YML'
site_id: site-lite
domain: site-lite.example.test
slug: sitelite
stack: lomp
topology: lite
host_ref: host-app
hub_ref: hub-main
db:
  name: wp_sitelite
  user: wp_sitelite
smtp_pass: should-not-be-here
redis:
  namespace: sitelite
YML
      ;;
    fatal-tab)
      printf '%s\n' \
'id: host-app' \
'role: host' \
'os: ubuntu-24.04' \
'arch: x86_64' \
'resources:' \
$'\tcpu_bucket: 2c' \
'  ram_bucket: 2g' \
'  disk_bucket: small' \
'tailscale:' \
'  ip: 100.64.0.10' \
'ssh:' \
'  port: 22' > "${case_dir}/inventory/hosts/host-app.yml"
      ;;
  esac

  set +e
  bash "${VALIDATOR}" --inventory-root "${case_dir}/inventory" > "${output_file}" 2>&1
  rc=$?
  set -e

  if [ "${rc}" -ne "${expected_rc}" ]; then
    echo "TEST ${case_name} FAIL expected_rc=${expected_rc} actual_rc=${rc}" >&2
    cat "${output_file}" >&2
    exit 1
  fi

  if ! grep -Fq "${expected_pattern}" "${output_file}"; then
    echo "TEST ${case_name} FAIL missing pattern: ${expected_pattern}" >&2
    cat "${output_file}" >&2
    exit 1
  fi

  if [ -n "${expected_pattern_two}" ] && ! grep -Fq "${expected_pattern_two}" "${output_file}"; then
    echo "TEST ${case_name} FAIL missing pattern: ${expected_pattern_two}" >&2
    cat "${output_file}" >&2
    exit 1
  fi

  if ! grep -Fq "RESULT inventory PASS=" "${output_file}"; then
    echo "TEST ${case_name} FAIL missing result line" >&2
    cat "${output_file}" >&2
    exit 1
  fi

  echo "TEST ${case_name} PASS"
  cat "${output_file}"
}

run_case "valid" 0 "CHECK inventory.sites.inventory/sites/site-lite.yml PASS"
run_case "missing-key" 1 "CHECK inventory.hosts.inventory/hosts/host-app.yml FAIL"
run_case "bad-value" 1 "CHECK inventory.sites.inventory/sites/site-lite.yml FAIL"
run_case "missing-ref" 1 "CHECK inventory.sites.inventory/sites/site-lite.yml FAIL"
run_case "hub-ref-non-hub" 0 "CHECK inventory.sites.inventory/sites/site-lite.yml PASS"
run_case "bad-key-name" 1 "CHECK inventory.sites.inventory/sites/site-lite.yml FAIL"
run_case "fatal-tab" 1 "ERROR|file=inventory/hosts/host-app.yml|code=YAML_UNSUPPORTED_TAB|message=line 6 uses tab indentation"

echo "inventory test: PASS"
