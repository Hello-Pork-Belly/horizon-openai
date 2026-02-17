#!/usr/bin/env bash
# lib/cron.sh
# Manage /etc/cron.d/hz-tasks (system-wide cron)
# Format: <SCHEDULE> <USER> <COMMAND> # <NAME>

CRON_FILE="${HZ_CRON_FILE:-/etc/cron.d/hz-tasks}"

cron__log_info() {
  if command -v log_info >/dev/null 2>&1; then
    log_info "$@"
  else
    echo "INFO: $*"
  fi
}

cron__log_warn() {
  if command -v log_warn >/dev/null 2>&1; then
    log_warn "$@"
  else
    echo "WARN: $*" >&2
  fi
}

cron__log_error() {
  if command -v log_error >/dev/null 2>&1; then
    log_error "$@"
  else
    echo "ERROR: $*" >&2
  fi
}

cron__require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    cron__log_error "cron: requires root to manage ${CRON_FILE}. Re-run with sudo."
    return 1
  fi
  return 0
}

cron__validate_schedule() {
  # Minimal validation: at least 5 fields (min, hour, dom, mon, dow)
  local s="${1:-}"
  [[ -n "${s}" ]] || return 1

  # shellcheck disable=SC2206
  local parts=( ${s} )
  [[ "${#parts[@]}" -ge 5 ]]
}

cron_ensure_file() {
  cron__require_root || return 1

  if [[ ! -f "${CRON_FILE}" ]]; then
    cron__log_info "cron: creating ${CRON_FILE}"
    umask 022
    : > "${CRON_FILE}"
  fi

  chmod 644 "${CRON_FILE}" 2>/dev/null || true
  chown root:root "${CRON_FILE}" 2>/dev/null || true
  return 0
}

cron_list_tasks() {
  cron__require_root || return 1
  cron_ensure_file || return 1
  cat "${CRON_FILE}"
}

cron_remove_task() {
  cron__require_root || return 1
  cron_ensure_file || return 1

  local name="${1:-}"
  [[ -n "${name}" ]] || {
    cron__log_error "cron remove: missing --name"
    return 2
  }

  local tmp
  tmp="$(mktemp 2>/dev/null || mktemp -t hz_cron)"
  chmod 600 "${tmp}" 2>/dev/null || true

  awk -v n="${name}" '
    {
      line=$0
      pattern = "#[[:space:]]*" n "[[:space:]]*$"
      if (line ~ pattern) next
      print line
    }
  ' "${CRON_FILE}" > "${tmp}"

  mv "${tmp}" "${CRON_FILE}"
  chmod 644 "${CRON_FILE}" 2>/dev/null || true
  chown root:root "${CRON_FILE}" 2>/dev/null || true

  cron__log_info "cron: removed task name=${name}"
  return 0
}

cron_add_task() {
  cron__require_root || return 1
  cron_ensure_file || return 1

  local name="${1:-}"
  local schedule="${2:-}"
  local user="${3:-}"
  local cmd="${4:-}"

  [[ -n "${name}" ]] || {
    cron__log_error "cron add: missing --name"
    return 2
  }
  [[ -n "${schedule}" ]] || {
    cron__log_error "cron add: missing --schedule"
    return 2
  }
  [[ -n "${user}" ]] || {
    cron__log_error "cron add: missing --user"
    return 2
  }
  [[ -n "${cmd}" ]] || {
    cron__log_error "cron add: missing --cmd"
    return 2
  }

  if ! cron__validate_schedule "${schedule}"; then
    cron__log_error "cron add: invalid schedule (need at least 5 fields): ${schedule}"
    return 2
  fi

  local newline
  newline="${schedule} ${user} ${cmd} # ${name}"

  local tmp
  tmp="$(mktemp 2>/dev/null || mktemp -t hz_cron)"
  chmod 600 "${tmp}" 2>/dev/null || true

  awk -v n="${name}" -v repl="${newline}" '
    BEGIN { replaced=0 }
    {
      line=$0
      pattern = "#[[:space:]]*" n "[[:space:]]*$"
      if (line ~ pattern) {
        print repl
        replaced=1
        next
      }
      print line
    }
    END {
      if (replaced==0) print repl
    }
  ' "${CRON_FILE}" > "${tmp}"

  mv "${tmp}" "${CRON_FILE}"
  chmod 644 "${CRON_FILE}" 2>/dev/null || true
  chown root:root "${CRON_FILE}" 2>/dev/null || true

  cron__log_info "cron: added/updated task name=${name}"
  return 0
}
