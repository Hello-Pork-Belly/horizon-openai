#!/bin/bash
set -euo pipefail

hz_recipe_dir() { echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/recipes/${1}"; }
hz_recipe_contract_path() { echo "$(hz_recipe_dir "$1")/contract.yml"; }
hz_recipe_run_path() { echo "$(hz_recipe_dir "$1")/run.sh"; }

hz__parse_required_env() {
  local contract="$1"
  awk '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function indent_of(s, t){
      t = s
      sub(/[^ \t].*$/, "", t)
      return length(t)
    }
    function emit(v){
      v = trim(v)
      if (v == "") return
      if (v !~ /^[A-Z_][A-Z0-9_]*$/) return
      if (!seen[v]++) print v
    }
    BEGIN { in_block=0; block_indent=-1; parse_error=0 }
    /^[ \t]*($|#)/ { next }
    {
      line=$0
      if (in_block) {
        cur_indent = indent_of(line)
        if (cur_indent <= block_indent) { in_block=0; block_indent=-1 }
        else {
          item = trim(line)
          if (item ~ /^-[ \t]*/) {
            sub(/^-[ \t]*/, "", item)
            emit(item)
            next
          }
          parse_error=1
          next
        }
      }

      tl = trim(line)
      if (tl ~ /^required_env:[ \t]*/) {
        if (tl ~ /^required_env:[ \t]*\[/) {
          inline = tl
          sub(/^required_env:[ \t]*\[/, "", inline)
          if (inline !~ /\][ \t]*$/) {
            parse_error=1
            next
          }
          sub(/\][ \t]*$/, "", inline)
          n = split(inline, parts, ",")
          for (i=1;i<=n;i++) emit(parts[i])
          next
        }
        if (tl ~ /^required_env:[ \t]*$/) {
          in_block=1
          block_indent = indent_of(line)
          next
        }
        parse_error=1
        next
      }
    }
    END {
      if (parse_error) exit 2
    }
  ' "$contract"
}

hz__validate_required_env_set() {
  local missing=0 v
  for v in "$@"; do
    if [[ -z "${!v-}" ]]; then
      log_error "missing required env var: ${v}"
      missing=1
    fi
  done
  return "$missing"
}

hz_recipe_install() {
  local name="${1:-}"
  local d contract run
  local required=()

  [[ -n "$name" ]] || { hz_usage; return 1; }

  d="$(hz_recipe_dir "$name")"
  contract="$(hz_recipe_contract_path "$name")"
  run="$(hz_recipe_run_path "$name")"

  [[ -d "$d" ]] || { log_error "recipe not found: recipes/${name}"; return 1; }
  [[ -f "$run" ]] || { log_error "missing run.sh: recipes/${name}/run.sh"; return 1; }
  [[ -f "$contract" ]] || { log_error "missing contract.yml: recipes/${name}/contract.yml"; return 1; }

  if command -v inventory_load_vars >/dev/null 2>&1; then
    log_debug "loading inventory before contract (host='${HZ_HOST:-}')"
    inventory_load_vars "${HZ_HOST:-}" || return 1
  fi

  local required_vars_output=""
  log_debug "parsing contract: ${contract}"
  if ! required_vars_output="$(hz__parse_required_env "$contract")"; then
    log_error "ABORT: failed to parse required_env from contract; run.sh was NOT executed"
    return 1
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    required+=("$line")
  done <<< "$required_vars_output"

  if [[ "${#required[@]}" -gt 0 ]]; then
    log_debug "contract required_env: ${required[*]}"
    if ! hz__validate_required_env_set "${required[@]}"; then
      log_error "ABORT: contract validation failed; run.sh was NOT executed"
      return 1
    fi
  else
    log_warn "no required_env declared in contract; proceeding"
  fi

  log_info "executing: bash recipes/${name}/run.sh"
  bash "$run"
}
