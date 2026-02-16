#!/usr/bin/env bash
set -euo pipefail

# lib/transport/ssh.sh
# Low-level SSH transport helpers for Phase 2.
#
# Env:
# - HZ_SSH_KEY: path to private key (optional)
# - HZ_SSH_ARGS: extra args for ssh/scp (optional, e.g. "-p 2222 -J jump")
# - HZ_SSH_STRICT_HOST_KEY_CHECKING: accept-new|yes|no (default: accept-new)
# - HZ_SSH_CONNECT_TIMEOUT: seconds (default: 10)
#
# Functions:
# - ssh_test <target>
# - ssh_exec <target> <command>
# - ssh_copy <target> <src> <dest>

HZ_SSH_ARGS="${HZ_SSH_ARGS:-}"
HZ_SSH_STRICT_HOST_KEY_CHECKING="${HZ_SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"
HZ_SSH_CONNECT_TIMEOUT="${HZ_SSH_CONNECT_TIMEOUT:-10}"

_ssh_common_args() {
  local strict="${HZ_SSH_STRICT_HOST_KEY_CHECKING}"

  case "${strict}" in
    accept-new|yes|no) ;;
    *)
      strict="accept-new"
      ;;
  esac

  # shellcheck disable=SC2086
  echo -n "-o BatchMode=yes -o ConnectTimeout=${HZ_SSH_CONNECT_TIMEOUT} -o StrictHostKeyChecking=${strict} ${HZ_SSH_ARGS}"
}

_ssh_key_args() {
  if [[ -n "${HZ_SSH_KEY:-}" ]]; then
    # Do not print the key path in logs.
    echo -n "-i ${HZ_SSH_KEY} -o IdentitiesOnly=yes"
  fi
}

ssh_test() {
  local target="${1:-}"
  [[ -n "${target}" ]] || { echo "ssh_test: missing target" >&2; return 2; }

  local common key
  common="$(_ssh_common_args)"
  key="$(_ssh_key_args)"

  # We intentionally run a no-op remote command.
  # shellcheck disable=SC2086
  ssh ${common} ${key} "${target}" "true"
}

ssh_exec() {
  local target="${1:-}"
  shift || true
  local cmd="${*:-}"

  [[ -n "${target}" ]] || { echo "ssh_exec: missing target" >&2; return 2; }
  [[ -n "${cmd}" ]] || { echo "ssh_exec: missing command" >&2; return 2; }

  local common key
  common="$(_ssh_common_args)"
  key="$(_ssh_key_args)"

  # Preserve remote exit code. Command expansion is intentionally local.
  # shellcheck disable=SC2086,SC2029
  ssh ${common} ${key} "${target}" "${cmd}"
}

ssh_copy() {
  local target="${1:-}"
  local src="${2:-}"
  local dest="${3:-}"

  [[ -n "${target}" ]] || { echo "ssh_copy: missing target" >&2; return 2; }
  [[ -n "${src}" ]] || { echo "ssh_copy: missing src" >&2; return 2; }
  [[ -n "${dest}" ]] || { echo "ssh_copy: missing dest" >&2; return 2; }

  local strict="${HZ_SSH_STRICT_HOST_KEY_CHECKING}"
  case "${strict}" in
    accept-new|yes|no) ;;
    *) strict="accept-new" ;;
  esac

  local key_args=()
  if [[ -n "${HZ_SSH_KEY:-}" ]]; then
    key_args=(-i "${HZ_SSH_KEY}" -o IdentitiesOnly=yes)
  fi

  # scp understands -o options; reuse BatchMode & StrictHostKeyChecking.
  # HZ_SSH_ARGS may contain ssh-style flags (including -p for port).
  # shellcheck disable=SC2206
  local extra=( ${HZ_SSH_ARGS} )

  scp -o BatchMode=yes -o ConnectTimeout="${HZ_SSH_CONNECT_TIMEOUT}" -o StrictHostKeyChecking="${strict}" \
    "${key_args[@]}" \
    "${extra[@]}" \
    "${src}" "${target}:${dest}"
}
