#!/usr/bin/env bash
set -euo pipefail

# Horizon-Lab Safe Cleaner
# - default: DRY-RUN (no changes)
# - apply requires: CLEAN_APPLY=1 CONFIRM="I_UNDERSTAND"
# - optional destructive flags via env:
#     CLEAN_DOCKER_ALL=1      # remove containers/images/networks + prune volumes
#     CLEAN_APT=1             # apt cache cleanup
#     CLEAN_JOURNAL=1         # journal vacuum
#     CLEAN_WEB=1             # remove common web dirs (with backup)
#     CLEAN_SERVICES=1        # stop/disable common web stack services
#
# Safety:
# - never touches tailscale
# - never removes github runner directories unless you explicitly add it later
# - backups web dirs before delete (tar.gz)

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*"; }

DRY_RUN=1
if [[ "${CLEAN_APPLY:-0}" == "1" && "${CONFIRM:-}" == "I_UNDERSTAND" ]]; then
  DRY_RUN=0
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log "[DRY] $*"
  else
    log "[RUN] $*"
    bash -lc "$*"
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
  run "uname -a || true"
  run "lsb_release -a 2>/dev/null || cat /etc/os-release || true"
  run "uptime || true"
  run "df -hT || true"
  run "free -h || true"
  run "ip -br a || true"
  run "command -v docker >/dev/null 2>&1 && docker ps -a || true"
  run "systemctl --no-pager --failed || true"
  log "=== END PREFLIGHT ==="
}

stop_disable_services() {
  # common services (best-effort)
  local units=(
    nginx apache2 caddy
    lsws openlitespeed
    mysql mariadb
    redis-server memcached
    php8.1-fpm php8.2-fpm php8.3-fpm php-fpm
  )

  log "Stopping/disabling common web stack services (best-effort)..."
  for u in "${units[@]}"; do
    run "systemctl is-enabled $u >/dev/null 2>&1 && systemctl disable --now $u || true"
    run "systemctl is-active  $u >/dev/null 2>&1 && systemctl stop $u || true"
  done
}

clean_docker_all() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found, skip docker cleanup."
    return 0
  fi

  log "Docker cleanup: stop/remove containers + prune images/networks (and volumes if enabled)..."
  run "docker ps -aq | xargs -r docker stop"
  run "docker ps -aq | xargs -r docker rm -f"
  run "docker system prune -af"
  if [[ "${CLEAN_DOCKER_VOLUMES:-0}" == "1" ]]; then
    run "docker volume prune -af"
  fi
}

clean_apt() {
  log "APT cleanup..."
  run "apt-get update -qq || true"
  run "apt-get autoremove -y --purge || true"
  run "apt-get autoclean -y || true"
  run "apt-get clean -y || true"
  run "rm -rf /var/lib/apt/lists/* || true"
}

clean_journal() {
  log "Journal cleanup (vacuum to 3 days)..."
  run "journalctl --vacuum-time=3d || true"
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
  run "mkdir -p '$backup_dir'"

  for p in "${targets[@]}"; do
    if [[ -e "$p" ]]; then
      local bn
      bn="$(echo "$p" | sed 's#/#_#g' | sed 's/^_//')"
      local out="$backup_dir/${bn}_$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
      log "Backup then remove: $p -> $out"
      run "tar -czf '$out' '$p' || true"
      run "rm -rf '$p'"
    else
      log "Skip (not exists): $p"
    fi
  done
}

post_report() {
  log "=== POST REPORT ==="
  run "df -hT || true"
  run "free -h || true"
  run "command -v docker >/dev/null 2>&1 && docker ps -a || true"
  run "systemctl --no-pager --failed || true"
  log "=== END POST ==="
}

main() {
  need_root
  log "Mode: $( [[ $DRY_RUN == 1 ]] && echo DRY-RUN || echo APPLY )"
  log "Flags: SERVICES=${CLEAN_SERVICES:-0} DOCKER_ALL=${CLEAN_DOCKER_ALL:-0} DOCKER_VOLUMES=${CLEAN_DOCKER_VOLUMES:-0} APT=${CLEAN_APT:-0} JOURNAL=${CLEAN_JOURNAL:-0} WEB=${CLEAN_WEB:-0}"

  preflight_report

  if [[ "${CLEAN_SERVICES:-0}" == "1" ]]; then stop_disable_services; fi
  if [[ "${CLEAN_DOCKER_ALL:-0}" == "1" ]]; then clean_docker_all; fi
  if [[ "${CLEAN_APT:-0}" == "1" ]]; then clean_apt; fi
  if [[ "${CLEAN_JOURNAL:-0}" == "1" ]]; then clean_journal; fi
  if [[ "${CLEAN_WEB:-0}" == "1" ]]; then backup_and_remove_web; fi

  post_report

  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN finished. To APPLY: set CLEAN_APPLY=1 and CONFIRM=I_UNDERSTAND in workflow/env."
  else
    log "APPLY finished."
  fi
}

main "$@"
