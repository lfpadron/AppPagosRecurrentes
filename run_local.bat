@echo off
setlocal EnableExtensions

set "ROOT_DIR=%~dp0"
set "MOBILE_DIR=%ROOT_DIR%mobile"
set "DEFAULT_USER_ID=00000000-0000-0000-0000-000000000001"

set "MODE=%~1"
if "%MODE%"=="" set "MODE=chrome"

if /I "%MODE%"=="help" goto :help
if /I "%MODE%"=="-h" goto :help
if /I "%MODE%"=="--help" goto :help

call :validate_mode "%MODE%"
if errorlevel 1 goto :usage_error

if not exist "%MOBILE_DIR%\pubspec.yaml" (
  echo [ERROR] No se encontro mobile\pubspec.yaml.
  echo Ejecuta este .bat desde la raiz del proyecto.
  exit /b 1
)

if /I "%SKIP_DOCKER%"=="1" (
  echo [Docker] SKIP_DOCKER=1, omitiendo docker compose.
) else (
  call :docker_build || exit /b 1
)

call :flutter_prepare || exit /b 1

if /I "%MODE%"=="chrome" goto :run_chrome
if /I "%MODE%"=="android" goto :run_android
if /I "%MODE%"=="build-web" goto :build_web
if /I "%MODE%"=="build-apk" goto :build_apk
if /I "%MODE%"=="build-aab" goto :build_aab

goto :usage_error

:validate_mode
if /I "%~1"=="chrome" exit /b 0
if /I "%~1"=="android" exit /b 0
if /I "%~1"=="build-web" exit /b 0
if /I "%~1"=="build-apk" exit /b 0
if /I "%~1"=="build-aab" exit /b 0
exit /b 1

:docker_build
echo.
echo [1/3] Construyendo y levantando backend con Docker Compose...
cd /d "%ROOT_DIR%" || exit /b 1
docker compose up -d --build
if errorlevel 1 (
  echo [ERROR] Fallo docker compose up -d --build.
  exit /b 1
)
exit /b 0

:flutter_prepare
echo.
echo [2/3] Preparando Flutter...
cd /d "%MOBILE_DIR%" || exit /b 1
call flutter clean
if errorlevel 1 exit /b 1
call flutter pub get
if errorlevel 1 exit /b 1
exit /b 0

:run_chrome
set "API_BASE_URL=%~2"
set "DATA_MODE=local"
if /I "%API_BASE_URL%"=="local" set "API_BASE_URL="
if not "%API_BASE_URL%"=="" set "DATA_MODE=api"
if "%API_BASE_URL%"=="" set "API_BASE_URL=http://localhost:8000"
set "WEB_PORT=%~3"
if "%WEB_PORT%"=="" set "WEB_PORT=8080"
set "USER_ID=%~4"
if "%USER_ID%"=="" set "USER_ID=%DEFAULT_USER_ID%"

echo.
echo [3/3] Ejecutando en Chrome...
echo API_BASE_URL=%API_BASE_URL%
echo DATA_MODE=%DATA_MODE%
echo WEB_PORT=%WEB_PORT%
cd /d "%MOBILE_DIR%" || exit /b 1
call flutter run -d chrome --web-port %WEB_PORT% "--dart-define=API_BASE_URL=%API_BASE_URL%" "--dart-define=USER_ID=%USER_ID%" "--dart-define=DATA_MODE=%DATA_MODE%" "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
exit /b %ERRORLEVEL%

:run_android
set "API_BASE_URL=%~2"
set "DATA_MODE=local"
if /I "%API_BASE_URL%"=="local" set "API_BASE_URL="
if not "%API_BASE_URL%"=="" set "DATA_MODE=api"
if "%API_BASE_URL%"=="" set "API_BASE_URL=http://10.0.2.2:8000"
set "ANDROID_DEVICE=%~3"
if "%ANDROID_DEVICE%"=="" set "ANDROID_DEVICE=emulator-5554"
set "USER_ID=%~4"
if "%USER_ID%"=="" set "USER_ID=%DEFAULT_USER_ID%"

echo.
echo [3/3] Ejecutando en emulador Android...
echo API_BASE_URL=%API_BASE_URL%
echo DATA_MODE=%DATA_MODE%
echo DEVICE=%ANDROID_DEVICE%
echo Si tu emulador tiene otro id, revisa con: flutter devices
cd /d "%MOBILE_DIR%" || exit /b 1
call flutter run -d %ANDROID_DEVICE% "--dart-define=API_BASE_URL=%API_BASE_URL%" "--dart-define=USER_ID=%USER_ID%" "--dart-define=DATA_MODE=%DATA_MODE%" "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
exit /b %ERRORLEVEL%

:build_web
set "API_BASE_URL=%~2"
set "DATA_MODE=local"
if /I "%API_BASE_URL%"=="local" set "API_BASE_URL="
if not "%API_BASE_URL%"=="" set "DATA_MODE=api"
if "%API_BASE_URL%"=="" set "API_BASE_URL=http://localhost:8000"
set "USER_ID=%~3"
if "%USER_ID%"=="" set "USER_ID=%DEFAULT_USER_ID%"

echo.
echo [3/3] Construyendo Web release...
echo API_BASE_URL=%API_BASE_URL%
echo DATA_MODE=%DATA_MODE%
cd /d "%MOBILE_DIR%" || exit /b 1
call flutter build web --release "--dart-define=API_BASE_URL=%API_BASE_URL%" "--dart-define=USER_ID=%USER_ID%" "--dart-define=DATA_MODE=%DATA_MODE%" "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
exit /b %ERRORLEVEL%

:build_apk
set "API_BASE_URL=%~2"
set "DATA_MODE=local"
if /I "%API_BASE_URL%"=="local" set "API_BASE_URL="
if not "%API_BASE_URL%"=="" set "DATA_MODE=api"
if "%API_BASE_URL%"=="" set "API_BASE_URL=http://10.0.2.2:8000"
set "USER_ID=%~3"
if "%USER_ID%"=="" set "USER_ID=%DEFAULT_USER_ID%"

echo.
echo [3/3] Construyendo Android APK release...
echo API_BASE_URL=%API_BASE_URL%
echo DATA_MODE=%DATA_MODE%
echo Nota: sin API_BASE_URL explicita, Android se construye en modo local y no necesita servidor.
cd /d "%MOBILE_DIR%" || exit /b 1
call flutter build apk --release "--dart-define=API_BASE_URL=%API_BASE_URL%" "--dart-define=USER_ID=%USER_ID%" "--dart-define=DATA_MODE=%DATA_MODE%" "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
exit /b %ERRORLEVEL%

:build_aab
set "API_BASE_URL=%~2"
set "DATA_MODE=local"
if /I "%API_BASE_URL%"=="local" set "API_BASE_URL="
if not "%API_BASE_URL%"=="" set "DATA_MODE=api"
if "%API_BASE_URL%"=="" set "API_BASE_URL=http://10.0.2.2:8000"
set "USER_ID=%~3"
if "%USER_ID%"=="" set "USER_ID=%DEFAULT_USER_ID%"

echo.
echo [3/3] Construyendo Android App Bundle release...
echo API_BASE_URL=%API_BASE_URL%
echo DATA_MODE=%DATA_MODE%
echo Nota: sin API_BASE_URL explicita, Android se construye en modo local y no necesita servidor.
cd /d "%MOBILE_DIR%" || exit /b 1
call flutter build appbundle --release "--dart-define=API_BASE_URL=%API_BASE_URL%" "--dart-define=USER_ID=%USER_ID%" "--dart-define=DATA_MODE=%DATA_MODE%" "--dart-define=SUPABASE_URL=%SUPABASE_URL%" "--dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%"
exit /b %ERRORLEVEL%

:detect_lan_api_url
set "DETECTED_IP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$cfg=Get-NetIPConfiguration; foreach($c in $cfg){if($c.IPv4DefaultGateway -and $c.IPv4Address){$c.IPv4Address[0].IPAddress; exit}}; foreach($ip in Get-NetIPAddress -AddressFamily IPv4){if($ip.IPAddress -notlike '127.*' -and $ip.IPAddress -notlike '169.254.*'){$ip.IPAddress; exit}}"`) do set "DETECTED_IP=%%I"
if "%DETECTED_IP%"=="" (
  set "API_BASE_URL=http://10.0.2.2:8000"
) else (
  set "API_BASE_URL=http://%DETECTED_IP%:8000"
)
exit /b 0

:usage_error
echo [ERROR] Modo no reconocido: %MODE%
call :print_usage
exit /b 1

:help
call :print_usage
exit /b 0

:print_usage
echo.
echo Uso:
echo   run_local.bat chrome [API_BASE_URL] [WEB_PORT] [USER_ID]
echo   run_local.bat android [API_BASE_URL] [DEVICE_ID] [USER_ID]
echo   run_local.bat build-web [API_BASE_URL] [USER_ID]
echo   run_local.bat build-apk [API_BASE_URL] [USER_ID]
echo   run_local.bat build-aab [API_BASE_URL] [USER_ID]
echo.
echo Ejemplos:
echo   run_local.bat chrome
echo   run_local.bat chrome http://localhost:8000 8080
echo   run_local.bat chrome local 8080
echo   run_local.bat android
echo   run_local.bat android http://10.0.2.2:8000 emulator-5554
echo   run_local.bat build-web http://localhost:8000
echo   run_local.bat build-apk
echo   run_local.bat build-apk http://192.168.1.50:8000
echo   run_local.bat build-apk local
echo   run_local.bat build-aab https://api.tu-dominio.com
echo.
echo Defaults:
echo   chrome:    DATA_MODE=local ^(sin servidor^)
echo   android:   DATA_MODE=local ^(sin servidor^)
echo   build-apk: DATA_MODE=local ^(sin servidor^)
echo.
echo Variables opcionales:
echo   set SKIP_DOCKER=1   Omitir docker compose up -d --build.
echo   set SUPABASE_URL=https://TU_PROYECTO.supabase.co
echo   set SUPABASE_ANON_KEY=TU_SUPABASE_ANON_PUBLIC_KEY
echo.
exit /b 0
