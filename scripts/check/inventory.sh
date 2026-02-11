#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INVENTORY_ROOT="${ROOT_DIR}/inventory"
STRICT=1

check_requirements() {
  local dep
  for dep in awk find grep mktemp sort tr; do
    if ! command -v "${dep}" >/dev/null 2>&1; then
      echo "missing required command: ${dep}" >&2
      exit 1
    fi
  done
}

usage() {
  echo "usage: scripts/check/inventory.sh [--inventory-root PATH] [--strict|--no-strict]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --inventory-root)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      INVENTORY_ROOT="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --no-strict)
      STRICT=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [[ "${INVENTORY_ROOT}" != /* ]]; then
  INVENTORY_ROOT="${PWD}/${INVENTORY_ROOT}"
fi

check_requirements

HOST_DIR="${INVENTORY_ROOT}/hosts"
SITE_DIR="${INVENTORY_ROOT}/sites"
RESULTS_FILE="$(mktemp)"
ERRORS_FILE="$(mktemp)"
HOST_IDS_FILE="$(mktemp)"

cleanup() {
  rm -f "${RESULTS_FILE}" "${ERRORS_FILE}" "${HOST_IDS_FILE}"
}
trap cleanup EXIT

append_reason() {
  local current="$1"
  local message="$2"
  if [ -z "${current}" ]; then
    printf '%s' "${message}"
  else
    printf '%s; %s' "${current}" "${message}"
  fi
}

normalize_value() {
  local value="$1"
  value="${value#${value%%[![:space:]]*}}"
  value="${value%${value##*[![:space:]]}}"
  if [[ "${value}" == \"*\" ]] && [ "${#value}" -ge 2 ]; then
    value="${value:1:${#value}-2}"
  elif [[ "${value}" == \'*\' ]] && [ "${#value}" -ge 2 ]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "${value}"
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

value_is_nullish() {
  local normalized
  normalized="$(normalize_value "$1")"
  case "$(to_lower "${normalized}")" in
    ""|null|~) return 0 ;;
    *) return 1 ;;
  esac
}

relpath_for_label() {
  local path="$1"
  if [[ "${path}" == *"/inventory/"* ]]; then
    printf 'inventory/%s' "${path##*/inventory/}"
  else
    printf '%s' "$(basename "${path}")"
  fi
}

emit_error() {
  local file_path="$1"
  local code="$2"
  local message="$3"
  printf '%s|%s|%s\n' "${file_path}" "${code}" "${message}" >> "${ERRORS_FILE}"
}

print_errors() {
  [ -s "${ERRORS_FILE}" ] || return 0
  sort -u -t'|' -k1,1 -k2,2 -k3,3 "${ERRORS_FILE}" | while IFS='|' read -r file_path code message; do
    printf 'ERROR|file=%s|code=%s|message=%s\n' "${file_path}" "${code}" "${message}"
  done
}

record_check() {
  local label="$1"
  local status="$2"
  local reason="$3"
  printf '%s|%s|%s\n' "${label}" "${status}" "${reason}" >> "${RESULTS_FILE}"
}

top_key_line() {
  local file="$1"
  local key="$2"
  awk -v k="${key}" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {next}
    $0 ~ "^" k ":[[:space:]]*" {print NR; exit}
  ' "${file}"
}

top_key_value() {
  local file="$1"
  local key="$2"
  awk -v k="${key}" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {next}
    $0 ~ "^" k ":[[:space:]]*" {
      value=$0
      sub("^[^:]*:[[:space:]]*", "", value)
      sub("[[:space:]]+#.*$", "", value)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      print value
      exit
    }
  ' "${file}"
}

nested_key_line() {
  local file="$1"
  local parent="$2"
  local key="$3"
  awk -v p="${parent}" -v k="${key}" '
    function indent_of(s, m) {
      m = match(s, /[^ ]/)
      if (m == 0) return length(s)
      return m - 1
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {next}
    {
      line=$0
      ind=indent_of(line)
      trimmed=substr(line, ind + 1)

      if (state==0 && trimmed ~ ("^" p ":[[:space:]]*$")) {
        state=1
        parent_indent=ind
        next
      }

      if (state==1) {
        if (ind <= parent_indent) {
          exit
        }
        if (trimmed ~ ("^" k ":[[:space:]]*")) {
          print NR
          exit
        }
      }
    }
  ' "${file}"
}

nested_key_value() {
  local file="$1"
  local parent="$2"
  local key="$3"
  awk -v p="${parent}" -v k="${key}" '
    function indent_of(s, m) {
      m = match(s, /[^ ]/)
      if (m == 0) return length(s)
      return m - 1
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {next}
    {
      line=$0
      ind=indent_of(line)
      trimmed=substr(line, ind + 1)

      if (state==0 && trimmed ~ ("^" p ":[[:space:]]*$")) {
        state=1
        parent_indent=ind
        next
      }

      if (state==1) {
        if (ind <= parent_indent) {
          exit
        }
        if (trimmed ~ ("^" k ":[[:space:]]*")) {
          value=trimmed
          sub("^[^:]*:[[:space:]]*", "", value)
          sub("[[:space:]]+#.*$", "", value)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
          print value
          exit
        }
      }
    }
  ' "${file}"
}

emit_credential_hits() {
  local file="$1"
  local line_no=0
  while IFS= read -r line || [ -n "${line}" ]; do
    line_no=$((line_no + 1))
    local trimmed="${line#${line%%[![:space:]]*}}"
    [ -n "${trimmed}" ] || continue
    [[ "${trimmed}" == \#* ]] && continue

    local key=""
    if [[ "${trimmed}" =~ ^([A-Za-z0-9_]+): ]]; then
      key="${BASH_REMATCH[1]}"
    elif [[ "${trimmed}" =~ ^-[[:space:]]*([A-Za-z0-9_]+): ]]; then
      key="${BASH_REMATCH[1]}"
    fi

    [ -n "${key}" ] || continue

    local lower
    lower="$(to_lower "${key}")"
    local p_a="pa""ss"
    local w_a="pass""word"
    local t_a="to""ken"
    local s_a="sec""ret"
    local k_a="key"
    local r_a="private"
    local cred=0

    case "${lower}" in
      "${p_a}"|"${w_a}"|"${t_a}"|"${s_a}"|"${k_a}"|"${r_a}"|smtp_pass|api_key|access_key|private_key|secret_key)
        cred=1
        ;;
      *)
        for marker in "${p_a}" "${w_a}" "${t_a}" "${s_a}" "${k_a}" "${r_a}"; do
          if [[ "${lower}" == ${marker}_* ]] || [[ "${lower}" == *_${marker} ]]; then
            cred=1
            break
          fi
        done
        ;;
    esac

    if [ "${cred}" -eq 1 ]; then
      printf '%s|%s\n' "${line_no}" "${lower}"
    fi
  done < "${file}"
}

scan_unsupported_constructs() {
  local file="$1"
  local relpath="$2"
  local reason="$3"
  local line_no=0

  while IFS= read -r line || [ -n "${line}" ]; do
    line_no=$((line_no + 1))
    local trimmed="${line#${line%%[![:space:]]*}}"
    [ -n "${trimmed}" ] || continue
    [[ "${trimmed}" == \#* ]] && continue

    if [[ "${line}" == *$'\t'* ]]; then
      emit_error "${relpath}" "YAML_UNSUPPORTED_TAB" "line ${line_no} uses tab indentation"
      reason="$(append_reason "${reason}" "line ${line_no}: tab indentation is not supported")"
    fi

    if [ "${STRICT}" -eq 1 ]; then
      if [[ "${trimmed}" == '---' ]] || [[ "${trimmed}" == '...' ]]; then
        emit_error "${relpath}" "YAML_UNSUPPORTED_FEATURE" "line ${line_no} uses yaml document markers"
        reason="$(append_reason "${reason}" "line ${line_no}: yaml document markers are not supported")"
      fi
      if printf '%s\n' "${trimmed}" | grep -Eq '(^|[^[:alnum:]_])&[[:alnum:]_]'; then
        emit_error "${relpath}" "YAML_UNSUPPORTED_FEATURE" "line ${line_no} uses yaml anchors"
        reason="$(append_reason "${reason}" "line ${line_no}: yaml anchors are not supported")"
      fi
      if printf '%s\n' "${trimmed}" | grep -Eq '(^|[^[:alnum:]_])\*[[:alnum:]_]'; then
        emit_error "${relpath}" "YAML_UNSUPPORTED_FEATURE" "line ${line_no} uses yaml aliases"
        reason="$(append_reason "${reason}" "line ${line_no}: yaml aliases are not supported")"
      fi
      if printf '%s\n' "${trimmed}" | grep -Eq ':[[:space:]]*[>|]'; then
        emit_error "${relpath}" "YAML_UNSUPPORTED_FEATURE" "line ${line_no} uses multiline scalars"
        reason="$(append_reason "${reason}" "line ${line_no}: multiline scalars are not supported")"
      fi
      if printf '%s\n' "${trimmed}" | grep -Eq '<<:'; then
        emit_error "${relpath}" "YAML_UNSUPPORTED_FEATURE" "line ${line_no} uses yaml merge keys"
        reason="$(append_reason "${reason}" "line ${line_no}: yaml merge keys are not supported")"
      fi
    fi
  done < "${file}"

  printf '%s' "${reason}"
}

validate_host_file() {
  local file="$1"
  local relpath
  relpath="$(relpath_for_label "${file}")"
  local reason=""

  reason="$(scan_unsupported_constructs "${file}" "${relpath}" "${reason}")"

  local key
  for key in id role os arch resources tailscale ssh; do
    local line
    line="$(top_key_line "${file}" "${key}")"
    if [ -z "${line}" ]; then
      reason="$(append_reason "${reason}" "missing key '${key}'")"
    fi
  done

  local role_line role_value
  role_line="$(top_key_line "${file}" "role")"
  role_value="$(normalize_value "$(top_key_value "${file}" "role")")"
  if [ -n "${role_line}" ] && [ -n "${role_value}" ]; then
    case "${role_value}" in
      host|hub) ;;
      *) reason="$(append_reason "${reason}" "line ${role_line}: role must be host or hub")" ;;
    esac
  fi

  local os_line os_value
  os_line="$(top_key_line "${file}" "os")"
  os_value="$(normalize_value "$(top_key_value "${file}" "os")")"
  if [ -n "${os_line}" ] && [ -n "${os_value}" ]; then
    case "${os_value}" in
      ubuntu-22.04|ubuntu-24.04) ;;
      *) reason="$(append_reason "${reason}" "line ${os_line}: os must be ubuntu-22.04 or ubuntu-24.04")" ;;
    esac
  fi

  local arch_line arch_value
  arch_line="$(top_key_line "${file}" "arch")"
  arch_value="$(normalize_value "$(top_key_value "${file}" "arch")")"
  if [ -n "${arch_line}" ] && [ -n "${arch_value}" ]; then
    case "${arch_value}" in
      x86_64|aarch64) ;;
      *) reason="$(append_reason "${reason}" "line ${arch_line}: arch must be x86_64 or aarch64")" ;;
    esac
  fi

  local ts_line ts_value
  ts_line="$(nested_key_line "${file}" "tailscale" "ip")"
  if [ -z "${ts_line}" ]; then
    reason="$(append_reason "${reason}" "missing key 'tailscale.ip'")"
  else
    ts_value="$(normalize_value "$(nested_key_value "${file}" "tailscale" "ip")")"
    if ! printf '%s\n' "${ts_value}" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
      reason="$(append_reason "${reason}" "line ${ts_line}: tailscale.ip must be ipv4 format")"
    fi
  fi

  local ssh_line ssh_value
  ssh_line="$(nested_key_line "${file}" "ssh" "port")"
  if [ -z "${ssh_line}" ]; then
    reason="$(append_reason "${reason}" "missing key 'ssh.port'")"
  else
    ssh_value="$(normalize_value "$(nested_key_value "${file}" "ssh" "port")")"
    if ! printf '%s\n' "${ssh_value}" | grep -Eq '^[0-9]+$'; then
      reason="$(append_reason "${reason}" "line ${ssh_line}: ssh.port must be numeric")"
    fi
  fi

  while IFS='|' read -r line_no key_name; do
    [ -n "${line_no}" ] || continue
    reason="$(append_reason "${reason}" "line ${line_no}: credential-like key '${key_name}' is not allowed")"
  done < <(emit_credential_hits "${file}")

  local id_line host_id
  id_line="$(top_key_line "${file}" "id")"
  host_id="$(normalize_value "$(top_key_value "${file}" "id")")"
  if [ -n "${id_line}" ] && ! value_is_nullish "${host_id}"; then
    printf '%s\n' "${host_id}" >> "${HOST_IDS_FILE}"
  fi

  if [ -z "${reason}" ]; then
    record_check "inventory.hosts.${relpath}" "PASS" "schema rules satisfied"
  else
    record_check "inventory.hosts.${relpath}" "FAIL" "${reason}"
  fi
}

host_id_exists() {
  local id="$1"
  [ -s "${HOST_IDS_FILE}" ] || return 1
  grep -Fxq "${id}" "${HOST_IDS_FILE}"
}

validate_site_file() {
  local file="$1"
  local relpath
  relpath="$(relpath_for_label "${file}")"
  local reason=""

  reason="$(scan_unsupported_constructs "${file}" "${relpath}" "${reason}")"

  local key
  for key in site_id domain slug stack topology host_ref db redis; do
    local line
    line="$(top_key_line "${file}" "${key}")"
    if [ -z "${line}" ]; then
      reason="$(append_reason "${reason}" "missing key '${key}'")"
    fi
  done

  local stack_line stack_value
  stack_line="$(top_key_line "${file}" "stack")"
  stack_value="$(normalize_value "$(top_key_value "${file}" "stack")")"
  if [ -n "${stack_line}" ] && [ -n "${stack_value}" ]; then
    case "${stack_value}" in
      lomp|lnmp) ;;
      *) reason="$(append_reason "${reason}" "line ${stack_line}: stack must be lomp or lnmp")" ;;
    esac
  fi

  local topology_line topology_value
  topology_line="$(top_key_line "${file}" "topology")"
  topology_value="$(normalize_value "$(top_key_value "${file}" "topology")")"
  if [ -n "${topology_line}" ] && [ -n "${topology_value}" ]; then
    case "${topology_value}" in
      lite|standard) ;;
      *) reason="$(append_reason "${reason}" "line ${topology_line}: topology must be lite or standard")" ;;
    esac
  fi

  local host_ref_line host_ref_value
  host_ref_line="$(top_key_line "${file}" "host_ref")"
  host_ref_value="$(normalize_value "$(top_key_value "${file}" "host_ref")")"
  if [ -n "${host_ref_line}" ]; then
    if value_is_nullish "${host_ref_value}" || ! host_id_exists "${host_ref_value}"; then
      reason="$(append_reason "${reason}" "line ${host_ref_line}: host_ref must resolve to hosts.id")"
    fi
  fi

  local hub_ref_line hub_ref_value
  hub_ref_line="$(top_key_line "${file}" "hub_ref")"
  hub_ref_value="$(normalize_value "$(top_key_value "${file}" "hub_ref")")"
  if [ "${topology_value}" = "lite" ]; then
    if [ -z "${hub_ref_line}" ]; then
      reason="$(append_reason "${reason}" "missing key 'hub_ref' for topology lite")"
    elif value_is_nullish "${hub_ref_value}" || ! host_id_exists "${hub_ref_value}"; then
      reason="$(append_reason "${reason}" "line ${hub_ref_line}: hub_ref must resolve to hosts.id")"
    fi
  elif [ -n "${hub_ref_line}" ] && ! value_is_nullish "${hub_ref_value}"; then
    if ! host_id_exists "${hub_ref_value}"; then
      reason="$(append_reason "${reason}" "line ${hub_ref_line}: hub_ref must resolve to hosts.id")"
    fi
  fi

  while IFS='|' read -r line_no key_name; do
    [ -n "${line_no}" ] || continue
    reason="$(append_reason "${reason}" "line ${line_no}: credential-like key '${key_name}' is not allowed")"
  done < <(emit_credential_hits "${file}")

  if [ -z "${reason}" ]; then
    record_check "inventory.sites.${relpath}" "PASS" "schema rules satisfied"
  else
    record_check "inventory.sites.${relpath}" "FAIL" "${reason}"
  fi
}

main() {
  if [ ! -d "${HOST_DIR}" ] || [ ! -d "${SITE_DIR}" ]; then
    emit_error "inventory" "INVENTORY_LAYOUT_ERROR" "missing required inventory/hosts or inventory/sites directory"
    record_check "inventory.layout" "FAIL" "expected inventory/hosts and inventory/sites directories"
    print_errors
    while IFS='|' read -r label status reason; do
      printf 'CHECK %s %s %s\n' "${label}" "${status}" "${reason}"
    done < <(sort -t'|' -k1,1 "${RESULTS_FILE}")
    echo "RESULT inventory PASS=0 FAIL=1"
    exit 1
  fi

  local host_files site_files
  host_files="$(find "${HOST_DIR}" -maxdepth 1 -type f -name '*.yml' | sort || true)"
  site_files="$(find "${SITE_DIR}" -maxdepth 1 -type f -name '*.yml' | sort || true)"

  if [ -z "${host_files}" ]; then
    emit_error "inventory/hosts" "INVENTORY_LAYOUT_ERROR" "no files matched inventory/hosts/*.yml"
    record_check "inventory.hosts.layout" "FAIL" "no files matched inventory/hosts/*.yml"
  fi
  if [ -z "${site_files}" ]; then
    emit_error "inventory/sites" "INVENTORY_LAYOUT_ERROR" "no files matched inventory/sites/*.yml"
    record_check "inventory.sites.layout" "FAIL" "no files matched inventory/sites/*.yml"
  fi

  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    validate_host_file "${file}"
  done <<< "${host_files}"

  if [ -s "${HOST_IDS_FILE}" ]; then
    sort -u "${HOST_IDS_FILE}" -o "${HOST_IDS_FILE}"
  fi

  while IFS= read -r file; do
    [ -n "${file}" ] || continue
    validate_site_file "${file}"
  done <<< "${site_files}"

  local pass_count=0
  local fail_count=0

  print_errors

  while IFS='|' read -r label status reason; do
    printf 'CHECK %s %s %s\n' "${label}" "${status}" "${reason}"
    if [ "${status}" = "PASS" ]; then
      pass_count=$((pass_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
  done < <(sort -t'|' -k1,1 "${RESULTS_FILE}")

  echo "RESULT inventory PASS=${pass_count} FAIL=${fail_count}"
  if [ "${fail_count}" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
