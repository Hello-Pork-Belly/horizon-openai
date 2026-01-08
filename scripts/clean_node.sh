#!/usr/bin/env bash
set -euo pipefail

# Horizon-Lab Safe Cleaner
# - default: DRY-RUN (no changes)
# - apply requires: APPLY=true
# - optional destructive flags via env:
#     PRUNE_VOLUMES=true     # prune docker volumes
#     CLEAN_WEB=true         # remove common web dirs (with backup)
#
# Safety:
# - never touches tailscale
# - never removes github runner directories unless you explicitly add it later
# - backups web dirs before delete (tar.gz)

is_truthy() {
  local value
  value="${1:-}"
  value="${value,,}"
  case "$value" in
    true|1|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*"; }

APPLY=${APPLY:-false}
PRUNE_VOLUMES=${PRUNE_VOLUMES:-false}
CLEAN_WEB=${CLEAN_WEB:-false}

if is_truthy "$APPLY"; then
  MODE="APPLY"
else
  MODE="DRY-RUN"
fi

log "=== MODE: $MODE ==="
log "Prune Volumes: $(is_truthy "$PRUNE_VOLUMES" && echo YES || echo NO)  Clean Web: $(is_truthy "$CLEAN_WEB" && echo YES || echo NO)"

run_cmd() {
  if [[ "$MODE" == "APPLY" ]]; then
    log "[EXEC] $*"
    bash -lc "$*"
  else
    log "[DRY] Would run: $*"
  fi
}

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log "ERROR: must run as root."
    exit 1
  fi
}

preflight_report() {
  log "=== PREFLIGHT REPORT ==="
  run_cmd "uname -a || true"
  run_cmd "lsb_release -a 2>/dev/null || cat /etc/os-release || true"
  run_cmd "uptime || true"
  run_cmd "df -hT || true"
  run_cmd "free -h || true"
  run_cmd "ip -br a || true"
  run_cmd "command -v docker >/dev/null 2>&1 && docker ps -a || true"
  run_cmd "systemctl --no-pager --failed || true"
  log "=== END PREFLIGHT ==="
}

clean_docker_all() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found, skip docker cleanup."
    return 0
  fi

  log "Docker cleanup: remove containers + prune images/networks (and volumes if enabled)..."
  run_cmd "docker ps -aq | xargs -r docker rm -f"
  if is_truthy "$PRUNE_VOLUMES"; then
    run_cmd "docker system prune -af --volumes"
  else
    run_cmd "docker system prune -af"
  fi
}

backup_and_remove_web() {
  # conservative list; you can extend later
  local targets=(
    "/var/www"
    "/usr/local/lsws"
    "/usr/local/openlitespeed"
    "/etc/nginx"
    "/etc/apache2"
  )

  local backup_dir="/var/backups/horizon-lab"
  run_cmd "mkdir -p '$backup_dir'"

  for p in "${targets[@]}"; do
    if [[ -e "$p" ]]; then
      local bn
      bn="$(echo "$p" | sed 's#/#_#g' | sed 's/^_//')"
      local out="$backup_dir/${bn}_$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
      log "Backup then remove: $p -> $out"
      run_cmd "tar -czf '$out' '$p' || true"
      run_cmd "rm -rf '$p'"
    else
      log "Skip (not exists): $p"
    fi
  done
}

post_report() {
  log "=== POST REPORT ==="
  run_cmd "df -hT || true"
  run_cmd "free -h || true"
  run_cmd "command -v docker >/dev/null 2>&1 && docker ps -a || true"
  run_cmd "systemctl --no-pager --failed || true"
  log "=== END POST ==="
}

main() {
  need_root

  preflight_report

  clean_docker_all
  if is_truthy "$CLEAN_WEB"; then backup_and_remove_web; fi

  post_report

  if [[ "$MODE" == "DRY-RUN" ]]; then
    log "DRY-RUN finished. To APPLY: set APPLY=true in workflow/env."
  else
    log "APPLY finished."
  fi
}

main "$@"
