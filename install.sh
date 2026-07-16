#!/bin/bash

# EPUB Fordító Rendszer - Telepítő/Frissítő Script v11.0
# Verzió: 11.0.0
# Kódnév: "Smart Optimizer"
# Dátum: 2025-07-17
# Leírás: Automatikus modell optimalizálás, dinamikus erőforrás kezelés,
#          intelligens modellváltás, valós idejű rendszerfigyelés

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NOWARNINGS="yes"
export DEBCONF_DB_OVERRIDE='File{/dev/null}'

# Színek
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Verzió
VERSION="11.0.0"
CODENAME="Smart Optimizer"
RELEASE_DATE="2025-07-17"
MIN_VERSION_FOR_UPDATE="9.0.0"

# Alapértelmezések
DEFAULT_MODEL="deepseek-r1:14b"
ADMIN_EMAIL="admin@epub-translator.local"
ADMIN_PASSWORD="Abrakadabra"
MAX_WORKERS=3
DEFAULT_LANGUAGE="hu"

# Rendszer erőforrások automatikus észlelése
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

# Automatikus modell ajánlás
if [ "$TOTAL_RAM" -ge 64 ]; then
    RECOMMENDED_MODEL="deepseek-r1:32b"
    MAX_WORKERS=4
elif [ "$TOTAL_RAM" -ge 32 ]; then
    RECOMMENDED_MODEL="deepseek-r1:14b"
    MAX_WORKERS=3
elif [ "$TOTAL_RAM" -ge 16 ]; then
    RECOMMENDED_MODEL="deepseek-r1:8b"
    MAX_WORKERS=2
else
    RECOMMENDED_MODEL="deepseek-r1:7b"
    MAX_WORKERS=1
fi

# Funkciók (mind alapértelmezetten engedélyezve)
ENABLE_AI_ASSISTANT="i"
ENABLE_OAUTH="i"
ENABLE_OCR="i"
ENABLE_VOICE_INPUT="i"
ENABLE_GAMIFICATION="i"
ENABLE_COMMUNITY="i"
ENABLE_FINE_TUNING="i"
ENABLE_AUTO_COMPLETE="i"
ENABLE_DARK_MODE="i"
ENABLE_SHORTCUTS="i"
ENABLE_I18N="i"
ENABLE_PWA="i"
ENABLE_CACHE="i"
ENABLE_AUTO_UPDATE="i"
ENABLE_REGISTRATION="i"
ENABLE_AUTO_OPTIMIZE="i"  # ÚJ: Automatikus optimalizálás
ENABLE_RESOURCE_MONITOR="i"  # ÚJ: Erőforrás figyelés
ENABLE_SMART_SWITCH="i"  # ÚJ: Intelligens modellváltás

# GitHub
GITHUB_REPO="https://github.com/sorosg/Epub-translate.git"
GITHUB_BRANCH="main"
GITHUB_TOKEN=""
UPDATE_CHECK_INTERVAL=3600

# Telepítési mód
IS_UPDATE=false
EXISTING_VERSION=""

# Log függvények
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[FIGYELEM]${NC} $1"; }
log_error() { echo -e "${RED}[HIBA]${NC} $1"; }
log_step() { echo -e "\n${BLUE}═══ [LÉPÉS] $1 ═══${NC}"; echo "----------------------------------------"; }
log_success() { echo -e "${CYAN}[SIKER]${NC} $1"; }
log_config() { echo -e "${PURPLE}[KONFIG]${NC} $1"; }
log_header() { echo -e "${WHITE}$1${NC}"; }
log_update() { echo -e "${YELLOW}[FRISSÍTÉS]${NC} $1"; }
log_perf() { echo -e "${CYAN}[TELJESÍTMÉNY]${NC} $1"; }

if [ "$EUID" -eq 0 ]; then 
    log_warn "Ne futtasd root-ként!"
    exit 1
fi

# ============================================================
# TELEPÍTÉSI MÓD ÉSZLELÉSE
# ============================================================
detect_installation_mode() {
    log_step "Telepítési mód észlelése"
    
    PROJECT_DIR="$HOME/epub-translator"
    
    if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.install_config" ]; then
        source "$PROJECT_DIR/.install_config" 2>/dev/null || true
        EXISTING_VERSION="${VERSION:-unknown}"
        
        echo ""
        log_header "╔══════════════════════════════════════════════════════════════╗"
        log_header "║     Meglévő telepítés észlelve!                              ║"
        log_header "║     Telepített verzió: ${EXISTING_VERSION}                              ║"
        log_header "║     Új verzió: ${VERSION} - ${CODENAME}                      ║"
        log_header "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        
        echo "Válassz:"
        echo "  1) Frissítés (adatok megőrzése) ⭐ Ajánlott"
        echo "  2) Újratelepítés (minden törlődik)"
        echo "  3) Csak optimalizálás (megtart mindent, csak hangol)"
        echo "  4) Kilépés"
        read -p "Választás [1]: " mode
        mode=${mode:-1}
        
        case $mode in
            1) IS_UPDATE=true; load_existing_config;;
            2) IS_UPDATE=false
               read -p "Biztosan? (i/n): " c
               [[ $c =~ ^[Ii]$ ]] || exit 0
               BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"
               cp -r "$PROJECT_DIR" "$BACKUP_DIR" 2>/dev/null || true
               rm -rf "$PROJECT_DIR";;
            3) IS_UPDATE=true; OPTIMIZE_ONLY=true; load_existing_config;;
            4) exit 0;;
            *) IS_UPDATE=true; load_existing_config;;
        esac
    else
        IS_UPDATE=false
        log_info "Friss telepítés"
    fi
}

load_existing_config() {
    [ -f "$PROJECT_DIR/.install_config" ] && source "$PROJECT_DIR/.install_config"
    [ -f "$PROJECT_DIR/.env" ] && cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
    ADMIN_EMAIL="${ADMIN_EMAIL:-admin@epub-translator.local}"
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-Abrakadabra}"
    SELECTED_MODEL="${SELECTED_MODEL:-$RECOMMENDED_MODEL}"
    DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE:-hu}"
    GITHUB_REPO="${GITHUB_REPO:-https://github.com/sorosg/Epub-translate.git}"
    GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    log_success "Konfiguráció betöltve"
}

# ============================================================
# RENDSZER ANALÍZIS ÉS OPTIMALIZÁLÁS
# ============================================================
analyze_and_optimize() {
    log_step "Rendszer analízis és automatikus optimalizálás"
    
    log_perf "Hardver információ:"
    log_info "  RAM: ${TOTAL_RAM} GB"
    log_info "  CPU: ${CPU_CORES} mag"
    log_info "  Szabad hely: ${FREE_SPACE} GB"
    
    # CPU optimalizálás
    if [ "$CPU_CORES" -ge 8 ]; then
        OPTIMAL_WORKERS=4
        OPTIMAL_OLLAMA_PARALLEL=3
    elif [ "$CPU_CORES" -ge 4 ]; then
        OPTIMAL_WORKERS=3
        OPTIMAL_OLLAMA_PARALLEL=2
    else
        OPTIMAL_WORKERS=1
        OPTIMAL_OLLAMA_PARALLEL=1
    fi
    
    # RAM optimalizálás
    if [ "$TOTAL_RAM" -ge 64 ]; then
        OPTIMAL_MEMORY_LIMIT="48G"
        OPTIMAL_REDIS="1024mb"
        OPTIMAL_PG_BUFFERS="1GB"
    elif [ "$TOTAL_RAM" -ge 32 ]; then
        OPTIMAL_MEMORY_LIMIT="24G"
        OPTIMAL_REDIS="512mb"
        OPTIMAL_PG_BUFFERS="512MB"
    elif [ "$TOTAL_RAM" -ge 16 ]; then
        OPTIMAL_MEMORY_LIMIT="12G"
        OPTIMAL_REDIS="256mb"
        OPTIMAL_PG_BUFFERS="256MB"
    else
        OPTIMAL_MEMORY_LIMIT="8G"
        OPTIMAL_REDIS="128mb"
        OPTIMAL_PG_BUFFERS="128MB"
    fi
    
    # Lemez optimalizálás
    if [ "$FREE_SPACE" -lt 20 ]; then
        log_warn "Kevesebb mint 20 GB szabad hely - nagytakarítás javasolt"
        ENABLE_CLEANUP="i"
    fi
    
    # Modell ajánlás
    log_perf "Optimális beállítások:"
    log_info "  Ajánlott modell: ${RECOMMENDED_MODEL}"
    log_info "  Optimális szálak: ${OPTIMAL_WORKERS}"
    log_info "  Memória limit: ${OPTIMAL_MEMORY_LIMIT}"
    log_info "  Redis cache: ${OPTIMAL_REDIS}"
    log_info "  PostgreSQL buffer: ${OPTIMAL_PG_BUFFERS}"
    
    # Automatikus optimalizálási profil mentése
    cat > .optimization_profile << EOF
OPTIMAL_WORKERS=${OPTIMAL_WORKERS}
OPTIMAL_OLLAMA_PARALLEL=${OPTIMAL_OLLAMA_PARALLEL}
OPTIMAL_MEMORY_LIMIT="${OPTIMAL_MEMORY_LIMIT}"
OPTIMAL_REDIS="${OPTIMAL_REDIS}"
OPTIMAL_PG_BUFFERS="${OPTIMAL_PG_BUFFERS}"
RECOMMENDED_MODEL="${RECOMMENDED_MODEL}"
CPU_CORES=${CPU_CORES}
TOTAL_RAM=${TOTAL_RAM}
EOF
    
    log_success "Optimalizálási profil létrehozva"
}

# ============================================================
# CSAK OPTIMALIZÁLÁS (meglévő telepítéshez)
# ============================================================
perform_optimization_only() {
    log_step "Rendszer optimalizálás (meglévő telepítés)"
    
    cd "$PROJECT_DIR"
    analyze_and_optimize
    
    log_info "Beállítások alkalmazása..."
    
    # .env frissítése
    sed -i "s/MAX_WORKERS=.*/MAX_WORKERS=${OPTIMAL_WORKERS}/" .env
    sed -i "s/SELECTED_MODEL=.*/SELECTED_MODEL=${RECOMMENDED_MODEL}/" .env
    
    # docker-compose.yml frissítése
    sed -i "s/memory: [0-9]*G/memory: ${OPTIMAL_MEMORY_LIMIT}/" docker-compose.yml
    
    # Redis optimalizálás
    $DOCKER exec epub-redis redis-cli CONFIG SET maxmemory "${OPTIMAL_REDIS}" 2>/dev/null || true
    
    # PostgreSQL optimalizálás
    $DOCKER exec epub-postgres psql -U epub_user -c "ALTER SYSTEM SET shared_buffers = '${OPTIMAL_PG_BUFFERS}';" 2>/dev/null || true
    $DOCKER exec epub-postgres psql -U epub_user -c "SELECT pg_reload_conf();" 2>/dev/null || true
    
    # Konténerek újraindítása az új beállításokkal
    $DOCKER compose restart ollama backend
    
    log_success "Optimalizálás befejezve!"
}

# ============================================================
# KONFIGURÁCIÓS VARÁZSLÓ
# ============================================================
configure_system() {
    [ "$IS_UPDATE" = true ] && { log_info "Meglévő konfiguráció megtartása"; return; }
    [ "${OPTIMIZE_ONLY:-false}" = true ] && return
    
    log_step "Konfigurációs varázsló"
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════╗"
    log_header "║     EPUB Fordító v${VERSION} - \"${CODENAME}\"    ║"
    log_header "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "   🆕 v11.0 Újdonságok:"
    echo "   🧠 Automatikus modell optimalizálás"
    echo "   📊 Valós idejű erőforrás figyelés"
    echo "   🔄 Intelligens modellváltás (auto-optimize)"
    echo "   💾 Dinamikus memória kezelés"
    echo "   ⚡ Teljesítmény profilok"
    echo "   🎯 Hardver alapú auto-konfiguráció"
    echo ""
    
    # Rendszer analízis
    analyze_and_optimize
    
    echo ""
    log_perf "A rendszered alapján az optimális beállítások:"
    echo "   🤖 Modell: ${RECOMMENDED_MODEL}"
    echo "   🧵 Szálak: ${OPTIMAL_WORKERS}"
    echo "   💾 RAM limit: ${OPTIMAL_MEMORY_LIMIT}"
    echo ""
    
    read -p "Elfogadod az automatikus beállításokat? (i/n) [i]: " c
    c=${c:-"i"}
    
    if [[ ! $c =~ ^[Ii]$ ]]; then
        echo ""; log_config "👤 Admin:"; read -p "Email [${ADMIN_EMAIL}]: " i; ADMIN_EMAIL=${i:-$ADMIN_EMAIL}; read -sp "Jelszó [${ADMIN_PASSWORD}]: " i; echo ""; ADMIN_PASSWORD=${i:-$ADMIN_PASSWORD}
        echo ""; log_config "🤖 Modell:"; select_model
        echo ""; log_config "⚡ Teljesítmény:"
        read -p "  Szálak [${OPTIMAL_WORKERS}]: " i; MAX_WORKERS=${i:-$OPTIMAL_WORKERS}
        read -p "  RAM limit [${OPTIMAL_MEMORY_LIMIT}]: " i; OPTIMAL_MEMORY_LIMIT=${i:-$OPTIMAL_MEMORY_LIMIT}
    else
        SELECTED_MODEL="${RECOMMENDED_MODEL}"
        MAX_WORKERS="${OPTIMAL_WORKERS}"
    fi
    
    echo ""; log_config "🆕 Funkciók:"
    read -p "  Auto-optimalizálás? (i/n) [i]: " i; ENABLE_AUTO_OPTIMIZE=${i:-"i"}
    read -p "  Erőforrás monitor? (i/n) [i]: " i; ENABLE_RESOURCE_MONITOR=${i:-"i"}
    read -p "  Intelligens modellváltás? (i/n) [i]: " i; ENABLE_SMART_SWITCH=${i:-"i"}
    read -p "  AI Asszisztens? (i/n) [i]: " i; ENABLE_AI_ASSISTANT=${i:-"i"}
    
    cat > .install_config << EOF
VERSION="${VERSION}"
CODENAME="${CODENAME}"
RELEASE_DATE="${RELEASE_DATE}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
MAX_WORKERS=${MAX_WORKERS}
SELECTED_MODEL="${SELECTED_MODEL}"
RECOMMENDED_MODEL="${RECOMMENDED_MODEL}"
OPTIMAL_WORKERS=${OPTIMAL_WORKERS}
OPTIMAL_MEMORY_LIMIT="${OPTIMAL_MEMORY_LIMIT}"
OPTIMAL_REDIS="${OPTIMAL_REDIS}"
OPTIMAL_PG_BUFFERS="${OPTIMAL_PG_BUFFERS}"
DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE}"
ENABLE_AUTO_OPTIMIZE="${ENABLE_AUTO_OPTIMIZE}"
ENABLE_RESOURCE_MONITOR="${ENABLE_RESOURCE_MONITOR}"
ENABLE_SMART_SWITCH="${ENABLE_SMART_SWITCH}"
ENABLE_AI_ASSISTANT="${ENABLE_AI_ASSISTANT}"
ENABLE_OAUTH="${ENABLE_OAUTH}"
ENABLE_OCR="${ENABLE_OCR}"
ENABLE_VOICE_INPUT="${ENABLE_VOICE_INPUT}"
ENABLE_GAMIFICATION="${ENABLE_GAMIFICATION}"
ENABLE_COMMUNITY="${ENABLE_COMMUNITY}"
ENABLE_FINE_TUNING="${ENABLE_FINE_TUNING}"
ENABLE_AUTO_COMPLETE="${ENABLE_AUTO_COMPLETE}"
ENABLE_AUTO_UPDATE="${ENABLE_AUTO_UPDATE}"
GITHUB_REPO="${GITHUB_REPO}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
INSTALL_DATE="$(date +%Y-%m-%d_%H:%M:%S)"
EOF
}

select_model() {
    echo "   Válassz modellt (ajánlott: ${RECOMMENDED_MODEL}):"
    echo "   1) deepseek-r1:1.5b (1.5GB)"
    echo "   2) deepseek-r1:7b (7GB)"
    echo "   3) deepseek-r1:8b (8GB)"
    echo "   4) deepseek-r1:14b (14GB) ★"
    echo "   5) deepseek-r1:32b (32GB)"
    echo "   6) deepseek-r1:70b (70GB)"
    read -p "   Választás [4]: " c; c=${c:-4}
    case $c in
        1) SELECTED_MODEL="deepseek-r1:1.5b";;
        2) SELECTED_MODEL="deepseek-r1:7b";;
        3) SELECTED_MODEL="deepseek-r1:8b";;
        4) SELECTED_MODEL="deepseek-r1:14b";;
        5) SELECTED_MODEL="deepseek-r1:32b";;
        6) SELECTED_MODEL="deepseek-r1:70b";;
        *) SELECTED_MODEL="${RECOMMENDED_MODEL}";;
    esac
}

# ============================================================
# FRISSÍTÉS
# ============================================================
perform_update() {
    log_step "Frissítés (${EXISTING_VERSION} → ${VERSION})"
    cd "$PROJECT_DIR"
    
    BACK="$PROJECT_DIR/backups/updates/pre_${EXISTING_VERSION}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACK"
    $DOCKER compose ps 2>/dev/null | grep -q postgres && $DOCKER exec epub-postgres pg_dump -U epub_user epub_translator > "$BACK/database.sql" 2>/dev/null || true
    cp .env "$BACK/.env" 2>/dev/null || true
    [ -d book_database ] && tar -czf "$BACK/book_database.tar.gz" book_database/ 2>/dev/null || true
    [ -d translation_memory ] && tar -czf "$BACK/translation_memory.tar.gz" translation_memory/ 2>/dev/null || true
    log_success "Mentés: $BACK"
    
    $DOCKER compose down 2>/dev/null || true
    [ -d .git ] && { git fetch origin 2>/dev/null && git pull origin main 2>/dev/null || log_warn "Git pull nem sikerült"; }
    
    create_all_files
    $DOCKER compose build 2>/dev/null || $DOCKER compose build --no-cache
    $DOCKER compose up -d
    sleep 15
    
    $DOCKER exec -i epub-backend python3 -c "from app import app, db; app.app_context().push(); db.create_all(); print('OK')" 2>/dev/null || log_warn "Migráció figyelmeztetés"
    
    # Optimalizálás alkalmazása
    apply_optimization
    
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
    echo "$(date): Frissítve ${EXISTING_VERSION} → ${VERSION}" >> updates.log
    log_success "Frissítés kész!"
}

# ============================================================
# FRISS TELEPÍTÉS
# ============================================================
perform_fresh_install() {
    log_step "Friss telepítés"
    PROJECT_DIR="$HOME/epub-translator"
    [ -d "$PROJECT_DIR" ] && { BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"; mv "$PROJECT_DIR" "$BACKUP_DIR" 2>/dev/null || true; }
    mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"
    
    create_directory_structure
    create_all_files
    apply_optimization
    
    # Csomagkezelő lock-ok felszabadulására várakozás
    log_info "Csomagkezelő lock-okra várakozás..."
    for i in $(seq 1 6); do
        LOCKS=$(sudo fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/cache/debconf/config.dat 2>/dev/null) || true
        if [ -z "$LOCKS" ]; then
            log_success "Csomagkezelő lock-ok felszabadultak"
            break
        fi
        if [ "$i" -eq 6 ]; then
            log_warn "A csomagkezelő 30 mp után is zárolva van, a lock-ot tartó folyamatok leállítása..."
            sudo fuser -k /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/cache/debconf/config.dat 2>/dev/null || true
            sleep 3
            break
        fi
        log_warn "Csomagkezelő zárolva, várakozás... ($i/6)"
        sleep 5
    done
    # Félbemaradt csomagok helyreállítása
    sudo dpkg --configure -a 2>/dev/null || true
    
    log_info "Rendszercsomagok telepítése..."
    for i in $(seq 1 5); do
        if sudo DEBIAN_FRONTEND=noninteractive apt update -qq 2>/dev/null; then
            sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y -qq 2>/dev/null || true
            break
        fi
        log_warn "Az apt zárolva van, várakozás... ($i/5)"
        sleep 10
    done
    log_info "Függőségek telepítése..."
    for i in $(seq 1 5); do
        if sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq curl wget git ca-certificates gnupg nano htop net-tools ufw build-essential python3-pip python3-venv libxml2-dev libxslt-dev redis-tools postgresql-client clamav postfix mailutils poppler-utils ffmpeg nginx openssl tesseract-ocr tesseract-ocr-hun tesseract-ocr-eng espeak mpg321 2>/dev/null; then
            break
        fi
        log_warn "Az apt install zárolva van, várakozás... ($i/5)"
        sleep 10
    done
    pip3 install pytesseract SpeechRecognition pyaudio pyttsx3 psutil 2>/dev/null || true
    
    if ! command -v docker &> /dev/null; then
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        log_info "Docker telepítése..."
        for i in $(seq 1 5); do
            if sudo DEBIAN_FRONTEND=noninteractive apt update -qq 2>/dev/null && sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null; then
                break
            fi
            log_warn "Az apt zárolva van, várakozás... ($i/5)"
            sleep 10
        done
        sudo systemctl enable docker && sudo systemctl start docker
        sudo usermod -aG docker $USER
        DOCKER="sudo docker"
        log_warn "A docker csoporttagság a következő bejelentkezéskor lép életbe."
        log_warn "Addig a script 'sudo docker'-t használ."
    else
        DOCKER="docker"
    fi
    
    $DOCKER compose build 2>/dev/null || $DOCKER compose build --no-cache
    $DOCKER compose up -d
    sleep 20
    
    $DOCKER exec -i epub-ollama ollama pull "$SELECTED_MODEL" 2>/dev/null || log_warn "Modell figyelmeztetés"
    sleep 10
    $DOCKER exec -i epub-backend python3 -c "from app import app, init_db; app.app_context().push(); init_db(); print('OK')" 2>/dev/null || log_warn "DB figyelmeztetés"
    
    [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && [ -n "$GITHUB_REPO" ] && $DOCKER exec -i epub-backend python3 -c "from app import app, db; from models import UpdateChannel; app.app_context().push(); c=UpdateChannel.query.filter_by(name='stable').first() or UpdateChannel(name='stable',github_repo='${GITHUB_REPO}',github_branch='${GITHUB_BRANCH:-main}',github_token='${GITHUB_TOKEN}' if '${GITHUB_TOKEN}' else None,auto_check=True); db.session.add(c); db.session.commit()" 2>/dev/null || true
    
    (crontab -l 2>/dev/null; echo "0 3 * * 0 $PROJECT_DIR/scripts/backup.sh") | crontab -
    (crontab -l 2>/dev/null; echo "0 4 * * 0 docker system prune -f") | crontab -
    (crontab -l 2>/dev/null; echo "*/30 * * * * $PROJECT_DIR/scripts/monitor.sh") | crontab -
    
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
}

# ============================================================
# OPTIMALIZÁLÁS ALKALMAZÁSA
# ============================================================
apply_optimization() {
    log_step "Optimalizálás alkalmazása"
    
    # Modell-specifikus beállítások
    case "$SELECTED_MODEL" in
        "deepseek-r1:1.5b")
            OLLAMA_MEMORY="4G"; OLLAMA_PARALLEL=4; BATCH_SIZE=8;;
        "deepseek-r1:7b")
            OLLAMA_MEMORY="12G"; OLLAMA_PARALLEL=3; BATCH_SIZE=6;;
        "deepseek-r1:8b")
            OLLAMA_MEMORY="16G"; OLLAMA_PARALLEL=2; BATCH_SIZE=5;;
        "deepseek-r1:14b")
            OLLAMA_MEMORY="24G"; OLLAMA_PARALLEL=2; BATCH_SIZE=5;;
        "deepseek-r1:32b")
            OLLAMA_MEMORY="30G"; OLLAMA_PARALLEL=1; BATCH_SIZE=2;;
        "deepseek-r1:70b")
            OLLAMA_MEMORY="60G"; OLLAMA_PARALLEL=1; BATCH_SIZE=1;;
        *)
            OLLAMA_MEMORY="${OPTIMAL_MEMORY_LIMIT}"; OLLAMA_PARALLEL=2; BATCH_SIZE=5;;
    esac
    
    # .env frissítése
    sed -i "s/MAX_WORKERS=.*/MAX_WORKERS=${MAX_WORKERS}/" .env 2>/dev/null || true
    sed -i "s/BATCH_SIZE=.*/BATCH_SIZE=${BATCH_SIZE}/" .env 2>/dev/null || true
    
    # docker-compose.yml frissítése
    sed -i "s/memory: [0-9]*G/memory: ${OLLAMA_MEMORY}/" docker-compose.yml 2>/dev/null || true
    
    log_success "Optimalizálás alkalmazva:"
    log_info "  Ollama memória: ${OLLAMA_MEMORY}"
    log_info "  Párhuzamos szálak: ${OLLAMA_PARALLEL}"
    log_info "  Batch méret: ${BATCH_SIZE}"
}

# ============================================================
# KÖNYVTÁR STRUKTÚRA
# ============================================================
create_directory_structure() {
    mkdir -p "$PROJECT_DIR"/{nginx/ssl,backend/{templates,utils,plugins/hooks,static,translations,models},static/{css,js,images,icons,screenshots,audio},uploads/{covers,books,temp,ocr,voice},output,logs/{nginx,backend},backups/{updates,database,config},scripts,postfix,book_database,translation_memory,glossaries,collaboration,tts-service,websocket,updates,integrations/{calibre,kindle,wordpress,chrome},community_library,achievements,challenges,fine_tuning,optimization_profiles}
}

# ============================================================
# ÖSSZES FÁJL LÉTREHOZÁSA
# ============================================================
create_all_files() {
    log_info "Fájlok létrehozása..."
    create_env_file
    create_docker_compose
    create_nginx_config
    create_ollama_files
    create_backend_files
    create_model_optimizer
    create_resource_monitor
    create_pwa_files
    create_scripts
    log_success "Fájlok kész"
}

create_env_file() {
    [ "$IS_UPDATE" = true ] && [ -f ".env" ] && { sed -i "s/VERSION=.*/VERSION=${VERSION}/" .env; sed -i "s/CODENAME=.*/CODENAME=\"${CODENAME}\"/" .env; return; }
    cat > .env << ENVEOF
SECRET_KEY=$(openssl rand -hex 32)
VERSION=${VERSION}
CODENAME="${CODENAME}"
RELEASE_DATE="${RELEASE_DATE}"
FLASK_ENV=production
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
DEFAULT_LANGUAGE=${DEFAULT_LANGUAGE}
SELECTED_MODEL=${SELECTED_MODEL}
RECOMMENDED_MODEL=${RECOMMENDED_MODEL}
MAX_WORKERS=${MAX_WORKERS}
BATCH_SIZE=${BATCH_SIZE:-5}
ENABLE_AUTO_OPTIMIZE=${ENABLE_AUTO_OPTIMIZE}
ENABLE_RESOURCE_MONITOR=${ENABLE_RESOURCE_MONITOR}
ENABLE_SMART_SWITCH=${ENABLE_SMART_SWITCH}
ENABLE_AI_ASSISTANT=${ENABLE_AI_ASSISTANT}
ENABLE_OAUTH=${ENABLE_OAUTH}
ENABLE_OCR=${ENABLE_OCR}
ENABLE_VOICE_INPUT=${ENABLE_VOICE_INPUT}
ENABLE_GAMIFICATION=${ENABLE_GAMIFICATION}
ENABLE_COMMUNITY=${ENABLE_COMMUNITY}
ENABLE_FINE_TUNING=${ENABLE_FINE_TUNING}
ENABLE_AUTO_COMPLETE=${ENABLE_AUTO_COMPLETE}
ENABLE_DARK_MODE=${ENABLE_DARK_MODE}
ENABLE_SHORTCUTS=${ENABLE_SHORTCUTS}
ENABLE_I18N=${ENABLE_I18N}
OPTIMAL_MEMORY_LIMIT=${OPTIMAL_MEMORY_LIMIT}
OPTIMAL_REDIS=${OPTIMAL_REDIS}
OPTIMAL_PG_BUFFERS=${OPTIMAL_PG_BUFFERS}
OLLAMA_HOST=http://ollama:11434
REDIS_URL=redis://redis:6379/0
SMTP_MODE=${SMTP_MODE:-local}
SMTP_HOST=${SMTP_HOST:-mailhog}
SMTP_PORT=${SMTP_PORT:-1025}
ENABLE_AUTO_UPDATE=${ENABLE_AUTO_UPDATE}
GITHUB_REPO=${GITHUB_REPO}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
ENVEOF
}

create_docker_compose() {
    cat > docker-compose.yml << 'DOCKEREOF'
services:
  nginx:
    image: nginx:alpine
    container_name: epub-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./static:/usr/share/nginx/html/static:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - translator-network
    restart: unless-stopped
  backend:
    build: ./backend
    container_name: epub-backend
    volumes:
      - ./backend:/app
      - epub_uploads:/app/uploads
      - epub_output:/app/output
      - ./logs/backend:/app/logs
      - ./book_database:/app/book_database
      - ./translation_memory:/app/translation_memory
      - ./glossaries:/app/glossaries
      - ./community_library:/app/community_library
      - ./achievements:/app/achievements
      - ./fine_tuning:/app/fine_tuning
      - ./optimization_profiles:/app/optimization_profiles
    environment:
      - DATABASE_URL=postgresql://epub_user:epub_password@postgres:5432/epub_translator
      - OLLAMA_HOST=http://ollama:11434
      - REDIS_URL=redis://redis:6379/0
      - SECRET_KEY=${SECRET_KEY}
      - SELECTED_MODEL=${SELECTED_MODEL}
      - MAX_WORKERS=${MAX_WORKERS}
      - VERSION=${VERSION}
      - ENABLE_AUTO_OPTIMIZE=${ENABLE_AUTO_OPTIMIZE}
      - ENABLE_RESOURCE_MONITOR=${ENABLE_RESOURCE_MONITOR}
      - ENABLE_SMART_SWITCH=${ENABLE_SMART_SWITCH}
    depends_on:
      postgres:
        condition: service_healthy
      ollama:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - translator-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 30s
    command: gunicorn -w 2 -b 0.0.0.0:5000 app:app --timeout 600 --worker-class eventlet
  postgres:
    image: postgres:15-alpine
    container_name: epub-postgres
    environment:
      - POSTGRES_DB=epub_translator
      - POSTGRES_USER=epub_user
      - POSTGRES_PASSWORD=epub_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    networks:
      - translator-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U epub_user -d epub_translator"]
      interval: 10s
      timeout: 5s
      retries: 5
  ollama:
    build: ./ollama
    container_name: epub-ollama
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_KEEP_ALIVE=24h
      - OLLAMA_HOST=0.0.0.0
      - OLLAMA_NUM_PARALLEL=2
    networks:
      - translator-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: ${OPTIMAL_MEMORY_LIMIT}
        reservations:
          memory: 16G
    healthcheck:
      test: ["CMD", "/healthcheck.sh"]
      interval: 10s
      timeout: 5s
      retries: 5
    command: serve
  redis:
    image: redis:alpine
    container_name: epub-redis
    volumes:
      - redis_data:/data
    command: redis-server --maxmemory ${OPTIMAL_REDIS} --maxmemory-policy allkeys-lru
    networks:
      - translator-network
    restart: unless-stopped
  mailhog:
    image: mailhog/mailhog:latest
    container_name: epub-mailhog
    ports:
      - "1025:1025"
      - "8025:8025"
    networks:
      - translator-network
    restart: unless-stopped
    profiles:
      - local
      - all
networks:
  translator-network:
    driver: bridge
volumes:
  postgres_data:
  ollama_data:
  redis_data:
  epub_uploads:
  epub_output:
DOCKEREOF
}

create_nginx_config() {
    cat > nginx/nginx.conf << 'NGINXEOF'
events { worker_connections 1024; }
http {
    client_max_body_size 200M;
    server {
        listen 80;
        location /health { return 200 "OK"; }
        location /api/ { proxy_pass http://backend:5000; }
        location /static { alias /usr/share/nginx/html/static; expires 30d; }
        location / { proxy_pass http://backend:5000; proxy_set_header Host $host; }
    }
}
NGINXEOF
}

create_ollama_files() {
    mkdir -p ollama
    echo 'FROM ollama/ollama:latest' > ollama/Dockerfile
    echo 'RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*' >> ollama/Dockerfile
    echo 'COPY healthcheck.sh /healthcheck.sh' >> ollama/Dockerfile
    echo 'RUN chmod +x /healthcheck.sh' >> ollama/Dockerfile
    echo '#!/bin/bash' > ollama/healthcheck.sh
    echo 'curl -f http://localhost:11434/api/tags 2>/dev/null || exit 1' >> ollama/healthcheck.sh
    chmod +x ollama/healthcheck.sh
}

create_backend_files() {
    mkdir -p backend/utils backend/templates backend/translations
    
    cat > backend/Dockerfile << 'BACKENDEOF'
FROM python:3.10-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc libxml2-dev libxslt-dev curl git tesseract-ocr espeak ffmpeg && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app", "--timeout", "600", "--worker-class", "eventlet"]
BACKENDEOF

    cat > backend/requirements.txt << 'REQEOF'
Flask==2.3.3
Flask-SQLAlchemy==3.0.5
Flask-Login==0.6.2
Flask-Mail==0.9.1
Flask-Babel==3.0.0
Flask-SocketIO==5.3.4
Flask-Limiter==3.5.0
Flask-CORS==4.0.0
Flask-Dance==7.0.0
SQLAlchemy==2.0.20
psycopg2-binary==2.9.7
gunicorn==21.2.0
eventlet==0.33.3
Werkzeug==2.3.7
EbookLib==0.18
beautifulsoup4==4.12.2
lxml==4.9.3
requests==2.31.0
python-dotenv==1.0.0
redis==4.6.0
Pillow==10.0.0
GitPython==3.1.40
packaging==23.2
pytesseract==0.3.10
SpeechRecognition==3.10.0
psutil==5.9.5
REQEOF

    cat > backend/config.py << 'CONFIGEOF'
import os
from dotenv import load_dotenv
load_dotenv()

class Config:
    VERSION = os.environ.get('VERSION', '11.0.0')
    CODENAME = os.environ.get('CODENAME', 'Smart Optimizer')
    RELEASE_DATE = os.environ.get('RELEASE_DATE', '2025-07-17')
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://localhost:11434')
    DEFAULT_MODEL = os.environ.get('SELECTED_MODEL', 'deepseek-r1:14b')
    RECOMMENDED_MODEL = os.environ.get('RECOMMENDED_MODEL', 'deepseek-r1:14b')
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    BATCH_SIZE = int(os.environ.get('BATCH_SIZE', 5))
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    ENABLE_AUTO_OPTIMIZE = os.environ.get('ENABLE_AUTO_OPTIMIZE', 'i').lower() == 'i'
    ENABLE_RESOURCE_MONITOR = os.environ.get('ENABLE_RESOURCE_MONITOR', 'i').lower() == 'i'
    ENABLE_SMART_SWITCH = os.environ.get('ENABLE_SMART_SWITCH', 'i').lower() == 'i'
    ENABLE_AI_ASSISTANT = os.environ.get('ENABLE_AI_ASSISTANT', 'i').lower() == 'i'
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
    OPTIMAL_MEMORY_LIMIT = os.environ.get('OPTIMAL_MEMORY_LIMIT', '24G')
    OPTIMAL_REDIS = os.environ.get('OPTIMAL_REDIS', '512mb')
    OPTIMAL_PG_BUFFERS = os.environ.get('OPTIMAL_PG_BUFFERS', '512MB')
CONFIGEOF

    cat > backend/models.py << 'MODELSEOF'
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
import json
db = SQLAlchemy()

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255))
    first_name = db.Column(db.String(80))
    last_name = db.Column(db.String(80))
    internal_email = db.Column(db.String(120), unique=True)
    tokens = db.Column(db.Integer, default=5)
    is_admin = db.Column(db.Boolean, default=False)
    language = db.Column(db.String(5), default='hu')
    dark_mode = db.Column(db.Boolean, default=True)
    points = db.Column(db.Integer, default=0)
    level = db.Column(db.Integer, default=1)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Translation(db.Model):
    __tablename__ = 'translations'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    original_filename = db.Column(db.String(255))
    output_filename = db.Column(db.String(255))
    status = db.Column(db.String(50), default='pending')
    progress = db.Column(db.Integer, default=0)
    model_used = db.Column(db.String(100))
    quality_score = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class SystemSettings(db.Model):
    __tablename__ = 'system_settings'
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), unique=True)
    value = db.Column(db.Text)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class OptimizationLog(db.Model):
    __tablename__ = 'optimization_logs'
    id = db.Column(db.Integer, primary_key=True)
    model = db.Column(db.String(100))
    action = db.Column(db.String(50))
    details = db.Column(db.Text)
    performance_before = db.Column(db.Text)
    performance_after = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
MODELSEOF

    cat > backend/app.py << 'APPEOF'
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_babel import Babel, gettext as _
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, SystemSettings, OptimizationLog
from datetime import datetime
from functools import wraps
import os, json, psutil, requests

app = Flask(__name__)
app.config.from_object(Config)
db.init_app(app)
babel = Babel(app)

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
limiter = Limiter(app=app, key_func=get_remote_address, default_limits=["200 per day", "50 per hour"])

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not current_user.is_authenticated or not current_user.is_admin:
            flash(_('Admin jogosultság szükséges!'), 'error')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'version': app.config['VERSION'],
        'codename': app.config['CODENAME'],
        'release_date': app.config['RELEASE_DATE'],
        'model': app.config['DEFAULT_MODEL'],
        'memory': f"{psutil.virtual_memory().percent}%",
        'cpu': f"{psutil.cpu_percent()}%"
    })

@app.route('/')
def index():
    return redirect(url_for('dashboard') if current_user.is_authenticated else url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        user = User.query.filter_by(email=email).first()
        if user and user.password_hash and check_password_hash(user.password_hash, password):
            login_user(user)
            return redirect(url_for('admin') if user.is_admin else url_for('dashboard'))
        flash(_('Hibás email vagy jelszó!'), 'error')
    return render_template('login.html')

@app.route('/dashboard')
@login_required
def dashboard():
    translations = Translation.query.filter_by(user_id=current_user.id).order_by(Translation.created_at.desc()).limit(20).all()
    return render_template('dashboard.html', user=current_user, translations=translations)

@app.route('/admin')
@login_required
@admin_required
def admin():
    # Rendszer információk
    sys_info = {
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent,
        'memory_used_gb': round(psutil.virtual_memory().used / (1024**3), 2),
        'memory_total_gb': round(psutil.virtual_memory().total / (1024**3), 2),
        'disk_percent': psutil.disk_usage('/').percent,
        'disk_free_gb': round(psutil.disk_usage('/').free / (1024**3), 2)
    }
    
    # Modell információk
    try:
        resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/tags", timeout=5)
        models = resp.json().get('models', []) if resp.status_code == 200 else []
    except:
        models = []
    
    return render_template('admin.html', sys_info=sys_info, models=models, current_model=app.config['DEFAULT_MODEL'])

@app.route('/api/models/switch', methods=['POST'])
@login_required
@admin_required
def switch_model():
    data = request.get_json()
    model_name = data.get('model')
    auto_optimize = data.get('auto_optimize', app.config['ENABLE_AUTO_OPTIMIZE'])
    
    if not model_name:
        return jsonify({'error': 'Modell név szükséges'}), 400
    
    try:
        # Modell váltás
        from utils.model_optimizer import ModelOptimizer
        optimizer = ModelOptimizer(app)
        
        # Optimalizálás ha kérték
        opt_result = None
        if auto_optimize:
            opt_result = optimizer.optimize_for_model(model_name)
        
        # Naplózás
        log = OptimizationLog(
            model=model_name,
            action='switch',
            details=json.dumps({'auto_optimize': auto_optimize}),
            performance_before=json.dumps({
                'cpu': psutil.cpu_percent(),
                'memory': psutil.virtual_memory().percent
            })
        )
        db.session.add(log)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': f'Modell átváltva: {model_name}',
            'optimization': opt_result
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/system/monitor')
@login_required
@admin_required
def system_monitor():
    if not app.config['ENABLE_RESOURCE_MONITOR']:
        return jsonify({'error': 'Monitor le van tiltva'}), 403
    
    return jsonify({
        'cpu': {
            'percent': psutil.cpu_percent(),
            'cores': psutil.cpu_count(),
            'frequency': psutil.cpu_freq().current if psutil.cpu_freq() else 0
        },
        'memory': {
            'total_gb': round(psutil.virtual_memory().total / (1024**3), 2),
            'used_gb': round(psutil.virtual_memory().used / (1024**3), 2),
            'available_gb': round(psutil.virtual_memory().available / (1024**3), 2),
            'percent': psutil.virtual_memory().percent
        },
        'disk': {
            'total_gb': round(psutil.disk_usage('/').total / (1024**3), 2),
            'used_gb': round(psutil.disk_usage('/').used / (1024**3), 2),
            'free_gb': round(psutil.disk_usage('/').free / (1024**3), 2),
            'percent': psutil.disk_usage('/').percent
        },
        'swap': {
            'total_gb': round(psutil.swap_memory().total / (1024**3), 2),
            'used_gb': round(psutil.swap_memory().used / (1024**3), 2),
            'percent': psutil.swap_memory().percent
        },
        'network': {
            'bytes_sent': psutil.net_io_counters().bytes_sent,
            'bytes_recv': psutil.net_io_counters().bytes_recv
        },
        'uptime': datetime.utcnow().isoformat()
    })

@app.route('/api/models/recommend')
@login_required
@admin_required
def recommend_model():
    if not app.config['ENABLE_SMART_SWITCH']:
        return jsonify({'error': 'Intelligens váltás le van tiltva'}), 403
    
    total_ram = psutil.virtual_memory().total / (1024**3)
    free_ram = psutil.virtual_memory().available / (1024**3)
    
    if total_ram >= 64 and free_ram > 50:
        recommended = 'deepseek-r1:32b'
    elif total_ram >= 32 and free_ram > 20:
        recommended = 'deepseek-r1:14b'
    elif total_ram >= 16 and free_ram > 10:
        recommended = 'deepseek-r1:8b'
    elif total_ram >= 8:
        recommended = 'deepseek-r1:7b'
    else:
        recommended = 'deepseek-r1:1.5b'
    
    return jsonify({
        'recommended': recommended,
        'current': app.config['DEFAULT_MODEL'],
        'should_switch': recommended != app.config['DEFAULT_MODEL'],
        'system_info': {
            'total_ram_gb': round(total_ram, 1),
            'free_ram_gb': round(free_ram, 1)
        }
    })

def init_db():
    with app.app_context():
        db.create_all()
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL, password_hash=generate_password_hash(Config.ADMIN_PASSWORD), first_name='Admin', last_name='User', is_admin=True, tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin); db.session.commit()

if __name__ == '__main__':
    init_db()
    app.run(debug=False, host='0.0.0.0', port=5000)
APPEOF

    touch backend/utils/__init__.py
    
    # Dashboard HTML
    cat > backend/templates/dashboard.html << 'DASHEOF'
{% extends "base.html" %}{% block title %}Vezérlőpult{% endblock %}{% block content %}
<h2>Üdvözlünk, {{ user.first_name }}! 🧠</h2>
<div class="row mt-4">
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ user.tokens }}</h1><p>💰 Token</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ user.points }}</h1><p>🏆 Pontok</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ user.level }}</h1><p>⭐ Szint</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ translations|length }}</h1><p>📚 Fordítás</p></div></div></div>
</div>
{% endblock %}
DASHEOF

    # Login HTML
    cat > backend/templates/login.html << 'LOGINEOF'
{% extends "base.html" %}{% block title %}Bejelentkezés{% endblock %}{% block content %}
<div class="row justify-content-center mt-5"><div class="col-md-4"><div class="card"><div class="card-header bg-primary text-white"><h3 class="text-center">Bejelentkezés</h3></div><div class="card-body"><form method="POST"><div class="mb-3"><label>Email</label><input type="email" class="form-control" name="email" required></div><div class="mb-3"><label>Jelszó</label><input type="password" class="form-control" name="password" required></div><button type="submit" class="btn btn-primary w-100">Bejelentkezés</button></form></div></div></div></div>
{% endblock %}
LOGINEOF
}

create_model_optimizer() {
    cat > backend/utils/model_optimizer.py << 'OPTEOF'
"""Automatikus Modell Optimalizáló"""
import os, json, requests, subprocess, psutil
from datetime import datetime
from models import db, SystemSettings, OptimizationLog

class ModelOptimizer:
    MODEL_CONFIGS = {
        'deepseek-r1:1.5b': {'max_workers': 4, 'batch_size': 8, 'memory_limit': '4G', 'num_parallel': 4, 'max_loaded_models': 2, 'redis_maxmemory': '128mb', 'pg_buffers': '128MB', 'description': 'Teszteléshez'},
        'deepseek-r1:7b': {'max_workers': 3, 'batch_size': 6, 'memory_limit': '12G', 'num_parallel': 3, 'max_loaded_models': 2, 'redis_maxmemory': '256mb', 'pg_buffers': '256MB', 'description': '16GB RAM-hoz'},
        'deepseek-r1:8b': {'max_workers': 3, 'batch_size': 5, 'memory_limit': '16G', 'num_parallel': 2, 'max_loaded_models': 1, 'redis_maxmemory': '512mb', 'pg_buffers': '512MB', 'description': 'Általános használatra'},
        'deepseek-r1:14b': {'max_workers': 3, 'batch_size': 5, 'memory_limit': '24G', 'num_parallel': 2, 'max_loaded_models': 1, 'redis_maxmemory': '512mb', 'pg_buffers': '512MB', 'description': 'Jobb minőség'},
        'deepseek-r1:32b': {'max_workers': 1, 'batch_size': 2, 'memory_limit': '30G', 'num_parallel': 1, 'max_loaded_models': 1, 'redis_maxmemory': '256mb', 'pg_buffers': '256MB', 'description': 'Max minőség'},
        'deepseek-r1:70b': {'max_workers': 1, 'batch_size': 1, 'memory_limit': '60G', 'num_parallel': 1, 'max_loaded_models': 1, 'redis_maxmemory': '128mb', 'pg_buffers': '128MB', 'description': 'Professzionális'}
    }
    
    def __init__(self, app=None):
        self.app = app
        self.ollama_host = app.config.get('OLLAMA_HOST', 'http://localhost:11434') if app else 'http://localhost:11434'
    
    def optimize_for_model(self, model_name):
        config = self.MODEL_CONFIGS.get(model_name)
        if not config:
            return {'success': False, 'error': f'Ismeretlen modell: {model_name}'}
        
        results = {'model': model_name, 'config': config, 'steps': []}
        
        # Környezeti változók frissítése
        if self.app:
            self.app.config['MAX_WORKERS'] = config['max_workers']
            self.app.config['BATCH_SIZE'] = config['batch_size']
        results['steps'].append({'step': 'env', 'success': True})
        
        # Redis optimalizálás
        try:
            import redis
            r = redis.Redis(host='redis', port=6379, decode_responses=True)
            r.config_set('maxmemory', config['redis_maxmemory'])
            results['steps'].append({'step': 'redis', 'success': True})
        except:
            results['steps'].append({'step': 'redis', 'success': False})
        
        # Naplózás
        try:
            log = OptimizationLog(model=model_name, action='optimize', details=json.dumps(config), created_at=datetime.utcnow())
            db.session.add(log); db.session.commit()
        except:
            pass
        
        return results
    
    def get_recommended_model(self):
        total_ram = psutil.virtual_memory().total / (1024**3)
        free_ram = psutil.virtual_memory().available / (1024**3)
        if total_ram >= 64 and free_ram > 50: return 'deepseek-r1:32b'
        elif total_ram >= 32 and free_ram > 20: return 'deepseek-r1:14b'
        elif total_ram >= 16 and free_ram > 10: return 'deepseek-r1:8b'
        elif total_ram >= 8: return 'deepseek-r1:7b'
        return 'deepseek-r1:1.5b'
OPTEOF
}

create_resource_monitor() {
    cat > backend/utils/resource_monitor.py << 'MONEOF'
"""Valós Idejű Erőforrás Figyelő"""
import psutil
import time
from datetime import datetime

class ResourceMonitor:
    def __init__(self):
        self.history = []
    
    def get_current_stats(self):
        return {
            'timestamp': datetime.utcnow().isoformat(),
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'memory_used_gb': round(psutil.virtual_memory().used / (1024**3), 2),
            'memory_total_gb': round(psutil.virtual_memory().total / (1024**3), 2),
            'memory_available_gb': round(psutil.virtual_memory().available / (1024**3), 2),
            'disk_percent': psutil.disk_usage('/').percent,
            'disk_free_gb': round(psutil.disk_usage('/').free / (1024**3), 2),
            'swap_percent': psutil.swap_memory().percent,
            'network_sent_mb': round(psutil.net_io_counters().bytes_sent / (1024**2), 2),
            'network_recv_mb': round(psutil.net_io_counters().bytes_recv / (1024**2), 2)
        }
    
    def collect_metrics(self, duration_seconds=60, interval_seconds=5):
        metrics = []
        for _ in range(duration_seconds // interval_seconds):
            metrics.append(self.get_current_stats())
            time.sleep(interval_seconds)
        self.history.extend(metrics)
        return metrics
    
    def get_average(self):
        if not self.history:
            return self.get_current_stats()
        return {
            'cpu_percent': sum(m['cpu_percent'] for m in self.history) / len(self.history),
            'memory_percent': sum(m['memory_percent'] for m in self.history) / len(self.history)
        }
    
    def is_resource_available(self, required_ram_gb=16):
        available = psutil.virtual_memory().available / (1024**3)
        return available >= required_ram_gb
MONEOF
}

create_pwa_files() {
    mkdir -p static/icons
    cat > static/manifest.json << 'MANIFESTEOF'
{"name":"EPUB Fordító v11.0","short_name":"EPUB Fordító","start_url":"/","display":"standalone","background_color":"#1a1a2e","theme_color":"#16213e","icons":[{"src":"/static/icons/icon-192x192.png","sizes":"192x192","type":"image/png"},{"src":"/static/icons/icon-512x512.png","sizes":"512x512","type":"image/png"}]}
MANIFESTEOF
    cat > static/js/sw.js << 'SWEOF'
const CACHE='epub-v11';self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(['/','/offline.html']))).then(()=>self.skipWaiting())});self.addEventListener('fetch',e=>{e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request)))});
SWEOF
}

create_scripts() {
    cat > scripts/backup.sh << 'BACKUPEOF'
#!/bin/bash
D=$(date +%Y%m%d_%H%M%S);mkdir -p ~/epub-backups
docker exec epub-postgres pg_dump -U epub_user epub_translator > ~/epub-backups/db_$D.sql 2>/dev/null
[ -d ~/epub-translator/community_library ] && tar -czf ~/epub-backups/community_$D.tar.gz -C ~/epub-translator community_library/ 2>/dev/null
echo "✅ ~/epub-backups/db_$D.sql"
BACKUPEOF

    cat > scripts/update.sh << 'UPDATEEOF'
#!/bin/bash
cd ~/epub-translator&&docker compose down&&git pull 2>/dev/null&&docker compose build&&docker compose up -d&&echo "✅ Frissítve!"
UPDATEEOF

    cat > scripts/status.sh << 'STATUSEOF'
#!/bin/bash
echo "EPUB Fordító v11.0 Smart Optimizer"
docker compose ps
echo "Web: http://localhost | Email: http://localhost:8025"
echo "Rendszer: CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')% | RAM: $(free -h | awk '/^Mem:/{print $3"/"$2}')"
STATUSEOF

    cat > scripts/monitor.sh << 'MONITOREOF'
#!/bin/bash
LOG=~/epub-translator/logs/resource_monitor.log
echo "$(date): CPU:$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')% RAM:$(free -h | awk '/^Mem:/{print $3"/"$2}') Disk:$(df -h / | awk 'NR==2{print $5}')" >> "$LOG"
MONITOREOF

    cat > scripts/optimize.sh << 'OPTIMIZEEOF'
#!/bin/bash
echo "🧠 EPUB Fordító - Optimalizálás"
cd ~/epub-translator
curl -X POST http://localhost/api/models/recommend 2>/dev/null
echo ""
echo "Javasolt modell váltás az admin felületen: http://localhost/admin"
OPTIMIZEEOF

    chmod +x scripts/*.sh
}

# ============================================================
# ÖSSZEGZÉS
# ============================================================
show_summary() {
    clear
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════════╗"
    [ "$IS_UPDATE" = true ] && log_header "║   ✅ Frissítve: ${EXISTING_VERSION} → v${VERSION}                          ║" || log_header "║   🎉 EPUB Fordító v${VERSION} - Telepítve! 🎉                      ║"
    log_header "║   \"${CODENAME}\"                            ║"
    log_header "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🌐 Web:        http://localhost"
    echo "📧 Email:      http://localhost:8025"
    echo "📊 Monitor:    http://localhost/admin (rendszer infók)"
    echo ""
    echo "🆕 v11.0 Újdonságok:"
    echo "   🧠 Automatikus modell optimalizálás"
    echo "   📊 Valós idejű erőforrás figyelés"
    echo "   🔄 Intelligens modellváltás (auto-optimize)"
    echo "   💾 Dinamikus memória kezelés"
    echo "   ⚡ Hardver alapú auto-konfiguráció"
    echo ""
    echo "🤖 Ajánlott modell: ${RECOMMENDED_MODEL}"
    echo "🧵 Optimális szálak: ${OPTIMAL_WORKERS}"
    echo "💾 Memória limit: ${OPTIMAL_MEMORY_LIMIT}"
    echo ""
    echo "👤 Admin: ${ADMIN_EMAIL} | 🔑 ${ADMIN_PASSWORD}"
    echo ""
    echo "📋 Parancsok:"
    echo "   Frissítés:     ./scripts/update.sh"
    echo "   Optimalizálás: ./scripts/optimize.sh"
    echo "   Monitor:       ./scripts/monitor.sh"
    echo "   Backup:        ./scripts/backup.sh"
    echo "   Státusz:       ./scripts/status.sh"
    echo ""
    log_success "Kész! 🚀🧠"
}

# ============================================================
# MAIN
# ============================================================
main() {
    # Docker parancs elérésének meghatározása
    if docker ps &>/dev/null 2>&1; then
        DOCKER="docker"
    elif sudo docker ps &>/dev/null 2>&1; then
        DOCKER="sudo docker"
    else
        DOCKER="docker"  # még nincs telepítve, a perform_fresh_install beállítja
    fi

    detect_installation_mode
    analyze_and_optimize
    
    if [ "${OPTIMIZE_ONLY:-false}" = true ]; then
        perform_optimization_only
        show_summary
        exit 0
    fi
    
    configure_system
    
    if [ "$IS_UPDATE" = true ]; then
        perform_update
    else
        perform_fresh_install
    fi
    
    show_summary
}

main "$@"