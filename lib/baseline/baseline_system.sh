#!/usr/bin/env bash
set -euo pipefail

baseline_cmd_exists() { command -v "$1" >/dev/null 2>&1; }

baseline_check_disk() {
  log_info "system: disk"
  if [[ "${HZ_DRY_RUN:-0}" != "0" ]]; then
    log_info "dry-run: would run df -h and df -i"
    return 0
  fi
  df -h || log_warn "disk: df -h failed"
  df -i || log_warn "disk: df -i failed"
}

baseline_check_memory() {
  log_info "system: memory"
  if [[ "${HZ_DRY_RUN:-0}" != "0" ]]; then
    log_info "dry-run: would run free -h (or vm_stat on mac)"
    return 0
  fi
  if baseline_cmd_exists free; then
    free -h || log_warn "memory: free -h failed"
  elif baseline_cmd_exists vm_stat; then
    vm_stat || log_warn "memory: vm_stat failed"
  else
    log_warn "memory: no supported tool found (free/vm_stat)"
  fi
}

baseline_check_cpu_load() {
  log_info "system: load"
  if [[ "${HZ_DRY_RUN:-0}" != "0" ]]; then
    log_info "dry-run: would read uptime"
    return 0
  fi
  uptime || log_warn "load: uptime failed"
}
