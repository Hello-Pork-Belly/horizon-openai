#!/bin/bash
set -euo pipefail

# Inventory loader (flat YAML -> env vars).
# Precedence (last wins within YAML), but existing shell env vars always win:
#   1) inventory/group_vars/all.yml
#   2) inventory/hosts/<host>.yml

inventory_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

inventory_path_all() {
  local root
  root="$(inventory_repo_root)"
  echo "${root}/inventory/group_vars/all.yml"
}

inventory_path_host() {
  local root host="$1"
  root="$(inventory_repo_root)"
  echo "${root}/inventory/hosts/${host}.yml"
}

inventory__dump_kv_from_yaml() {
  # Output: KEY=VALUE lines (one per line), for flat uppercase keys only.
  # Parser preference:
  #   - python3 + PyYAML if available
  #   - fallback: strict line parser (KEY: VALUE) inside python3 stdlib
  # If python3 missing, fallback to strict grep/sed parser in bash.
  local file="$1"

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import re, sys

path = sys.argv[1]

def emit(mapping):
    seen = set()
    for k, v in mapping.items():
        if not isinstance(k, str):
            continue
        if not re.match(r'^[A-Z_][A-Z0-9_]*$', k):
            continue
        if k in seen:
            continue
        seen.add(k)
        if v is None:
            s = ""
        elif isinstance(v, (int, float, bool)):
            s = str(v)
        elif isinstance(v, str):
            s = v
        else:
            # Ignore non-flat structures by design
            continue
        print(f"{k}={s}")

# Try PyYAML
try:
    import yaml  # type: ignore
    with open(path, "r", encoding="utf-8") as f:
        obj = yaml.safe_load(f)
    if isinstance(obj, dict):
        emit(obj)
    sys.exit(0)
except Exception:
    pass

# Fallback: strict flat parser KEY: VALUE
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

  # Bash fallback (very strict flat parse)
  # Accept: KEY: VALUE, KEY: "VALUE", KEY: 'VALUE' ; ignore others.
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
  # Args: hostname (optional). Empty means global only.
  # Exports vars into current shell (or respects HZ_DRY_RUN to avoid export).
  local host="${1:-}"
  local root all_file host_file
  local -a files=()
  local dry="${HZ_DRY_RUN:-0}"
  local debug="${HZ_DEBUG:-0}"

  root="$(inventory_repo_root)"
  all_file="$(inventory_path_all)"
  host_file=""

  if [[ -f "$all_file" ]]; then
    files+=("$all_file")
  fi

  if [[ -n "$host" ]]; then
    host_file="$(inventory_path_host "$host")"
    if [[ -f "$host_file" ]]; then
      files+=("$host_file")
    fi
  fi

  if [[ "${#files[@]}" -eq 0 ]]; then
    hz_log "INFO" "inventory: no inventory files found to load"
    return 0
  fi

  # Merge order: all then host; later overwrites earlier within YAML,
  # but existing shell env overrides YAML (never overwritten).
  local f line k v
  for f in "${files[@]}"; do
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      k="${line%%=*}"
      v="${line#*=}"

      # shell env overrides: if already set and non-empty, do not override
      if [[ -n "${!k-}" ]]; then
        if [[ "$dry" != "0" ]]; then
          hz_log "INFO" "inventory skip (env override): ${k}"
        fi
        continue
      fi

      if [[ "$dry" != "0" ]]; then
        if [[ "$debug" == "1" ]]; then
          hz_log "INFO" "inventory load: ${k}='${v}' (from ${f})"
        else
          hz_log "INFO" "inventory load: ${k} (from ${f})"
        fi
        continue
      fi

      export "${k}=${v}"
    done < <(inventory__dump_kv_from_yaml "$f" || true)
  done

  return 0
}
