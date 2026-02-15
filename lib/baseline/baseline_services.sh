#!/usr/bin/env bash
set -euo pipefail

baseline_service_active() {
  local svc="$1"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active --quiet "$svc"
    return $?
  fi
  # Fallback: process grep (best-effort)
  pgrep -x "$svc" >/dev/null 2>&1
}

baseline_check_service() {
  local label="$1" svc="$2"
  log_info "service: ${label}"
  if [[ "${HZ_DRY_RUN:-0}" != "0" ]]; then
    log_info "dry-run: would check service status for ${svc}"
    return 0
  fi

  if baseline_service_active "$svc"; then
    log_info "service: ${label} status=running"
  else
    log_warn "service: ${label} status=not-running-or-not-found"
  fi
}

baseline_check_web_stack() {
  baseline_check_service "nginx" "nginx"
  baseline_check_service "openlitespeed" "lshttpd"
}

baseline_check_data_stack() {
  baseline_check_service "mariadb/mysql" "mariadb" || true
  baseline_check_service "mysql" "mysql" || true
  baseline_check_service "redis" "redis-server" || true
}
