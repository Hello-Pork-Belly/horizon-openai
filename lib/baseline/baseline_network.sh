#!/usr/bin/env bash
set -euo pipefail

baseline_check_internet() {
  log_info "network: internet"
  if [[ "${HZ_DRY_RUN:-0}" != "0" ]]; then
    log_info "dry-run: would run curl -I https://example.com (or ping)"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -fsSI https://example.com >/dev/null && log_info "network: internet ok" || log_warn "network: internet check failed"
    return 0
  fi

  if command -v ping >/dev/null 2>&1; then
    ping -c 1 1.1.1.1 >/dev/null 2>&1 && log_info "network: ping ok" || log_warn "network: ping failed"
    return 0
  fi

  log_warn "network: no curl/ping found; skipped"
}

baseline_check_dns() {
  log_info "network: dns"
  if [[ "${HZ_DRY_RUN:-0}" != "0" ]]; then
    log_info "dry-run: would resolve github.com"
    return 0
  fi

  if command -v getent >/dev/null 2>&1; then
    getent hosts github.com >/dev/null && log_info "network: dns ok" || log_warn "network: dns failed"
    return 0
  fi

  if command -v nslookup >/dev/null 2>&1; then
    nslookup github.com >/dev/null 2>&1 && log_info "network: dns ok" || log_warn "network: dns failed"
    return 0
  fi

  log_warn "network: no getent/nslookup found; skipped"
}
