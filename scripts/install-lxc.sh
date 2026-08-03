#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/1blu-ddns"
ENV_FILE="/etc/1blu-ddns.env"
CRON_FILE="/etc/cron.d/1blu-ddns"
SERVICE_USER="root"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this installer as root inside the LXC container." >&2
  exit 1
fi

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

apt-get update
apt-get install -y --no-install-recommends python3 python3-venv python3-pip ca-certificates cron rsync

install -d "$APP_DIR"
if [[ "$SOURCE_DIR" != "$APP_DIR" ]]; then
  rsync -a --delete \
    --exclude ".git" \
    --exclude ".venv" \
    --exclude "__pycache__" \
    --exclude ".pytest_cache" \
    "$SOURCE_DIR/" "$APP_DIR/"
fi

python3 -m venv "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/pip" install --upgrade pip
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

if [[ ! -f "$ENV_FILE" ]]; then
  install -m 600 "$APP_DIR/1blu-ddns.env.example" "$ENV_FILE"
  echo "Created $ENV_FILE. Edit it with your 1Blu credentials before relying on cron updates."
fi

cat > "$CRON_FILE" <<EOF
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

* * * * * $SERVICE_USER set -a; . $ENV_FILE; set +a; cd $APP_DIR && $APP_DIR/.venv/bin/python -m app.main --once >> /var/log/1blu-ddns.log 2>&1
EOF
chmod 644 "$CRON_FILE"

systemctl enable --now cron >/dev/null 2>&1 || service cron start

echo "Installed 1Blu DDNS to $APP_DIR."
echo "Configuration: $ENV_FILE"
echo "Cron: $CRON_FILE"
echo "Log: /var/log/1blu-ddns.log"
