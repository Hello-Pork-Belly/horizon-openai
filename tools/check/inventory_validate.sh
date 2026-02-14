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
  local code="$1"
  local file="$2"
  local message="$3"
  echo "ERROR|file=${file}|code=${code}|message=${message}" >&2
}

require_key() {
  local file="$1"
  local key="$2"
  if ! grep -Eq "^[[:space:]]*${key}:[[:space:]]*" "${file}"; then
    err "MISSING_KEY" "${file}" "missing required key '${key}'"
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
    err "MISSING_DIR" "inventory" "expected inventory/hosts and inventory/sites"
    exit 1
  fi

  HOST_IDS_FILE="$(mktemp)"
  trap cleanup EXIT

  local host_files site_files
  host_files="$(find "${HOST_DIR}" -type f -name '*.yml' | sort || true)"
  site_files="$(find "${SITE_DIR}" -type f -name '*.yml' | sort || true)"

  if [ -z "${host_files}" ]; then
    err "MISSING_HOST_FILES" "inventory/hosts" "no host inventory files found"
    rc=1
  fi
  if [ -z "${site_files}" ]; then
    err "MISSING_SITE_FILES" "inventory/sites" "no site inventory files found"
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
    require_key "${file}" "node_name" || rc=1
    require_key "${file}" "ip" || rc=1
    require_key "${file}" "user" || rc=1
    require_key "${file}" "port" || rc=1

    host_id="$(extract_scalar "${file}" "id")"
    if [ -z "${host_id}" ]; then
      err "EMPTY_VALUE" "${file}" "empty id value"
      rc=1
    else
      echo "${host_id}" >> "${HOST_IDS_FILE}"
    fi

    role="$(extract_scalar "${file}" "role")"
    case "${role}" in
      host|hub) ;;
      *)
        err "INVALID_VALUE" "${file}" "role must be host or hub"
        rc=1
        ;;
    esac

    os_value="$(extract_scalar "${file}" "os")"
    case "${os_value}" in
      ubuntu-22.04|ubuntu-24.04) ;;
      *)
        err "INVALID_VALUE" "${file}" "os must be ubuntu-22.04 or ubuntu-24.04"
        rc=1
        ;;
    esac

    arch_value="$(extract_scalar "${file}" "arch")"
    case "${arch_value}" in
      x86_64|aarch64) ;;
      *)
        err "INVALID_VALUE" "${file}" "arch must be x86_64 or aarch64"
        rc=1
        ;;
    esac

    ts_ip="$(extract_scalar "${file}" "ip")"
    if ! printf '%s\n' "${ts_ip}" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
      err "INVALID_VALUE" "${file}" "tailscale ip must be IPv4 format"
      rc=1
    fi

    ssh_port="$(extract_scalar "${file}" "port")"
    if ! printf '%s\n' "${ssh_port}" | grep -Eq '^[0-9]+$'; then
      err "INVALID_VALUE" "${file}" "ssh port must be numeric"
      rc=1
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
    require_key "${file}" "name" || rc=1
    require_key "${file}" "user" || rc=1
    require_key "${file}" "namespace" || rc=1

    stack_value="$(extract_scalar "${file}" "stack")"
    case "${stack_value}" in
      lomp|lnmp) ;;
      *)
        err "INVALID_VALUE" "${file}" "stack must be lomp or lnmp"
        rc=1
        ;;
    esac

    host_ref="$(extract_scalar "${file}" "host_ref")"
    if [ -n "${host_ref}" ] && ! grep -Fxq "${host_ref}" "${HOST_IDS_FILE}"; then
      err "UNRESOLVED_REF" "${file}" "host_ref not found in inventory/hosts"
      rc=1
    fi

    topology="$(extract_scalar "${file}" "topology")"
    case "${topology}" in
      lite|standard) ;;
      *)
        err "INVALID_VALUE" "${file}" "topology must be lite or standard"
        rc=1
        ;;
    esac

    hub_ref="$(extract_scalar "${file}" "hub_ref")"
    if [ "${topology}" = "lite" ]; then
      if [ -z "${hub_ref}" ] || [ "${hub_ref}" = "null" ]; then
        err "UNRESOLVED_REF" "${file}" "lite topology requires non-null hub_ref"
        rc=1
      elif ! grep -Fxq "${hub_ref}" "${HOST_IDS_FILE}"; then
        err "UNRESOLVED_REF" "${file}" "hub_ref not found in inventory/hosts"
        rc=1
      fi
    elif [ -n "${hub_ref}" ] && [ "${hub_ref}" != "null" ]; then
      if ! grep -Fxq "${hub_ref}" "${HOST_IDS_FILE}"; then
        err "UNRESOLVED_REF" "${file}" "hub_ref not found in inventory/hosts"
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
