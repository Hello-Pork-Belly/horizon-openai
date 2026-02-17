#!/bin/bash
set -euo pipefail

# lib/completion.sh
# Shell completion generator for hz.

hz_completion_print() {
  local shell="${1:-}"

  if [[ -z "${shell}" ]]; then
    if [[ -n "${ZSH_VERSION:-}" ]]; then
      shell="zsh"
    else
      shell="bash"
    fi
  fi

  case "${shell}" in
    bash)
      cat <<'BASH_EOF'
# Bash completion for hz
# Usage:
#   source <(hz completion bash)

_hz_repo_root() {
  local hp d link
  hp="$(command -v hz 2>/dev/null || true)"
  [[ -n "${hp}" ]] || return 1

  d="$(cd "$(dirname "${hp}")" && pwd)"
  hp="${d}/$(basename "${hp}")"

  while [[ -L "${hp}" ]]; do
    link="$(readlink "${hp}" || true)"
    [[ -n "${link}" ]] || break
    if [[ "${link}" = /* ]]; then
      hp="${link}"
    else
      hp="$(cd "$(dirname "${hp}")" && cd "$(dirname "${link}")" 2>/dev/null && pwd)/$(basename "${link}")"
    fi
  done

  echo "$(cd "$(dirname "${hp}")/.." && pwd)"
}

_hz_list_recipes() {
  local root
  root="$(_hz_repo_root 2>/dev/null)" || return 0
  [[ -d "${root}/recipes" ]] || return 0
  (cd "${root}/recipes" && ls -1d */ 2>/dev/null | sed 's:/$::' | sort) || true
}

_hz_list_hosts() {
  local root
  root="$(_hz_repo_root 2>/dev/null)" || return 0
  [[ -d "${root}/inventory/hosts" ]] || return 0
  (cd "${root}/inventory/hosts" && ls -1 *.yml 2>/dev/null | sed 's:\.yml$::' | sort) || true
}

_hz_list_groups() {
  local root
  root="$(_hz_repo_root 2>/dev/null)" || return 0
  [[ -d "${root}/inventory/groups" ]] || return 0
  (cd "${root}/inventory/groups" && ls -1 *.yml 2>/dev/null | sed 's:\.yml$::' | sed 's:^:@:' | sort) || true
}

_hz_complete() {
  local cur prev cmd sub
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmd="${COMP_WORDS[1]:-}"
  sub="${COMP_WORDS[2]:-}"

  local commands="check install ping diagnose doctor inventory recipe module notify cron watch report secret completion version help"
  if [[ "${COMP_CWORD}" -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${commands}" -- "${cur}") )
    return 0
  fi

  if [[ "${prev}" == "--target" ]]; then
    local tg
    tg="$(_hz_list_hosts) $(_hz_list_groups)"
    COMPREPLY=( $(compgen -W "${tg}" -- "${cur}") )
    return 0
  fi

  case "${cmd}" in
    install)
      if [[ "${COMP_CWORD}" -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "$(_hz_list_recipes)" -- "${cur}") )
        return 0
      fi
      COMPREPLY=( $(compgen -W "--dry-run --target --target= --host --host= --rolling --rolling= --pause --pause= --timeout --timeout= --local-mode --headless" -- "${cur}") )
      return 0
      ;;
    report)
      if [[ "${COMP_CWORD}" -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "html" -- "${cur}") )
        return 0
      fi
      if [[ "${sub}" == "html" ]]; then
        COMPREPLY=( $(compgen -W "--latest --out --out=" -- "${cur}") )
        return 0
      fi
      ;;
    secret)
      if [[ "${COMP_CWORD}" -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "gen-key encrypt decrypt" -- "${cur}") )
        return 0
      fi
      ;;
    cron)
      if [[ "${COMP_CWORD}" -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "list add remove" -- "${cur}") )
        return 0
      fi
      ;;
    watch)
      if [[ "${COMP_CWORD}" -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "run once install" -- "${cur}") )
        return 0
      fi
      COMPREPLY=( $(compgen -W "--heal --schedule --schedule= --user --user= --name --name=" -- "${cur}") )
      return 0
      ;;
    inventory)
      if [[ "${COMP_CWORD}" -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "resolve" -- "${cur}") )
        return 0
      fi
      if [[ "${COMP_CWORD}" -eq 3 && "${sub}" == "resolve" ]]; then
        COMPREPLY=( $(compgen -W "$(_hz_list_hosts) $(_hz_list_groups)" -- "${cur}") )
        return 0
      fi
      ;;
    completion)
      COMPREPLY=( $(compgen -W "bash zsh" -- "${cur}") )
      return 0
      ;;
  esac

  COMPREPLY=()
  return 0
}

complete -o bashdefault -o default -F _hz_complete hz
BASH_EOF
      ;;
    zsh)
      cat <<'ZSH_EOF'
# Zsh completion for hz (via bashcompinit)
# Usage:
#   source <(hz completion zsh)

autoload -U +X bashcompinit && bashcompinit
source <(hz completion bash)
ZSH_EOF
      ;;
    *)
      echo "Unknown shell: ${shell}. Expected: bash|zsh" >&2
      return 1
      ;;
  esac
}
