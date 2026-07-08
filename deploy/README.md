# Despliegue y Backups

Scripts para operar la primera version productiva en DigitalOcean Droplet + Managed PostgreSQL.

## Archivos

- `deploy_api.sh`: construye imagen Podman, ejecuta migraciones y levanta FastAPI en `127.0.0.1:8000`.
- `deploy_web.ps1`: construye Flutter Web en Windows y sube el build a Caddy.
- `backup_postgres.sh`: crea backup logico `.dump` con `pg_dump` usando contenedor PostgreSQL.
- `install_backup_timer.sh`: instala un timer systemd diario para backups.

## Primer Despliegue API En El Droplet

Desde el Droplet:

```bash
cd /opt/pagos-recurrentes
cp .env.production.example .env.production
nano .env.production
chmod 600 .env.production
bash deploy/deploy_api.sh
```

Verificar:

```bash
curl http://127.0.0.1:8000/health
```

Y en navegador:

```text
https://api.pagos-recurrentes.com/health
```

## Despliegues Posteriores De API

Desde el Droplet:

```bash
cd /opt/pagos-recurrentes
bash deploy/deploy_api.sh --pull
```

Si ya hiciste `git pull` manualmente:

```bash
bash deploy/deploy_api.sh
```

## Publicar Web App

Desde Windows, en la raiz del repo:

```powershell
.\deploy\deploy_web.ps1 `
  -SshKey .\pagosrec_dev `
  -SupabaseUrl "https://TU_PROYECTO.supabase.co" `
  -SupabaseAnonKey "TU_SUPABASE_ANON_KEY"
```

El script usa `--no-wasm-dry-run` para evitar fallas conocidas del dry-run wasm en algunos builds de Flutter/Windows.

La web queda en:

```text
https://app.pagos-recurrentes.com
```

## Backup Manual

Desde el Droplet:

```bash
cd /opt/pagos-recurrentes
bash deploy/backup_postgres.sh
```

El script usa por omision `docker.io/library/postgres:18-alpine` porque el PostgreSQL administrado actual esta en version mayor 18. Si DigitalOcean cambia la version mayor de la base, usa el cliente igual o mas nuevo:

```bash
POSTGRES_IMAGE=docker.io/library/postgres:19-alpine bash deploy/backup_postgres.sh
```

Los archivos quedan en:

```text
/opt/pagos-recurrentes/backups/postgres/
```

Formato:

```text
pagos_recurrentes_YYYYMMDD_HHMMSS.dump
pagos_recurrentes_YYYYMMDD_HHMMSS.dump.sha256
```

## Backup Automatico Diario

Desde el Droplet como root:

```bash
cd /opt/pagos-recurrentes
bash deploy/install_backup_timer.sh
```

Si tu base administrada esta en otra version mayor de PostgreSQL:

```bash
POSTGRES_IMAGE=docker.io/library/postgres:18-alpine bash deploy/install_backup_timer.sh
```

Consultar estado:

```bash
systemctl status pagos-postgres-backup.timer
systemctl list-timers --all | grep pagos-postgres-backup
```

Ejecutar una prueba manual:

```bash
systemctl start pagos-postgres-backup.service
journalctl -u pagos-postgres-backup.service --no-pager -n 100
```

## Restaurar Un Backup En Una Base De Prueba

No restaures directo sobre produccion sin snapshot previo.

```bash
podman run --rm \
  -e "RESTORE_URL=postgresql://USUARIO:PASSWORD@HOST:25060/BASE_PRUEBA?sslmode=require" \
  -v /opt/pagos-recurrentes/backups/postgres:/backups \
  docker.io/library/postgres:16-alpine \
  sh -c 'pg_restore --clean --if-exists --no-owner --no-acl --dbname "$RESTORE_URL" /backups/NOMBRE_DEL_BACKUP.dump'
```

## Subir Backups A Storage Externo

El script soporta `rclone` si configuras un remote.

Ejemplo:

```bash
export BACKUP_RCLONE_REMOTE="spaces:pagos-recurrentes-backups/postgres"
bash deploy/backup_postgres.sh
```

Para produccion, mantener:

- Backups automaticos del Managed PostgreSQL.
- Backups logicos diarios con este script.
- Prueba periodica de restauracion.
