#!/usr/bin/env bash
set -euo pipefail

# Unified logging for hz.
# LOG_LEVEL: ERROR | WARN | INFO | DEBUG (default: INFO)
# ERROR must go to stderr.

LOG_LEVEL="${LOG_LEVEL:-INFO}"

hz__log_level_num() {
  case "${1:-INFO}" in
    ERROR) echo 0 ;;
    WARN)  echo 1 ;;
    INFO)  echo 2 ;;
    DEBUG) echo 3 ;;
    *)     echo 2 ;;
  esac
}

hz__log_now_utc() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

hz__log_use_color() {
  # Use colors only on TTY and when NO_COLOR is not set.
  [[ -t 1 ]] || return 1
  [[ -z "${NO_COLOR:-}" ]] || return 1
  return 0
}

hz__log_color() {
  local lvl="$1"
  if ! hz__log_use_color; then
    echo ""
    return 0
  fi
  case "$lvl" in
    ERROR) echo $'\033[31m' ;; # red
    WARN)  echo $'\033[33m' ;; # yellow
    INFO)  echo $'\033[32m' ;; # green
    DEBUG) echo $'\033[36m' ;; # cyan
    *)     echo "" ;;
  esac
}

hz__log_reset() {
  hz__log_use_color && echo $'\033[0m' || echo ""
}

hz__log_should_print() {
  local want="$1" cur
  cur="$(hz__log_level_num "${LOG_LEVEL}")"
  [[ "$(hz__log_level_num "$want")" -le "$cur" ]]
}

log_info() {
  hz__log_should_print INFO || return 0
  local c r
  c="$(hz__log_color INFO)"; r="$(hz__log_reset)"
  echo "${c}[$(hz__log_now_utc)] [INFO] $*${r}"
}

log_warn() {
  hz__log_should_print WARN || return 0
  local c r
  c="$(hz__log_color WARN)"; r="$(hz__log_reset)"
  echo "${c}[$(hz__log_now_utc)] [WARN] $*${r}"
}

log_debug() {
  hz__log_should_print DEBUG || return 0
  local c r
  c="$(hz__log_color DEBUG)"; r="$(hz__log_reset)"
  echo "${c}[$(hz__log_now_utc)] [DEBUG] $*${r}"
}

log_error() {
  # Always allow ERROR when LOG_LEVEL >= ERROR (always true with our scale).
  local c r
  c="$(hz__log_color ERROR)"; r="$(hz__log_reset)"
  echo "${c}[$(hz__log_now_utc)] [ERROR] $*${r}" 1>&2
}

# --- Masking helpers (keep vendor-neutral, avoid secrets in INFO) ---

hz_default_log_dir() {
  local root="${1:-$(pwd)}"
  if [[ -n "${HZ_LOG_DIR:-}" ]]; then
    printf '%s\n' "${HZ_LOG_DIR}"
    return 0
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
  if [[ "${len}" -le 8 ]]; then
    printf '***\n'
    return 0
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

  if [[ "${key}" == "${line}" ]]; then
    printf '%s\n' "${line}"
    return 0
  fi

  local upper_key
  upper_key="$(printf '%s' "${key}" | tr '[:lower:]' '[:upper:]')"
  case "${upper_key}" in
    *_PASS|*_TOKEN*|*_KEY*|*_SECRET*|*_PASSWORD*)
      printf '%s=%s\n' "${key}" "$(hz_mask_value "${value}")"
      ;;
    *)
      printf '%s\n' "${line}"
      ;;
  esac
}
