#!/bin/bash
set -euo pipefail

# install.sh
# Install Horizon from local checkout or GitHub tarball.

log() { printf "%s\n" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    die "Need sha256sum or shasum for checksum verification"
  fi
}
ensure_writable_dir() {
  local dir="$1"
  mkdir -p "${dir}" 2>/dev/null || die "Cannot create directory: ${dir} (set HZ_INSTALL_DIR/HZ_BIN_DIR)"
  [[ -w "${dir}" ]] || die "Directory is not writable: ${dir}"
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need bash
need curl
need tar
need mktemp

REPO="Hello-Pork-Belly/horizon-openai"
if [[ -f "${ROOT_DIR}/VERSION" ]]; then
  REF_DEFAULT="$(cat "${ROOT_DIR}/VERSION")"
else
  REF_DEFAULT="main"
fi
REF="${HZ_INSTALL_REF:-${REF_DEFAULT}}"
LOCAL_MODE="${HZ_INSTALL_LOCAL:-0}"

is_root=0
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  is_root=1
fi

default_root_dir="/opt/hz"
default_user_dir="${HOME}/.local/opt/hz"
default_bin_root="/usr/local/bin"
default_bin_user="${HOME}/.local/bin"

INSTALL_DIR="${HZ_INSTALL_DIR:-}"
BIN_DIR="${HZ_BIN_DIR:-}"
EXPECT_SHA256="${HZ_INSTALL_SHA256:-}"

if [[ -z "${INSTALL_DIR}" ]]; then
  if [[ "${is_root}" -eq 1 && -w "$(dirname "${default_root_dir}")" ]]; then
    INSTALL_DIR="${default_root_dir}"
  else
    INSTALL_DIR="${default_user_dir}"
  fi
fi

if [[ -z "${BIN_DIR}" ]]; then
  if [[ "${is_root}" -eq 1 && -w "${default_bin_root}" ]]; then
    BIN_DIR="${default_bin_root}"
  else
    BIN_DIR="${default_bin_user}"
  fi
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

log "Installing hz from ${REPO}@${REF}"
log "Install dir: ${INSTALL_DIR}"
log "Bin dir:     ${BIN_DIR}"

mkdir -p "${TMP}/src"

if [[ "${LOCAL_MODE}" == "1" || ( -f "./bin/hz" && -d "./lib" && -d "./recipes" ) ]]; then
  log "Detected local checkout; packaging local files."
  tar -C . -czf "${TMP}/pkg.tgz" \
    --exclude-vcs --exclude "records" --exclude "*.log" \
    bin lib tools recipes inventory VERSION docs 2>/dev/null || \
  tar -C . -czf "${TMP}/pkg.tgz" \
    --exclude-vcs --exclude "records" --exclude "*.log" \
    bin lib tools recipes inventory VERSION docs
else
  url=""
  if [[ "${REF}" == v* ]]; then
    url="https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz"
  elif [[ "${REF}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    url="https://github.com/${REPO}/archive/refs/tags/v${REF}.tar.gz"
  else
    url="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz"
  fi
  log "Downloading: ${url}"
  curl -fsSL "${url}" -o "${TMP}/pkg.tgz"
fi

if [[ -n "${EXPECT_SHA256}" ]]; then
  actual_sha="$(sha256_file "${TMP}/pkg.tgz")"
  if [[ "${actual_sha}" != "${EXPECT_SHA256}" ]]; then
    die "SHA256 mismatch: expected=${EXPECT_SHA256} actual=${actual_sha}"
  fi
  log "SHA256 verified."
fi

if [[ "${LOCAL_MODE}" == "1" || ( -f "./bin/hz" && -d "./lib" && -d "./recipes" ) ]]; then
  tar -C "${TMP}/src" -xzf "${TMP}/pkg.tgz"
else
  tar -C "${TMP}/src" -xzf "${TMP}/pkg.tgz"
  top="$(find "${TMP}/src" -maxdepth 1 -type d -name "${REPO##*/}-*" | head -n1 || true)"
  [[ -n "${top}" ]] || die "Failed to locate extracted source directory."
  mkdir -p "${TMP}/stage"
  cp -a "${top}/bin" "${TMP}/stage/"
  cp -a "${top}/lib" "${TMP}/stage/"
  cp -a "${top}/recipes" "${TMP}/stage/"
  cp -a "${top}/tools" "${TMP}/stage/" 2>/dev/null || true
  cp -a "${top}/inventory" "${TMP}/stage/" 2>/dev/null || true
  cp -a "${top}/VERSION" "${TMP}/stage/" 2>/dev/null || true
  cp -a "${top}/docs" "${TMP}/stage/" 2>/dev/null || true
  rm -rf "${TMP}/src"/*
  cp -a "${TMP}/stage/." "${TMP}/src/"
fi

ensure_writable_dir "${INSTALL_DIR}"
rm -rf "${INSTALL_DIR}/current"
mkdir -p "${INSTALL_DIR}/current"
cp -a "${TMP}/src/." "${INSTALL_DIR}/current/"

ensure_writable_dir "${BIN_DIR}"
cat > "${BIN_DIR}/hz" <<WRAPPER
#!/bin/bash
set -euo pipefail
exec "${INSTALL_DIR}/current/bin/hz" "\$@"
WRAPPER
chmod +x "${BIN_DIR}/hz"

log "Installed: ${BIN_DIR}/hz -> wrapper -> ${INSTALL_DIR}/current/bin/hz"
log "Run:"
log "  hz version"
log "Optional completion:"
log "  source <(hz completion bash)"
