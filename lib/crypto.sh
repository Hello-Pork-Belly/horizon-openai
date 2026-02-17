#!/bin/bash
set -euo pipefail

# lib/crypto.sh
# Phase 5 secret helpers.
# Encrypted format: HZENC:<single-line-base64>
#
# Env:
# - HZ_SECRET_KEY: passphrase used by OpenSSL enc/decrypt.

crypto__log_warn() { command -v log_warn >/dev/null 2>&1 && log_warn "$@" || echo "WARN: $*" >&2; }
crypto__log_error() { command -v log_error >/dev/null 2>&1 && log_error "$@" || echo "ERROR: $*" >&2; }

crypto__require_openssl() {
  command -v openssl >/dev/null 2>&1 || {
    crypto__log_error "openssl not found"
    return 1
  }
}

crypto__require_key() {
  [[ -n "${HZ_SECRET_KEY:-}" ]] || {
    crypto__log_error "HZ_SECRET_KEY is not set"
    return 1
  }
}

crypto__require_pbkdf2() {
  crypto__require_openssl || return 1
  HZ_SECRET_KEY="probe" openssl enc -aes-256-cbc -pbkdf2 -salt -a -A -pass env:HZ_SECRET_KEY </dev/null >/dev/null 2>&1 || {
    crypto__log_error "OpenSSL missing -pbkdf2 support (need >=1.1.1)"
    return 1
  }
}

crypto_gen_key() {
  crypto__require_openssl || return 1
  openssl rand -base64 32
}

crypto_encrypt_string() {
  crypto__require_openssl || return 1
  crypto__require_key || return 1
  crypto__require_pbkdf2 || return 1

  local plaintext="${1:-}"
  if [[ -z "$plaintext" ]]; then
    plaintext="$(cat)"
  fi

  local cipher=""
  cipher="$(printf '%s' "$plaintext" | openssl enc -aes-256-cbc -pbkdf2 -salt -a -A -pass env:HZ_SECRET_KEY 2>/dev/null)" || {
    crypto__log_error "encryption failed"
    return 1
  }

  printf 'HZENC:%s\n' "$cipher"
}

crypto_decrypt_string() {
  crypto__require_openssl || return 1
  crypto__require_key || return 1
  crypto__require_pbkdf2 || return 1

  local enc="${1:-}"
  if [[ -z "$enc" ]]; then
    enc="$(cat)"
  fi

  [[ "$enc" == HZENC:* ]] || {
    crypto__log_error "input is not HZENC:*"
    return 1
  }

  local b64="${enc#HZENC:}"
  local plain=""
  plain="$(printf '%s' "$b64" | openssl enc -d -aes-256-cbc -pbkdf2 -a -A -pass env:HZ_SECRET_KEY 2>/dev/null)" || {
    crypto__log_error "decryption failed (wrong key or corrupted ciphertext)"
    return 1
  }

  printf '%s\n' "$plain"
}
