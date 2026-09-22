#!/usr/bin/env bash
# ==============================================================================
#  SANCTUARY PLATFORM - ANDROID APK BUILDER
#  Compila el binario APK de Android con barra de progreso dinámica.
# ==============================================================================

set -e

C_RESET="\033[0m"
C_BOLD="\033[1m"
C_EMERALD="\033[38;2;16;185;129m"
C_CYAN="\033[38;2;6;182;212m"
C_PURPLE="\033[38;2;168;85;247m"
C_DIM="\033[2m"

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

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

clear
echo -e "${C_EMERALD}${C_BOLD}"
cat << "EOF"
  ____        _ _     _      _    ____  _  __
 | __ ) _   _(_) | __| |    / \  |  _ \| |/ /
 |  _ \| | | | | |/ _` |   / _ \ | |_) | ' / 
 | |_) | |_| | | | (_| |  / ___ \|  __/| . \ 
 |____/ \__,_|_|_|\__,_| /_/   \_\_|   |_|\_\
EOF
echo -e "${C_RESET}${C_DIM} Compilador de APK Android para la plataforma Sanctuary${C_RESET}\n"

echo -e " ${C_PURPLE}▶ Paso 1/3:${C_RESET} Resolviendo dependencias de Flutter..."
flutter pub get > /dev/null 2>&1
echo -e "   ${C_EMERALD}✔${C_RESET} Dependencias listas."

echo -e "\n ${C_PURPLE}▶ Paso 2/3:${C_RESET} Compilando APK Android (Gradle & Flutter)..."

# Lanzar build de APK
flutter build apk --debug > /tmp/sanctuary_apk_build.log 2>&1 &
BUILD_PID=$!

steps=0
spin_chars=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
while kill -0 $BUILD_PID 2> /dev/null; do
    idx=$(( steps % 10 ))
    pct=$(( (steps * 3) % 94 + 5 ))
    printf "\r  ${C_CYAN}${spin_chars[$idx]}${C_RESET}  ${C_BOLD}Compilando código Dart y dependencias nativas...${C_RESET} "
    progress_bar "$pct"
    steps=$(( steps + 1 ))
    sleep 0.3
done
wait $BUILD_PID

printf "\r  ${C_EMERALD}✔${C_RESET}  ${C_BOLD}Compilación de APK completada con éxito          ${C_RESET} "
progress_bar 100
printf "  ${C_EMERALD}[OK]${C_RESET}\n\n"

echo -e " ${C_PURPLE}▶ Paso 3/3:${C_RESET} Verificando archivo generado..."
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"

if [ -f "$APK_PATH" ]; then
    SIZE=$(du -h "$APK_PATH" | awk '{print $1}')
    echo -e "   ${C_EMERALD}✔ APK Generado:${C_RESET} ${C_BOLD}$APK_PATH${C_RESET} (${SIZE})"
    echo -e "\n ${C_EMERALD}★ ¡Listo para instalar en cualquier dispositivo Android o emulador!${C_RESET}\n"
else
    echo -e "   ${C_DIM}Revisa /tmp/sanctuary_apk_build.log para más detalles.${C_RESET}"
fi
