#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/pagos-recurrentes}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env.production}"
BACKUP_DIR="${BACKUP_DIR:-$APP_DIR/backups/postgres}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-docker.io/library/postgres:18-alpine}"
TZ="${TZ:-America/Mexico_City}"
BACKUP_COMPLETED=0

log() {
  printf '\n[%s] %s\n' "$(TZ="$TZ" date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '\n[ERROR] %s\n' "$*" >&2
  exit 1
}

cleanup_incomplete_backup() {
  if [[ "$BACKUP_COMPLETED" == "0" && -n "${BACKUP_PATH:-}" ]]; then
    rm -f "$BACKUP_PATH" "$BACKUP_PATH.sha256"
  fi
}

trap cleanup_incomplete_backup ERR

read_env_value() {
  local key="$1"
  if [[ ! -f "$ENV_FILE" ]]; then
    return 1
  fi
  grep -E "^${key}=" "$ENV_FILE" | tail -n 1 | cut -d '=' -f 2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

if [[ ! -f "$ENV_FILE" ]]; then
  fail "No existe ENV_FILE=$ENV_FILE"
fi

DB_URL="${PG_DUMP_URL:-}"
if [[ -z "$DB_URL" ]]; then
  DB_URL="$(read_env_value "PG_DUMP_URL" || true)"
fi
if [[ -z "$DB_URL" ]]; then
  DB_URL="$(read_env_value "DATABASE_URL" || true)"
fi
if [[ -z "$DB_URL" ]]; then
  fail "No encontre DATABASE_URL ni PG_DUMP_URL en $ENV_FILE"
fi

DB_URL="$(printf '%s' "$DB_URL" | sed 's#^postgresql+psycopg://#postgresql://#')"
DB_URL="$(printf '%s' "$DB_URL" | sed 's#^postgresql+asyncpg://#postgresql://#')"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

TIMESTAMP="$(TZ="$TZ" date '+%Y%m%d_%H%M%S')"
BACKUP_BASENAME="pagos_recurrentes_${TIMESTAMP}.dump"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_BASENAME"

log "Creando backup PostgreSQL en $BACKUP_PATH"
rm -f "$BACKUP_PATH" "$BACKUP_PATH.sha256"
podman run --rm \
  --name pagos-postgres-backup \
  -e "PG_DUMP_URL=$DB_URL" \
  -e "BACKUP_BASENAME=$BACKUP_BASENAME" \
  -v "$BACKUP_DIR:/backups" \
  "$POSTGRES_IMAGE" \
  sh -c 'pg_dump --format=custom --no-owner --no-acl --file="/backups/$BACKUP_BASENAME" "$PG_DUMP_URL"'

sha256sum "$BACKUP_PATH" > "$BACKUP_PATH.sha256"
chmod 600 "$BACKUP_PATH" "$BACKUP_PATH.sha256"
BACKUP_COMPLETED=1

log "Backup creado"
ls -lh "$BACKUP_PATH" "$BACKUP_PATH.sha256"

if command -v rclone >/dev/null 2>&1 && [[ -n "${BACKUP_RCLONE_REMOTE:-}" ]]; then
  log "Subiendo backup a rclone remote: $BACKUP_RCLONE_REMOTE"
  rclone copy "$BACKUP_PATH" "$BACKUP_RCLONE_REMOTE"
  rclone copy "$BACKUP_PATH.sha256" "$BACKUP_RCLONE_REMOTE"
fi

if [[ "$BACKUP_RETENTION_DAYS" =~ ^[0-9]+$ && "$BACKUP_RETENTION_DAYS" -gt 0 ]]; then
  log "Limpiando backups locales con mas de $BACKUP_RETENTION_DAYS dias"
  find "$BACKUP_DIR" -type f -name 'pagos_recurrentes_*.dump' -mtime +"$BACKUP_RETENTION_DAYS" -delete
  find "$BACKUP_DIR" -type f -name 'pagos_recurrentes_*.dump.sha256' -mtime +"$BACKUP_RETENTION_DAYS" -delete
fi

log "Backup finalizado"
