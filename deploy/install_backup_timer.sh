#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/pagos-recurrentes}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env.production}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-$APP_DIR/deploy/backup_postgres.sh}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
BACKUP_ON_CALENDAR="${BACKUP_ON_CALENDAR:-*-*-* 03:15:00}"

if [[ "$(id -u)" != "0" ]]; then
  echo "[ERROR] Ejecuta este script como root." >&2
  exit 1
fi

if [[ ! -f "$BACKUP_SCRIPT" ]]; then
  echo "[ERROR] No existe BACKUP_SCRIPT=$BACKUP_SCRIPT" >&2
  exit 1
fi

cat > /etc/systemd/system/pagos-postgres-backup.service <<EOF
[Unit]
Description=Pagos Recurrentes PostgreSQL logical backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
Environment=APP_DIR=$APP_DIR
Environment=ENV_FILE=$ENV_FILE
Environment=BACKUP_RETENTION_DAYS=$BACKUP_RETENTION_DAYS
ExecStart=/bin/bash $BACKUP_SCRIPT
EOF

cat > /etc/systemd/system/pagos-postgres-backup.timer <<EOF
[Unit]
Description=Run Pagos Recurrentes PostgreSQL backup daily

[Timer]
OnCalendar=$BACKUP_ON_CALENDAR
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now pagos-postgres-backup.timer
systemctl list-timers --all | grep pagos-postgres-backup || true

echo "Timer instalado. Prueba manual:"
echo "  systemctl start pagos-postgres-backup.service"
echo "  journalctl -u pagos-postgres-backup.service --no-pager -n 100"
