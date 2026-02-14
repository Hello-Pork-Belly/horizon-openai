#!/usr/bin/env bash
set -euo pipefail

hz_default_log_dir() {
  local root="${1:-$(pwd)}"
  if [ -n "${HZ_LOG_DIR:-}" ]; then
    printf '%s\n' "${HZ_LOG_DIR}"
    return
  fi
  printf '%s/logs\n' "${root}"
}

hz_prepare_log_dir() {
  local root="${1:-$(pwd)}"
  local dir
  dir="$(hz_default_log_dir "${root}")"
  mkdir -p "${dir}"
  printf '%s\n' "${dir}"
}

hz_mask_value() {
  local value="${1:-}"
  local len="${#value}"
  if [ "${len}" -le 8 ]; then
    printf '***\n'
    return
  fi
  local head tail
  head="${value:0:4}"
  tail="${value:len-4:4}"
  printf '%s***%s\n' "${head}" "${tail}"
}

hz_mask_kv_line() {
  local line="${1:-}"
  local key="${line%%=*}"
  local value="${line#*=}"
  local upper_key=""
  if [[ "${key}" == "${line}" ]]; then
    printf '%s\n' "${line}"
    return
  fi

  upper_key="$(printf '%s' "${key}" | tr '[:lower:]' '[:upper:]')"
  case "${upper_key}" in
    *_PASS|*_TOKEN*|*_KEY*|*_SECRET*)
      printf '%s=%s\n' "${key}" "$(hz_mask_value "${value}")"
      ;;
    *)
      printf '%s\n' "${line}"
      ;;
  esac
}
