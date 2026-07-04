#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${APP_DIR:-/opt/pagos-recurrentes}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env.production}"
IMAGE_NAME="${IMAGE_NAME:-pagos-api:prod}"
CONTAINER_NAME="${CONTAINER_NAME:-pagos-api}"
BIND_ADDR="${BIND_ADDR:-127.0.0.1}"
HOST_PORT="${HOST_PORT:-8000}"
APP_PORT="${APP_PORT:-8000}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:${HOST_PORT}/health}"

log() {
  printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

fail() {
  printf '\n[ERROR] %s\n' "$*" >&2
  exit 1
}

cd "$APP_DIR" || fail "No existe APP_DIR=$APP_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  fail "No existe ENV_FILE=$ENV_FILE. Crea .env.production antes de desplegar."
fi

if [[ "${1:-}" == "--pull" || "${PULL:-0}" == "1" ]]; then
  log "Actualizando repo con git pull --ff-only"
  git pull --ff-only
fi

log "Construyendo imagen $IMAGE_NAME"
podman build -t "$IMAGE_NAME" .

log "Ejecutando migraciones Alembic"
podman run --rm --env-file "$ENV_FILE" "$IMAGE_NAME" alembic upgrade head

log "Levantando contenedor $CONTAINER_NAME"
podman run -d \
  --name "$CONTAINER_NAME" \
  --replace \
  --restart=always \
  --env-file "$ENV_FILE" \
  -p "${BIND_ADDR}:${HOST_PORT}:${APP_PORT}" \
  "$IMAGE_NAME"

if command -v systemctl >/dev/null 2>&1 && [[ "$(id -u)" == "0" ]]; then
  systemctl enable --now podman-restart.service >/dev/null 2>&1 || true
fi

log "Esperando healthcheck $HEALTH_URL"
for _ in $(seq 1 30); do
  if curl -fsS "$HEALTH_URL" >/dev/null; then
    log "API saludable"
    podman ps --filter "name=$CONTAINER_NAME"
    exit 0
  fi
  sleep 1
done

podman logs "$CONTAINER_NAME" --tail 120 || true
fail "La API no respondio saludable en $HEALTH_URL"
