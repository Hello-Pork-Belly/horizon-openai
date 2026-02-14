#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REQUIRED_SUBCOMMANDS="install,status,check,upgrade,backup,restore,uninstall,diagnostics"

err() {
  local file="$1"
  local message="$2"
  echo "ERROR|file=${file}|code=INTERFACE|message=${message}" >&2
}

get_contract_value() {
  local file="$1"
  local key="$2"
  awk -F ':' -v k="${key}" '
    $1 ~ "^[[:space:]]*" k "$" {
      sub(/^[[:space:]]+/, "", $2)
      sub(/[[:space:]]+$/, "", $2)
      print $2
      exit
    }
  ' "${file}"
}

check_required_keys() {
  local file="$1"
  local rc=0
  for key in name runner supported_subcommands; do
    if ! grep -Eq "^[[:space:]]*${key}:[[:space:]]*" "${file}"; then
      err "${file}" "missing key '${key}'"
      rc=1
    fi
  done
  return "${rc}"
}

check_subcommands() {
  local file="$1"
  local declared="$2"
  local token
  IFS=',' read -r -a required <<< "${REQUIRED_SUBCOMMANDS}"
  for token in "${required[@]}"; do
    if ! printf '%s\n' "${declared}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -Fxq "${token}"; then
      err "${file}" "missing required subcommand '${token}'"
      return 1
    fi
  done
}

check_target_dir() {
  local dir="$1"
  local rc=0
  local contract

  while IFS= read -r contract; do
    [ -n "${contract}" ] || continue
    check_required_keys "${contract}" || rc=1
    name="$(get_contract_value "${contract}" "name")"
    runner="$(get_contract_value "${contract}" "runner")"
    commands="$(get_contract_value "${contract}" "supported_subcommands")"

    [ -n "${name}" ] || { err "${contract}" "empty name"; rc=1; }
    [ -n "${runner}" ] || { err "${contract}" "empty runner"; rc=1; }
    [ -n "${commands}" ] || { err "${contract}" "empty supported_subcommands"; rc=1; }

    if [ -n "${runner}" ] && [ ! -f "${ROOT_DIR}/${runner}" ]; then
      err "${contract}" "runner file not found"
      rc=1
    fi

    if [ -n "${commands}" ]; then
      check_subcommands "${contract}" "${commands}" || rc=1
    fi
  done < <(find "${ROOT_DIR}/${dir}" -mindepth 2 -maxdepth 2 -type f -name contract.yml | sort)

  return "${rc}"
}

main() {
  local rc=0
  check_target_dir "modules" || rc=1
  check_target_dir "recipes" || rc=1

  if [ "${rc}" -ne 0 ]; then
    exit "${rc}"
  fi

  echo "interface consistency: PASS"
}

main "$@"
