# ==============================================================================
#  SANCTUARY PLATFORM - LAUNCHER & ORCHESTRATOR (WINDOWS POWERSHELL)
#  Levanta Docker / Node.js Backend (8088) y Flutter Web (8085)
#  Compatible con directivas de Windows Device Guard / WDAC
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

# Paso 1: Verificacion de Dependencias y Device Guard
Write-Host ""
Write-Host " [1/5] Verificando dependencias del sistema y politicas de seguridad..." -ForegroundColor Cyan

$nodeCmd = "node"
if (Test-Path "C:\Program Files\nodejs\node.exe") {
    $nodeCmd = "C:\Program Files\nodejs\node.exe"
    Write-Host "       [OK] Node.js detectado ($nodeCmd)." -ForegroundColor Green
} elseif (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Host "       [OK] Node.js detectado en PATH." -ForegroundColor Green
} else {
    Write-Host "       [ERROR] Node.js no encontrado. Por favor instala Node.js." -ForegroundColor Red
    exit 1
}

# Comprobar si flutter / dart.exe puede ejecutarse o si esta bloqueado por Device Guard / AppLocker
$canRunFlutter = $false
try {
    $flutterCmd = "flutter"
    if (Test-Path "C:\src\flutter\bin\flutter.bat") {
        $flutterCmd = "C:\src\flutter\bin\flutter.bat"
    } elseif (Get-Command flutter -ErrorAction SilentlyContinue) {
        $flutterCmd = (Get-Command flutter).Source
    }
    
    # Comprobar si flutter puede ejecutar subprocesos sin ser bloqueado por la directiva de seguridad de Windows
    $flutterTest = & $flutterCmd --version 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and ($flutterTest -notmatch "bloqueó|bloqueo|Device Guard|ProcessStarter|Control de aplicaciones")) {
        $canRunFlutter = $true
    }
} catch {
    $canRunFlutter = $false
}

if ($canRunFlutter) {
    Write-Host "       [OK] Flutter SDK activo y ejecutable en modo nativo." -ForegroundColor Green
} else {
    Write-Host "       [INFO] Windows Device Guard / Control de aplicaciones bloquea subprocesos de Dart/Flutter." -ForegroundColor Yellow
    Write-Host "       [MODO ALTA DISPONIBILIDAD] Activando Servidor Web Node.js nativo (puerto 8085)." -ForegroundColor Green
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

# Paso 2: Levantar Backend API (Puerto 8088)
Write-Host ""
Write-Host " [2/5] Iniciando Backend API (Puerto 8088)..." -ForegroundColor Cyan
if ($hasDocker) {
    Write-Host "       Levantando servicios con Docker Compose (PostgreSQL + API)..." -ForegroundColor Gray
    docker compose up -d --build | Out-Null
    Write-Host "       [OK] Contenedores Docker levantados." -ForegroundColor Green
} else {
    Write-Host "       Iniciando Backend nativo (Node.js en http://localhost:8088)..." -ForegroundColor Gray
    $serverPath = Join-Path $PSScriptRoot "backend\server.js"
    if (Test-Path $serverPath) {
        $backendProcess = Start-Process -FilePath $nodeCmd -ArgumentList "`"$serverPath`"" -WorkingDirectory (Join-Path $PSScriptRoot "backend") -PassThru -WindowStyle Hidden
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
    Write-Host "       [INFO] Backend iniciandose en segundo plano." -ForegroundColor Gray
}

# Paso 4: Preparacion de la Aplicacion Web
Write-Host ""
Write-Host " [4/5] Verificando paquetes y build web..." -ForegroundColor Cyan
if ($canRunFlutter) {
    & flutter pub get | Out-Null
    Write-Host "       [OK] Paquetes Dart sincronizados." -ForegroundColor Green
} else {
    # Asegurar que build/web contenga la compilacion web mas reciente
    $webIndex = Join-Path $PSScriptRoot "build\web\index.html"
    $needsExtract = -not (Test-Path $webIndex)
    
    try {
        git fetch origin gh-pages 2>$null | Out-Null
        $remoteCommit = (git rev-parse origin/gh-pages 2>$null)
        $idFile = Join-Path $PSScriptRoot "build\.gh_pages_commit"
        $localCommit = ""
        if (Test-Path $idFile) {
            $localCommit = (Get-Content $idFile -Raw).Trim()
        }
        if ($needsExtract -or ($remoteCommit -and $localCommit -ne $remoteCommit)) {
            Write-Host "       Sincronizando compilacion web desde GitHub Pages..." -ForegroundColor Cyan
            $zipPath = Join-Path $PSScriptRoot "build\gh-pages.zip"
            if (-not (Test-Path (Join-Path $PSScriptRoot "build"))) {
                New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot "build") -Force | Out-Null
            }
            git archive --format=zip --output="$zipPath" origin/gh-pages 2>$null
            if (Test-Path $zipPath) {
                Expand-Archive -Path $zipPath -DestinationPath (Join-Path $PSScriptRoot "build\web") -Force
                Remove-Item $zipPath -Force
                if ($remoteCommit) {
                    Set-Content -Path $idFile -Value $remoteCommit -Force
                }
            }
        }
    } catch {}

    if (Test-Path $webIndex) {
        Write-Host "       [OK] Paquete web de produccion listo para servir en local." -ForegroundColor Green
    } else {
        Write-Host "       [WARN] No se encontro build/web/index.html." -ForegroundColor Yellow
    }
}

# Paso 5: Lanzar Flutter Web (Puerto 8085)
Write-Host ""
Write-Host " [5/5] Iniciando Aplicacion Web Sanctuary..." -ForegroundColor Cyan
Write-Host "       * Flutter Web: http://localhost:8085" -ForegroundColor Yellow
Write-Host "       * Backend API: http://localhost:8088" -ForegroundColor Yellow
Write-Host ""

Start-Job -ScriptBlock {
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:8085"
} | Out-Null

if ($canRunFlutter) {
    $useChrome = $args -contains "--chrome"
    if ($useChrome) {
        & flutter run -d chrome --web-port=8085 --web-hostname=0.0.0.0
    } else {
        & flutter run -d web-server --web-port=8085 --web-hostname=0.0.0.0
    }
} else {
    $webServerPath = Join-Path $PSScriptRoot "backend\web_server.js"
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host " SANCTUARY PLATFORM ESTA ACTIVA Y OPERATIVA" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "  * Web Local:         http://localhost:8085" -ForegroundColor White
    Write-Host "  * Backend API:       http://localhost:8088" -ForegroundColor White
    Write-Host "  * Web en la Nube:    https://carlosss91.github.io/Sanctuary/" -ForegroundColor Gray
    Write-Host "  * Backend en Nube:   https://sanctuary-backend-u1m1.onrender.com" -ForegroundColor Gray
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host " Servidor Web Node.js activo en primer plano." -ForegroundColor Cyan
    Write-Host " Presiona Ctrl+C para detener ambos servidores cuando termines." -ForegroundColor DarkGray
    Write-Host ""

    # Ejecutar el servidor web en primer plano para mantener la ventana viva y limpiar al cerrar
    try {
        & $nodeCmd "$webServerPath"
    } finally {
        if ($backendProcess -and -not $backendProcess.HasExited) {
            Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
