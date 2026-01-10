#!/usr/bin/env bash
set -euo pipefail

# Rebind GitHub Actions runner to a new repo (safe-ish)
# Required env:
#   REPO_URL="https://github.com/<owner>/<repo>"
#   RUNNER_TOKEN="<registration-token>"   (registration token from GitHub UI)
# Optional env:
#   RUNNER_DIR="/opt/actions-runner"
#   RUNNER_NAME="$(hostname)-runner"
#   RUNNER_LABELS="self-hosted,linux"
#   CPU_QUOTA="80%"
#   MEMORY_HIGH="1024M"

need_root() { [[ "$(id -u)" -eq 0 ]] || { echo "ERROR: run as root"; exit 1; }; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing $1"; exit 1; }; }

detect_service_units() {
  systemctl list-units --type=service --all "actions.runner*" --no-legend 2>/dev/null | awk '{print $1}' || true
}

stop_and_uninstall_existing() {
  local units
  units="$(detect_service_units)"
  if [[ -n "${units}" ]]; then
    echo "[INFO] Found existing runner services:"
    echo "${units}"
  fi

  if [[ -d "${RUNNER_DIR}/" ]]; then
    if [[ -x "${RUNNER_DIR}/svc.sh" ]]; then
      echo "[INFO] Stopping/uninstalling existing runner service (best-effort)."
      "${RUNNER_DIR}/svc.sh" stop || true
      "${RUNNER_DIR}/svc.sh" uninstall || true
    fi
    echo "[INFO] Removing old runner local config files (keeps directory)."
    rm -f "${RUNNER_DIR}/.runner" "${RUNNER_DIR}/.credentials" "${RUNNER_DIR}/.credentials_rsaparams" || true
  fi
}

install_runner_if_needed() {
  mkdir -p "${RUNNER_DIR}"
  if [[ ! -x "${RUNNER_DIR}/config.sh" ]]; then
    echo "[INFO] Runner not found in ${RUNNER_DIR}, installing latest."
    local tmp="/tmp/actions-runner-install"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    cd "$tmp"

    # Pick arch
    local arch
    arch="$(uname -m)"
    local runner_arch=""
    case "$arch" in
      x86_64) runner_arch="x64" ;;
      aarch64|arm64) runner_arch="arm64" ;;
      *) echo "ERROR: unsupported arch: $arch"; exit 1 ;;
    esac

    # Fetch latest via GitHub redirect (no hardcoded version)
    need curl
    need tar
    local url="https://github.com/actions/runner/releases/latest/download/actions-runner-linux-${runner_arch}.tar.gz"
    curl -fsSL "$url" -o runner.tgz
    tar -xzf runner.tgz
    cp -a ./* "${RUNNER_DIR}/"
    cd /
    rm -rf "$tmp"
  fi

  # deps
  if [[ -x "${RUNNER_DIR}/bin/installdependencies.sh" ]]; then
    "${RUNNER_DIR}/bin/installdependencies.sh" || true
  fi
}

configure_runner() {
  : "${REPO_URL:?missing REPO_URL}"
  : "${RUNNER_TOKEN:?missing RUNNER_TOKEN}"

  local name="${RUNNER_NAME:-$(hostname)-runner}"
  local labels="${RUNNER_LABELS:-self-hosted,linux}"
  echo "[INFO] Configuring runner for ${REPO_URL}"
  echo "[INFO] Name=${name}"
  echo "[INFO] Labels=${labels}"

  cd "${RUNNER_DIR}"
  ./config.sh remove --unattended || true

  ./config.sh \
    --unattended \
    --url "${REPO_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${name}" \
    --labels "${labels}" \
    --work "_work" \
    --replace

  ./svc.sh install
  ./svc.sh start
}

apply_systemd_limits() {
  local cpu="${CPU_QUOTA:-80%}"
  local mem="${MEMORY_HIGH:-1024M}"

  local unit
  unit="$(detect_service_units | head -n1 || true)"
  if [[ -z "$unit" ]]; then
    echo "[WARN] Runner systemd unit not detected yet. Skipping limits."
    return 0
  fi

  echo "[INFO] Applying systemd limits to ${unit}: CPUQuota=${cpu}, MemoryHigh=${mem}"
  local dropin="/etc/systemd/system/${unit}.d"
  mkdir -p "$dropin"
  cat > "${dropin}/override.conf" <<EOF
[Service]
CPUQuota=${cpu}
MemoryHigh=${mem}
EOF

  systemctl daemon-reload
  systemctl restart "${unit}" || true
  systemctl --no-pager status "${unit}" || true
}

main() {
  need_root
  need systemctl
  need bash

  RUNNER_DIR="${RUNNER_DIR:-/opt/actions-runner}"

  stop_and_uninstall_existing
  install_runner_if_needed
  configure_runner
  apply_systemd_limits

  echo "[OK] Runner rebind finished."
}

main "$@"
