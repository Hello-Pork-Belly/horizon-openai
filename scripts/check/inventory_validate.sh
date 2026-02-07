#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST_DIR="${ROOT_DIR}/inventory/hosts"
SITE_DIR="${ROOT_DIR}/inventory/sites"
HOST_IDS_FILE=""

cleanup() {
  if [ -n "${HOST_IDS_FILE}" ] && [ -f "${HOST_IDS_FILE}" ]; then
    rm -f "${HOST_IDS_FILE}"
  fi
}

err() {
  echo "ERROR: $*" >&2
}

require_key() {
  local file="$1"
  local key="$2"
  if ! grep -Eq "^[[:space:]]*${key}:[[:space:]]*" "${file}"; then
    err "${file}: missing required key '${key}'"
    return 1
  fi
}

extract_scalar() {
  local file="$1"
  local key="$2"
  awk -F ':' -v k="${key}" '
    $1 ~ "^[[:space:]]*" k "$" {
      sub(/^[[:space:]]+/, "", $2);
      sub(/[[:space:]]+$/, "", $2);
      print $2;
      exit
    }
  ' "${file}"
}

main() {
  local rc=0

  if [ ! -d "${HOST_DIR}" ] || [ ! -d "${SITE_DIR}" ]; then
    err "inventory directory missing (expected inventory/hosts and inventory/sites)"
    exit 1
  fi

  HOST_IDS_FILE="$(mktemp)"
  trap cleanup EXIT

  local host_files site_files
  host_files="$(find "${HOST_DIR}" -type f -name '*.yml' | sort || true)"
  site_files="$(find "${SITE_DIR}" -type f -name '*.yml' | sort || true)"

  if [ -z "${host_files}" ]; then
    err "no host inventory files found"
    rc=1
  fi
  if [ -z "${site_files}" ]; then
    err "no site inventory files found"
    rc=1
  fi

  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    require_key "${file}" "id" || rc=1
    require_key "${file}" "role" || rc=1
    require_key "${file}" "os" || rc=1
    require_key "${file}" "arch" || rc=1
    require_key "${file}" "resources" || rc=1
    require_key "${file}" "tailscale" || rc=1
    require_key "${file}" "ssh" || rc=1
    host_id="$(extract_scalar "${file}" "id")"
    if [ -z "${host_id}" ]; then
      err "${file}: empty id value"
      rc=1
    else
      echo "${host_id}" >> "${HOST_IDS_FILE}"
    fi
  done <<< "${host_files}"

  sort -u "${HOST_IDS_FILE}" -o "${HOST_IDS_FILE}"

  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    require_key "${file}" "site_id" || rc=1
    require_key "${file}" "domain" || rc=1
    require_key "${file}" "slug" || rc=1
    require_key "${file}" "stack" || rc=1
    require_key "${file}" "topology" || rc=1
    require_key "${file}" "host_ref" || rc=1
    require_key "${file}" "db" || rc=1
    require_key "${file}" "redis" || rc=1

    host_ref="$(extract_scalar "${file}" "host_ref")"
    if [ -n "${host_ref}" ] && ! grep -Fxq "${host_ref}" "${HOST_IDS_FILE}"; then
      err "${file}: host_ref '${host_ref}' not found in inventory/hosts"
      rc=1
    fi

    topology="$(extract_scalar "${file}" "topology")"
    hub_ref="$(extract_scalar "${file}" "hub_ref")"
    if [ "${topology}" = "lite" ]; then
      if [ -z "${hub_ref}" ] || [ "${hub_ref}" = "null" ]; then
        err "${file}: lite topology requires non-null hub_ref"
        rc=1
      elif ! grep -Fxq "${hub_ref}" "${HOST_IDS_FILE}"; then
        err "${file}: hub_ref '${hub_ref}' not found in inventory/hosts"
        rc=1
      fi
    fi
  done <<< "${site_files}"

  if [ "${rc}" -ne 0 ]; then
    exit "${rc}"
  fi

  echo "inventory validate: PASS"
}

main "$@"
