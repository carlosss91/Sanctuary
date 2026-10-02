# ==============================================================================
#  SANCTUARY PLATFORM - STOP SCRIPT (WINDOWS POWERSHELL)
# ==============================================================================

Write-Host ""
Write-Host "Deteniendo todos los servicios de Sanctuary..." -ForegroundColor Yellow

# 1. Detener contenedores Docker si existen
if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
        docker compose down 2>$null | Out-Null
        docker rm -f sanctuary_api sanctuary_postgres 2>$null | Out-Null
    } catch {}
}

# 2. Matar procesos en puertos 8085 y 8088
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

# 3. Matar procesos flutter / dart huerfanos de web-server
Get-Process -Name "dart", "flutter" -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like "*flutter*"
} | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "[OK] Todos los servicios, puertos y contenedores han sido detenidos correctamente." -ForegroundColor Green
Write-Host ""
