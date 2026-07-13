param(
  [string]$HostName = "pagos-recurrentes.com",
  [string]$User = "root",
  [string]$SshKey = ".\pagosrec_dev",
  [string]$ApiBaseUrl = "https://api.pagos-recurrentes.com",
  [string]$SupabaseUrl = "",
  [string]$SupabaseAnonKey = "",
  [string]$RemotePath = "/var/www/pagos-recurrentes-app"
)

$ErrorActionPreference = "Stop"
$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$MobileDir = Join-Path $RootDir "mobile"
$BuildDir = Join-Path $MobileDir "build\web"

Write-Host ""
Write-Host "[1/3] Construyendo Flutter Web..."
Push-Location $MobileDir
try {
  flutter clean
  flutter pub get
  $buildArgs = @(
    "build",
    "web",
    "--release",
    "--no-wasm-dry-run",
    "--dart-define=API_BASE_URL=$ApiBaseUrl",
    "--dart-define=DATA_MODE=api"
  )
  if ($SupabaseUrl -ne "") {
    $buildArgs += "--dart-define=SUPABASE_URL=$SupabaseUrl"
  }
  if ($SupabaseAnonKey -ne "") {
    $buildArgs += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
  }
  flutter @buildArgs
} finally {
  Pop-Location
}

if (-not (Test-Path $BuildDir)) {
  throw "No existe $BuildDir"
}

Write-Host ""
Write-Host "[2/3] Preparando directorio remoto y subiendo build a ${User}@${HostName}:$RemotePath..."
$RemotePrepCommand = "case '$RemotePath' in /var/www/*) mkdir -p '$RemotePath' && find '$RemotePath' -mindepth 1 -maxdepth 1 -exec rm -rf {} \; ;; *) echo 'RemotePath no permitido: $RemotePath' >&2; exit 1 ;; esac"
ssh -i $SshKey "${User}@${HostName}" $RemotePrepCommand
scp -i $SshKey -r "$BuildDir\." "${User}@${HostName}:$RemotePath/"

Write-Host ""
Write-Host "[3/3] Ajustando permisos y recargando Caddy..."
$RemoteCommand = "chown -R caddy:caddy $RemotePath && find $RemotePath -type d -exec chmod 755 {} \; && find $RemotePath -type f -exec chmod 644 {} \; && systemctl reload caddy"
ssh -i $SshKey "${User}@${HostName}" $RemoteCommand

Write-Host ""
Write-Host "Web app publicada en https://app.pagos-recurrentes.com"
