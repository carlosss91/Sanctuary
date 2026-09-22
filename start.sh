#!/usr/bin/env bash
# ==============================================================================
#  SANCTUARY PLATFORM - LAUNCHER & ORCHESTRATOR
#  Levanta Docker (PostgreSQL + Backend API) y la Web App en Flutter
#  con barras de progreso dinámicas y comprobaciones de salud.
# ==============================================================================

set -e

# Colores ANSI y estilos
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_EMERALD="\033[38;2;16;185;129m"
C_CYAN="\033[38;2;6;182;212m"
C_BLUE="\033[38;2;59;130;246m"
C_PURPLE="\033[38;2;168;85;247m"
C_YELLOW="\033[38;2;245;158;11m"
C_RED="\033[38;2;239;68;68m"
C_BG_DARK="\033[48;2;11;15;23m"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Función de barra de progreso dinámica animada
progress_bar() {
    local percent=$1
    local width=34
    local filled=$(( percent * width / 100 ))
    local empty=$(( width - filled ))
    
    printf "\r  ${C_DIM}[${C_RESET}"
    for ((i=0; i<filled; i++)); do printf "${C_EMERALD}━${C_RESET}"; done
    for ((i=0; i<empty; i++)); do printf "${C_DIM}┄${C_RESET}"; done
    printf "${C_DIM}]${C_RESET} ${C_BOLD}%3d%%${C_RESET}" "$percent"
}

spinner_progress() {
    local task_name="$1"
    local duration="$2"
    local steps=20
    local sleep_time=$(awk "BEGIN {print $duration/$steps}")
    local spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    
    for ((s=0; s<=steps; s++)); do
        local pct=$(( s * 100 / steps ))
        local char_idx=$(( s % 10 ))
        printf "\r  ${C_CYAN}${spin_chars[$char_idx]}${C_RESET}  ${C_BOLD}%-35s${C_RESET} " "$task_name"
        progress_bar "$pct"
        sleep "$sleep_time"
    done
    printf "\r  ${C_EMERALD}✔${C_RESET}  ${C_BOLD}%-35s${C_RESET} " "$task_name"
    progress_bar 100
    printf "  ${C_EMERALD}[LISTO]${C_RESET}\n"
}

clear
echo -e "${C_EMERALD}${C_BOLD}"
cat << "EOF"
   _____             _                      
  / ____|           | |                     
 | (___   __ _ _ __ | |_ _   _  __ _ _ __ _   _ 
  \___ \ / _` | '_ \| __| | | |/ _` | '__| | | |
  ____) | (_| | | | | |_| |_| | (_| | |  | |_| |
 |_____/ \__,_|_| |_|\__|\__,_|\__,_|_|   \__, |
                                           __/ |
                                          |___/ 
EOF
echo -e "${C_RESET}${C_DIM} Plataforma Multiplataforma · Flutter · Docker · PostgreSQL · CV Builder${C_RESET}\n"

echo -e " ${C_BOLD}${C_PURPLE}▶ Paso 0/5:${C_RESET} Verificando y deteniendo servicios previos si estaban en ejecución..."
# 1. Detener contenedores previos de Sanctuary
docker compose down > /dev/null 2>&1 || true
docker rm -f sanctuary_api sanctuary_postgres > /dev/null 2>&1 || true

# 2. Liberar puertos y procesos por si quedaron instancias huérfanas
fuser -k 8085/tcp > /dev/null 2>&1 || true
fuser -k 8088/tcp > /dev/null 2>&1 || true
fuser -k 5438/tcp > /dev/null 2>&1 || true
pkill -f "flutter_tools.*8085" > /dev/null 2>&1 || true
pkill -f "flutter.*8085" > /dev/null 2>&1 || true
pkill -f "flutter run.*Sanctuary" > /dev/null 2>&1 || true
pkill -f "node.*server.js" > /dev/null 2>&1 || true

sleep 1
printf "  ${C_EMERALD}✔${C_RESET}  ${C_BOLD}Servicios previos detenidos y puertos liberados${C_RESET} "
progress_bar 100
printf "  ${C_EMERALD}[OK]${C_RESET}\n\n"

echo -e " ${C_BOLD}${C_PURPLE}▶ Paso 1/5:${C_RESET} Verificando dependencias del sistema..."
# Check Docker
if command -v docker &> /dev/null; then
    echo -e "   ${C_EMERALD}✔${C_RESET} Docker detectado: $(docker --version | awk '{print $3}' | tr -d ',')"
else
    echo -e "   ${C_RED}✘ Docker no está instalado.${C_RESET}"
    exit 1
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
    echo -e "   ${C_EMERALD}✔${C_RESET} Docker Compose detectado: $(docker compose version | awk '{print $4}')"
else
    echo -e "   ${C_RED}✘ Docker Compose no está disponible.${C_RESET}"
    exit 1
fi

# Check Flutter
if command -v flutter &> /dev/null; then
    echo -e "   ${C_EMERALD}✔${C_RESET} Flutter SDK detectado: $(flutter --version | head -n 1 | awk '{print $2}')"
else
    echo -e "   ${C_RED}✘ Flutter no encontrado en PATH.${C_RESET}"
    exit 1
fi
echo ""

echo -e " ${C_BOLD}${C_PURPLE}▶ Paso 2/5:${C_RESET} Levantando contenedores Docker (PostgreSQL 16 & Backend API)..."
docker compose up -d --build > /dev/null 2>&1 &
DOCKER_PID=$!

# Animación de progreso mientras Docker arranca
steps=0
spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
while kill -0 $DOCKER_PID 2> /dev/null; do
    idx=$(( steps % 10 ))
    pct=$(( (steps * 4) % 95 + 5 ))
    printf "\r  ${C_CYAN}${spin_chars[$idx]}${C_RESET}  ${C_BOLD}Construyendo e iniciando servicios...${C_RESET} "
    progress_bar "$pct"
    steps=$(( steps + 1 ))
    sleep 0.2
done
wait $DOCKER_PID

printf "\r  ${C_EMERALD}✔${C_RESET}  ${C_BOLD}Contenedores Docker iniciados        ${C_RESET} "
progress_bar 100
printf "  ${C_EMERALD}[OK]${C_RESET}\n\n"

echo -e " ${C_BOLD}${C_PURPLE}▶ Paso 3/5:${C_RESET} Verificando conectividad con PostgreSQL y Backend API..."
DB_READY=0
for i in {1..20}; do
    pct=$(( i * 5 ))
    printf "\r  ${C_CYAN}⠋${C_RESET}  ${C_BOLD}Esperando salud de la API (puerto 8088)...${C_RESET} "
    progress_bar "$pct"
    
    if curl -s http://localhost:8088/api/health | grep -q "ok"; then
        DB_READY=1
        break
    fi
    sleep 0.5
done

if [ $DB_READY -eq 1 ]; then
    printf "\r  ${C_EMERALD}✔${C_RESET}  ${C_BOLD}PostgreSQL (5438) y Backend API (8088)${C_RESET} "
    progress_bar 100
    printf "  ${C_EMERALD}[CONECTADO]${C_RESET}\n\n"
else
    echo -e "\n  ${C_YELLOW}⚠ La API sigue inicializando. Continuando con el modo híbrido/offline...${C_RESET}\n"
fi

echo -e " ${C_BOLD}${C_PURPLE}▶ Paso 4/5:${C_RESET} Verificando dependencias Flutter..."
flutter pub get > /dev/null 2>&1
echo -e "  ${C_EMERALD}✔${C_RESET}  ${C_BOLD}Paquetes y recursos Dart listos     ${C_RESET} "
progress_bar 100
printf "  ${C_EMERALD}[OK]${C_RESET}\n\n"

echo -e " ${C_BOLD}${C_PURPLE}▶ Paso 5/5:${C_RESET} Lanzando Aplicación Web Sanctuary..."
echo -e "  ${C_EMERALD}★ URL Web:${C_RESET}       ${C_BOLD}${C_CYAN}http://localhost:8085${C_RESET}"
echo -e "  ${C_EMERALD}★ Backend API:${C_RESET}   ${C_BOLD}${C_CYAN}http://localhost:8088${C_RESET}"
echo -e "  ${C_EMERALD}★ PostgreSQL:${C_RESET}    ${C_BOLD}${C_CYAN}localhost:5438 (DB: sanctuary_db)${C_RESET}"
echo -e "  ${C_EMERALD}★ Usuario admin:${C_RESET} ${C_BOLD}admin${C_RESET} / ${C_BOLD}admin${C_RESET}\n"

# Apertura automática del navegador en segundo plano
(
    sleep 3
    if command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:8085" > /dev/null 2>&1 || true
    elif command -v google-chrome &> /dev/null; then
        google-chrome "http://localhost:8085" > /dev/null 2>&1 || true
    fi
) &

USE_CHROME=false
for arg in "$@"; do
    if [ "$arg" == "--chrome" ]; then
        USE_CHROME=true
    fi
done

if [ "$USE_CHROME" = true ]; then
    echo -e " ${C_DIM}Iniciando Flutter en Chrome (con supresión de advertencias de extensiones/DWDS)...${C_RESET}"
    exec flutter run -d chrome --web-port=8085 --web-hostname=0.0.0.0 \
        --web-browser-flag="--disable-extensions" \
        --web-browser-flag="--disable-default-apps" \
        2> >(grep -v -E "RemoteDebuggerExecutionContext|dartDevEmbedder|WipError|-32602|Invalid parameters" >&2)
else
    # web-server mode: Elimina al 100% los errores de DWDS (Timed out finding an execution context, WipError -32602)
    # y sirve de manera robusta y ligera con soporte para hot reload (tecla 'r') y hot restart ('R').
    echo -e " ${C_DIM}Iniciando servidor de desarrollo Flutter Web en el puerto 8085...${C_RESET}"
    exec flutter run -d web-server --web-port=8085 --web-hostname=0.0.0.0
fi
