#!/usr/bin/env bash
# ==============================================================================
#  SANCTUARY PLATFORM - STOP SCRIPT
#  Detiene ordenadamente los contenedores Docker y procesos activos.
# ==============================================================================

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_EMERALD="\033[38;2;16;185;129m"
C_YELLOW="\033[38;2;245;158;11m"
C_DIM="\033[2m"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo -e "\n${C_BOLD}${C_YELLOW}⏹ Deteniendo todos los servicios de Sanctuary...${C_RESET}"

# 1. Detener contenedores Docker
docker compose down 2>/dev/null || true
docker rm -f sanctuary_api sanctuary_postgres 2>/dev/null || true

# 2. Liberar puertos y procesos de Flutter / Node / Postgres
fuser -k 8085/tcp 2>/dev/null || true
fuser -k 8088/tcp 2>/dev/null || true
fuser -k 5438/tcp 2>/dev/null || true
pkill -f "flutter_tools.*8085" 2>/dev/null || true
pkill -f "flutter.*8085" 2>/dev/null || true
pkill -f "flutter run.*Sanctuary" 2>/dev/null || true
pkill -f "node.*server.js" 2>/dev/null || true

echo -e "${C_EMERALD}✔ Todos los servicios, puertos y contenedores han sido detenidos correctamente.${C_RESET}\n"
