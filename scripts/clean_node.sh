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
# noop


parse_bool() {
  local value
  value="${1:-}"
  value="${value//[[:space:]]/}"
  value="${value,,}"
  if [[ -z "$value" ]]; then
    echo ""
    return 0
  fi

  case "$value" in
codex/sync-allowed-policy/docs-from-1click-to-hlab
    true|1|yes|on)
      echo "true"
      ;;
    false|0|no|off)
      echo "false"
      ;;
    *)
      log "ERROR: invalid boolean value: '$1' (expected true/false)."
      exit 1
      ;;
=======
    "") echo "" ;;
    true|1|yes|on) echo "true" ;;
    false|0|no|off) echo "false" ;;
    *) echo "invalid" ;;
main
  esac
}

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*"; }

APPLY_VALUE="$(parse_bool "${APPLY:-${CLEAN_APPLY:-}}")"
PRUNE_VOLUMES_VALUE="$(parse_bool "${PRUNE_VOLUMES:-}")"
CLEAN_WEB_VALUE="$(parse_bool "${CLEAN_WEB:-}")"

codex/sync-allowed-policy/docs-from-1click-to-hlab
if [[ "$APPLY_VALUE" == "true" ]]; then
=======
APPLY_STATE="$(parse_bool "$APPLY_VALUE")"
PRUNE_STATE="$(parse_bool "$PRUNE_VOLUMES_VALUE")"
CLEAN_WEB_STATE="$(parse_bool "$CLEAN_WEB_VALUE")"

if [[ "$APPLY_STATE" == "invalid" ]]; then
  log "[WARN] Invalid APPLY value '$APPLY_VALUE'; defaulting to DRY-RUN."
  APPLY_STATE="false"
fi
if [[ "$PRUNE_STATE" == "invalid" ]]; then
  log "[WARN] Invalid PRUNE_VOLUMES value '$PRUNE_VOLUMES_VALUE'; defaulting to NO."
  PRUNE_STATE="false"
fi
if [[ "$CLEAN_WEB_STATE" == "invalid" ]]; then
  log "[WARN] Invalid CLEAN_WEB value '$CLEAN_WEB_VALUE'; defaulting to NO."
  CLEAN_WEB_STATE="false"
fi

if [[ "$APPLY_STATE" == "true" ]]; then
main
  APPLY_ENABLED=true
  MODE="APPLY"
else
  APPLY_ENABLED=false
  MODE="DRY-RUN"
fi

codex/sync-allowed-policy/docs-from-1click-to-hlab
if [[ "$PRUNE_VOLUMES_VALUE" == "true" ]]; then
=======
if [[ "$PRUNE_STATE" == "true" && "$APPLY_ENABLED" == "true" ]]; then
main
  PRUNE_VOLUMES_ENABLED=true
  PRUNE_LABEL="YES"
elif [[ "$PRUNE_STATE" == "true" ]]; then
  PRUNE_VOLUMES_ENABLED=false
  PRUNE_LABEL="IGNORED (requires APPLY)"
else
  PRUNE_VOLUMES_ENABLED=false
  PRUNE_LABEL="NO"
fi

codex/sync-allowed-policy/docs-from-1click-to-hlab
if [[ "$CLEAN_WEB_VALUE" == "true" ]]; then
=======
if [[ "$CLEAN_WEB_STATE" == "true" && "$APPLY_ENABLED" == "true" ]]; then
main
  CLEAN_WEB_ENABLED=true
  CLEAN_WEB_LABEL="YES"
elif [[ "$CLEAN_WEB_STATE" == "true" ]]; then
  CLEAN_WEB_ENABLED=false
  CLEAN_WEB_LABEL="IGNORED (requires APPLY)"
else
  CLEAN_WEB_ENABLED=false
  CLEAN_WEB_LABEL="NO"
fi

if [[ "$APPLY_ENABLED" != "true" ]]; then
  if [[ "$PRUNE_VOLUMES_ENABLED" == "true" || "$CLEAN_WEB_ENABLED" == "true" ]]; then
    log "DRY-RUN: ignoring PRUNE_VOLUMES/CLEAN_WEB flags until APPLY=true."
  fi
  PRUNE_VOLUMES_ENABLED=false
  CLEAN_WEB_ENABLED=false
  PRUNE_LABEL="NO"
  CLEAN_WEB_LABEL="NO"
fi

echo "=== MODE: [$MODE] === Configuration: Prune Volumes: [$PRUNE_LABEL], Clean Web: [$CLEAN_WEB_LABEL]"

run_cmd() {
  if [[ "$#" -eq 0 ]]; then
    log "[WARN] Empty command skipped."
    return 0
  fi
  if [[ "$APPLY_ENABLED" == "true" ]]; then
    if [[ "$#" -eq 0 ]]; then
      log "[WARN] Empty command skipped."
      return 0
    fi
    log "[EXEC] $*"
    eval "$*"
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

  log "Docker cleanup: remove containers and prune images/networks (and volumes if enabled)."
  run_cmd "docker ps -aq | xargs -r docker rm -f"
  if [[ "$PRUNE_VOLUMES_ENABLED" == "true" ]]; then
    run_cmd "docker system prune -af --volumes"
  else
    run_cmd "docker system prune -af"
  fi
}

backup_and_remove_web() {
  # conservative list; you can extend later
  local targets
  targets=(
    "/var/www"
    "/usr/local/lsws"
    "/usr/local/openlitespeed"
    "/etc/nginx"
    "/etc/apache2"
  )

  local backup_dir
  backup_dir="/var/backups/horizon-lab"
  run_cmd "mkdir -p '$backup_dir'"

  for p in "${targets[@]}"; do
    if [[ -e "$p" ]]; then
      local bn
      bn="$(echo "$p" | sed 's#/#_#g' | sed 's/^_//')"
      # Split declaration/assignment to avoid SC2155.
      local out
      out="$backup_dir/${bn}_$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
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
  if [[ "$MODE" == "APPLY" ]]; then
    need_root
  else
    log "DRY-RUN mode: root privileges not required."
  fi

  preflight_report

  clean_docker_all
  if [[ "$CLEAN_WEB_ENABLED" == "true" ]]; then backup_and_remove_web; fi

  post_report

  if [[ "$MODE" == "DRY-RUN" ]]; then
    log "DRY-RUN finished. To APPLY: set APPLY=true in workflow/env."
  else
    log "APPLY finished."
  fi
}

main "$@"
