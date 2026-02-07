#!/usr/bin/env bash
set -euo pipefail

TMP_HITS=""

cleanup() {
  if [ -n "${TMP_HITS}" ] && [ -f "${TMP_HITS}" ]; then
    rm -f "${TMP_HITS}"
  fi
}

b64_decode() {
  if printf '' | base64 --decode >/dev/null 2>&1; then
    base64 --decode
    return
  fi
  base64 -D
}

regex_escape() {
  printf '%s' "$1" | sed -e 's/[.[\*^$+?(){}|\\]/\\&/g'
}

build_pattern() {
  local encoded_terms=(
    "b3JhY2xl"
    "b2Np"
    "YW1hem9uIHdlYiBzZXJ2aWNlcw=="
    "YXdz"
    "Z2Nw"
    "Z29vZ2xlIGNsb3Vk"
    "YXp1cmU="
    "ZGlnaXRhbG9jZWFu"
    "bGlub2Rl"
    "YWxpYmFiYQ=="
    "dGVuY2VudCBjbG91ZA=="
    "dnVsdHI="
  )
  local pattern_parts=()
  local decoded escaped

  for token in "${encoded_terms[@]}"; do
    decoded="$(printf '%s' "$token" | b64_decode 2>/dev/null || true)"
    [ -n "$decoded" ] || continue
    escaped="$(regex_escape "$decoded")"
    if [[ "$decoded" == *" "* ]]; then
      pattern_parts+=("$escaped")
    else
      pattern_parts+=("\\b${escaped}\\b")
    fi
  done

  if [ "${#pattern_parts[@]}" -eq 0 ]; then
    return 1
  fi

  (IFS='|'; printf '%s' "${pattern_parts[*]}")
}

main() {
  local pattern
  pattern="$(build_pattern)"

  TMP_HITS="$(mktemp)"
  trap cleanup EXIT

  while IFS= read -r path; do
    [ -f "$path" ] || continue
    grep -Hn -I -i -E "$pattern" "$path" 2>/dev/null | cut -d: -f1,2 >>"$TMP_HITS" || true
  done < <(git ls-files)

  if [ -s "$TMP_HITS" ]; then
    sort -u "$TMP_HITS"
    exit 1
  fi

  echo "vendor-neutral scan: PASS"
}

main "$@"
