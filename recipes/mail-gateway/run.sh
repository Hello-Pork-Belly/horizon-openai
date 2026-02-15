#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
# shellcheck source=lib/cli_core.sh
. "${REPO_ROOT}/lib/cli_core.sh"

RC_SUCCESS=0
RC_EXPECTED_FAIL=1

HZ_SUBCOMMAND="${HZ_SUBCOMMAND:-install}"
HZ_DRY_RUN="${HZ_DRY_RUN:-0}"

# Required (contract gate)
MAIL_RELAY_HOST="${MAIL_RELAY_HOST:-}"
MAIL_RELAY_PORT="${MAIL_RELAY_PORT:-}"
MAIL_USERNAME="${MAIL_USERNAME:-}"
MAIL_PASSWORD="${MAIL_PASSWORD:-}"
MAIL_FROM_ADDRESS="${MAIL_FROM_ADDRESS:-}"

# Optional
MAIL_MODE="${MAIL_MODE:-msmtp}"
MAIL_ADMIN_EMAIL="${MAIL_ADMIN_EMAIL:-}"
MAIL_USE_TLS="${MAIL_USE_TLS:-true}"

as_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON) echo "true" ;;
    0|false|FALSE|no|NO|off|OFF|"") echo "false" ;;
    *) echo "false" ;;
  esac
}

ensure_root_or_sudo() {
  if [[ "${EUID:-0}" -eq 0 ]]; then
    echo ""
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    echo "sudo"
    return 0
  fi
  log_error "must run as root or have sudo available"
  return "${RC_EXPECTED_FAIL}"
}

pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

apt_update_once() {
  local sudo_cmd="$1"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would run apt-get update"
    return 0
  fi
  ${sudo_cmd} apt-get update -y
}

apt_install_pkg() {
  local pkg="$1" sudo_cmd="$2"
  if pkg_installed "$pkg"; then
    log_info "package already installed: ${pkg}"
    return 0
  fi
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would install package: ${pkg}"
    return 0
  fi
  log_info "installing package: ${pkg}"
  ${sudo_cmd} apt-get install -y "${pkg}"
}

write_file_root() {
  # Args: sudo_cmd path mode content
  local sudo_cmd="$1" path="$2" mode="$3" content="$4"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would write file ${path} (mode ${mode})"
    return 0
  fi
  printf '%s' "${content}" | ${sudo_cmd} tee "${path}" >/dev/null
  ${sudo_cmd} chmod "${mode}" "${path}"
}

send_test_mail() {
  local to="$1"
  [[ -n "$to" ]] || return 0

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would send test email to ${to}"
    return 0
  fi

  # prefer mail(1), fallback to sendmail
  local subject body
  subject="Horizon mail-gateway test"
  body="This is a test email from Horizon mail-gateway on $(hostname -f 2>/dev/null || hostname)."

  if command -v mail >/dev/null 2>&1; then
    printf '%s\n' "${body}" | mail -s "${subject}" "${to}" || {
      log_error "test email failed via mail(1)"
      return "${RC_EXPECTED_FAIL}"
    }
    log_info "test email sent via mail(1) to ${to}"
    return 0
  fi

  if command -v sendmail >/dev/null 2>&1; then
    {
      echo "From: ${MAIL_FROM_ADDRESS}"
      echo "To: ${to}"
      echo "Subject: ${subject}"
      echo
      echo "${body}"
    } | sendmail -t || {
      log_error "test email failed via sendmail"
      return "${RC_EXPECTED_FAIL}"
    }
    log_info "test email sent via sendmail to ${to}"
    return 0
  fi

  log_warn "no mail(1) or sendmail found; skipping test email"
  return 0
}

configure_msmtp() {
  local sudo_cmd="$1"
  local tls
  tls="$(as_bool "${MAIL_USE_TLS}")"

  log_info "mode=msmtp: configuring outbound SMTP via /etc/msmtprc"
  apt_install_pkg "msmtp" "${sudo_cmd}"
  apt_install_pkg "msmtp-mta" "${sudo_cmd}"
  apt_install_pkg "bsd-mailx" "${sudo_cmd}" || true

  # Use single account as default.
  # Note: msmtp accepts password with special chars; stored as literal line.
  local msmtprc
  msmtprc="defaults
auth           on
tls            ${tls}
tls_starttls   ${tls}
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           ${MAIL_RELAY_HOST}
port           ${MAIL_RELAY_PORT}
from           ${MAIL_FROM_ADDRESS}
user           ${MAIL_USERNAME}
password       ${MAIL_PASSWORD}

account default : default
"
  write_file_root "${sudo_cmd}" "/etc/msmtprc" "600" "${msmtprc}"

  # Ensure log file exists (optional)
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would touch /var/log/msmtp.log and chmod 600"
  else
    ${sudo_cmd} touch /var/log/msmtp.log
    ${sudo_cmd} chmod 600 /var/log/msmtp.log
  fi

  log_info "msmtp configured (secrets hidden; use --verbose for masked debug)"
  log_debug "$(hz_mask_kv_line "MAIL_PASSWORD=${MAIL_PASSWORD}")"
}

configure_postfix() {
  local sudo_cmd="$1"
  local tls
  tls="$(as_bool "${MAIL_USE_TLS}")"

  log_info "mode=postfix: configuring postfix relay"
  # postfix uses debconf; keep it minimal, no interactive config required for relay mode
  apt_install_pkg "postfix" "${sudo_cmd}"
  apt_install_pkg "libsasl2-modules" "${sudo_cmd}"
  apt_install_pkg "bsd-mailx" "${sudo_cmd}" || true

  local sasl="/etc/postfix/sasl_passwd"
  local entry
  entry="[${MAIL_RELAY_HOST}]:${MAIL_RELAY_PORT} ${MAIL_USERNAME}:${MAIL_PASSWORD}
"
  write_file_root "${sudo_cmd}" "${sasl}" "600" "${entry}"

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would run postmap ${sasl}"
  else
    ${sudo_cmd} postmap "${sasl}"
    ${sudo_cmd} chmod 600 "${sasl}.db" || true
  fi

  # Minimal main.cf lines for relay + sasl auth
  # Conservative: set/replace keys via append (idempotent enough for first port).
  local maincf="/etc/postfix/main.cf"
  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would configure ${maincf} relayhost/sasl/tls"
  else
    ${sudo_cmd} sed -i -E '/^relayhost[[:space:]]*=.*/d' "${maincf}" || true
    ${sudo_cmd} sed -i -E '/^smtp_sasl_auth_enable[[:space:]]*=.*/d' "${maincf}" || true
    ${sudo_cmd} sed -i -E '/^smtp_sasl_password_maps[[:space:]]*=.*/d' "${maincf}" || true
    ${sudo_cmd} sed -i -E '/^smtp_sasl_security_options[[:space:]]*=.*/d' "${maincf}" || true
    ${sudo_cmd} sed -i -E '/^smtp_use_tls[[:space:]]*=.*/d' "${maincf}" || true
    ${sudo_cmd} sed -i -E '/^smtp_tls_security_level[[:space:]]*=.*/d' "${maincf}" || true
    ${sudo_cmd} sed -i -E '/^smtp_tls_CAfile[[:space:]]*=.*/d' "${maincf}" || true

    {
      echo "relayhost = [${MAIL_RELAY_HOST}]:${MAIL_RELAY_PORT}"
      echo "smtp_sasl_auth_enable = yes"
      echo "smtp_sasl_password_maps = hash:${sasl}"
      echo "smtp_sasl_security_options = noanonymous"
      echo "smtp_use_tls = ${tls}"
      echo "smtp_tls_security_level = may"
      echo "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
    } | ${sudo_cmd} tee -a "${maincf}" >/dev/null
  fi

  if [[ "${HZ_DRY_RUN}" != "0" ]]; then
    log_info "dry-run: would restart postfix"
  else
    if command -v systemctl >/dev/null 2>&1; then
      ${sudo_cmd} systemctl restart postfix
    else
      ${sudo_cmd} service postfix restart || true
    fi
  fi

  log_info "postfix relay configured (secrets hidden; use --verbose for masked debug)"
  log_debug "$(hz_mask_kv_line "MAIL_PASSWORD=${MAIL_PASSWORD}")"
}

case "${HZ_SUBCOMMAND}" in
  install|status|check|upgrade|backup|restore|uninstall|diagnostics) ;;
  *)
    log_error "missing or invalid HZ_SUBCOMMAND"
    exit "${RC_EXPECTED_FAIL}"
    ;;
esac

case "${HZ_DRY_RUN}" in
  0|1|2) ;;
  *)
    log_error "invalid HZ_DRY_RUN (expected 0|1|2)"
    exit "${RC_EXPECTED_FAIL}"
    ;;
esac

log_info "recipe=mail-gateway subcommand=${HZ_SUBCOMMAND} dry_run=${HZ_DRY_RUN}"
log_info "mode=${MAIL_MODE} from=${MAIL_FROM_ADDRESS} relay=${MAIL_RELAY_HOST}:${MAIL_RELAY_PORT}"
log_debug "user=${MAIL_USERNAME} tls=$(as_bool "${MAIL_USE_TLS}")"
log_debug "$(hz_mask_kv_line "MAIL_PASSWORD=${MAIL_PASSWORD}")"

if [[ "${HZ_SUBCOMMAND}" == "check" ]]; then
  log_info "check: contract vars present (enforced by hz)"
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_SUBCOMMAND}" == "status" ]]; then
  if pkg_installed msmtp; then
    log_info "status: msmtp installed=yes"
  else
    log_info "status: msmtp installed=no"
  fi
  if pkg_installed postfix; then
    log_info "status: postfix installed=yes"
  else
    log_info "status: postfix installed=no"
  fi
  exit "${RC_SUCCESS}"
fi

if [[ "${HZ_DRY_RUN}" != "0" ]]; then
  log_info "dry-run: would run apt-get update"
  case "${MAIL_MODE}" in
    msmtp|"")
      log_info "dry-run: would install package: msmtp"
      log_info "dry-run: would install package: msmtp-mta"
      log_info "dry-run: would install package: bsd-mailx"
      log_info "dry-run: would write file /etc/msmtprc (mode 600)"
      log_info "dry-run: would touch /var/log/msmtp.log and chmod 600"
      ;;
    postfix)
      log_info "dry-run: would install package: postfix"
      log_info "dry-run: would install package: libsasl2-modules"
      log_info "dry-run: would install package: bsd-mailx"
      log_info "dry-run: would write file /etc/postfix/sasl_passwd (mode 600)"
      log_info "dry-run: would run postmap /etc/postfix/sasl_passwd"
      log_info "dry-run: would configure /etc/postfix/main.cf relayhost/sasl/tls"
      log_info "dry-run: would restart postfix"
      ;;
    *)
      log_error "unknown MAIL_MODE: ${MAIL_MODE} (supported: msmtp, postfix)"
      exit "${RC_EXPECTED_FAIL}"
      ;;
  esac

  if [[ -n "${MAIL_ADMIN_EMAIL}" ]]; then
    log_info "dry-run: would send test email to ${MAIL_ADMIN_EMAIL}"
  else
    log_info "test: MAIL_ADMIN_EMAIL not set; skipping test email"
  fi

  log_info "done: mail-gateway configured"
  exit "${RC_SUCCESS}"
fi

sudo_cmd="$(ensure_root_or_sudo)" || exit "${RC_EXPECTED_FAIL}"
command -v apt-get >/dev/null 2>&1 || { log_error "apt-get not found"; exit "${RC_EXPECTED_FAIL}"; }
command -v dpkg >/dev/null 2>&1 || { log_error "dpkg not found"; exit "${RC_EXPECTED_FAIL}"; }

apt_update_once "${sudo_cmd}"

case "${MAIL_MODE}" in
  msmtp|"")
    configure_msmtp "${sudo_cmd}"
    ;;
  postfix)
    configure_postfix "${sudo_cmd}"
    ;;
  *)
    log_error "unknown MAIL_MODE: ${MAIL_MODE} (supported: msmtp, postfix)"
    exit "${RC_EXPECTED_FAIL}"
    ;;
esac

if [[ -n "${MAIL_ADMIN_EMAIL}" ]]; then
  log_info "test: sending test email to MAIL_ADMIN_EMAIL=${MAIL_ADMIN_EMAIL}"
  send_test_mail "${MAIL_ADMIN_EMAIL}" || exit "${RC_EXPECTED_FAIL}"
else
  log_info "test: MAIL_ADMIN_EMAIL not set; skipping test email"
fi

log_info "done: mail-gateway configured"
exit "${RC_SUCCESS}"
