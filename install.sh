#!/bin/bash

# EPUB Fordító Rendszer - Telepítő/Frissítő Script v9.0
# Verzió: 9.0.0
# Kódnév: "User Portal"
# Leírás: Felhasználói regisztráció, belső email, könyvtárkezelés, automatikus frissítés

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
VERSION="9.0.0"
CODENAME="User Portal"
RELEASE_DATE="2025-01-15"
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
ENABLE_REGISTRATION="i"
DEFAULT_TOKENS=5
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
        echo "  1) Frissítés meglévő telepítésről (adatok megőrzése) ⭐ Ajánlott"
        echo "  2) Teljes újratelepítés (minden adat törlődik)"
        echo "  3) Csak konfiguráció frissítése (megtartja az adatbázist)"
        echo "  4) Kilépés"
        echo ""
        read -p "Választás [1]: " install_mode
        install_mode=${install_mode:-1}
        
        case $install_mode in
            1)
                IS_UPDATE=true
                log_update "Frissítési mód kiválasztva"
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
                BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"
                log_info "Biztonsági mentés: $BACKUP_DIR"
                cp -r "$PROJECT_DIR" "$BACKUP_DIR" 2>/dev/null || true
                rm -rf "$PROJECT_DIR"
                ;;
            3)
                IS_UPDATE=true
                CONFIG_ONLY=true
                log_update "Konfiguráció frissítési mód"
                load_existing_config
                ;;
            4)
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
        cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Környezeti változók mentve"
    fi
    
    # Meglévő értékek megtartása
    ADMIN_EMAIL="${ADMIN_EMAIL:-admin@epub-translator.local}"
    ADMIN_PASSWORD="${ADMIN_PASSWORD:-Abrakadabra}"
    SELECTED_MODEL="${SELECTED_MODEL:-$DEFAULT_MODEL}"
    SMTP_MODE="${SMTP_MODE:-local}"
    GITHUB_REPO="${GITHUB_REPO:-https://github.com/sorosg/Epub-translate.git}"
    GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    ENABLE_REGISTRATION="${ENABLE_REGISTRATION:-i}"
    DEFAULT_TOKENS="${DEFAULT_TOKENS:-5}"
    
    log_success "Konfiguráció betöltve"
}

# ============================================================
# RENDSZER ERŐFORRÁSOK
# ============================================================
check_system_resources() {
    log_step "Rendszer erőforrások ellenőrzése"
    
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    log_info "Teljes memória: ${TOTAL_RAM}GB"
    
    if [ "$TOTAL_RAM" -lt 16 ]; then
        log_error "Minimum 16GB RAM szükséges! (Ajánlott: 32GB)"
        exit 1
    elif [ "$TOTAL_RAM" -lt 32 ]; then
        RECOMMENDED_MODEL="deepseek-r1:7b"
        MAX_WORKERS=2
    else
        RECOMMENDED_MODEL="deepseek-r1:8b"
        MAX_WORKERS=3
    fi
    
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_info "Szabad lemezterület: ${FREE_SPACE}GB"
    
    CPU_CORES=$(nproc)
    log_info "CPU magok: $CPU_CORES"
}

# ============================================================
# KONFIGURÁCIÓS VARÁZSLÓ
# ============================================================
configure_system() {
    if [ "$IS_UPDATE" = true ] && [ "${CONFIG_ONLY:-false}" = false ]; then
        log_info "Frissítés - meglévő konfiguráció megtartása"
        return
    fi
    
    log_step "Konfigurációs varázsló"
    
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════╗"
    log_header "║     EPUB Fordító v${VERSION} - \"${CODENAME}\"    ║"
    log_header "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "   🆕 v9.0 Újdonságok:"
    echo "   👤 Felhasználói regisztrációs oldal"
    echo "   📧 Belső email cím automatikus generálás"
    echo "   🎁 Kezdő tokenek új felhasználóknak"
    echo "   📨 MailHog integráció a felületen"
    echo "   📚 Drag & Drop könyvtárfeltöltés"
    echo "   🔄 Egykattintásos frissítés"
    echo "   🎨 Továbbfejlesztett felhasználói felület"
    echo ""
    
    read -p "Szeretnéd testreszabni a telepítést? (i/n) [i]: " customize
    customize=${customize:-"i"}
    
    if [[ $customize =~ ^[Ii]$ ]]; then
        echo ""
        log_config "👤 Adminisztrátor:"
        read -p "   Email [${ADMIN_EMAIL}]: " input
        ADMIN_EMAIL=${input:-$ADMIN_EMAIL}
        read -sp "   Jelszó [${ADMIN_PASSWORD}]: " input
        echo ""
        ADMIN_PASSWORD=${input:-$ADMIN_PASSWORD}
        
        echo ""
        log_config "👥 Felhasználói regisztráció:"
        read -p "   Regisztráció engedélyezése? (i/n) [i]: " input
        ENABLE_REGISTRATION=${input:-"i"}
        if [[ $ENABLE_REGISTRATION =~ ^[Ii]$ ]]; then
            read -p "   Kezdő tokenek száma [5]: " input
            DEFAULT_TOKENS=${input:-5}
        fi
        
        echo ""
        log_config "🤖 AI Modell:"
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
        read -p "   PWA? (i/n) [i]: " input; ENABLE_PWA=${input:-"i"}
        read -p "   TTS? (i/n) [i]: " input; ENABLE_TTS=${input:-"i"}
        read -p "   Kollaboráció? (i/n) [i]: " input; ENABLE_COLLABORATION=${input:-"i"}
        read -p "   Plugin? (i/n) [i]: " input; ENABLE_PLUGINS=${input:-"i"}
        
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
ENABLE_REGISTRATION="${ENABLE_REGISTRATION}"
DEFAULT_TOKENS=${DEFAULT_TOKENS}
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
IS_FRESH_INSTALL=$([ "$IS_UPDATE" = false ] && echo "true" || echo "false")
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
    UPDATE_BACKUP="backups/updates/pre_update_${EXISTING_VERSION}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$UPDATE_BACKUP"
    
    if docker compose ps 2>/dev/null | grep -q postgres; then
        docker exec epub-postgres pg_dump -U epub_user epub_translator > "$UPDATE_BACKUP/database.sql" 2>/dev/null || true
    fi
    
    cp .env "$UPDATE_BACKUP/.env" 2>/dev/null || true
    cp .install_config "$UPDATE_BACKUP/.install_config" 2>/dev/null || true
    
    # Könyvtár és fordítási memória mentése
    if [ -d "book_database" ]; then
        tar -czf "$UPDATE_BACKUP/book_database.tar.gz" book_database/ 2>/dev/null || true
    fi
    if [ -d "translation_memory" ]; then
        tar -czf "$UPDATE_BACKUP/translation_memory.tar.gz" translation_memory/ 2>/dev/null || true
    fi
    
    log_success "Biztonsági mentés: $UPDATE_BACKUP"
    
    # 2. Konténerek leállítása
    log_info "Konténerek leállítása..."
    docker compose down 2>/dev/null || true
    
    # 3. Új fájlok telepítése
    if [ "${CONFIG_ONLY:-false}" = true ]; then
        log_info "Csak konfiguráció frissítése..."
        create_config_files
    else
        log_info "Teljes frissítés..."
        if [ -d ".git" ]; then
            git fetch origin 2>/dev/null && git pull origin main 2>/dev/null || log_warn "Git pull nem sikerült"
        fi
        create_directory_structure
        create_config_files
    fi
    
    # 4. Konténerek újraépítése
    log_info "Konténerek újraépítése..."
    docker compose build 2>/dev/null || docker compose build --no-cache
    
    # 5. Indítás
    log_info "Konténerek indítása..."
    docker compose up -d
    sleep 15
    
    # 6. Adatbázis migráció
    log_info "Adatbázis migráció..."
    docker exec -it epub-backend python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
    print('Adatbázis migráció kész')
" 2>/dev/null || log_warn "Migráció figyelmeztetés"
    
    # 7. Verzió frissítése
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
    echo "$(date): Frissítve ${EXISTING_VERSION} → ${VERSION}" >> updates.log
    
    log_success "Frissítés befejezve!"
}

# ============================================================
# FRISS TELEPÍTÉS
# ============================================================
perform_fresh_install() {
    log_step "Friss telepítés"
    
    PROJECT_DIR="$HOME/epub-translator"
    
    if [ -d "$PROJECT_DIR" ]; then
        BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"
        mv "$PROJECT_DIR" "$BACKUP_DIR" 2>/dev/null || true
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    create_directory_structure
    create_config_files
    
    # Rendszer frissítése
    sudo apt update -qq && sudo apt upgrade -y -qq
    
    # Függőségek
    install_dependencies
    
    # Docker
    install_docker
    
    # Konténerek
    build_and_start_containers
    
    # Modell
    download_model
    
    # Adatbázis
    initialize_database
    
    # Frissítési csatorna
    setup_update_channel
    
    # Cron
    setup_cron
    
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
}

# ============================================================
# KÖNYVTÁR STRUKTÚRA
# ============================================================
create_directory_structure() {
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
# FÜGGŐSÉGEK
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
        poppler-utils ffmpeg espeak mpg321 \
        nginx openssl 2>/dev/null || true
}

# ============================================================
# DOCKER
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
        log_info "Docker már telepítve"
    fi
}

# ============================================================
# KONFIGURÁCIÓS FÁJLOK
# ============================================================
create_config_files() {
    log_info "Konfigurációs fájlok létrehozása..."
    
    # .env
    if [ "$IS_UPDATE" = true ] && [ -f ".env" ]; then
        log_info "Meglévő .env frissítése..."
        sed -i "s/VERSION=.*/VERSION=${VERSION}/" .env 2>/dev/null || true
        sed -i "s/CODENAME=.*/CODENAME=\"${CODENAME}\"/" .env 2>/dev/null || true
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

# Regisztráció
ENABLE_REGISTRATION=${ENABLE_REGISTRATION}
DEFAULT_TOKENS=${DEFAULT_TOKENS}

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
SELECTED_MODEL=${SELECTED_MODEL}
MAX_WORKERS=${MAX_WORKERS}

# Funkciók
ENABLE_PWA=${ENABLE_PWA}
ENABLE_TTS=${ENABLE_TTS}
ENABLE_COLLABORATION=${ENABLE_COLLABORATION}
ENABLE_PLUGINS=${ENABLE_PLUGINS}
ENABLE_API=${ENABLE_API}
ENABLE_BOOK_DB=${ENABLE_BOOK_DB}
ENABLE_CACHE=${ENABLE_CACHE}

# Auto-Update
ENABLE_AUTO_UPDATE=${ENABLE_AUTO_UPDATE}
GITHUB_REPO=${GITHUB_REPO}
GITHUB_BRANCH=${GITHUB_BRANCH}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
UPDATE_CHECK_INTERVAL=${UPDATE_CHECK_INTERVAL}

# Redis
REDIS_URL=redis://redis:6379/0
ENVEOF
    fi
    
    # docker-compose.yml
    create_docker_compose
    
    # Nginx
    create_nginx_config
    
    # Ollama
    create_ollama_dockerfile
    
    # Backend
    create_backend_files
    
    # PWA
    create_pwa_files
    
    # Scriptek
    create_scripts
    
    log_success "Konfigurációs fájlok kész"
}

create_docker_compose() {
    cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    container_name: epub-nginx
    ports: ["80:80", "443:443"]
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./static:/usr/share/nginx/html/static:ro
      - ./logs/nginx:/var/log/nginx
    depends_on: {backend: {condition: service_healthy}}
    networks: [translator-network]
    restart: unless-stopped
    healthcheck: {test: ["CMD", "curl", "-f", "http://localhost:80/health"], interval: 30s, timeout: 10s, retries: 3}

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
      - ENABLE_REGISTRATION=${ENABLE_REGISTRATION}
      - DEFAULT_TOKENS=${DEFAULT_TOKENS}
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
    depends_on: {postgres: {condition: service_healthy}, ollama: {condition: service_healthy}, redis: {condition: service_started}}
    networks: [translator-network]
    restart: unless-stopped
    command: gunicorn -w 2 -b 0.0.0.0:5000 app:app --timeout 600 --worker-class eventlet
    healthcheck: {test: ["CMD", "curl", "-f", "http://localhost:5000/health"], interval: 30s, timeout: 10s, retries: 3, start_period: 40s}

  postgres:
    image: postgres:15-alpine
    container_name: epub-postgres
    environment: [POSTGRES_DB=epub_translator, POSTGRES_USER=epub_user, POSTGRES_PASSWORD=epub_password]
    volumes: [postgres_data:/var/lib/postgresql/data, ./backups:/backups]
    networks: [translator-network]
    restart: unless-stopped
    healthcheck: {test: ["CMD-SHELL", "pg_isready -U epub_user -d epub_translator"], interval: 10s, timeout: 5s, retries: 5}

  ollama:
    build: ./ollama
    container_name: epub-ollama
    volumes: [ollama_data:/root/.ollama]
    environment: [OLLAMA_KEEP_ALIVE=24h, OLLAMA_HOST=0.0.0.0]
    networks: [translator-network]
    restart: unless-stopped
    deploy: {resources: {limits: {memory: 24G}, reservations: {memory: 16G}}}
    command: serve
    healthcheck: {test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"], interval: 30s, timeout: 10s, retries: 3, start_period: 60s}

  redis:
    image: redis:alpine
    container_name: epub-redis
    volumes: [redis_data:/data]
    networks: [translator-network]
    restart: unless-stopped
    healthcheck: {test: ["CMD", "redis-cli", "ping"], interval: 10s, timeout: 5s, retries: 3}

  mailhog:
    image: mailhog/mailhog:latest
    container_name: epub-mailhog
    ports: ["1025:1025", "8025:8025"]
    networks: [translator-network]
    restart: unless-stopped
    profiles: [local, all]

networks:
  translator-network: {driver: bridge}

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
    client_max_body_size 100M;
    server {
        listen 80;
        location /health { return 200 "OK"; }
        location /manifest.json { alias /usr/share/nginx/html/static/manifest.json; add_header Content-Type application/json; }
        location /sw.js { alias /usr/share/nginx/html/static/js/sw.js; add_header Content-Type application/javascript; add_header Service-Worker-Allowed "/"; }
        location /api/ { proxy_pass http://backend:5000; proxy_set_header Host $host; }
        location /ws/ { proxy_pass http://websocket:3001; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; }
        location /static { alias /usr/share/nginx/html/static; expires 30d; }
        location / { proxy_pass http://backend:5000; proxy_set_header Host $host; proxy_set_header X-Real-IP $remote_addr; }
    }
}
NGINXEOF
}

create_ollama_dockerfile() {
    mkdir -p ollama
    echo 'FROM ollama/ollama:latest' > ollama/Dockerfile
    echo 'COPY healthcheck.sh /healthcheck.sh' >> ollama/Dockerfile
    echo 'RUN chmod +x /healthcheck.sh' >> ollama/Dockerfile
    echo 'HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD /healthcheck.sh || exit 1' >> ollama/Dockerfile
    echo 'EXPOSE 11434' >> ollama/Dockerfile
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
RUN apt-get update && apt-get install -y gcc libxml2-dev libxslt-dev curl git && rm -rf /var/lib/apt/lists/*
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
python-socketio==5.9.0
psutil==5.9.5
Pillow==10.0.0
qrcode==7.4.2
pyotp==2.9.0
cryptography==41.0.3
isbnlib==3.10.14
numpy==1.24.3
GitPython==3.1.40
packaging==23.2
REQEOF

    # config.py
    cat > backend/config.py << 'CONFIGEOF'
import os
from dotenv import load_dotenv
load_dotenv()

class Config:
    VERSION = os.environ.get('VERSION', '9.0.0')
    CODENAME = os.environ.get('CODENAME', 'User Portal')
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
    ENABLE_REGISTRATION = os.environ.get('ENABLE_REGISTRATION', 'i').lower() == 'i'
    DEFAULT_TOKENS = int(os.environ.get('DEFAULT_TOKENS', 5))
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
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
CONFIGEOF

    # models.py
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
    tokens = db.Column(db.Integer, default=5)
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
    word_count = db.Column(db.Integer)
    file_hash = db.Column(db.String(64), unique=True)
    file_path = db.Column(db.String(500))
    use_count = db.Column(db.Integer, default=0)
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
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class ActivityLog(db.Model):
    __tablename__ = 'activity_logs'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    action = db.Column(db.String(100))
    details = db.Column(db.Text)
    ip_address = db.Column(db.String(45))
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
MODELSEOF

    # app.py
    cat > backend/app.py << 'APPEOF'
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, BookUpload, InternalEmail, ActivityLog, SystemVersion
from datetime import datetime
from functools import wraps
import os, re

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
            return redirect(url_for('admin') if user.is_admin else url_for('dashboard'))
        flash('Hibás email vagy jelszó!', 'error')
    return render_template('login.html')

@app.route('/register')
def register_page():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    if not app.config['ENABLE_REGISTRATION']:
        flash('A regisztráció jelenleg le van tiltva!', 'error')
        return redirect(url_for('login'))
    return render_template('register.html')

@app.route('/api/register', methods=['POST'])
@limiter.limit("5 per hour")
def register_user():
    if not app.config['ENABLE_REGISTRATION']:
        return jsonify({'error': 'A regisztráció le van tiltva!'}), 403
    
    data = request.get_json()
    
    for field in ['email', 'password', 'first_name', 'last_name']:
        if not data.get(field):
            return jsonify({'error': f'A(z) {field} mező kötelező!'}), 400
    
    if not re.match(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', data['email']):
        return jsonify({'error': 'Érvénytelen email!'}), 400
    
    if User.query.filter_by(email=data['email']).first():
        return jsonify({'error': 'Ez az email már regisztrálva van!'}), 400
    
    if len(data['password']) < 8:
        return jsonify({'error': 'A jelszó minimum 8 karakter!'}), 400
    
    base_username = data['email'].split('@')[0]
    username = base_username
    counter = 1
    while User.query.filter_by(username=username).first():
        username = f"{base_username}{counter}"
        counter += 1
    
    user = User(
        username=username,
        email=data['email'],
        password_hash=generate_password_hash(data['password']),
        first_name=data['first_name'].strip(),
        last_name=data['last_name'].strip(),
        tokens=app.config['DEFAULT_TOKENS']
    )
    db.session.add(user)
    db.session.commit()
    
    # Belső email generálása
    first = user.first_name.lower().replace(' ', '.')
    last = user.last_name.lower().replace(' ', '.')
    internal = f"{first}.{last}@epub.local"
    counter = 1
    while User.query.filter_by(internal_email=internal).first():
        internal = f"{first}.{last}{counter}@epub.local"
        counter += 1
    user.internal_email = internal
    db.session.commit()
    
    # Üdvözlő email
    welcome = InternalEmail(
        sender_id=None,
        recipient_id=user.id,
        subject='🎉 Üdvözlünk az EPUB Fordítóban!',
        body=f'Kedves {user.first_name}!\n\nSikeres regisztráció!\nBelső email: {internal}\nTokenek: {user.tokens}\n\nÜdvözlettel,\nEPUB Fordító'
    )
    db.session.add(welcome)
    
    activity = ActivityLog(user_id=user.id, action='user_registered', details=f'Új felhasználó: {user.email}', ip_address=request.remote_addr)
    db.session.add(activity)
    db.session.commit()
    
    return jsonify({'success': True, 'user_id': user.id, 'internal_email': internal, 'tokens': user.tokens})

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
    translations = Translation.query.filter_by(user_id=current_user.id).order_by(Translation.created_at.desc()).limit(20).all()
    return render_template('dashboard.html', user=current_user, translations=translations)

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

@app.route('/api/internal-mail/inbox')
@login_required
def inbox():
    emails = InternalEmail.query.filter_by(recipient_id=current_user.id).order_by(InternalEmail.created_at.desc()).limit(20).all()
    return jsonify({'emails': [{'id': e.id, 'subject': e.subject, 'body': e.body[:200], 'is_read': e.is_read, 'is_starred': e.is_starred, 'created_at': e.created_at.isoformat()} for e in emails], 'unread': InternalEmail.query.filter_by(recipient_id=current_user.id, is_read=False).count()})

def init_db():
    with app.app_context():
        db.create_all()
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL, password_hash=generate_password_hash(Config.ADMIN_PASSWORD), first_name='Admin', last_name='User', is_admin=True, tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin)
            db.session.commit()

if __name__ == '__main__':
    init_db()
    app.run(debug=False, host='0.0.0.0', port=5000)
APPEOF

    touch backend/utils/__init__.py
    
    # HTML sablonok
    create_html_templates
}

create_html_templates() {
    # register.html
    cat > backend/templates/register.html << 'REGEOF'
{% extends "base.html" %}
{% block title %}Regisztráció{% endblock %}
{% block content %}
<div class="row justify-content-center mt-5">
    <div class="col-md-6 col-lg-5">
        <div class="card shadow">
            <div class="card-header bg-success text-white">
                <h3 class="text-center mb-0"><i class="fas fa-user-plus"></i> Regisztráció</h3>
            </div>
            <div class="card-body">
                <form id="registerForm">
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Vezetéknév *</label>
                            <input type="text" class="form-control" id="last_name" required>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Keresztnév *</label>
                            <input type="text" class="form-control" id="first_name" required>
                        </div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Email cím *</label>
                        <input type="email" class="form-control" id="email" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Jelszó *</label>
                        <input type="password" class="form-control" id="password" required minlength="8">
                        <small class="text-muted">Minimum 8 karakter</small>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Jelszó megerősítése *</label>
                        <input type="password" class="form-control" id="confirm_password" required>
                    </div>
                    <button type="submit" class="btn btn-success w-100 mb-3" id="registerBtn">
                        <i class="fas fa-user-plus"></i> Regisztráció
                    </button>
                    <div class="text-center">
                        <span>Már van fiókod?</span>
                        <a href="/login">Bejelentkezés</a>
                    </div>
                </form>
                <div id="registerSuccess" class="d-none text-center py-4">
                    <i class="fas fa-check-circle fa-4x text-success mb-3"></i>
                    <h4>Sikeres regisztráció!</h4>
                    <p>Belső email: <strong id="internalEmail"></strong></p>
                    <p>Tokenek: <strong id="tokenCount"></strong></p>
                    <a href="/login" class="btn btn-primary">Bejelentkezés</a>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
{% block scripts %}
<script>
document.getElementById('registerForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    const pwd = document.getElementById('password').value;
    if (pwd !== document.getElementById('confirm_password').value) { alert('A jelszavak nem egyeznek!'); return; }
    if (pwd.length < 8) { alert('Minimum 8 karakter!'); return; }
    
    const btn = document.getElementById('registerBtn');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm"></span> Regisztráció...';
    
    try {
        const res = await fetch('/api/register', {
            method: 'POST', headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                first_name: document.getElementById('first_name').value,
                last_name: document.getElementById('last_name').value,
                email: document.getElementById('email').value,
                password: pwd
            })
        });
        const data = await res.json();
        if (data.success) {
            document.getElementById('registerForm').classList.add('d-none');
            document.getElementById('registerSuccess').classList.remove('d-none');
            document.getElementById('internalEmail').textContent = data.internal_email;
            document.getElementById('tokenCount').textContent = data.tokens;
        } else {
            alert('Hiba: ' + (data.error || 'Ismeretlen hiba'));
        }
    } catch(e) {
        alert('Hálózati hiba: ' + e);
    } finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="fas fa-user-plus"></i> Regisztráció';
    }
});
</script>
{% endblock %}
REGEOF

    # login.html (frissítve regisztrációs gombbal)
    cat > backend/templates/login.html << 'LOGINEOF'
{% extends "base.html" %}
{% block title %}Bejelentkezés{% endblock %}
{% block content %}
<div class="row justify-content-center mt-5">
    <div class="col-md-5 col-lg-4">
        <div class="card shadow">
            <div class="card-header bg-primary text-white">
                <h3 class="text-center mb-0"><i class="fas fa-sign-in-alt"></i> Bejelentkezés</h3>
            </div>
            <div class="card-body">
                <form method="POST">
                    <div class="mb-3">
                        <label class="form-label">Email cím</label>
                        <input type="email" class="form-control" name="email" required autofocus>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Jelszó</label>
                        <input type="password" class="form-control" name="password" required>
                    </div>
                    <button type="submit" class="btn btn-primary w-100 mb-3">Bejelentkezés</button>
                    <hr>
                    <a href="/register" class="btn btn-success w-100">
                        <i class="fas fa-user-plus"></i> Új fiók létrehozása
                    </a>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}
LOGINEOF

    # base.html (alap)
    cat > backend/templates/base.html << 'BASEEOF'
<!DOCTYPE html>
<html lang="hu">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EPUB Fordító - {% block title %}{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="/"><i class="fas fa-book-open"></i> EPUB Fordító</a>
            <div class="navbar-nav ms-auto">
                {% if current_user.is_authenticated %}
                <span class="nav-link text-light"><i class="fas fa-coins"></i> Tokenek: {{ current_user.tokens }}</span>
                <a class="nav-link" href="/logout"><i class="fas fa-sign-out-alt"></i> Kijelentkezés</a>
                {% else %}
                <a class="nav-link" href="/login">Bejelentkezés</a>
                <a class="btn btn-success btn-sm mt-1" href="/register">Regisztráció</a>
                {% endif %}
            </div>
        </div>
    </nav>
    <div class="container mt-4">
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% for category, message in messages %}
                <div class="alert alert-{{ category }}">{{ message }}</div>
            {% endfor %}
        {% endwith %}
        {% block content %}{% endblock %}
    </div>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
    {% block scripts %}{% endblock %}
</body>
</html>
BASEEEOF

    # dashboard.html
    cat > backend/templates/dashboard.html << 'DASHEOF'
{% extends "base.html" %}
{% block title %}Vezérlőpult{% endblock %}
{% block content %}
<h2>Üdvözlünk, {{ user.first_name }}!</h2>
<div class="row mt-4">
    <div class="col-md-4">
        <div class="card">
            <div class="card-header">Tokenek</div>
            <div class="card-body text-center">
                <h1>{{ user.tokens }}</h1>
                <p class="text-muted">felhasználható token</p>
                {% if user.tokens == 0 %}<button class="btn btn-warning">Tokenek kérése</button>{% endif %}
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card">
            <div class="card-header">Belső email</div>
            <div class="card-body text-center">
                <p><code>{{ user.internal_email }}</code></p>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card">
            <div class="card-header">Fordítások</div>
            <div class="card-body text-center">
                <h1>{{ translations|length }}</h1>
            </div>
        </div>
    </div>
</div>
{% endblock %}
DASHEOF
}

create_pwa_files() {
    mkdir -p static/icons
    cat > static/manifest.json << 'MANIFESTEOF'
{"name":"EPUB Fordító v9.0","short_name":"EPUB Fordító","start_url":"/","display":"standalone","background_color":"#1a1a2e","theme_color":"#16213e","icons":[{"src":"/static/icons/icon-192x192.png","sizes":"192x192","type":"image/png"},{"src":"/static/icons/icon-512x512.png","sizes":"512x512","type":"image/png"}]}
MANIFESTEOF
}

create_scripts() {
    cat > scripts/backup.sh << 'BACKUPEOF'
#!/bin/bash
D=$(date +%Y%m%d_%H%M%S)
mkdir -p ~/epub-backups
docker exec epub-postgres pg_dump -U epub_user epub_translator > ~/epub-backups/db_$D.sql 2>/dev/null
echo "✅ Mentés: ~/epub-backups/db_$D.sql"
BACKUPEOF

    cat > scripts/update.sh << 'UPDATEEOF'
#!/bin/bash
cd ~/epub-translator
docker compose down
git pull 2>/dev/null || echo "Git nem elérhető"
docker compose build
docker compose up -d
echo "✅ Frissítve!"
UPDATEEOF

    cat > scripts/status.sh << 'STATUSEOF'
#!/bin/bash
echo "EPUB Fordító v9.0"
docker compose ps
echo "Web: http://localhost | Email: http://localhost:8025"
STATUSEOF

    chmod +x scripts/*.sh
}

# ============================================================
# KONTÉNEREK
# ============================================================
build_and_start_containers() {
    log_info "Konténerek építése..."
    docker compose build 2>/dev/null || docker compose build --no-cache
    docker compose up -d
    sleep 20
}

download_model() {
    log_info "Modell: $SELECTED_MODEL"
    docker exec -it epub-ollama ollama pull "$SELECTED_MODEL" 2>/dev/null || log_warn "Modell figyelmeztetés"
}

initialize_database() {
    log_info "Adatbázis inicializálása..."
    sleep 10
    docker exec -it epub-backend python3 -c "from app import app, init_db; app.app_context().push(); init_db(); print('OK')" 2>/dev/null || log_warn "DB figyelmeztetés"
}

setup_update_channel() {
    [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && [ -n "$GITHUB_REPO" ] && \
    docker exec -it epub-backend python3 -c "from app import app, db; from models import UpdateChannel; app.app_context().push(); c=UpdateChannel.query.filter_by(name='stable').first() or UpdateChannel(name='stable',github_repo='${GITHUB_REPO}',github_branch='${GITHUB_BRANCH}',github_token='${GITHUB_TOKEN}' or None,auto_check=True); db.session.add(c); db.session.commit(); print('Csatorna OK')" 2>/dev/null || true
}

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
    if [ "$IS_UPDATE" = true ]; then
        log_header "║   ✅ EPUB Fordító Frissítve: ${EXISTING_VERSION} → v${VERSION}                  ║"
    else
        log_header "║   🎉 EPUB Fordító v${VERSION} - Telepítve! 🎉                      ║"
    fi
    log_header "║   \"${CODENAME}\"                            ║"
    log_header "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🌐 Web:        http://localhost"
    echo "📧 Email UI:   http://localhost:8025"
    echo "👤 Regisztráció: http://localhost/register"
    echo "📚 Könyvtár:   http://localhost/admin/library"
    echo ""
    echo "👤 Admin:       ${ADMIN_EMAIL}"
    echo "🔑 Jelszó:      ${ADMIN_PASSWORD}"
    echo "🤖 Modell:      ${SELECTED_MODEL}"
    echo ""
    echo "🆕 v9.0: Felhasználói regisztráció, belső email, könyvtárkezelés"
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
    detect_installation_mode
    check_system_resources
    configure_system
    
    if [ "$IS_UPDATE" = true ]; then
        perform_update
    else
        perform_fresh_install
    fi
    
    show_summary
    log_success "Kész! 🚀"
}

main "$@"