# ==============================================================================
#  SANCTUARY PLATFORM - LAUNCHER & ORCHESTRATOR (WINDOWS POWERSHELL)
#  Levanta Docker (o Node.js nativo si Docker no esta activo) y Flutter Web
# ==============================================================================

# 1. Asegurar PATH en esta sesion
$requiredPaths = @(
    "C:\src\flutter\bin",
    "C:\src\flutter\bin\cache\dart-sdk\bin",
    "C:\Program Files\nodejs",
    "C:\Program Files\Git\bin",
    "C:\Program Files\Git\cmd",
    "C:\Program Files\Docker\Docker\resources\bin"
)

foreach ($p in $requiredPaths) {
    if (Test-Path $p) {
        if ($env:Path -notlike "*$p*") {
            $env:Path = "$p;" + $env:Path
        }
    }
}

# Banner
Write-Host ""
Write-Host "   _____             _                      " -ForegroundColor Green
Write-Host "  / ____|           | |                     " -ForegroundColor Green
Write-Host " | (___   __ _ _ __ | |_ _   _  __ _ _ __ _   _ " -ForegroundColor Green
Write-Host "  \___ \ / _`` | '_ \| __| | | |/ _`` | '__| | | |" -ForegroundColor Green
Write-Host "  ____) | (_| | | | | |_| |_| | (_| | |  | |_| |" -ForegroundColor Green
Write-Host " |_____/ \__,_|_| |_|\__|\__,_|\__,_|_|   \__, |" -ForegroundColor Green
Write-Host "                                           __/ |" -ForegroundColor Green
Write-Host "                                          |___/ " -ForegroundColor Green
Write-Host " Plataforma Multiplataforma - Flutter - Docker/Node - PostgreSQL - CV Builder - Slide Downloader" -ForegroundColor DarkGray
Write-Host ""

# Paso 0: Limpiar puertos y servicios previos
Write-Host " [0/5] Verificando y liberando puertos previos (8085, 8088)..." -ForegroundColor Cyan

$ports = @(8085, 8088)
foreach ($port in $ports) {
    try {
        $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        foreach ($conn in $conns) {
            if ($conn.OwningProcess -and $conn.OwningProcess -ne 0) {
                Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
        docker compose down 2>$null | Out-Null
        docker rm -f sanctuary_api sanctuary_postgres 2>$null | Out-Null
    } catch {}
}
Write-Host "       [OK] Puertos liberados y entorno listo." -ForegroundColor Green

# Paso 1: Verificacion de Dependencias
Write-Host ""
Write-Host " [1/5] Verificando dependencias del sistema..." -ForegroundColor Cyan

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    if (Test-Path "C:\src\flutter\bin\flutter.bat") {
        $flutterCmd = "C:\src\flutter\bin\flutter.bat"
        Write-Host "       [OK] Flutter detectado en C:\src\flutter\bin" -ForegroundColor Green
    } else {
        Write-Host "       [ERROR] Flutter no encontrado en PATH ni en C:\src\flutter\bin." -ForegroundColor Red
        Write-Host "       Por favor asegurate de tener Flutter en C:\src\flutter." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "       [OK] Flutter detectado." -ForegroundColor Green
}

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd -and (Test-Path "C:\Program Files\nodejs\node.exe")) {
    $nodeCmd = "C:\Program Files\nodejs\node.exe"
}
if ($nodeCmd) {
    Write-Host "       [OK] Node.js detectado." -ForegroundColor Green
} else {
    Write-Host "       [WARN] Node.js no detectado directamente." -ForegroundColor Yellow
}

$hasDocker = $false
if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
        $dockerCheck = docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            $hasDocker = $true
            Write-Host "       [OK] Docker Desktop activo y funcionando." -ForegroundColor Green
        } else {
            Write-Host "       [INFO] Docker instalado pero el daemon no esta iniciado." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "       [INFO] Docker daemon no responde." -ForegroundColor Yellow
    }
} else {
    Write-Host "       [INFO] Docker no instalado en Windows. Se usara Backend nativo Node.js." -ForegroundColor DarkYellow
}

# Paso 2: Levantar Backend
Write-Host ""
Write-Host " [2/5] Iniciando Backend API..." -ForegroundColor Cyan
if ($hasDocker) {
    Write-Host "       Levantando servicios con Docker Compose (PostgreSQL + API)..." -ForegroundColor Gray
    docker compose up -d --build | Out-Null
    Write-Host "       [OK] Contenedores Docker levantados." -ForegroundColor Green
} else {
    Write-Host "       Iniciando Backend nativo (Node.js en http://localhost:8088)..." -ForegroundColor Gray
    $serverPath = Join-Path $PSScriptRoot "backend\server.js"
    if (Test-Path $serverPath) {
        $nodePath = "node"
        if (Test-Path "C:\Program Files\nodejs\node.exe") {
            $nodePath = "C:\Program Files\nodejs\node.exe"
        }
        $backendProcess = Start-Process -FilePath $nodePath -ArgumentList "`"$serverPath`"" -WorkingDirectory (Join-Path $PSScriptRoot "backend") -PassThru -WindowStyle Hidden
        Write-Host "       [OK] Backend Node.js en ejecucion (PID: $($backendProcess.Id))." -ForegroundColor Green
    } else {
        Write-Host "       [WARN] No se encontro backend/server.js." -ForegroundColor Yellow
    }
}

# Paso 3: Salud de la API
Write-Host ""
Write-Host " [3/5] Verificando salud del Backend..." -ForegroundColor Cyan
$apiReady = $false
for ($i = 1; $i -le 10; $i++) {
    try {
        $res = Invoke-RestMethod -Uri "http://localhost:8088/api/health" -TimeoutSec 2 -ErrorAction Stop
        if ($res.status -eq "ok" -or $res.status -eq "error") {
            $apiReady = $true
            break
        }
    } catch {
        Start-Sleep -Milliseconds 600
    }
}

if ($apiReady) {
    Write-Host "       [OK] Backend API respondiendo en http://localhost:8088" -ForegroundColor Green
} else {
    Write-Host "       [INFO] Backend iniciandose en segundo plano (continuando en modo hibrido)." -ForegroundColor Gray
}

# Paso 4: Flutter packages
Write-Host ""
Write-Host " [4/5] Verificando paquetes Flutter..." -ForegroundColor Cyan
& flutter pub get | Out-Null
Write-Host "       [OK] Paquetes Dart sincronizados." -ForegroundColor Green

# Paso 5: Lanzar Flutter Web
Write-Host ""
Write-Host " [5/5] Iniciando Aplicacion Web Sanctuary..." -ForegroundColor Cyan
Write-Host "       * Flutter Web: http://localhost:8085" -ForegroundColor Yellow
Write-Host "       * Backend API: http://localhost:8088" -ForegroundColor Yellow
Write-Host ""

Start-Job -ScriptBlock {
    Start-Sleep -Seconds 3
    Start-Process "http://localhost:8085"
} | Out-Null

$useChrome = $args -contains "--chrome"
if ($useChrome) {
    & flutter run -d chrome --web-port=8085 --web-hostname=0.0.0.0
} else {
    & flutter run -d web-server --web-port=8085 --web-hostname=0.0.0.0
}
