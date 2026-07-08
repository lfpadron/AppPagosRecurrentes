# Pagos Recurrentes

Primera version funcional de una app monetizable para controlar pagos recurrentes. Incluye backend FastAPI + SQLModel + PostgreSQL + Alembic, y un MVP Flutter web/mobile conectado por HTTP.

## Estructura

- `app/`: API FastAPI modular por rutas, modelos, schemas y servicios de negocio.
- `alembic/`: migraciones de base de datos.
- `scripts/seed.py`: datos demo minimos.
- `mobile/`: app Flutter con capas `core`, `features` y `shared`.
- `docker-compose.yml`: PostgreSQL + API.
- `deploy/`: scripts de despliegue productivo con Podman, Flutter Web y backups.

## Backend

### Levantar con Docker

```powershell
copy .env.example .env
docker compose up --build
```

La API queda en `http://localhost:8000` y la documentacion interactiva en `http://localhost:8000/docs`.

El contenedor de API ejecuta automaticamente:

```powershell
alembic upgrade head
python -m scripts.seed
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Levantar local sin Docker

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
alembic upgrade head
python -m scripts.seed
uvicorn app.main:app --reload
```

### Tests

```powershell
py -3 -m pytest app/tests
```

### Produccion

Los scripts para DigitalOcean Droplet + Managed PostgreSQL viven en:

```text
deploy/
```

Documentacion rapida:

```text
deploy/README.md
```

### Usuario temporal

Mientras se integra Supabase Auth o Firebase Auth, la API usa `X-User-Id`. Si no se envia, toma:

```text
00000000-0000-0000-0000-000000000001
```

## Endpoints MVP

- `POST /services`
- `GET /services`
- `GET /services/{id}`
- `PATCH /services/{id}`
- `POST /services/{id}/regenerate-payments`
- `POST /services/{id}/exceptions`
- `GET /services/{id}/versions`
- `POST /payments/one-time`
- `GET /payments`
- `GET /payments/{id}`
- `PATCH /payments/{id}`
- `POST /payments/{id}/mark-paid`
- `POST /payments/{id}/cancel`
- `GET /calendar?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`
- `GET /reports/export-excel`
- `GET /reports/paid-summary?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&service_account_id=UUID`
- `GET /reports/estimated-summary?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&service_account_id=UUID`
- `POST /imports/excel`
- `GET /sync/status`
- `POST /sync/bootstrap`
- `GET /sync/pull`

## Flutter

```powershell
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=USER_ID=00000000-0000-0000-0000-000000000001
```

Validaciones:

```powershell
flutter analyze
flutter test
flutter build web
```

## Preparacion Premium, tienda y sincronizacion

La app queda preparada para el modelo local-first antes del VPS:

- Plan `economico`: datos locales en celular, sin sincronizacion ni web app editable.
- Plan `premium`: bandera local de prueba para habilitar sincronizacion, web app y respaldo.
- En web, el acceso queda preparado como premium-only con flujo OTP simulado hasta conectar Supabase Auth o Firebase Auth.
- En celular se pide usuario local una vez y existe boton `Cerrar sesion`.
- PIN local opcional de 4 digitos: se guarda como hash con salt, nunca como texto plano.
- Servicios y pagos guardan metadata para sync/conflictos:
  - `last_modified_at`
  - `last_modified_platform`
  - `last_modified_device_id`
- La base local tiene `schema_version`; PostgreSQL tiene tabla `app_schema_versions`.
- Existe UI base para resolver conflictos mostrando plataforma y fecha/hora de cada version, con opcion de aplicar a todos.

### Auth real y web premium

La API soporta `AUTH_PROVIDER=local` para desarrollo y `AUTH_PROVIDER=supabase` para produccion. En modo Supabase, FastAPI exige `Authorization: Bearer <token>` y valida la sesion contra Supabase Auth.

Variables productivas:

```env
AUTH_PROVIDER=supabase
SUPABASE_URL=https://TU_PROYECTO.supabase.co
SUPABASE_ANON_KEY=TU_SUPABASE_ANON_KEY
REQUIRE_PREMIUM_FOR_API=true
PREMIUM_EMAIL_ALLOWLIST=tu-correo@dominio.com
```

`PREMIUM_EMAIL_ALLOWLIST` es temporal para pruebas y administracion inicial. La web app consulta `/auth/me` y solo permite entrar si el usuario tiene Premium activo por allowlist o por la tabla `user_entitlements`.

Al publicar Flutter Web, construir con:

```powershell
.\deploy\deploy_web.ps1 `
  -SshKey .\pagosrec_dev `
  -SupabaseUrl "https://TU_PROYECTO.supabase.co" `
  -SupabaseAnonKey "TU_SUPABASE_ANON_KEY"
```

### Bootstrap Android -> servidor

La primera sincronizacion premium sube en lote los datos locales del celular al servidor:

1. Construir APK/API con Supabase configurado.
2. Abrir Android -> `Configuracion` -> `Sincronizacion`.
3. Iniciar sesion con correo OTP.
4. Tocar `Subir datos locales`.

El backend guarda `sync_devices` y `sync_external_ids` para mapear IDs locales del celular a UUIDs del servidor. Esto evita duplicados si se ejecuta el bootstrap mas de una vez desde el mismo dispositivo.

Construccion Android conectada a produccion:

```powershell
set SKIP_DOCKER=1
set SUPABASE_URL=https://TU_PROYECTO.supabase.co
set SUPABASE_ANON_KEY=TU_SUPABASE_ANON_KEY
.\run_local.bat build-apk https://api.pagos-recurrentes.com
```

Endpoints de sync:

- `GET /sync/status`: valida usuario, premium y conteos del servidor.
- `POST /sync/bootstrap`: sube snapshot local completo de servicios y pagos.
- `GET /sync/pull`: descarga snapshot servidor para el usuario autenticado.

Pruebas de tienda recomendadas antes de publicar:

1. APK instalado manualmente.
2. Google Play Internal Testing.
3. Google Play Closed Testing.
4. License testers para compras y suscripciones.
5. Pruebas de cancelacion, no renovacion, expiracion, offline y migracion de version.

Pendiente para activar produccion:

- Conectar Supabase Auth/Firebase Auth para OTP real.
- Conectar RevenueCat + Google Play Billing para entitlements reales.
- Reemplazar el plan local de prueba por validacion backend.
- Implementar motor de sync bidireccional y cola offline SQLite.

## Reglas implementadas

- Crear servicio genera pagos recurrentes hasta el horizonte configurado.
- Los estados de pago se derivan por fecha y son parametrizables con `DUE_SOON_DAYS` y `UPCOMING_DAYS`.
- Manuales: `overdue` si la fecha esta en el pasado, `due_soon` desde hoy hasta `DUE_SOON_DAYS`, `upcoming` despues de `DUE_SOON_DAYS` y hasta `UPCOMING_DAYS`, `future` despues de `UPCOMING_DAYS`, `paid` si ya se pagaron.
- Automaticos: `autopay_pending_confirmation` si la fecha esta en el pasado, `autopay_due_soon` desde hoy hasta `DUE_SOON_DAYS`, `autopay_future` despues de `DUE_SOON_DAYS`, `paid` si ya se confirmaron.
- Cada servicio puede definir que pasa si la fecha de pago cae en sabado o domingo: no moverla, moverla al lunes siguiente o moverla al viernes anterior.
- Excepciones por rango marcan pagos como `not_applicable_exception`.
- Servicios tienen ciclo de vida `active`, `paused` o `ended`; pausar o terminar cancela pagos recalculables desde `effective_from` sin tocar pagos pagados.
- Servicios tienen `icon_key`, y cada pago guarda `service_icon_key_snapshot` para conservar el icono historico.
- Pagos unicos se crean con `payment_type = one_time`.
- Marcar pagado asigna `paid_at`, `paid_amount` y `status = paid`.
- Editar servicio crea snapshot en `service_versions`, cancela pagos recalculables desde `effective_from` y genera reemplazos sin tocar pagos pagados.
- Cancelados se ocultan de calendario y busquedas de pagos por default; en reportes solo aparecen si se pide `include_cancelled`.
- Pagos se listan en paginas de 90 registros con `limit` y `offset`; para meses con mas de 90 pagos se avanza por paginas manteniendo el mismo filtro.
- Servicios se listan con limite visual de 30 registros y filtros por predio/objeto y estado.
- Calendario devuelve pagos agrupados por fecha.
- Reportes calcula cuanto se pago y cuanto se estima pagar por rango y servicio.
- Export Excel genera un archivo `.xlsx` basico.
- Import Excel queda como stub documentado para v2.

## Datos seed

`python -m scripts.seed` crea:

- Usuario demo local.
- Servicio demo `Casa - Ejemplo`, mensual por `$900.00`, proveedor `proveedor`, inicio `2026-01-30`.
- Pagos recurrentes generados desde ese servicio.

## Iconos

Hay dos categorias:

1. Iconos fijos del producto: navegacion, app y estados de pago.
2. Iconos seleccionables por servicio: escuela, gas, carro/moto, SaaS, electricidad, etc.

Coloca los archivos generados aqui:

```text
mobile/assets/icons/app/
  app_home.png
  app_icon_source.png

mobile/assets/icons/navigation/
  nav_home.png
  nav_services.png
  nav_payments.png
  nav_calendar.png
  nav_settings.png
  nav_reports.png

mobile/assets/icons/status/
  manual_vencido.png
  manual_atencion.png
  manual_proximo.png
  manual_futuro.png
  manual_pagado.png
  automatico_por_confirmar.png
  automatico_pronto_pago.png
  automatico_futuro.png
  automatico_pagado.png
  status_pending.png
  status_active.png
  status_exception.png
  status_cancelled.png
  status_recalculated.png

mobile/assets/icons/services/
  generico_abc.png
  generico_123.png
  escuelas.png
  autobus_escolar.png
  electricidad.png
  gas.png
  internet_triple_play.png
  edificio_departamentos.png
  servicio_limpia.png
  seguros_medicos.png
  automovil.png
  motocicleta.png
  saas.png
  streaming.png
  predial.png
  agua_potable.png
  telefonia_fija.png
  telefonia_movil.png
  servicios_gubernamentales.png
  pagos_domiciliados.png
  facturas_pagadas_agrupadas.png
```

La biblioteca visible para el usuario vive en:

```text
mobile/lib/shared/icons/service_icon_catalog.dart
```

Cada opcion tiene:

- `key`: valor guardado en backend, por ejemplo `service_school`.
- `label`: texto corto para la UI.
- `description`: descripcion breve para que el usuario elija bien.
- `icon`: fallback Material mientras no usemos los assets finales.
- `assetPath`: ruta al PNG real o fallback Material si falta.

Los paths fijos estan centralizados en:

```text
mobile/lib/shared/icons/fixed_icon_manifest.dart
```

## TODOs v2

- Auth real con Supabase Auth o Firebase Auth.
- Sync offline con SQLite local y resolucion de conflictos.
- Firebase Cloud Messaging para recordatorios push.
- RevenueCat para planes Pro y paywalls.
- Storage real de comprobantes.
- Completar set final de iconos PNG y automatizar validacion de assets.
- Importacion Excel completa con validaciones y preview.
- Exportacion Excel avanzada con filtros, pivots y resumen mensual.
- Jobs programados para refrescar estados y generar ventanas futuras.
- Auditoria fina por usuario/dispositivo.

## Referencias tecnicas

- [Flutter app architecture](https://docs.flutter.dev/app-architecture)
- [FastAPI SQL databases](https://fastapi.tiangolo.com/tutorial/sql-databases/)
- [SQLModel](https://sqlmodel.tiangolo.com/)
- [Alembic tutorial](https://alembic.sqlalchemy.org/en/latest/tutorial.html)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [RevenueCat Flutter SDK](https://www.revenuecat.com/docs/getting-started/installation/flutter)
