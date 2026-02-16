#!/bin/bash
set -euo pipefail

inventory_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

inventory_path_all() {
  echo "$(inventory_repo_root)/inventory/group_vars/all.yml"
}

inventory_path_host() {
  echo "$(inventory_repo_root)/inventory/hosts/${1}.yml"
}

inventory__dump_kv_from_yaml() {
  local file="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import re, sys
path = sys.argv[1]

def emit(mapping):
  for k, v in mapping.items():
    if not isinstance(k, str):
      continue
    if not re.match(r'^[A-Z_][A-Z0-9_]*$', k):
      continue
    if v is None:
      s = ""
    elif isinstance(v, (int, float, bool)):
      s = str(v)
    elif isinstance(v, str):
      s = v
    else:
      continue
    print(f"{k}={s}")

try:
  import yaml  # type: ignore
  with open(path, "r", encoding="utf-8") as f:
    obj = yaml.safe_load(f)
  if isinstance(obj, dict):
    emit(obj)
  sys.exit(0)
except Exception:
  pass

kv = {}
pat = re.compile(r'^\s*([A-Z_][A-Z0-9_]*)\s*:\s*(.*?)\s*$')
with open(path, "r", encoding="utf-8") as f:
  for line in f:
    line = line.rstrip("\n")
    if not line or line.lstrip().startswith("#"):
      continue
    m = pat.match(line)
    if not m:
      continue
    k, raw = m.group(1), m.group(2)
    raw = re.split(r'\s+#', raw, maxsplit=1)[0].strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ("'", '"'):
      raw = raw[1:-1]
    kv[k] = raw
emit(kv)
PY
    return 0
  fi

  awk '
    /^[ \t]*($|#)/ { next }
    {
      line=$0
      sub(/^[ \t]*/, "", line)
      split(line, parts, ":")
      k=parts[1]
      if (k !~ /^[A-Z_][A-Z0-9_]*$/) next
      v=substr(line, index(line, ":")+1)
      sub(/[ \t]+#.*/, "", v)
      gsub(/^[ \t]+|[ \t]+$/, "", v)
      if (v ~ /^".*"$/ || v ~ /^'\''.*'\''$/) { v=substr(v,2,length(v)-2) }
      print k "=" v
    }
  ' "$file"
}

inventory_load_vars() {
  local host="${1:-}"
  local all_file host_file
  local -a files=()
  local dry="${HZ_DRY_RUN:-0}"
  local debug="${HZ_DEBUG:-0}"
  local tracked_keys=" "

  all_file="$(inventory_path_all)"
  if [[ -f "$all_file" ]]; then
    files+=("$all_file")
  else
    log_debug "inventory: global not found: ${all_file}"
  fi

  if [[ -n "$host" ]]; then
    host_file="$(inventory_path_host "$host")"
    if [[ -f "$host_file" ]]; then
      files+=("$host_file")
    else
      log_warn "inventory: host file not found: ${host_file}"
    fi
  fi

  if [[ "${#files[@]}" -eq 0 ]]; then
    log_info "inventory: no inventory files to load"
    return 0
  fi

  local f line k v
  for f in "${files[@]}"; do
    log_debug "inventory: reading file: ${f}"
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      k="${line%%=*}"
      v="${line#*=}"

      # Preserve shell overrides, but allow host yaml to override keys loaded
      # from global yaml during this same call.
      if [[ -n "${!k+x}" ]] && [[ "${tracked_keys}" != *" ${k} "* ]]; then
        [[ "$dry" != "0" ]] && log_info "inventory skip (env override): ${k}"
        continue
      fi

      if [[ "$dry" != "0" ]]; then
        if [[ "$debug" == "1" ]]; then
          log_debug "inventory would load: $(hz_mask_kv_line "${k}=${v}") (from ${f})"
        else
          log_info "inventory would load: ${k} (from ${f})"
        fi
        if [[ "${tracked_keys}" != *" ${k} "* ]]; then
          tracked_keys="${tracked_keys}${k} "
        fi
        continue
      fi

      export "${k}=${v}"
      if [[ "$debug" == "1" ]]; then
        log_debug "inventory loaded: $(hz_mask_kv_line "${k}=${v}") (from ${f})"
      else
        log_debug "inventory loaded: ${k} (from ${f})"
      fi
      if [[ "${tracked_keys}" != *" ${k} "* ]]; then
        tracked_keys="${tracked_keys}${k} "
      fi
    done < <(inventory__dump_kv_from_yaml "$f" || true)
  done
}

inventory__ssh_args_has_port() {
  # Detect if HZ_SSH_ARGS already includes a -p option.
  local s="${HZ_SSH_ARGS:-}"
  [[ -n "$s" ]] || return 1
  case " $s " in
    *" -p "*) return 0 ;;
    *" -p"* ) return 0 ;; # covers "-p2222" style
    *) return 1 ;;
  esac
}

inventory_resolve_target() {
  # Resolve alias -> user@host and export HZ_SSH_KEY/HZ_SSH_ARGS if provided by inventory.
  # Contract: sets HZ_RESOLVED_TARGET and returns 0 on success.
  local input="${1:-}"
  [[ -n "$input" ]] || { log_error "inventory_resolve_target: missing target_input"; return 2; }

  export HZ_RESOLVED_TARGET="$input"

  local host_file
  host_file="$(inventory_path_host "$input")"
  if [[ ! -f "$host_file" ]]; then
    # Pass-through
    return 0
  fi

  local host="" user="" port="" key=""
  local line k v
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    k="${line%%=*}"
    v="${line#*=}"
    case "$k" in
      HZ_CONNECTION_HOST|HZ_HOST_ADDR) host="$v" ;;
      HZ_CONNECTION_USER|HZ_HOST_USER) user="$v" ;;
      HZ_CONNECTION_PORT|HZ_HOST_PORT) port="$v" ;;
      HZ_CONNECTION_KEY|HZ_HOST_KEY_PATH) key="$v" ;;
      *) : ;;
    esac
  done < <(inventory__dump_kv_from_yaml "$host_file" || true)

  if [[ -z "$host" ]]; then
    log_error "inventory: host alias '${input}' missing HZ_CONNECTION_HOST (or HZ_HOST_ADDR) in ${host_file}"
    return 1
  fi

  if [[ -z "$user" ]]; then
    user="$(whoami 2>/dev/null || true)"
    [[ -n "$user" ]] || user="root"
  fi

  if [[ -z "$port" ]]; then
    port="22"
  fi

  export HZ_RESOLVED_TARGET="${user}@${host}"

  # Only set SSH key if caller didn't already set it (shell overrides inventory).
  if [[ -z "${HZ_SSH_KEY:-}" && -n "$key" ]]; then
    export HZ_SSH_KEY="$key"
  fi

  # Port handling: append -p <port> only if needed and not already present.
  if [[ "$port" != "22" ]]; then
    if ! inventory__ssh_args_has_port; then
      if [[ -n "${HZ_SSH_ARGS:-}" ]]; then
        export HZ_SSH_ARGS="${HZ_SSH_ARGS} -p ${port}"
      else
        export HZ_SSH_ARGS="-p ${port}"
      fi
    fi
  fi

  # Debug log (do not print key path)
  local key_state="unset"
  [[ -n "${HZ_SSH_KEY:-}" ]] && key_state="set"
  log_debug "inventory: resolved target '${input}' -> '${HZ_RESOLVED_TARGET}' (port=${port} key=${key_state})"
  return 0
}
