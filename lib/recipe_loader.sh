#!/bin/bash
set -euo pipefail

# Contract-first recipe loader for hz.
# Pure bash; minimal YAML subset parser for required_env.

hz_recipe_dir() {
  local root name
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  name="${1:-}"
  echo "${root}/recipes/${name}"
}

hz_recipe_contract_path() {
  local d
  d="$(hz_recipe_dir "$1")"
  echo "${d}/contract.yml"
}

hz_recipe_run_path() {
  local d
  d="$(hz_recipe_dir "$1")"
  echo "${d}/run.sh"
}

hz__parse_required_env() {
  # Extract required env vars from contract.yml.
  # Supports:
  #   required_env: [A, B]
  #   required_env:
  #     - A
  #     - B
  # Also supports nested under inputs:
  #
  # Output: one var name per line (unique, in-order best effort).
  local contract="$1"

  awk '
    function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function emit(v){
      v = trim(v)
      if (v == "") return
      # basic name sanity: A-Z0-9_
      if (v !~ /^[A-Z_][A-Z0-9_]*$/) return
      if (!seen[v]++) print v
    }

    BEGIN {
      in_block = 0
      block_indent = -1
    }

    # Detect required_env key (top-level or inside inputs)
    {
      line = $0
      # Skip comments/blank
      if (line ~ /^[ \t]*($|#)/) next
      cur_indent = length(line) - length(trim(line))

      # If currently reading block list, continue until indent decreases
      if (in_block) {
        if (cur_indent <= block_indent) {
          in_block = 0
          block_indent = -1
        } else {
          item = trim(line)
          if (item ~ /^-[ \t]*/) {
            sub(/^-[ \t]*/, "", item)
            emit(item)
          }
          next
        }
      }

      # Match required_env: [A, B]
      tl = trim(line)
      if (tl ~ /^required_env:[ \t]*\[/) {
        sub(/^required_env:[ \t]*\[/, "", tl)
        sub(/\][ \t]*$/, "", tl)
        n = split(tl, parts, ",")
        for (i = 1; i <= n; i++) emit(parts[i])
        next
      }

      # Match required_env: then start block
      if (tl ~ /^required_env:[ \t]*$/) {
        in_block = 1
        block_indent = cur_indent
        next
      }

      # Also allow required_env inside inputs: without needing exact path matching,
      # because we already accept it globally; however nesting is handled by indent.
      # (No extra branch needed.)
    }
  ' "$contract"
}

hz__validate_required_env_set() {
  # args: var1 var2 ...
  local missing=0 v
  for v in "$@"; do
    # indirect expansion; treat unset or empty as missing
    if [[ -z "${!v-}" ]]; then
      hz_log "ERROR" "missing required env var: ${v}"
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

  [[ -d "$d" ]] || { hz_die "recipe not found: recipes/${name}"; return 1; }
  [[ -f "$run" ]] || { hz_die "missing run.sh: recipes/${name}/run.sh"; return 1; }
  [[ -f "$contract" ]] || { hz_die "missing contract.yml: recipes/${name}/contract.yml"; return 1; }

  # Inventory integration (load BEFORE contract enforcement)
  if command -v inventory_load_vars >/dev/null 2>&1; then
    hz_log "INFO" "inventory load (host='${HZ_HOST:-}')"
    inventory_load_vars "${HZ_HOST:-}" || return 1
  fi

  # Load required_env from contract (hard-fail on parser errors)
  local parsed_required=""
  if ! parsed_required="$(hz__parse_required_env "$contract")"; then
    hz_log "ERROR" "ABORT: failed to parse required_env from contract; run.sh was NOT executed"
    return 1
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    required+=("$line")
  done <<< "$parsed_required"

  if [[ "${#required[@]}" -gt 0 ]]; then
    hz_log "INFO" "contract required_env: ${required[*]}"
    if ! hz__validate_required_env_set "${required[@]}"; then
      hz_log "ERROR" "ABORT: contract validation failed; run.sh was NOT executed"
      return 1
    fi
  else
    hz_log "WARN" "no required_env declared in contract; proceeding"
  fi

  hz_log "INFO" "executing: bash recipes/${name}/run.sh"
  HZ_SUBCOMMAND="install" \
  HZ_TARGET_TYPE="recipes" \
  HZ_TARGET_NAME="$name" \
  bash "$run"
}
