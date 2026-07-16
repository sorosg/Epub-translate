    #!/bin/bash

# EPUB Fordító Rendszer - Telepítő/Frissítő Script v11.0
# Verzió: 11.0.24
# Kódnév: "Smart Optimizer"
# Dátum: 2026-07-16
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
VERSION="11.0.30"
CODENAME="Smart Optimizer"
RELEASE_DATE="2026-07-16"
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
    
    if [ -d "$PROJECT_DIR" ] && { [ -f "$PROJECT_DIR/.install_config" ] || [ -f "$PROJECT_DIR/docker-compose.yml" ]; }; then
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
    log_info "Backend újraépítése (cache nélkül a friss fájlokért)..."
    $DOCKER compose build --no-cache backend 2>/dev/null || $DOCKER compose build backend
    log_info "Többi konténer építése..."
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
    
    # Port detektálás és beállítás
    HTTP_PORT=80
    HTTPS_PORT=443
    
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
        if sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq curl wget git ca-certificates gnupg nano htop net-tools ufw build-essential python3-pip python3-venv libxml2-dev libxslt-dev redis-tools postgresql-client cron clamav postfix mailutils poppler-utils ffmpeg nginx openssl tesseract-ocr tesseract-ocr-hun tesseract-ocr-eng espeak mpg321 2>/dev/null; then
            break
        fi
        log_warn "Az apt install zárolva van, várakozás... ($i/5)"
        sleep 10
    done
    pip3 install pytesseract SpeechRecognition pyaudio pyttsx3 psutil 2>/dev/null || true
    
    if ! docker ps &>/dev/null 2>&1; then
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
        fi
        DOCKER="sudo docker"
    fi
    
    # Korábbi konténerek leállítása és port felszabadítás
    log_info "Korábbi konténerek leállítása..."
    set +e
    $DOCKER compose down --remove-orphans 2>/dev/null || true
    $DOCKER rm -f epub-nginx epub-backend epub-postgres epub-ollama epub-redis epub-mailhog 2>/dev/null || true
    # Host webszerverek leállítása és letiltása (hogy ne induljanak újra)
    sudo systemctl stop nginx 2>/dev/null || true
    sudo systemctl stop apache2 2>/dev/null || true
    sudo systemctl disable nginx 2>/dev/null || true
    sudo systemctl disable apache2 2>/dev/null || true
    # Portok felszabadítása
    sudo fuser -k 80/tcp 2>/dev/null || true
    sudo fuser -k 443/tcp 2>/dev/null || true
    sleep 5
    # Még egyszer, ha a folyamat azonnal újraindult
    sudo fuser -k 80/tcp 2>/dev/null || true
    sudo fuser -k 443/tcp 2>/dev/null || true
    sleep 2
    # Ha a 80-as port még mindig foglalt, alternatív port használata
    if sudo fuser 80/tcp 2>/dev/null; then
        log_warn "A 80-as port továbbra is foglalt, alternatív port használata: 8080"
        HTTP_PORT=8080
        HTTPS_PORT=8443
        sed -i 's/"80:80"/"8080:80"/' docker-compose.yml
        sed -i 's/"443:443"/"8443:443"/' docker-compose.yml
        log_info "Portok átállítva a docker-compose.yml-ben"
        log_info "Ellenőrzés:"
        grep -n '8080:80\|8443:443' docker-compose.yml || log_warn "A portcsere nem sikerült, a 80-as porttal próbálkozunk"
    fi
    set -e
    
    $DOCKER compose build 2>/dev/null || $DOCKER compose build --no-cache
    $DOCKER compose up -d
    sleep 10
    
    # Modell letöltés háttérben (nem blokkoljuk a telepítést)
    log_info "AI modell letöltése háttérben: $SELECTED_MODEL"
    $DOCKER exec -d epub-ollama ollama pull "$SELECTED_MODEL" 2>/dev/null || log_warn "Modell letöltés figyelmeztetés (háttérben fut, akár 30-60 perc is lehet)"
    log_info "A modell letöltése a háttérben zajlik. A webes felület azonnal elérhető."
    log_info "Amíg a modell töltődik, a fordítás nem fog működni."
    sleep 5
    $DOCKER exec -i epub-backend python3 -c "from app import app, init_db; app.app_context().push(); init_db(); print('OK')" 2>/dev/null || log_warn "DB figyelmeztetés"
    
    [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && [ -n "$GITHUB_REPO" ] && $DOCKER exec -i epub-backend python3 -c "from app import app, db; from models import UpdateChannel; app.app_context().push(); c=UpdateChannel.query.filter_by(name='stable').first() or UpdateChannel(name='stable',github_repo='${GITHUB_REPO}',github_branch='${GITHUB_BRANCH:-main}',github_token='${GITHUB_TOKEN}' if '${GITHUB_TOKEN}' else None,auto_check=True); db.session.add(c); db.session.commit()" 2>/dev/null || true
    
    if command -v crontab &>/dev/null; then
        (crontab -l 2>/dev/null; echo "0 3 * * 0 $PROJECT_DIR/scripts/backup.sh") | crontab - 2>/dev/null || true
        (crontab -l 2>/dev/null; echo "0 4 * * 0 docker system prune -f") | crontab - 2>/dev/null || true
        (crontab -l 2>/dev/null; echo "*/30 * * * * $PROJECT_DIR/scripts/monitor.sh") | crontab - 2>/dev/null || true
        log_info "Cron jobok beállítva"
    else
        log_warn "A 'crontab' parancs nem elérhető, cron jobok kihagyva"
    fi
    
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
    
    # Git repo inicializálása a frissítésekhez (ha még nincs)
    if [ ! -d .git ]; then
        git init . 2>/dev/null || true
        git remote add origin "$GITHUB_REPO" 2>/dev/null || true
        git fetch origin 2>/dev/null || true
        log_info "Git repo inicializálva a frissítésekhez"
    fi
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
    log_info "Fájlok másolása a forrás könyvtárból..."
    SRC_DIR="${SCRIPT_DIR}/src"
    
    # Ha a src könyvtár nem létezik (pl. régi install.sh), használjuk a heredoc-generálást
    if [ ! -d "$SRC_DIR" ]; then
        log_warn "A src/ könyvtár nem található, fájlok generálása a scriptből..."
        _create_files_from_script
        return
    fi
    
    # docker-compose.yml másolása
    cp "$SRC_DIR/docker-compose.yml" docker-compose.yml
    
    # nginx config
    mkdir -p nginx
    cp "$SRC_DIR/nginx/nginx.conf" nginx/nginx.conf
    
    # ollama fájlok
    mkdir -p ollama
    cp "$SRC_DIR/ollama/Dockerfile" ollama/Dockerfile
    cp "$SRC_DIR/ollama/healthcheck.sh" ollama/healthcheck.sh
    chmod +x ollama/healthcheck.sh
    
    # backend fájlok
    mkdir -p backend/utils backend/templates backend/translations
    cp "$SRC_DIR/backend/Dockerfile" backend/Dockerfile
    cp "$SRC_DIR/backend/requirements.txt" backend/requirements.txt
    cp "$SRC_DIR/backend/config.py" backend/config.py
    cp "$SRC_DIR/backend/models.py" backend/models.py
    cp "$SRC_DIR/backend/app.py" backend/app.py
    
    # backend template-ek
    cp "$SRC_DIR/backend/templates/base.html" backend/templates/base.html 2>/dev/null || true
    cp "$SRC_DIR/backend/templates/login.html" backend/templates/login.html 2>/dev/null || true
    cp "$SRC_DIR/backend/templates/dashboard.html" backend/templates/dashboard.html 2>/dev/null || true
    cp "$SRC_DIR/backend/templates/admin.html" backend/templates/admin.html 2>/dev/null || true
    cp "$SRC_DIR/backend/templates/users.html" backend/templates/users.html 2>/dev/null || true
    cp "$SRC_DIR/backend/templates/users_form.html" backend/templates/users_form.html 2>/dev/null || true
    cp "$SRC_DIR/backend/templates/update.html" backend/templates/update.html 2>/dev/null || true
    
    # backend utils
    cp "$SRC_DIR/backend/utils/model_optimizer.py" backend/utils/model_optimizer.py 2>/dev/null || true
    cp "$SRC_DIR/backend/utils/resource_monitor.py" backend/utils/resource_monitor.py 2>/dev/null || true
    touch backend/utils/__init__.py
    
    create_env_file
    create_scripts
    
    log_success "Fájlok kész"
}

# Fallback: régi heredoc alapú fájlgenerálás (ha nincs src/)
_create_files_from_script() {
    create_env_file
    create_docker_compose
    create_nginx_config
    create_ollama_files
    create_backend_files
    create_model_optimizer
    create_resource_monitor
    create_pwa_files
    create_scripts
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
    dns:
      - 8.8.8.8
      - 1.1.1.1
    volumes:
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
        condition: service_started
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
      retries: 10
      start_period: 60s
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
    proxy_read_timeout 120s;
    proxy_connect_timeout 10s;
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
    VERSION = os.environ.get('VERSION', '11.0.30')
    CODENAME = os.environ.get('CODENAME', 'Smart Optimizer')
    RELEASE_DATE = os.environ.get('RELEASE_DATE', '2026-07-16')
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
    address = db.Column(db.String(255))
    birth_date = db.Column(db.String(20))
    tax_id = db.Column(db.String(50))
    phone = db.Column(db.String(30))
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

class ReferenceBook(db.Model):
    __tablename__ = 'reference_books'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    filename = db.Column(db.String(255))
    title = db.Column(db.String(255))
    language = db.Column(db.String(10), default='hu')
    file_path = db.Column(db.String(500))
    extracted_text = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
MODELSEOF

    cat > backend/app.py << 'APPEOF'
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, send_file, send_from_directory
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_babel import Babel, gettext as _
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, SystemSettings, OptimizationLog
from datetime import datetime
from functools import wraps
import os, json, psutil, requests, threading, uuid, shutil

app = Flask(__name__)
app.config.from_object(Config)
app.config['UPLOAD_FOLDER'] = '/app/uploads/books'
app.config['OUTPUT_FOLDER'] = '/app/output'
app.config['MAX_CONTENT_LENGTH'] = 200 * 1024 * 1024  # 200MB max
db.init_app(app)
def get_locale():
    return 'hu'

babel = Babel(app, locale_selector=get_locale)

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(app.config['OUTPUT_FOLDER'], exist_ok=True)

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
limiter = Limiter(app=app, key_func=get_remote_address, default_limits=["500 per day", "100 per hour"])

ALLOWED_EXTENSIONS = {'epub'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

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

import traceback as _traceback
@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('admin') if current_user.is_admin else url_for('dashboard'))
    if request.method == 'POST':
        try:
            email = request.form.get('email', '').strip()
            password = request.form.get('password', '')
            user = User.query.filter_by(email=email).first()
            if user and user.password_hash and check_password_hash(user.password_hash, password):
                login_user(user)
                return redirect(url_for('admin') if user.is_admin else url_for('dashboard'))
            flash(_('Hibás email vagy jelszó!'), 'error')
        except Exception as e:
            app.logger.error(f"Login error: {_traceback.format_exc()}")
            flash(_(f'Bejelentkezési hiba: {str(e)[:100]}'), 'error')
    return render_template('login.html')

@app.errorhandler(500)
def internal_server_error(e):
    app.logger.error(f"500 error: {_traceback.format_exc()}")
    return f"<h2>500 Internal Server Error</h2><pre>{_traceback.format_exc()}</pre>", 500


@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    translations = Translation.query.filter_by(user_id=current_user.id).order_by(Translation.created_at.desc()).all()
    return render_template('dashboard.html', user=current_user, translations=translations, Config=Config)

@app.route('/upload', methods=['POST'])
@login_required
def upload_epub():
    if 'file' not in request.files:
        flash(_('Nincs fájl kiválasztva!'), 'error')
        return redirect(url_for('dashboard'))
    file = request.files['file']
    if file.filename == '':
        flash(_('Nincs fájl kiválasztva!'), 'error')
        return redirect(url_for('dashboard'))
    if not allowed_file(file.filename):
        flash(_('Csak EPUB fájlok tölthetők fel!'), 'error')
        return redirect(url_for('dashboard'))
    if current_user.tokens <= 0:
        flash(_('Nincs elég tokened a fordításhoz!'), 'error')
        return redirect(url_for('dashboard'))
    
    filename = f"{uuid.uuid4().hex}_{secure_filename(file.filename)}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)
    
    translation = Translation(
        user_id=current_user.id,
        original_filename=file.filename,
        output_filename=None,
        status='pending',
        progress=0,
        model_used=app.config['DEFAULT_MODEL']
    )
    db.session.add(translation)
    current_user.tokens -= 1
    db.session.commit()
    
    # Fordítás indítása háttérszálban
    thread = threading.Thread(target=translate_epub, args=(app, translation.id, filepath))
    thread.daemon = True
    thread.start()
    
    flash(_('Fájl feltöltve, fordítás folyamatban...'), 'success')
    return redirect(url_for('dashboard'))

@app.route('/api/status/<int:translation_id>')
@login_required
def translation_status(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error': 'Nincs jogosultságod'}), 403
    return jsonify({
        'id': t.id,
        'status': t.status,
        'progress': t.progress,
        'original_filename': t.original_filename,
        'output_filename': t.output_filename
    })

@app.route('/download/<int:translation_id>')
@login_required
def download_translation(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        flash(_('Nincs jogosultságod'), 'error')
        return redirect(url_for('dashboard'))
    if t.status != 'completed' or not t.output_filename:
        flash(_('A fordítás még nem készült el'), 'error')
        return redirect(url_for('dashboard'))
    output_path = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
    if not os.path.exists(output_path):
        flash(_('A fájl nem található'), 'error')
        return redirect(url_for('dashboard'))
    return send_file(output_path, as_attachment=True, download_name=f"forditott_{t.original_filename}")

@app.route('/delete/<int:translation_id>', methods=['POST'])
@login_required
def delete_translation(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        flash(_('Nincs jogosultságod'), 'error')
        return redirect(url_for('dashboard'))
    if t.output_filename:
        out = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
        if os.path.exists(out): os.remove(out)
    db.session.delete(t)
    db.session.commit()
    flash(_('Fordítás törölve'), 'success')
    return redirect(url_for('dashboard'))

@app.route('/admin')
@login_required
@admin_required
def admin():
    sys_info = {
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent,
        'memory_used_gb': round(psutil.virtual_memory().used / (1024**3), 2),
        'memory_total_gb': round(psutil.virtual_memory().total / (1024**3), 2),
        'disk_percent': psutil.disk_usage('/').percent,
        'disk_free_gb': round(psutil.disk_usage('/').free / (1024**3), 2)
    }
    models = []
    for attempt in range(1, 4):
        try:
            resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/tags", timeout=10)
            if resp.status_code == 200:
                models = resp.json().get('models', [])
                if not models:
                    flash(_('Nincsenek modellek betöltve az Ollama-ban. Futtasd: docker exec -it epub-ollama ollama pull deepseek-r1:14b'), 'warning')
                break
        except Exception as e:
            if attempt == 3:
                flash(_(f'Nem sikerült lekérni az Ollama modelleket ({attempt}. próbálkozás): {str(e)[:80]}'), 'error')
            else:
                import time
                time.sleep(3)
    all_translations = Translation.query.order_by(Translation.created_at.desc()).limit(50).all()
    users_count = User.query.count()
    
    return render_template('admin.html', sys_info=sys_info, models=models, 
                          current_model=app.config['DEFAULT_MODEL'], 
                          translations=all_translations, users_count=users_count,
                          translations_count=Translation.query.count())

@app.route('/admin/users')
@login_required
@admin_required
def admin_users():
    users = User.query.order_by(User.created_at.desc()).all()
    return render_template('users.html', users=users)

@app.route('/admin/users/add', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_users_add():
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '').strip()
        tokens = request.form.get('tokens', '5').strip()
        if not email or not password:
            flash(_('Az email és a jelszó kötelező!'), 'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=False)
        if User.query.filter_by(email=email).first():
            flash(_('Ez az email cím már használatban van!'), 'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=False)
        user = User(
            username=email.split('@')[0],
            email=email,
            password_hash=generate_password_hash(password),
            first_name=request.form.get('first_name', '').strip(),
            last_name=request.form.get('last_name', '').strip(),
            address=request.form.get('address', '').strip(),
            birth_date=request.form.get('birth_date', '').strip(),
            tax_id=request.form.get('tax_id', '').strip(),
            phone=request.form.get('phone', '').strip(),
            tokens=int(tokens) if tokens.isdigit() else 5,
            is_admin=request.form.get('is_admin') == '1'
        )
        db.session.add(user)
        db.session.commit()
        flash(_('Felhasználó létrehozva!'), 'success')
        return redirect(url_for('admin_users'))
    return render_template('users_form.html', user_data={}, edit_mode=False)

@app.route('/admin/users/edit/<int:user_id>', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_users_edit(user_id):
    user = User.query.get_or_404(user_id)
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '').strip()
        tokens = request.form.get('tokens', str(user.tokens)).strip()
        existing = User.query.filter_by(email=email).first()
        if existing and existing.id != user.id:
            flash(_('Ez az email cím már használatban van!'), 'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=True, user=user)
        user.email = email
        user.first_name = request.form.get('first_name', '').strip()
        user.last_name = request.form.get('last_name', '').strip()
        user.address = request.form.get('address', '').strip()
        user.birth_date = request.form.get('birth_date', '').strip()
        user.tax_id = request.form.get('tax_id', '').strip()
        user.phone = request.form.get('phone', '').strip()
        user.tokens = int(tokens) if tokens.isdigit() else user.tokens
        user.is_admin = request.form.get('is_admin') == '1'
        if password:
            user.password_hash = generate_password_hash(password)
        db.session.commit()
        flash(_('Felhasználó módosítva!'), 'success')
        return redirect(url_for('admin_users'))
    return render_template('users_form.html', user_data={}, edit_mode=True, user=user)

@app.route('/admin/users/delete/<int:user_id>', methods=['POST'])
@login_required
@admin_required
def admin_users_delete(user_id):
    if user_id == current_user.id:
        flash(_('Saját magadat nem törölheted!'), 'error')
        return redirect(url_for('admin_users'))
    user = User.query.get_or_404(user_id)
    Translation.query.filter_by(user_id=user.id).delete()
    db.session.delete(user)
    db.session.commit()
    flash(_('Felhasználó törölve!'), 'success')
    return redirect(url_for('admin_users'))

@app.route('/api/models/switch', methods=['POST'])
@login_required
@admin_required
def switch_model():
    data = request.get_json()
    model_name = data.get('model')
    if not model_name:
        return jsonify({'error': 'Modell név szükséges'}), 400
    app.config['DEFAULT_MODEL'] = model_name
    log = OptimizationLog(model=model_name, action='switch', details=json.dumps({'switched_by': current_user.email}), created_at=datetime.utcnow())
    db.session.add(log); db.session.commit()
    return jsonify({'success': True, 'message': f'Modell átváltva: {model_name}'})

@app.route('/admin/update')
@login_required
@admin_required
def admin_update():
    return render_template('update.html', current_version=app.config['VERSION'])

@app.route('/api/update/check')
@login_required
@admin_required
def api_update_check():
    for attempt in range(1, 4):
        try:
            resp = requests.get('https://api.github.com/repos/sorosg/Epub-translate/releases/latest', 
                               headers={'Accept': 'application/vnd.github.v3+json'}, timeout=15)
            if resp.status_code == 200:
                data = resp.json()
                remote_version = data.get('tag_name', '').lstrip('v')
                has_update = remote_version > app.config['VERSION']
                return jsonify({
                    'remote_version': remote_version or 'ismeretlen',
                    'current': app.config['VERSION'],
                    'has_update': has_update,
                    'release_url': data.get('html_url', ''),
                    'release_notes': (data.get('body', '') or '')[:500]
                })
            return jsonify({'error': f'GitHub API hiba: {resp.status_code}'}), resp.status_code
        except Exception as e:
            if attempt == 3:
                return jsonify({
                    'error': 'Nem sikerült ellenőrizni a frissítéseket. Ellenőrizd az internetkapcsolatot.',
                    'current': app.config['VERSION'],
                    'has_update': False
                })
            import time
            time.sleep(3)

@app.route('/api/update/run', methods=['POST'])
@login_required
@admin_required
def api_update_run():
    import subprocess
    try:
        result = subprocess.run(['bash', '/app/../scripts/update.sh'], capture_output=True, text=True, timeout=600)
        log = OptimizationLog(model='system', action='update', 
                             details=json.dumps({'output': result.stdout[-500:], 'returncode': result.returncode}),
                             created_at=datetime.utcnow())
        db.session.add(log); db.session.commit()
        return jsonify({'success': result.returncode == 0, 'output': result.stdout[-500:]})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)[:200]}), 500

@app.route('/api/system/monitor')
@login_required
@admin_required
def system_monitor():
    return jsonify({
        'cpu': {'percent': psutil.cpu_percent(), 'cores': psutil.cpu_count()},
        'memory': {'total_gb': round(psutil.virtual_memory().total/(1024**3),2), 'used_gb': round(psutil.virtual_memory().used/(1024**3),2), 'percent': psutil.virtual_memory().percent},
        'disk': {'total_gb': round(psutil.disk_usage('/').total/(1024**3),2), 'free_gb': round(psutil.disk_usage('/').free/(1024**3),2), 'percent': psutil.disk_usage('/').percent},
        'uptime': datetime.utcnow().isoformat()
    })

def translate_epub(app_ref, translation_id, filepath):
    """EPUB fordítás Ollama API-val (háttérszálban fut)"""
    with app_ref.app_context():
        t = Translation.query.get(translation_id)
        if not t: return
        try:
            t.status = 'processing'
            t.progress = 5
            db.session.commit()

            # EPUB olvasása
            from ebooklib import epub
            from bs4 import BeautifulSoup
            
            book = epub.read_epub(filepath)
            model = app_ref.config['DEFAULT_MODEL']
            ollama_host = app_ref.config['OLLAMA_HOST']
            
            # Szövegek kinyerése és fordítása
            items = list(book.get_items_of_type(9))  # ITEM_DOCUMENT
            total = len(items)
            
            for idx, item in enumerate(items):
                soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                text = soup.get_text().strip()
                if not text or len(text) < 10:
                    continue

                # Ollama API hívás
                resp = requests.post(f"{ollama_host}/api/generate", json={
                    'model': model,
                    'prompt': f"Fordítsd le magyar nyelvre a következő szöveget. Csak a fordítást add vissza, semmi mást:\n\n{text[:3000]}",
                    'stream': False
                }, timeout=120)
                
                if resp.status_code == 200:
                    translated = resp.json().get('response', text)
                    new_tag = soup.new_tag('p')
                    new_tag.string = translated
                    soup.clear()
                    soup.append(new_tag)
                    item.set_content(str(soup).encode('utf-8'))
                
                t.progress = 5 + int(90 * (idx + 1) / total)
                db.session.commit()
            
            # EPUB mentése
            output_filename = f"translated_{uuid.uuid4().hex[:8]}.epub"
            output_path = os.path.join(app_ref.config['OUTPUT_FOLDER'], output_filename)
            epub.write_epub(output_path, book)
            
            t.output_filename = output_filename
            t.status = 'completed'
            t.progress = 100
            t.quality_score = 85
            db.session.commit()
            
        except Exception as e:
            t.status = 'failed'
            t.progress = 0
            t.output_filename = str(e)[:200]
            db.session.commit()
        finally:
            if os.path.exists(filepath):
                os.remove(filepath)

def init_db():
    with app.app_context():
        db.create_all()
        # Hiányzó oszlopok hozzáadása (ha a tábla már létezett korábbi verzióból)
        try:
            for col, col_type in [('address', 'VARCHAR(255)'), ('birth_date', 'VARCHAR(20)'), ('tax_id', 'VARCHAR(50)'), ('phone', 'VARCHAR(30)')]:
                db.session.execute(db.text(f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {col} {col_type}"))
            db.session.commit()
        except Exception as e:
            db.session.rollback()
        
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL,
                        password_hash=generate_password_hash(Config.ADMIN_PASSWORD),
                        first_name='Admin', last_name='User', is_admin=True,
                        tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin); db.session.commit()

# Adatbázis inicializálása az első kérés előtt
with app.app_context():
    try:
        init_db()
    except Exception as e:
        app.logger.error(f"DB init error: {e}")

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)
APPEOF

    touch backend/utils/__init__.py
    
    # Base HTML
    cat > backend/templates/base.html << 'BASEEOF'
<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{% block title %}EPUB Fordító{% endblock %}</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-dark text-light">
<nav class="navbar navbar-expand-lg navbar-dark bg-dark border-bottom border-secondary mb-4">
  <div class="container">
    <a class="navbar-brand" href="/">🧠 EPUB Fordító</a>
    <div class="navbar-nav ms-auto">
      {% if current_user.is_authenticated %}
        <a class="nav-link" href="/dashboard">Vezérlőpult</a>
        {% if current_user.is_admin %}<a class="nav-link" href="/admin">Admin</a><a class="nav-link" href="/admin/users">Felhasználók</a><a class="nav-link" href="/admin/update">Frissítés</a>{% endif %}
        <a class="nav-link" href="/logout">Kijelentkezés</a>
      {% endif %}
    </div>
  </div>
</nav>
<div class="container">
{% with messages = get_flashed_messages(with_categories=true) %}
  {% if messages %}
    {% for category, message in messages %}
      <div class="alert alert-{{ 'danger' if category == 'error' else category }}">{{ message }}</div>
    {% endfor %}
  {% endif %}
{% endwith %}
{% block content %}{% endblock %}
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
BASEEOF

    # Dashboard HTML
    cat > backend/templates/dashboard.html << 'DASHEOF'
{% extends "base.html" %}{% block title %}Vezérlőpult{% endblock %}{% block content %}
<h2>Üdvözlünk, {{ user.first_name }}! 🧠</h2>
<div class="row mt-3">
    <div class="col-md-3"><div class="card bg-primary text-white"><div class="card-body text-center"><h1>{{ user.tokens }}</h1><p>💰 Token</p></div></div></div>
    <div class="col-md-3"><div class="card bg-success text-white"><div class="card-body text-center"><h1>{{ user.points }}</h1><p>🏆 Pontok</p></div></div></div>
    <div class="col-md-3"><div class="card bg-warning text-dark"><div class="card-body text-center"><h1>{{ user.level }}</h1><p>⭐ Szint</p></div></div></div>
    <div class="col-md-3"><div class="card bg-info text-white"><div class="card-body text-center"><h1>{{ translations|length }}</h1><p>📚 Fordítás</p></div></div></div>
</div>

<div class="card mt-4">
  <div class="card-header"><h5>📤 Új EPUB feltöltése</h5></div>
  <div class="card-body">
    <form action="/upload" method="POST" enctype="multipart/form-data" class="row g-3">
      <div class="col-md-8">
        <input type="file" class="form-control" name="file" accept=".epub" required>
        <small class="text-muted">Maximum 200MB, EPUB formátum</small>
      </div>
      <div class="col-md-4">
        <button type="submit" class="btn btn-success w-100">⬆️ Feltöltés és fordítás</button>
      </div>
    </form>
  </div>
</div>

<div class="card mt-4">
  <div class="card-header"><h5>📋 Fordításaim</h5></div>
  <div class="card-body">
    {% if translations %}
    <table class="table table-dark table-striped">
      <thead><tr><th>Fájl</th><th>Modell</th><th>Státusz</th><th>Haladás</th><th>Dátum</th><th>Műveletek</th></tr></thead>
      <tbody>
      {% for t in translations %}
      <tr>
        <td>{{ t.original_filename }}</td>
        <td>{{ t.model_used }}</td>
        <td>
          {% if t.status == 'pending' %}<span class="badge bg-secondary">Várakozik</span>
          {% elif t.status == 'processing' %}<span class="badge bg-warning">Fordítás alatt</span>
          {% elif t.status == 'completed' %}<span class="badge bg-success">Kész</span>
          {% elif t.status == 'failed' %}<span class="badge bg-danger">Hiba</span>
          {% endif %}
        </td>
        <td>
          {% if t.status == 'processing' %}
          <div class="progress" style="height:20px"><div class="progress-bar progress-bar-striped progress-bar-animated" style="width:{{ t.progress }}%">{{ t.progress }}%</div></div>
          {% elif t.status == 'pending' %}
          <small class="text-muted">Sorban áll...</small>
          {% elif t.status == 'completed' %}
          <span class="text-success">✅ 100%</span>
          {% endif %}
        </td>
        <td><small>{{ t.created_at.strftime('%Y-%m-%d %H:%M') }}</small></td>
        <td>
          {% if t.status == 'completed' %}<a href="/download/{{ t.id }}" class="btn btn-sm btn-success">📥 Letöltés</a>{% endif %}
          <form action="/delete/{{ t.id }}" method="POST" style="display:inline">
            <button class="btn btn-sm btn-danger" onclick="return confirm('Biztosan törlöd?')">🗑️</button>
          </form>
        </td>
      </tr>
      {% endfor %}
      </tbody>
    </table>
    {% else %}
    <p class="text-muted text-center py-3">Még nincsenek fordításaid. Tölts fel egy EPUB fájlt a fordításhoz!</p>
    {% endif %}
  </div>
</div>

{% if translations|selectattr('status','equalto','processing')|list|length > 0 %}
<script>
// Automatikus frissítés ha van folyamatban lévő fordítás
setTimeout(function(){ location.reload(); }, 10000);
</script>
{% endif %}
{% endblock %}
DASHEOF

    # Login HTML
    cat > backend/templates/login.html << 'LOGINEOF'
{% extends "base.html" %}{% block title %}Bejelentkezés{% endblock %}{% block content %}
<div class="row justify-content-center mt-5"><div class="col-md-4"><div class="card"><div class="card-header bg-primary text-white"><h3 class="text-center">Bejelentkezés</h3></div><div class="card-body"><form method="POST"><div class="mb-3"><label>Email</label><input type="email" class="form-control" name="email" required></div><div class="mb-3"><label>Jelszó</label><input type="password" class="form-control" name="password" required></div><button type="submit" class="btn btn-primary w-100">Bejelentkezés</button></form></div></div></div></div>
{% endblock %}
LOGINEOF

    # Admin Users HTML (felhasználók listája)
    cat > backend/templates/users.html << 'USERSEOF'
{% extends "base.html" %}{% block title %}Felhasználók{% endblock %}{% block content %}
<h2>👥 Felhasználók kezelése</h2>
<div class="mb-3"><a href="/admin/users/add" class="btn btn-primary">➕ Új felhasználó</a></div>
<div class="card">
  <div class="card-body">
    {% if users %}
    <table class="table table-dark table-striped">
      <thead><tr><th>ID</th><th>Név</th><th>Email</th><th>Token</th><th>Admin</th><th>Regisztrált</th><th>Műveletek</th></tr></thead>
      <tbody>
      {% for u in users %}
      <tr>
        <td>{{ u.id }}</td>
        <td>{{ u.last_name }} {{ u.first_name }}</td>
        <td>{{ u.email }}</td>
        <td>{{ u.tokens }}</td>
        <td>{% if u.is_admin %}✅{% else %}❌{% endif %}</td>
        <td><small>{{ u.created_at.strftime('%Y-%m-%d') if u.created_at else '-' }}</small></td>
        <td>
          <a href="/admin/users/edit/{{ u.id }}" class="btn btn-sm btn-warning">✏️</a>
          <form action="/admin/users/delete/{{ u.id }}" method="POST" style="display:inline">
            <button class="btn btn-sm btn-danger" onclick="return confirm('Biztosan törlöd a felhasználót?')">🗑️</button>
          </form>
        </td>
      </tr>
      {% endfor %}
      </tbody>
    </table>
    {% else %}
    <p class="text-muted">Nincsenek felhasználók.</p>
    {% endif %}
  </div>
</div>
{% endblock %}
USERSEOF

    # Admin Users Form HTML (felhasználó hozzáadás/szerkesztés)
    cat > backend/templates/users_form.html << 'USERFORMEOF'
{% extends "base.html" %}{% block title %}{% if edit_mode %}Felhasználó szerkesztése{% else %}Új felhasználó{% endif %}{% endblock %}{% block content %}
<h2>{% if edit_mode %}✏️ Felhasználó szerkesztése: {{ user.email }}{% else %}➕ Új felhasználó létrehozása{% endif %}</h2>
<div class="card mt-3">
  <div class="card-body">
    <form method="POST">
      <div class="row g-3">
        <div class="col-md-6">
          <label class="form-label">Vezetéknév</label>
          <input type="text" class="form-control" name="last_name" value="{% if edit_mode %}{{ user.last_name or '' }}{% else %}{{ user_data.get('last_name', '') }}{% endif %}">
        </div>
        <div class="col-md-6">
          <label class="form-label">Keresztnév</label>
          <input type="text" class="form-control" name="first_name" value="{% if edit_mode %}{{ user.first_name or '' }}{% else %}{{ user_data.get('first_name', '') }}{% endif %}">
        </div>
        <div class="col-md-6">
          <label class="form-label">Email cím <span class="text-danger">*</span></label>
          <input type="email" class="form-control" name="email" required value="{% if edit_mode %}{{ user.email }}{% else %}{{ user_data.get('email', '') }}{% endif %}">
        </div>
        <div class="col-md-6">
          <label class="form-label">Telefonszám</label>
          <input type="text" class="form-control" name="phone" value="{% if edit_mode %}{{ user.phone or '' }}{% else %}{{ user_data.get('phone', '') }}{% endif %}">
        </div>
        <div class="col-md-12">
          <label class="form-label">Cím</label>
          <input type="text" class="form-control" name="address" value="{% if edit_mode %}{{ user.address or '' }}{% else %}{{ user_data.get('address', '') }}{% endif %}">
        </div>
        <div class="col-md-4">
          <label class="form-label">Születési dátum</label>
          <input type="date" class="form-control" name="birth_date" value="{% if edit_mode %}{{ user.birth_date or '' }}{% else %}{{ user_data.get('birth_date', '') }}{% endif %}">
        </div>
        <div class="col-md-4">
          <label class="form-label">Adószám</label>
          <input type="text" class="form-control" name="tax_id" value="{% if edit_mode %}{{ user.tax_id or '' }}{% else %}{{ user_data.get('tax_id', '') }}{% endif %}">
        </div>
        <div class="col-md-4">
          <label class="form-label">Tokenek száma <span class="text-danger">*</span></label>
          <input type="number" class="form-control" name="tokens" required value="{% if edit_mode %}{{ user.tokens }}{% else %}5{% endif %}" min="0">
        </div>
        <div class="col-md-6">
          <label class="form-label">Jelszó {% if not edit_mode %}<span class="text-danger">*</span>{% else %}(ha üres, nem változik){% endif %}</label>
          <input type="password" class="form-control" name="password" {% if not edit_mode %}required{% endif %}>
        </div>
        <div class="col-md-6">
          <label class="form-label">Admin jogosultság</label>
          <div class="form-check mt-2">
            <input class="form-check-input" type="checkbox" name="is_admin" value="1" id="isAdmin" {% if edit_mode and user.is_admin %}checked{% endif %}>
            <label class="form-check-label" for="isAdmin">Adminisztrátor</label>
          </div>
        </div>
      </div>
      <div class="mt-4">
        <button type="submit" class="btn btn-success">💾 Mentés</button>
        <a href="/admin/users" class="btn btn-secondary">Mégse</a>
      </div>
    </form>
  </div>
</div>
{% endblock %}
USERFORMEOF

    # Admin Update HTML (frissítés ellenőrző)
    cat > backend/templates/update.html << 'UPDHTML'
{% extends "base.html" %}{% block title %}Frissítés{% endblock %}{% block content %}
<h2>🔄 Frissítés ellenőrzése</h2>
<div class="row mt-4">
  <div class="col-md-8">
    <div class="card">
      <div class="card-header"><h5>Verzió információk</h5></div>
      <div class="card-body">
        <p><strong>Jelenlegi verzió:</strong> v{{ current_version }}</p>
        <div id="updateStatus">
          <button class="btn btn-primary" onclick="checkUpdate()">🔍 Frissítés keresése</button>
        </div>
        <div id="updateResult" class="mt-3" style="display:none"></div>
      </div>
    </div>
    <div class="card mt-3">
      <div class="card-header"><h5>📋 Frissítési napló</h5></div>
      <div class="card-body">
        <p class="text-muted">A frissítések naplózása az <a href="/admin">Admin oldalon</a> látható.</p>
        <p class="text-muted">Automatikus ellenőrzés: 2 óránként</p>
      </div>
    </div>
  </div>
</div>
<script>
async function checkUpdate() {
  document.getElementById('updateStatus').innerHTML = '<div class="spinner-border text-primary"></div> Ellenőrzés folyamatban...';
  try {
    const resp = await fetch('/api/update/check');
    const data = await resp.json();
    const div = document.getElementById('updateResult');
    div.style.display = 'block';
    if (data.error) {
      div.innerHTML = `<div class="alert alert-danger">${data.error}</div>`;
      document.getElementById('updateStatus').innerHTML = '<button class="btn btn-primary" onclick="checkUpdate()">🔍 Frissítés keresése</button>';
      return;
    }
    if (data.has_update) {
      div.innerHTML = `
        <div class="alert alert-warning">
          <strong>🚀 Új verzió elérhető: v${data.remote_version}</strong>
          <p class="mt-2">${data.release_notes || 'Nincs részletes leírás.'}</p>
          <a href="${data.release_url}" target="_blank" class="btn btn-sm btn-outline-light me-2">📋 Release notes</a>
          <button class="btn btn-success" onclick="runUpdate()">⬆️ Frissítés telepítése</button>
        </div>`;
      document.getElementById('updateStatus').innerHTML = '<span class="badge bg-warning">Frissítés elérhető!</span>';
    } else {
      div.innerHTML = `<div class="alert alert-success">✅ A rendszer naprakész. (v${data.current})</div>`;
      document.getElementById('updateStatus').innerHTML = '<button class="btn btn-primary" onclick="checkUpdate()">🔍 Frissítés keresése</button>';
    }
  } catch(e) {
    document.getElementById('updateResult').style.display = 'block';
    document.getElementById('updateResult').innerHTML = `<div class="alert alert-danger">Hiba: ${e.message}</div>`;
    document.getElementById('updateStatus').innerHTML = '<button class="btn btn-primary" onclick="checkUpdate()">🔍 Frissítés keresése</button>';
  }
}
async function runUpdate() {
  if (!confirm('Biztosan futtatod a frissítést? Ez újraindítja a konténereket!')) return;
  document.getElementById('updateResult').innerHTML = '<div class="alert alert-info"><div class="spinner-border spinner-border-sm"></div> Frissítés folyamatban... Ez eltarthat néhány percig.</div>';
  try {
    const resp = await fetch('/api/update/run', {method: 'POST'});
    const data = await resp.json();
    if (data.success) {
      document.getElementById('updateResult').innerHTML = `<div class="alert alert-success">✅ Frissítés sikeres!<br><pre style="font-size:12px">${data.output || ''}</pre></div>`;
      setTimeout(() => location.reload(), 5000);
    } else {
      document.getElementById('updateResult').innerHTML = `<div class="alert alert-danger">❌ Frissítés sikertelen!<br><pre style="font-size:12px">${data.error || data.output || ''}</pre></div>`;
    }
  } catch(e) {
    document.getElementById('updateResult').innerHTML = `<div class="alert alert-danger">Hiba: ${e.message}</div>`;
  }
}
// Automatikus ellenőrzés oldal betöltésekor
window.addEventListener('load', () => checkUpdate());
</script>
{% endblock %}
UPDHTML

    # Admin HTML
    cat > backend/templates/admin.html << 'ADMINEOF'
{% extends "base.html" %}{% block title %}Admin{% endblock %}{% block content %}
<h2>⚙️ Admin Vezérlőpult</h2>
<div class="row mt-4">
  <div class="col-md-3"><div class="card bg-success text-white"><div class="card-body text-center"><h3>{{ sys_info.cpu_percent }}%</h3><p>CPU</p></div></div></div>
  <div class="col-md-3"><div class="card bg-info text-white"><div class="card-body text-center"><h3>{{ sys_info.memory_percent }}%</h3><p>RAM ({{ sys_info.memory_used_gb }}/{{ sys_info.memory_total_gb }} GB)</p></div></div></div>
  <div class="col-md-3"><div class="card bg-warning text-dark"><div class="card-body text-center"><h3>{{ sys_info.disk_percent }}%</h3><p>Lemez ({{ sys_info.disk_free_gb }} GB szabad)</p></div></div></div>
  <div class="col-md-3"><div class="card bg-secondary text-white"><div class="card-body text-center"><h3>{{ models|length }}</h3><p>Modell</p></div></div></div>
</div>

<div class="card mt-4">
  <div class="card-header"><h5>🤖 AI Modellek</h5></div>
  <div class="card-body">
    <p>Aktuális modell: <strong>{{ current_model }}</strong></p>
    {% if models %}
    <table class="table table-dark table-striped">
      <thead><tr><th>Név</th><th>Méret</th><th>Művelet</th></tr></thead>
      <tbody>
      {% for m in models %}
        <tr>
          <td>{{ m.name }}</td>
          <td>{{ (m.size / 1024 / 1024 / 1024)|round(1) }} GB</td>
          <td><button class="btn btn-sm btn-outline-light switch-model" data-model="{{ m.name }}">Váltás</button></td>
        </tr>
      {% endfor %}
      </tbody>
    </table>
    {% else %}
    <p class="text-muted">Nincsenek modellek betöltve.</p>
    {% endif %}
  </div>
</div>
<script>
document.querySelectorAll('.switch-model').forEach(btn => {
  btn.addEventListener('click', async () => {
    const model = btn.dataset.model;
    const resp = await fetch('/api/models/switch', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({model: model, auto_optimize: true})
    });
    const data = await resp.json();
    alert(data.message || data.error);
    if (data.success) location.reload();
  });
});
</script>
{% endblock %}
ADMINEOF
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
cd ~/epub-translator

echo "🔄 EPUB Fordító - Frissítés"

# Git repo ellenőrzése
if [ ! -d .git ]; then
    echo "Git repo inicializálása..."
    git init .
fi

# Remote beállítása (ha még nincs)
if ! git remote get-url origin &>/dev/null 2>&1; then
    git remote add origin https://github.com/sorosg/Epub-translate.git 2>/dev/null || true
else
    git remote set-url origin https://github.com/sorosg/Epub-translate.git 2>/dev/null || true
fi

# Legújabb verzió letöltése
echo "📥 Legújabb verzió letöltése..."
UPDATED=false
if git fetch origin main 2>/dev/null; then
    git reset --hard FETCH_HEAD 2>/dev/null && { echo "✅ Repó frissítve"; UPDATED=true; }
fi
if [ "$UPDATED" = false ]; then
    # Fallback: próbáljunk git pull-t
    if git pull origin main --force 2>/dev/null; then
        echo "✅ Repó frissítve (pull)"
        UPDATED=true
    fi
fi
if [ "$UPDATED" = false ]; then
    echo "⚠️  A GitHub nem elérhető, a meglévő fájlokkal dolgozunk"
fi

echo "🛑 Konténerek leállítása..."
DOCKER=$(docker ps &>/dev/null 2>&1 && echo "docker" || echo "sudo docker")
$DOCKER compose down 2>/dev/null || true

echo "🔨 Újraépítés..."
$DOCKER compose build 2>/dev/null || $DOCKER compose build --no-cache

echo "🚀 Konténerek indítása..."
$DOCKER compose up -d

echo "✅ Frissítés kész!"
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
    echo "🌐 Web:        http://localhost:${HTTP_PORT:-80}"
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
    # Script saját könyvtárának elmentése (ahol az install.sh és a src/ található)
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
        cd "$PROJECT_DIR"
        log_info "A telepítési könyvtár: $PROJECT_DIR"
        exit 0
    fi
    
    configure_system
    
    if [ "$IS_UPDATE" = true ]; then
        perform_update
    else
        perform_fresh_install
    fi
    
    show_summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    log_info "A telepítési könyvtár: $PROJECT_DIR"
    log_info "A script befejeződött. A terminál visszaállt a futtatási könyvtárba."
    echo ""
    log_info "A webes felület eléréséhez futtasd:"
    echo "    cd ~/epub-translator"
    echo "    sudo docker compose ps"
    echo ""
    log_info "VAGY lépj be a telepítési könyvtárba:"
    echo "    cd ~/epub-translator"
}

main "$@"