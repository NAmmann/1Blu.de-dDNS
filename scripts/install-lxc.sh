#!/usr/bin/env bash
set -Eeuo pipefail

APP="1Blu.de dDNS"
APP_ID="1blu-ddns"
APP_DIR="/opt/${APP_ID}"
ENV_FILE="/etc/${APP_ID}.env"
SERVICE_FILE="/etc/systemd/system/${APP_ID}.service"
TIMER_FILE="/etc/systemd/system/${APP_ID}.timer"
MOTD_FILE="/etc/update-motd.d/99-${APP_ID}"
UPDATE_BIN="/usr/local/bin/update-${APP_ID}"

YW=$'\033[33m'
GN=$'\033[32m'
RD=$'\033[31m'
BL=$'\033[34m'
CL=$'\033[0m'
CHECK="${GN}✓${CL}"
CROSS="${RD}✗${CL}"
INFO="${BL}i${CL}"

msg_info() {
  echo -e "${INFO} ${YW}${1}${CL}"
}

msg_ok() {
  echo -e "${CHECK} ${GN}${1}${CL}"
}

msg_error() {
  echo -e "${CROSS} ${RD}${1}${CL}" >&2
}

fatal() {
  msg_error "$1"
  exit 1
}

on_error() {
  local exit_code=$?
  local line=${1:-unknown}
  msg_error "Installation failed at line ${line} with exit code ${exit_code}."
  msg_error "Fix the reported issue and rerun: ${UPDATE_BIN}"
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

run_quiet() {
  if [[ "${VERBOSE:-no}" == "yes" ]]; then
    "$@"
  else
    "$@" >/tmp/${APP_ID}.install.log 2>&1
  fi
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || fatal "Run this installer as root inside the LXC container."
}

require_systemd() {
  command -v systemctl >/dev/null 2>&1 || fatal "This installer expects a systemd-based Debian/Ubuntu LXC container."
}

detect_os() {
  [[ -r /etc/os-release ]] || fatal "Cannot detect OS: /etc/os-release is missing."
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    debian | ubuntu) ;;
    *) fatal "Unsupported OS '${ID:-unknown}'. Use a Debian or Ubuntu LXC container." ;;
  esac
  msg_ok "Detected ${PRETTY_NAME:-${ID}}"
}

network_check() {
  msg_info "Checking network and DNS"
  local failed=0
  local host
  for host in deb.debian.org pypi.org files.pythonhosted.org ident.me ksb.1blu.de; do
    if getent hosts "$host" >/dev/null 2>&1; then
      msg_ok "DNS resolves ${host}"
    else
      msg_error "DNS cannot resolve ${host}"
      failed=1
    fi
  done
  [[ "$failed" -eq 0 ]] || fatal "Network/DNS check failed. Fix the container network before installing."
}

apt_update() {
  msg_info "Updating APT package index"
  local attempt
  for attempt in 1 2 3; do
    if run_quiet apt-get update; then
      msg_ok "Updated APT package index"
      return 0
    fi
    msg_error "APT update failed, retrying (${attempt}/3)"
    sleep 2
  done
  fatal "APT update failed. Last log: /tmp/${APP_ID}.install.log"
}

install_packages() {
  msg_info "Installing OS packages"
  export DEBIAN_FRONTEND=noninteractive
  apt_update
  run_quiet apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    rsync
  msg_ok "Installed OS packages"
}

install_application() {
  msg_info "Installing application files"
  local source_dir
  source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  install -d -m 755 "$APP_DIR"
  if [[ "$source_dir" != "$APP_DIR" ]]; then
    run_quiet rsync -a --delete \
      --exclude ".git" \
      --exclude ".venv" \
      --exclude "__pycache__" \
      --exclude ".pytest_cache" \
      "$source_dir/" "$APP_DIR/"
  fi

  python3 -m venv "$APP_DIR/.venv"
  run_quiet "$APP_DIR/.venv/bin/pip" install --upgrade pip
  run_quiet "$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
  msg_ok "Installed application files"
}

install_config() {
  msg_info "Installing configuration"
  if [[ ! -f "$ENV_FILE" ]]; then
    install -m 600 "$APP_DIR/1blu-ddns.env.example" "$ENV_FILE"
    msg_ok "Created ${ENV_FILE}"
    msg_error "Edit ${ENV_FILE} with your real 1Blu.de credentials before relying on automatic updates."
  else
    chmod 600 "$ENV_FILE"
    msg_ok "Kept existing ${ENV_FILE}"
  fi
}

install_systemd_units() {
  msg_info "Installing systemd service and timer"
  cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=${APP} update
Documentation=https://github.com/NAmmann/1Blu.de-dDNS
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${APP_DIR}/.venv/bin/python -m app.main
EOF

  cat >"$TIMER_FILE" <<EOF
[Unit]
Description=Run ${APP} every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=10s
Persistent=true
Unit=${APP_ID}.service

[Install]
WantedBy=timers.target
EOF

  if [[ -f "/etc/cron.d/${APP_ID}" ]]; then
    rm -f "/etc/cron.d/${APP_ID}"
    msg_ok "Removed legacy cron job"
  fi

  systemctl daemon-reload
  systemctl enable --now "${APP_ID}.timer" >/dev/null
  msg_ok "Installed systemd timer"
}

install_helpers() {
  msg_info "Installing helper commands and MOTD"
  install -d -m 755 "$(dirname "$MOTD_FILE")"
  cat >"$UPDATE_BIN" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
cd "${APP_DIR}"
exec "${APP_DIR}/scripts/install-lxc.sh"
EOF
  chmod 755 "$UPDATE_BIN"

  cat >"$MOTD_FILE" <<EOF
#!/usr/bin/env bash
cat <<'MOTD'

${APP}
  Config:  ${ENV_FILE}
  Status:  systemctl status ${APP_ID}.timer
  Logs:    journalctl -u ${APP_ID}.service -n 50
  Update:  ${UPDATE_BIN}

MOTD
EOF
  chmod 755 "$MOTD_FILE"
  msg_ok "Installed helper commands and MOTD"
}

cleanup_lxc() {
  msg_info "Cleaning up"
  run_quiet apt-get -y autoremove || true
  run_quiet apt-get -y autoclean || true
  run_quiet apt-get -y clean || true
  rm -rf /root/.cache/pip /tmp/${APP_ID}.install.log
  msg_ok "Cleaned up"
}

main() {
  require_root
  require_systemd
  detect_os
  network_check
  install_packages
  install_application
  install_config
  install_systemd_units
  install_helpers
  cleanup_lxc

  msg_ok "Completed ${APP} setup"
  echo "Configuration: ${ENV_FILE}"
  echo "Timer:         ${APP_ID}.timer"
  echo "Logs:          journalctl -u ${APP_ID}.service -n 50"
}

main "$@"
