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
  case "$value" in
    "") echo "false" ;;
    true|1|yes|y|on) echo "true" ;;
    false|0|no|n|off) echo "false" ;;
    *) echo "invalid" ;;
  esac
}

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*"; }

APPLY_VALUE="${APPLY:-${CLEAN_APPLY:-}}"
PRUNE_VOLUMES_VALUE="${PRUNE_VOLUMES:-}"
CLEAN_WEB_VALUE="${CLEAN_WEB:-${CLEAN:-}}"

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
  APPLY_ENABLED=true
  MODE="APPLY"
else
  APPLY_ENABLED=false
  MODE="DRY-RUN"
fi

PRUNE_VOLUMES_ENABLED=false
PRUNE_LABEL="NO"
if [[ "$PRUNE_STATE" == "true" ]]; then
  if [[ "$APPLY_ENABLED" == "true" ]]; then
    PRUNE_VOLUMES_ENABLED=true
    PRUNE_LABEL="YES"
  else
    log "[WARN] PRUNE_VOLUMES=true ignored without APPLY=true."
    PRUNE_LABEL="IGNORED (requires APPLY=true)"
  fi
fi

CLEAN_WEB_ENABLED=false
CLEAN_WEB_LABEL="NO"
if [[ "$CLEAN_WEB_STATE" == "true" ]]; then
  if [[ "$APPLY_ENABLED" == "true" ]]; then
    CLEAN_WEB_ENABLED=true
    CLEAN_WEB_LABEL="YES"
  else
    log "[WARN] CLEAN_WEB=true ignored without APPLY=true."
    CLEAN_WEB_LABEL="IGNORED (requires APPLY=true)"
  fi
fi

echo "=== MODE: [$MODE] === Configuration: Prune Volumes: [$PRUNE_LABEL], Clean Web: [$CLEAN_WEB_LABEL]"

run_cmd() {
  local cmd
  local requires_apply="false"
  local allow_dry_run="false"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --apply)
        requires_apply="true"
        shift
        ;;
      --always)
        allow_dry_run="true"
        shift
        ;;
      *)
        break
        ;;
    esac
  done
  cmd="$*"
  if [[ -z "$cmd" ]]; then
    log "[WARN] Empty command skipped."
    return 0
  fi
  if [[ "$APPLY_ENABLED" != "true" ]]; then
    if [[ "$requires_apply" == "true" ]]; then
      log "[DRY] Would run: $cmd"
      return 0
    fi
    if [[ "$allow_dry_run" != "true" ]]; then
      log "[DRY] Would run: $cmd"
      return 0
    fi
  fi
  log "[EXEC] $cmd"
  eval "$cmd"
}

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log "ERROR: must run as root."
    exit 1
  fi
}

preflight_report() {
  log "=== PREFLIGHT REPORT ==="
  run_cmd --always "uname -a || true"
  run_cmd --always "lsb_release -a 2>/dev/null || cat /etc/os-release || true"
  run_cmd --always "uptime || true"
  run_cmd --always "df -hT || true"
  run_cmd --always "free -h || true"
  run_cmd --always "ip -br a || true"
  run_cmd --always "command -v docker >/dev/null 2>&1 && docker ps -a || true"
  run_cmd --always "systemctl --no-pager --failed || true"
  log "=== END PREFLIGHT ==="
}

clean_docker_all() {
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found, skip docker cleanup."
    return 0
  fi

  log "Docker cleanup: remove containers and prune images/networks (and volumes if enabled)."
  run_cmd --apply "docker ps -aq | xargs -r docker rm -f"
  if [[ "$PRUNE_VOLUMES_ENABLED" == "true" ]]; then
    run_cmd --apply "docker system prune -af --volumes"
  else
    run_cmd --apply "docker system prune -af"
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
  run_cmd --apply "mkdir -p '$backup_dir'"

  for p in "${targets[@]}"; do
    if [[ -e "$p" ]]; then
      local bn
      bn="$(echo "$p" | sed 's#/#_#g' | sed 's/^_//')"
      # Split declaration/assignment to avoid SC2155.
      local out
      out="$backup_dir/${bn}_$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
      log "Backup then remove: $p -> $out"
      run_cmd --apply "tar -czf '$out' '$p' || true"
      run_cmd --apply "rm -rf '$p'"
    else
      log "Skip (not exists): $p"
    fi
  done
}

post_report() {
  log "=== POST REPORT ==="
  run_cmd --always "df -hT || true"
  run_cmd --always "free -h || true"
  run_cmd --always "command -v docker >/dev/null 2>&1 && docker ps -a || true"
  run_cmd --always "systemctl --no-pager --failed || true"
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
