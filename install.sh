#!/bin/bash

# EPUB Fordító Rendszer - Teljes Telepítő Script v7.0
# Verzió: 7.0.0
# Kódnév: "Self-Evolving Translator"
# Leírás: Automatikus GitHub frissítés, öntanuló rendszer, teljes PWA, kollaboráció

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
VERSION="7.0.0"
CODENAME="Self-Evolving Translator"
RELEASE_DATE="2024-09-15"

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

# Log függvények
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[FIGYELEM]${NC} $1"; }
log_error() { echo -e "${RED}[HIBA]${NC} $1"; }
log_step() { echo -e "\n${BLUE}═══ [LÉPÉS] $1 ═══${NC}"; echo "----------------------------------------"; }
log_success() { echo -e "${CYAN}[SIKER]${NC} $1"; }
log_config() { echo -e "${PURPLE}[KONFIG]${NC} $1"; }
log_header() { echo -e "${WHITE}$1${NC}"; }

# Jogosultság ellenőrzése
if [ "$EUID" -eq 0 ]; then 
    log_warn "Ne futtasd root-ként! Használj normál felhasználót sudo jogosultságokkal."
    exit 1
fi

# Rendszer erőforrások ellenőrzése
check_system_resources() {
    log_step "Rendszer erőforrások ellenőrzése"
    
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    log_info "Teljes memória: ${TOTAL_RAM}GB"
    
    if [ "$TOTAL_RAM" -lt 16 ]; then
        log_error "Minimum 16GB RAM szükséges! (Ajánlott: 32GB)"
        log_error "A rendszer nem telepíthető."
        exit 1
    elif [ "$TOTAL_RAM" -lt 32 ]; then
        log_warn "Az ajánlott 32GB RAM-nál kevesebb van."
        log_warn "Kisebb modell (deepseek-r1:7b) ajánlott."
        RECOMMENDED_MODEL="deepseek-r1:7b"
        MAX_WORKERS=2
    else
        RECOMMENDED_MODEL="deepseek-r1:8b"
        MAX_WORKERS=3
        log_info "Megfelelő memória (32GB+). Optimális teljesítmény várható."
    fi
    
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_info "Szabad lemezterület: ${FREE_SPACE}GB"
    
    if [ "$FREE_SPACE" -lt 50 ]; then
        log_warn "Kevés a szabad lemezterület (minimum 50GB ajánlott)"
        log_warn "A könyv adatbázis és fordítási memória sok helyet foglalhat."
    fi
    
    CPU_CORES=$(nproc)
    log_info "CPU magok száma: $CPU_CORES"
    
    if [ "$CPU_CORES" -lt 4 ]; then
        MAX_WORKERS=1
        log_warn "Kevés CPU mag. A fordítás lassabb lehet."
    elif [ "$CPU_CORES" -lt 8 ]; then
        MAX_WORKERS=2
    fi
    
    log_info "Ajánlott párhuzamos szálak: $MAX_WORKERS"
}

# Interaktív konfigurációs varázsló
configure_system() {
    log_step "Konfigurációs varázsló"
    
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════╗"
    log_header "║     EPUB Fordító v${VERSION} - \"${CODENAME}\"    ║"
    log_header "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "   🆕 v7.0 Újdonságok:"
    echo "   📡 Automatikus GitHub frissítés"
    echo "   🧠 Öntanuló fordítási memória"
    echo "   🔄 Verziókövetés és visszaállítás"
    echo "   📱 Teljes PWA mobil támogatás"
    echo "   👥 Valós idejű kollaboráció"
    echo "   🔊 Hangoskönyv generálás"
    echo "   🔌 Plugin rendszer"
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
        log_config "📡 GitHub Auto-Update beállítások:"
        read -p "   Automatikus frissítés engedélyezése? (i/n) [i]: " input
        ENABLE_AUTO_UPDATE=${input:-"i"}
        
        if [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]]; then
            read -p "   GitHub repository URL [${GITHUB_REPO}]: " input
            GITHUB_REPO=${input:-$GITHUB_REPO}
            read -p "   GitHub branch [${GITHUB_BRANCH}]: " input
            GITHUB_BRANCH=${input:-$GITHUB_BRANCH}
            read -sp "   GitHub Personal Access Token (opcionális): " input
            echo ""
            GITHUB_TOKEN=${input:-""}
            read -p "   Ellenőrzési intervallum másodpercben [${UPDATE_CHECK_INTERVAL}]: " input
            UPDATE_CHECK_INTERVAL=${input:-$UPDATE_CHECK_INTERVAL}
            
            if [ -n "$GITHUB_TOKEN" ]; then
                log_success "GitHub token megadva - privát repository is elérhető"
            else
                log_warn "Nincs GitHub token - csak publikus repository érhető el"
            fi
        fi
        
        echo ""
        log_config "📱 PWA (Progresszív Web App):"
        read -p "   PWA támogatás engedélyezése? (i/n) [i]: " input
        ENABLE_PWA=${input:-"i"}
        
        echo ""
        log_config "🔊 Hang (TTS - Text-to-Speech):"
        read -p "   Hangoskönyv generálás engedélyezése? (i/n) [i]: " input
        ENABLE_TTS=${input:-"i"}
        
        echo ""
        log_config "👥 Kollaboratív fordítás:"
        read -p "   Többfelhasználós fordítás engedélyezése? (i/n) [i]: " input
        ENABLE_COLLABORATION=${input:-"i"}
        
        echo ""
        log_config "🔌 Plugin rendszer:"
        read -p "   Plugin támogatás engedélyezése? (i/n) [i]: " input
        ENABLE_PLUGINS=${input:-"i"}
        
        echo ""
        log_config "🌐 REST API:"
        read -p "   API hozzáférés engedélyezése? (i/n) [i]: " input
        ENABLE_API=${input:-"i"}
        
        echo ""
        log_config "📚 Könyv adatbázis:"
        read -p "   Könyv adatbázis engedélyezése? (i/n) [i]: " input
        ENABLE_BOOK_DB=${input:-"i"}
        if [[ $ENABLE_BOOK_DB =~ ^[Ii]$ ]]; then
            read -p "   Online könyv keresés? (i/n) [i]: " input
            ENABLE_ONLINE_SEARCH=${input:-"i"}
            read -p "   Maximális mintakönyvek száma [${MAX_SAMPLE_BOOKS}]: " input
            MAX_SAMPLE_BOOKS=${input:-$MAX_SAMPLE_BOOKS}
        fi
        
        echo ""
        log_config "📧 Email beállítások:"
        configure_smtp
        
        echo ""
        log_config "⚡ Teljesítmény beállítások:"
        read -p "   Párhuzamos fordítási szálak [${MAX_WORKERS}]: " input
        MAX_WORKERS=${input:-$MAX_WORKERS}
        read -p "   Redis cache engedélyezése? (i/n) [i]: " input
        ENABLE_CACHE=${input:-"i"}
        
        echo ""
        log_config "🔒 Biztonsági beállítások:"
        read -p "   HTTPS/SSL engedélyezése? (i/n) [n]: " input
        ENABLE_SSL=${input:-"n"}
        read -p "   Monitoring eszközök telepítése? (i/n) [n]: " input
        INSTALL_MONITORING=${input:-"n"}
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
EOF

    log_success "Konfiguráció mentve!"
}

# Modell választás
select_model() {
    echo ""
    echo "   Válassz DeepSeek modellt:"
    echo "   ┌─────┬─────────────────────┬──────────┬─────────────┐"
    echo "   │  #  │ Modell              │ Méret    │ RAM igény   │"
    echo "   ├─────┼─────────────────────┼──────────┼─────────────┤"
    echo "   │  1  │ deepseek-r1:1.5b   │ 1.5 GB   │ 8 GB        │"
    echo "   │  2  │ deepseek-r1:7b     │ 7 GB     │ 16 GB       │"
    echo "   │  3  │ deepseek-r1:8b  ★  │ 8 GB     │ 32 GB       │"
    echo "   │  4  │ deepseek-r1:14b    │ 14 GB    │ 32 GB       │"
    echo "   │  5  │ deepseek-r1:32b    │ 32 GB    │ 64 GB       │"
    echo "   │  6  │ deepseek-r1:70b    │ 70 GB    │ 128 GB      │"
    echo "   └─────┴─────────────────────┴──────────┴─────────────┘"
    echo ""
    echo "   ★ Ajánlott: ${RECOMMENDED_MODEL} (a rendszered alapján)"
    echo ""
    read -p "   Választás [3]: " choice
    choice=${choice:-3}
    
    case $choice in
        1) SELECTED_MODEL="deepseek-r1:1.5b"; MODEL_SIZE="1.5GB";;
        2) SELECTED_MODEL="deepseek-r1:7b"; MODEL_SIZE="7GB";;
        3) SELECTED_MODEL="deepseek-r1:8b"; MODEL_SIZE="8GB";;
        4) SELECTED_MODEL="deepseek-r1:14b"; MODEL_SIZE="14GB";;
        5) SELECTED_MODEL="deepseek-r1:32b"; MODEL_SIZE="32GB";;
        6) SELECTED_MODEL="deepseek-r1:70b"; MODEL_SIZE="70GB";;
        *) SELECTED_MODEL="deepseek-r1:8b"; MODEL_SIZE="8GB";;
    esac
    
    log_success "Kiválasztva: ${SELECTED_MODEL} (${MODEL_SIZE})"
}

# SMTP konfiguráció
configure_smtp() {
    echo ""
    echo "   Válassz email kézbesítési módot:"
    echo "   1) Helyi (MailHog) - Fejlesztéshez"
    echo "   2) Gmail relay - Külső küldéshez"
    echo "   3) Egyéni SMTP - Saját szerver"
    read -p "   Választás [1]: " choice
    choice=${choice:-1}
    
    case $choice in
        1)
            SMTP_MODE="local"
            SMTP_HOST="mailhog"
            SMTP_PORT="1025"
            SMTP_USER=""
            SMTP_PASSWORD=""
            log_success "Helyi email (MailHog) - http://localhost:8025"
            ;;
        2)
            SMTP_MODE="gmail"
            SMTP_HOST="smtp.gmail.com"
            SMTP_PORT="587"
            read -p "   Gmail cím: " SMTP_USER
            read -sp "   Alkalmazás jelszó: " SMTP_PASSWORD
            echo ""
            log_success "Gmail relay beállítva"
            ;;
        3)
            SMTP_MODE="custom"
            read -p "   SMTP szerver: " SMTP_HOST
            read -p "   Port [587]: " SMTP_PORT
            SMTP_PORT=${SMTP_PORT:-587}
            read -p "   Felhasználónév: " SMTP_USER
            read -sp "   Jelszó: " SMTP_PASSWORD
            echo ""
            log_success "Egyéni SMTP beállítva"
            ;;
    esac
}

# Fő telepítés kezdete
PROJECT_DIR="$HOME/epub-translator"
BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"

clear
echo ""
log_header "╔══════════════════════════════════════════════════════════════════╗"
log_header "║                                                                  ║"
log_header "║     EPUB Fordító Rendszer v${VERSION}                              ║"
log_header "║     \"${CODENAME}\"                        ║"
log_header "║                                                                  ║"
log_header "║  🆕 GitHub Auto-Update       - Automatikus frissítések           ║"
log_header "║  🆕 Verziókövetés            - Frissítési előzmények             ║"
log_header "║  🆕 Visszaállítási pontok    - Biztonságos frissítés             ║"
log_header "║  🆕 Több frissítési csatorna - Stable, Beta, Nightly             ║"
log_header "║  📱 Teljes PWA               - Offline működés, push értesítések ║"
log_header "║  👥 Kollaboráció             - Valós idejű közös fordítás        ║"
log_header "║  🔊 TTS                      - Hangoskönyv generálás             ║"
log_header "║  🔌 Plugins                  - Bővíthető architektúra            ║"
log_header "║                                                                  ║"
log_header "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Rendszer ellenőrzése
if [ ! -f /etc/os-release ]; then
    log_error "Ez a script csak Ubuntu rendszeren működik!"
    exit 1
fi

source /etc/os-release
if [ "$ID" != "ubuntu" ]; then
    log_warn "Ez a script Ubuntu-ra van optimalizálva (${ID} észlelve)."
    read -p "Szeretnéd folytatni? (i/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]$ ]]; then
        exit 1
    fi
fi

# Ellenőrzések és konfiguráció
check_system_resources
configure_system

# ============================================================
# 1. RENDSZER FRISSÍTÉSE
# ============================================================
log_step "1/20 Rendszer frissítése és alapcsomagok telepítése"

log_info "Csomaglista frissítése..."
sudo apt update -qq

log_info "Rendszer frissítése..."
sudo apt upgrade -y -qq

log_info "Alapcsomagok telepítése..."
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
    nginx \
    openssl

log_info "Python csomagok telepítése..."
pip3 install --quiet pyyaml requests packaging 2>/dev/null || true

# ============================================================
# 2. DOCKER TELEPÍTÉSE
# ============================================================
log_step "2/20 Docker és Docker Compose telepítése"

if ! command -v docker &> /dev/null; then
    log_info "Docker GPG kulcs hozzáadása..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    
    log_info "Docker repository hozzáadása..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update -qq
    sudo apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    
    log_success "Docker telepítve"
    log_warn "A docker csoporttagság érvényesítéséhez jelentkezz ki és be!"
else
    log_info "Docker már telepítve: $(docker --version)"
fi

# ============================================================
# 3. CLAMAV FRISSÍTÉSE
# ============================================================
log_step "3/20 Vírusadatbázis frissítése"

log_info "ClamAV frissítése..."
sudo systemctl stop clamav-freshclam 2>/dev/null || true
sudo freshclam --quiet 2>/dev/null || log_warn "ClamAV frissítés nem sikerült (folytatás...)"

# ============================================================
# 4. PROJEKT STRUKTÚRA
# ============================================================
log_step "4/20 Projekt struktúra létrehozása"

if [ -d "$PROJECT_DIR" ]; then
    log_warn "Meglévő telepítés észlelve: $PROJECT_DIR"
    read -p "Szeretnéd biztonsági mentés után újratelepíteni? (i/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ii]$ ]]; then
        log_info "Biztonsági mentés készítése: $BACKUP_DIR"
        cp -r "$PROJECT_DIR" "$BACKUP_DIR" 2>/dev/null || true
        rm -rf "$PROJECT_DIR"
        log_success "Régi telepítés eltávolítva, mentés: $BACKUP_DIR"
    else
        log_info "Meglévő telepítés megtartva. Kilépés."
        exit 0
    fi
fi

log_info "Könyvtárak létrehozása..."
mkdir -p "$PROJECT_DIR"/{
    nginx/ssl,
    backend/{templates,utils,plugins/hooks,static},
    static/{css,js,images,icons,screenshots},
    uploads/{covers,books,temp},
    output,
    logs/{nginx,backend},
    backups,
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

cd "$PROJECT_DIR"

# ============================================================
# 5. KÖRNYEZETI VÁLTOZÓK
# ============================================================
log_step "5/20 Környezeti változók (.env) létrehozása"

cat > .env << ENVEOF
# ╔══════════════════════════════════════════════════════════════╗
# ║     EPUB Fordító v${VERSION} - Környezeti Változók         ║
# ╚══════════════════════════════════════════════════════════════╝

# Alkalmazás
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
BATCH_SIZE=5
TRANSLATION_TIMEOUT=600

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

# VAPID (Web Push)
VAPID_PRIVATE_KEY=
VAPID_PUBLIC_KEY=
VAPID_CLAIMS_EMAIL=${ADMIN_EMAIL}

# SSL
SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
SSL_KEY_PATH=/etc/nginx/ssl/key.pem
ENVEOF

log_success ".env fájl létrehozva (SECRET_KEY: $(openssl rand -hex 8)...)"

# ============================================================
# 6. SSL TANÚSÍTVÁNY
# ============================================================
log_step "6/20 SSL tanúsítvány (opcionális)"

if [[ $ENABLE_SSL =~ ^[Ii]$ ]]; then
    log_info "Önaláírt SSL tanúsítvány generálása..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/key.pem \
        -out nginx/ssl/cert.pem \
        -subj "/C=HU/ST=Budapest/L=Budapest/O=EPUB Translator/CN=localhost" 2>/dev/null
    log_success "SSL tanúsítvány létrehozva"
else
    log_info "SSL kihagyva"
fi

# ============================================================
# 7. DOCKER COMPOSE (v7.0)
# ============================================================
log_step "7/20 Docker Compose konfiguráció létrehozása"

cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'

services:
  # Web szerver
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

  # Fő backend
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

  # Adatbázis
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

  # AI Modell szerver
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

  # Cache
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

  # Helyi email (alapértelmezett)
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

  # TTS szolgáltatás
  tts-service:
    build: ./tts-service
    container_name: epub-tts
    volumes:
      - ./tts-service:/app
      - epub_output:/app/output
    environment:
      - BACKEND_URL=http://backend:5000
    networks:
      - translator-network
    restart: unless-stopped
    profiles:
      - tts
      - all

  # WebSocket kollaborációhoz
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

  # Monitoring (opcionális)
  prometheus:
    image: prom/prometheus:latest
    container_name: epub-prometheus
    volumes:
      - ./scripts/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - translator-network
    restart: unless-stopped
    profiles:
      - monitoring
      - all

  grafana:
    image: grafana/grafana:latest
    container_name: epub-grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-clock-panel
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - translator-network
    restart: unless-stopped
    profiles:
      - monitoring
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
  prometheus_data:
  grafana_data:
DOCKEREOF

log_success "docker-compose.yml létrehozva"

# ============================================================
# 8. NGINX KONFIGURÁCIÓ
# ============================================================
log_step "8/20 Nginx konfiguráció létrehozása"

cat > nginx/nginx.conf << 'NGINXEOF'
events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    # Alap beállítások
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Naplózás
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;
    
    # Fájl feltöltés limit
    client_max_body_size 100M;
    client_body_timeout 600s;
    
    # Biztonsági fejlécek
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-EPUB-Translator-Version "7.0" always;
    add_header Service-Worker-Allowed "/" always;
    
    # Rate limiting zónák
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=upload_limit:10m rate=20r/m;
    limit_conn_zone $binary_remote_addr zone=conn_limit:10m;
    
    # Gzip tömörítés
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
    
    server {
        listen 80;
        server_name localhost;
        
        # Kapcsolat limit
        limit_conn conn_limit 10;
        
        # Health check
        location /health {
            return 200 "OK";
        }
        
        # PWA manifest
        location = /manifest.json {
            alias /usr/share/nginx/html/static/manifest.json;
            add_header Content-Type application/json;
            add_header Cache-Control "no-cache";
        }
        
        # Service Worker
        location = /sw.js {
            alias /usr/share/nginx/html/static/js/sw.js;
            add_header Content-Type application/javascript;
            add_header Cache-Control "no-cache";
            add_header Service-Worker-Allowed "/";
        }
        
        # Offline oldal
        location = /offline.html {
            alias /usr/share/nginx/html/static/offline.html;
            add_header Cache-Control "no-cache";
        }
        
        # API végpontok
        location /api/ {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 600s;
            proxy_send_timeout 600s;
            proxy_read_timeout 600s;
        }
        
        # Fordítási végpont (limitált)
        location /api/translate {
            limit_req zone=upload_limit burst=5 nodelay;
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
        }
        
        # Bejelentkezés (limitált)
        location /login {
            limit_req zone=login_limit burst=3 nodelay;
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        # WebSocket (kollaboráció)
        location /ws/ {
            proxy_pass http://websocket:3001;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_read_timeout 86400;
        }
        
        # Statikus fájlok
        location /static {
            alias /usr/share/nginx/html/static;
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
        
        # Minden más a backend-re
        location / {
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 600s;
            proxy_send_timeout 600s;
            proxy_read_timeout 600s;
        }
    }
}
NGINXEOF

log_success "Nginx konfiguráció létrehozva"

# ============================================================
# 9. OLLAMA DOCKERFILE
# ============================================================
log_step "9/20 Ollama Dockerfile létrehozása"

mkdir -p ollama
cat > ollama/Dockerfile << 'OLLAMAEOF'
FROM ollama/ollama:latest

COPY healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh || exit 1

EXPOSE 11434
OLLAMAEOF

cat > ollama/healthcheck.sh << 'HCEOF'
#!/bin/bash
curl -f http://localhost:11434/api/tags 2>/dev/null || exit 1
HCEOF
chmod +x ollama/healthcheck.sh

# ============================================================
# 10. BACKEND DOCKERFILE
# ============================================================
log_step "10/20 Backend Dockerfile létrehozása"

cat > backend/Dockerfile << 'BACKENDEOF'
FROM python:3.10-slim

WORKDIR /app

# Rendszer függőségek
RUN apt-get update && apt-get install -y \
    gcc libxml2-dev libxslt-dev curl git espeak ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Python függőségek
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Alkalmazás
COPY . .

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

EXPOSE 5000

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app", "--timeout", "600", "--worker-class", "eventlet", "--access-logfile", "/app/logs/access.log", "--error-logfile", "/app/logs/error.log"]
BACKENDEOF

# ============================================================
# 11. BACKEND REQUIREMENTS
# ============================================================
log_step "11/20 Backend requirements.txt létrehozása"

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
gTTS==2.3.2
pyttsx3==2.90
pywebpush==1.14.0
GitPython==3.1.40
packaging==23.2
semver==3.0.2
REQEOF

log_success "requirements.txt létrehozva"

# ============================================================
# 12. BACKEND KONFIGURÁCIÓ
# ============================================================
log_step "12/20 Backend konfigurációs fájlok létrehozása"

cat > backend/config.py << 'CONFIGEOF'
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Verzió
    VERSION = os.environ.get('VERSION', '7.0.0')
    CODENAME = os.environ.get('CODENAME', 'Self-Evolving Translator')
    
    # Alap
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Ollama
    OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://localhost:11434')
    DEFAULT_MODEL = os.environ.get('SELECTED_MODEL', 'deepseek-r1:8b')
    AVAILABLE_MODELS = [
        'deepseek-r1:1.5b', 'deepseek-r1:7b', 'deepseek-r1:8b',
        'deepseek-r1:14b', 'deepseek-r1:32b', 'deepseek-r1:70b'
    ]
    
    # Email
    SMTP_MODE = os.environ.get('SMTP_MODE', 'local')
    MAIL_SERVER = os.environ.get('SMTP_HOST', 'mailhog')
    MAIL_PORT = int(os.environ.get('SMTP_PORT', 1025))
    MAIL_USE_TLS = os.environ.get('SMTP_USE_TLS', 'false').lower() == 'true'
    MAIL_USERNAME = os.environ.get('SMTP_USER', '') or None
    MAIL_PASSWORD = os.environ.get('SMTP_PASSWORD', '') or None
    MAIL_DEFAULT_SENDER = os.environ.get('MAIL_DEFAULT_SENDER', 'epub-translator@localhost')
    
    # Funkciók
    ENABLE_PWA = os.environ.get('ENABLE_PWA', 'i').lower() == 'i'
    ENABLE_TTS = os.environ.get('ENABLE_TTS', 'i').lower() == 'i'
    ENABLE_COLLABORATION = os.environ.get('ENABLE_COLLABORATION', 'i').lower() == 'i'
    ENABLE_PLUGINS = os.environ.get('ENABLE_PLUGINS', 'i').lower() == 'i'
    ENABLE_API = os.environ.get('ENABLE_API', 'i').lower() == 'i'
    ENABLE_BOOK_DB = os.environ.get('ENABLE_BOOK_DB', 'i').lower() == 'i'
    ENABLE_CACHE = os.environ.get('ENABLE_CACHE', 'i').lower() == 'i'
    ENABLE_ONLINE_SEARCH = os.environ.get('ENABLE_ONLINE_SEARCH', 'i').lower() == 'i'
    
    # Auto-Update
    ENABLE_AUTO_UPDATE = os.environ.get('ENABLE_AUTO_UPDATE', 'i').lower() == 'i'
    GITHUB_REPO = os.environ.get('GITHUB_REPO', '')
    GITHUB_BRANCH = os.environ.get('GITHUB_BRANCH', 'main')
    GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN', '') or None
    UPDATE_CHECK_INTERVAL = int(os.environ.get('UPDATE_CHECK_INTERVAL', 3600))
    
    # Fordítás
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    MAX_SAMPLE_BOOKS = int(os.environ.get('MAX_SAMPLE_BOOKS', 5))
    BATCH_SIZE = int(os.environ.get('BATCH_SIZE', 5))
    TRANSLATION_TIMEOUT = int(os.environ.get('TRANSLATION_TIMEOUT', 600))
    
    # Elérési utak
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    BOOK_DB_PATH = '/app/book_database'
    TM_PATH = '/app/translation_memory'
    GLOSSARY_PATH = '/app/glossaries'
    PLUGIN_PATH = '/app/plugins'
    COLLAB_PATH = '/app/collaboration'
    UPDATE_PATH = '/app/updates'
    LOG_FOLDER = '/app/logs'
    
    # Admin
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    
    # Redis
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
    
    # Rate limiting
    RATELIMIT_DEFAULT = "200 per day;50 per hour"
    RATELIMIT_STORAGE_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
    
    # VAPID (Web Push)
    VAPID_PRIVATE_KEY = os.environ.get('VAPID_PRIVATE_KEY', '')
    VAPID_PUBLIC_KEY = os.environ.get('VAPID_PUBLIC_KEY', '')
    VAPID_CLAIMS_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    
    # Fájl méret limit
    MAX_CONTENT_LENGTH = int(os.environ.get('MAX_CONTENT_LENGTH', 104857600))
CONFIGEOF

log_success "config.py létrehozva"

# ============================================================
# 13. BACKEND MODELLEK
# ============================================================
log_step "13/20 Backend modellek létrehozása"

cat > backend/models.py << 'MODELSEOF'
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
import json
import secrets
import uuid

db = SQLAlchemy()

# Kapcsoló táblák
book_authors = db.Table('book_authors',
    db.Column('book_id', db.Integer, db.ForeignKey('books.id'), primary_key=True),
    db.Column('author_id', db.Integer, db.ForeignKey('authors.id'), primary_key=True)
)

collaboration_participants = db.Table('collaboration_participants',
    db.Column('session_id', db.Integer, db.ForeignKey('collaboration_sessions.id'), primary_key=True),
    db.Column('user_id', db.Integer, db.ForeignKey('users.id'), primary_key=True)
)

# ==================== ALAP MODELLEK ====================

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(80))
    last_name = db.Column(db.String(80))
    zip_code = db.Column(db.String(10))
    city = db.Column(db.String(100))
    street = db.Column(db.String(200))
    house_number = db.Column(db.String(20))
    tax_number = db.Column(db.String(50))
    tokens = db.Column(db.Integer, default=0)
    is_admin = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    two_factor_enabled = db.Column(db.Boolean, default=False)
    two_factor_secret = db.Column(db.String(32))
    last_login = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    translations = db.relationship('Translation', backref='user', lazy=True)
    api_keys = db.relationship('ApiKey', backref='user', lazy=True)
    push_subscriptions = db.relationship('PushSubscription', backref='user', lazy=True)

class Book(db.Model):
    __tablename__ = 'books'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(500))
    isbn = db.Column(db.String(20), unique=True, nullable=True)
    publisher = db.Column(db.String(200))
    publication_year = db.Column(db.Integer)
    language = db.Column(db.String(10))
    genre = db.Column(db.String(100))
    sub_genre = db.Column(db.String(100))
    writing_style = db.Column(db.String(100))
    complexity_level = db.Column(db.String(20))
    word_count = db.Column(db.Integer)
    chapter_count = db.Column(db.Integer)
    file_size = db.Column(db.Integer)
    file_hash = db.Column(db.String(64), unique=True)
    file_path = db.Column(db.String(500))
    description = db.Column(db.Text)
    cover_image = db.Column(db.String(500))
    tags = db.Column(db.Text)
    use_count = db.Column(db.Integer, default=0)
    context_weight = db.Column(db.Float, default=0.5)
    first_uploaded = db.Column(db.DateTime, default=datetime.utcnow)
    last_used = db.Column(db.DateTime)
    
    authors = db.relationship('Author', secondary=book_authors, backref='books')
    translations = db.relationship('BookTranslation', backref='book', lazy=True)
    sample_usages = db.relationship('SampleBookUsage', backref='book', lazy=True)

class Author(db.Model):
    __tablename__ = 'authors'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(300), unique=True)
    birth_year = db.Column(db.Integer)
    nationality = db.Column(db.String(100))
    writing_style = db.Column(db.String(500))
    common_genres = db.Column(db.Text)

class Translation(db.Model):
    __tablename__ = 'translations'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    original_filename = db.Column(db.String(255))
    output_filename = db.Column(db.String(255))
    status = db.Column(db.String(50), default='pending')
    error_message = db.Column(db.Text)
    progress = db.Column(db.Integer, default=0)
    total_paragraphs = db.Column(db.Integer, default=0)
    translated_paragraphs = db.Column(db.Integer, default=0)
    model_used = db.Column(db.String(100))
    translation_time = db.Column(db.Integer)
    quality_score = db.Column(db.Integer)
    hybrid_score = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    completed_at = db.Column(db.DateTime)
    sample_books = db.Column(db.Text)
    sample_books_metadata = db.Column(db.Text)
    audio_file = db.Column(db.String(500))

class BookTranslation(db.Model):
    __tablename__ = 'book_translations'
    id = db.Column(db.Integer, primary_key=True)
    book_id = db.Column(db.Integer, db.ForeignKey('books.id'))
    translation_id = db.Column(db.Integer, db.ForeignKey('translations.id'))
    translated_text_path = db.Column(db.String(500))
    quality_score = db.Column(db.Integer)
    translation_model = db.Column(db.String(100))
    translation_time = db.Column(db.Integer)
    sample_books_used = db.Column(db.Text)
    context_score = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class SampleBookUsage(db.Model):
    __tablename__ = 'sample_book_usages'
    id = db.Column(db.Integer, primary_key=True)
    book_id = db.Column(db.Integer, db.ForeignKey('books.id'))
    used_for_translation_id = db.Column(db.Integer, db.ForeignKey('translations.id'))
    relevance_score = db.Column(db.Float)
    paragraphs_used = db.Column(db.Integer)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class ActivityLog(db.Model):
    __tablename__ = 'activity_logs'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    action = db.Column(db.String(100))
    details = db.Column(db.Text)
    ip_address = db.Column(db.String(45))
    user_agent = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class ApiKey(db.Model):
    __tablename__ = 'api_keys'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    key = db.Column(db.String(64), unique=True, default=lambda: secrets.token_hex(32))
    name = db.Column(db.String(100))
    is_active = db.Column(db.Boolean, default=True)
    last_used = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==================== FORDÍTÁSI MEMÓRIA ====================

class TranslationMemory(db.Model):
    __tablename__ = 'translation_memory'
    id = db.Column(db.Integer, primary_key=True)
    source_text = db.Column(db.Text, nullable=False)
    source_hash = db.Column(db.String(64), unique=True, nullable=False)
    translated_text = db.Column(db.Text, nullable=False)
    source_language = db.Column(db.String(10))
    target_language = db.Column(db.String(10))
    context = db.Column(db.Text)
    quality_score = db.Column(db.Integer, default=100)
    usage_count = db.Column(db.Integer, default=1)
    last_used = db.Column(db.DateTime, default=datetime.utcnow)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==================== GLOSSZÁRIUM ====================

class Glossary(db.Model):
    __tablename__ = 'glossaries'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200))
    domain = db.Column(db.String(100))
    source_language = db.Column(db.String(10))
    target_language = db.Column(db.String(10))
    created_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    is_public = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class GlossaryTerm(db.Model):
    __tablename__ = 'glossary_terms'
    id = db.Column(db.Integer, primary_key=True)
    glossary_id = db.Column(db.Integer, db.ForeignKey('glossaries.id'))
    source_term = db.Column(db.String(500), nullable=False)
    target_term = db.Column(db.String(500), nullable=False)
    context = db.Column(db.Text)
    notes = db.Column(db.Text)
    approved = db.Column(db.Boolean, default=True)

# ==================== KOLLABORÁCIÓ ====================

class CollaborationSession(db.Model):
    __tablename__ = 'collaboration_sessions'
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.String(36), unique=True, default=lambda: str(uuid.uuid4()))
    translation_id = db.Column(db.Integer, db.ForeignKey('translations.id'))
    owner_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    status = db.Column(db.String(20), default='active')
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    closed_at = db.Column(db.DateTime)
    
    participants = db.relationship('User', secondary=collaboration_participants, backref='collaborations')
    suggestions = db.relationship('TranslationSuggestion', backref='session', lazy=True)
    comments = db.relationship('CollaborationComment', backref='session', lazy=True)

class TranslationSuggestion(db.Model):
    __tablename__ = 'translation_suggestions'
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey('collaboration_sessions.id'))
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    paragraph_index = db.Column(db.Integer)
    suggestion = db.Column(db.Text)
    votes = db.Column(db.Integer, default=0)
    is_accepted = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class CollaborationComment(db.Model):
    __tablename__ = 'collaboration_comments'
    id = db.Column(db.Integer, primary_key=True)
    session_id = db.Column(db.Integer, db.ForeignKey('collaboration_sessions.id'))
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    paragraph_index = db.Column(db.Integer)
    comment = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==================== PUSH ÉRTESÍTÉSEK ====================

class PushSubscription(db.Model):
    __tablename__ = 'push_subscriptions'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    subscription_json = db.Column(db.Text)
    device_type = db.Column(db.String(50))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ==================== FRISSÍTÉSI RENDSZER ====================

class UpdateChannel(db.Model):
    __tablename__ = 'update_channels'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    github_repo = db.Column(db.String(500))
    github_branch = db.Column(db.String(100), default='main')
    github_token = db.Column(db.String(255))
    auto_check = db.Column(db.Boolean, default=True)
    check_interval = db.Column(db.Integer, default=3600)
    last_check = db.Column(db.DateTime)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime)

class UpdateLog(db.Model):
    __tablename__ = 'update_logs'
    id = db.Column(db.Integer, primary_key=True)
    channel_id = db.Column(db.Integer, db.ForeignKey('update_channels.id'))
    from_version = db.Column(db.String(20))
    to_version = db.Column(db.String(20))
    status = db.Column(db.String(50))
    details = db.Column(db.Text)
    changelog = db.Column(db.Text)
    started_at = db.Column(db.DateTime)
    completed_at = db.Column(db.DateTime)
    triggered_by = db.Column(db.Integer, db.ForeignKey('users.id'))
    is_automatic = db.Column(db.Boolean, default=False)
    
    channel = db.relationship('UpdateChannel', backref='logs')

class SystemVersion(db.Model):
    __tablename__ = 'system_versions'
    id = db.Column(db.Integer, primary_key=True)
    version = db.Column(db.String(20), unique=True)
    release_date = db.Column(db.DateTime)
    changelog = db.Column(db.Text)
    is_current = db.Column(db.Boolean, default=False)
    is_stable = db.Column(db.Boolean, default=True)
    download_url = db.Column(db.String(500))
    file_hash = db.Column(db.String(64))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class BackupPoint(db.Model):
    __tablename__ = 'backup_points'
    id = db.Column(db.Integer, primary_key=True)
    version = db.Column(db.String(20))
    description = db.Column(db.String(500))
    backup_path = db.Column(db.String(500))
    db_backup_path = db.Column(db.String(500))
    config_backup_path = db.Column(db.String(500))
    size_bytes = db.Column(db.BigInteger)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    created_by = db.Column(db.Integer, db.ForeignKey('users.id'))

# ==================== PLUGIN RENDSZER ====================

class Plugin(db.Model):
    __tablename__ = 'plugins'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True)
    version = db.Column(db.String(20))
    description = db.Column(db.Text)
    author = db.Column(db.String(200))
    enabled = db.Column(db.Boolean, default=True)
    config = db.Column(db.Text)
    installed_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime)
MODELSEOF

log_success "models.py létrehozva"

# ============================================================
# 14-16. TOVÁBBI BACKEND FÁJLOK
# ============================================================
log_step "14/20 Backend segédfájlok létrehozása"

# __init__.py
touch backend/utils/__init__.py

# app.py - Alap alkalmazás
cat > backend/app.py << 'APPEOF'
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, send_file
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from config import Config
from models import db, User, Translation, ActivityLog
from datetime import datetime
from functools import wraps
import os
import json

app = Flask(__name__)
app.config.from_object(Config)

# Adatbázis
db.init_app(app)

# Login
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

# ==================== SEGÉDFÜGGVÉNYEK ====================

def admin_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not current_user.is_authenticated or not current_user.is_admin:
            flash('Admin jogosultság szükséges!', 'error')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated_function

def log_activity(action, details=""):
    if current_user.is_authenticated:
        activity = ActivityLog(
            user_id=current_user.id,
            action=action,
            details=details,
            ip_address=request.remote_addr
        )
        db.session.add(activity)
        db.session.commit()

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# ==================== ALAP ÚTVONALAK ====================

@app.route('/health')
def health_check():
    return jsonify({
        'status': 'healthy',
        'version': app.config['VERSION'],
        'codename': app.config['CODENAME'],
        'timestamp': datetime.utcnow().isoformat()
    })

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
            log_activity('login', 'Sikeres bejelentkezés')
            
            if user.is_admin:
                return redirect(url_for('admin'))
            return redirect(url_for('dashboard'))
        
        flash('Hibás email cím vagy jelszó!', 'error')
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    log_activity('logout', 'Kijelentkezés')
    logout_user()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    if current_user.is_admin:
        return redirect(url_for('admin'))
    translations = Translation.query.filter_by(user_id=current_user.id).order_by(Translation.created_at.desc()).all()
    return render_template('dashboard.html', user=current_user, translations=translations)

@app.route('/admin')
@login_required
@admin_required
def admin():
    return render_template('admin.html')

# ==================== ADATBÁZIS INICIALIZÁLÁS ====================

def init_db():
    with app.app_context():
        db.create_all()
        
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(
                username='admin',
                email=Config.ADMIN_EMAIL,
                password_hash=generate_password_hash(Config.ADMIN_PASSWORD),
                first_name='Admin',
                last_name='User',
                is_admin=True,
                tokens=999999
            )
            db.session.add(admin)
            
            # Alapértelmezett verzió
            from models import SystemVersion
            version = SystemVersion(
                version=Config.VERSION,
                release_date=datetime.utcnow(),
                changelog='Kezdeti telepítés',
                is_current=True,
                is_stable=True
            )
            db.session.add(version)
            
            db.session.commit()
            app.logger.info('Adatbázis inicializálva')

if __name__ == '__main__':
    init_db()
    app.run(debug=False, host='0.0.0.0', port=5000)
APPEOF

log_success "app.py létrehozva"

# ============================================================
# 17. PWA FÁJLOK
# ============================================================
log_step "17/20 PWA fájlok létrehozása"

# manifest.json
cat > static/manifest.json << 'MANIFESTEOF'
{
    "name": "EPUB Fordító v7.0",
    "short_name": "EPUB Fordító",
    "description": "Ingyenes, helyben futó, öntanuló könyvfordító rendszer",
    "start_url": "/",
    "display": "standalone",
    "background_color": "#1a1a2e",
    "theme_color": "#16213e",
    "orientation": "any",
    "icons": [
        {"src": "/static/icons/icon-72x72.png", "sizes": "72x72", "type": "image/png"},
        {"src": "/static/icons/icon-96x96.png", "sizes": "96x96", "type": "image/png"},
        {"src": "/static/icons/icon-128x128.png", "sizes": "128x128", "type": "image/png"},
        {"src": "/static/icons/icon-144x144.png", "sizes": "144x144", "type": "image/png"},
        {"src": "/static/icons/icon-152x152.png", "sizes": "152x152", "type": "image/png"},
        {"src": "/static/icons/icon-192x192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable"},
        {"src": "/static/icons/icon-384x384.png", "sizes": "384x384", "type": "image/png"},
        {"src": "/static/icons/icon-512x512.png", "sizes": "512x512", "type": "image/png"}
    ],
    "categories": ["books", "education", "utilities"],
    "lang": "hu-HU",
    "shortcuts": [
        {
            "name": "Új fordítás",
            "url": "/upload",
            "icons": [{"src": "/static/icons/upload.png", "sizes": "96x96"}]
        },
        {
            "name": "Könyveim",
            "url": "/translations",
            "icons": [{"src": "/static/icons/books.png", "sizes": "96x96"}]
        }
    ]
}
MANIFESTEOF

# Service Worker
cat > static/js/sw.js << 'SWEOF'
const CACHE_NAME = 'epub-translator-v7';
const RUNTIME = 'epub-translator-runtime';

const PRECACHE = [
    '/', '/offline.html',
    '/static/css/style.css',
    '/static/js/main.js',
    '/static/js/pwa.js',
    '/static/icons/icon-192x192.png',
    '/static/icons/icon-512x512.png'
];

self.addEventListener('install', e => {
    e.waitUntil(
        caches.open(CACHE_NAME)
            .then(cache => cache.addAll(PRECACHE))
            .then(() => self.skipWaiting())
    );
});

self.addEventListener('activate', e => {
    e.waitUntil(
        caches.keys().then(keys => {
            return Promise.all(
                keys.filter(key => key !== CACHE_NAME && key !== RUNTIME)
                    .map(key => caches.delete(key))
            );
        }).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', e => {
    if (e.request.url.includes('/api/')) {
        e.respondWith(networkFirst(e.request));
    } else {
        e.respondWith(cacheFirst(e.request));
    }
});

async function cacheFirst(request) {
    const cached = await caches.match(request);
    if (cached) return cached;
    
    try {
        const response = await fetch(request);
        const cache = await caches.open(RUNTIME);
        cache.put(request, response.clone());
        return response;
    } catch {
        return caches.match('/offline.html');
    }
}

async function networkFirst(request) {
    try {
        const response = await fetch(request);
        const cache = await caches.open(RUNTIME);
        cache.put(request, response.clone());
        return response;
    } catch {
        return caches.match(request);
    }
}

self.addEventListener('push', e => {
    const data = e.data.json();
    e.waitUntil(
        self.registration.showNotification(data.title, {
            body: data.body,
            icon: '/static/icons/icon-192x192.png',
            badge: '/static/icons/icon-72x72.png',
            data: { url: data.url || '/' }
        })
    );
});

self.addEventListener('notificationclick', e => {
    e.notification.close();
    e.waitUntil(clients.openWindow(e.notification.data.url));
});

self.addEventListener('sync', e => {
    if (e.tag === 'sync-translations') {
        e.waitUntil(syncTranslations());
    }
});

async function syncTranslations() {
    const cache = await caches.open(RUNTIME);
    const requests = await cache.keys();
    for (const req of requests) {
        if (req.url.includes('/api/translation/')) {
            try {
                const res = await fetch(req.url);
                await cache.put(req, res);
            } catch {}
        }
    }
}
SWEOF

# Offline oldal
cat > static/offline.html << 'OFFLINEEOF'
<!DOCTYPE html>
<html lang="hu">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Offline - EPUB Fordító</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, #1a1a2e, #16213e);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255,255,255,0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        .icon { font-size: 5rem; margin-bottom: 1rem; }
        h1 { font-size: 2rem; margin-bottom: 1rem; }
        p { color: #ccc; margin-bottom: 1rem; }
        button {
            padding: 12px 30px;
            background: #e94560;
            color: white;
            border: none;
            border-radius: 25px;
            font-size: 1rem;
            cursor: pointer;
            transition: 0.3s;
        }
        button:hover { background: #c23152; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📡</div>
        <h1>Offline Mód</h1>
        <p>Jelenleg nincs internetkapcsolat.</p>
        <p>A korábban megnyitott oldalak továbbra is elérhetők.</p>
        <button onclick="location.reload()">Újrapróbálkozás</button>
    </div>
</body>
</html>
OFFLINEEOF

# PWA JavaScript
cat > static/js/pwa.js << 'PWAJSEOF'
let deferredPrompt;

window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e;
    
    const btn = document.getElementById('installBtn');
    if (btn) {
        btn.style.display = 'block';
        btn.addEventListener('click', async () => {
            deferredPrompt.prompt();
            const { outcome } = await deferredPrompt.userChoice;
            console.log(`Telepítés: ${outcome}`);
            deferredPrompt = null;
        });
    }
});

window.addEventListener('appinstalled', () => {
    console.log('PWA telepítve!');
});

if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
            .then(reg => console.log('SW regisztrálva:', reg.scope))
            .catch(err => console.log('SW hiba:', err));
    });
}

async function subscribeToPush() {
    try {
        const reg = await navigator.serviceWorker.ready;
        const sub = await reg.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: 'YOUR_PUBLIC_KEY'
        });
        await fetch('/api/push/subscribe', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(sub)
        });
    } catch (e) {
        console.error('Push hiba:', e);
    }
}

async function requestNotificationPermission() {
    if (!('Notification' in window)) return;
    const perm = await Notification.requestPermission();
    if (perm === 'granted') await subscribeToPush();
}

window.addEventListener('online', () => {
    document.body.classList.remove('offline');
});

window.addEventListener('offline', () => {
    document.body.classList.add('offline');
});
PWAJSEOF

log_success "PWA fájlok létrehozva"

# ============================================================
# 18. PWA IKONOK
# ============================================================
log_step "18/20 PWA ikonok generálása"

mkdir -p static/icons
for size in 72 96 128 144 152 192 384 512; do
    if command -v python3 &> /dev/null; then
        python3 -c "
from PIL import Image, ImageDraw
size = ${size}
img = Image.new('RGB', (size, size), '#16213e')
draw = ImageDraw.Draw(img)
# Egyszerű könyv ikon
margin = size // 4
draw.rectangle([margin, margin//2, size-margin, size-margin//2], fill='#e94560')
draw.rectangle([size//3, margin//2, 2*size//3, size-margin//2], fill='white')
img.save('static/icons/icon-${size}x${size}.png')
print(f'Icon ${size}x${size} created')
" 2>/dev/null || echo "Placeholder: ${size}x${size}" > "static/icons/icon-${size}x${size}.png"
    else
        echo "Placeholder: ${size}x${size}" > "static/icons/icon-${size}x${size}.png"
    fi
done

log_success "PWA ikonok létrehozva"

# ============================================================
# 19. SEGÉDSCRIPTEK
# ============================================================
log_step "19/20 Segédscriptek létrehozása"

cat > scripts/backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="$HOME/epub-backups"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y%m%d_%H%M%S)

echo "📦 EPUB Fordító v7.0 - Biztonsági mentés"
echo "========================================"

echo "1/4 Adatbázis mentése..."
docker exec epub-postgres pg_dump -U epub_user epub_translator > "$BACKUP_DIR/db_$DATE.sql" 2>/dev/null

echo "2/4 Konfiguráció mentése..."
cp "$HOME/epub-translator/.env" "$BACKUP_DIR/env_$DATE" 2>/dev/null

echo "3/4 Fordítási memória mentése..."
if [ -d "$HOME/epub-translator/translation_memory" ]; then
    tar -czf "$BACKUP_DIR/tm_$DATE.tar.gz" -C "$HOME/epub-translator" translation_memory/ 2>/dev/null
fi

echo "4/4 Könyv adatbázis mentése..."
if [ -d "$HOME/epub-translator/book_database" ]; then
    tar -czf "$BACKUP_DIR/books_$DATE.tar.gz" -C "$HOME/epub-translator" book_database/ 2>/dev/null
fi

echo ""
echo "✅ Mentés kész: $BACKUP_DIR"
ls -lh "$BACKUP_DIR" | grep "$DATE"
BACKUPEOF

cat > scripts/status.sh << 'STATUSEOF'
#!/bin/bash
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     EPUB Fordító v7.0 - Rendszer Állapot                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Konténerek:"
docker compose ps 2>/dev/null
echo ""
echo "💾 Lemez:"
df -h / | tail -1
echo ""
echo "🧠 Memória:"
free -h | head -2
echo ""
echo "🤖 Modell:"
docker exec epub-ollama ollama list 2>/dev/null || echo "  Nem elérhető"
echo ""
echo "📧 Email: http://localhost:8025"
echo "🌐 Web:   http://localhost"
echo ""
STATUSEOF

cat > scripts/update.sh << 'UPDATEEOF'
#!/bin/bash
echo "🔄 EPUB Fordító - Frissítés"
echo "============================"

cd "$HOME/epub-translator"

echo "1/3 GitHub repository frissítése..."
git pull origin main 2>/dev/null || echo "  Git nem elérhető, docker compose build..."

echo "2/3 Konténerek újraépítése..."
docker compose down 2>/dev/null
docker compose build --no-cache 2>/dev/null

echo "3/3 Konténerek indítása..."
docker compose up -d

echo ""
echo "✅ Frissítés kész!"
echo "   Verzió ellenőrzése: http://localhost/health"
UPDATEEOF

chmod +x scripts/*.sh

log_success "Segédscriptek létrehozva"

# ============================================================
# 20. KONTÉNEREK INDÍTÁSA ÉS TELEPÍTÉS BEFEJEZÉSE
# ============================================================
log_step "20/20 Konténerek indítása és telepítés befejezése"

# Profil kiválasztása
COMPOSE_PROFILE="local"
[[ $ENABLE_TTS =~ ^[Ii]$ ]] && COMPOSE_PROFILE="$COMPOSE_PROFILE,tts"
[[ $ENABLE_COLLABORATION =~ ^[Ii]$ ]] && COMPOSE_PROFILE="$COMPOSE_PROFILE,collab"
[[ $INSTALL_MONITORING =~ ^[Ii]$ ]] && COMPOSE_PROFILE="$COMPOSE_PROFILE,monitoring"

log_info "Profil: $COMPOSE_PROFILE"
log_info "Konténerek építése..."
docker compose build 2>/dev/null || log_warn "Build warningok (folytatás)"

log_info "Konténerek indítása..."
docker compose up -d 2>/dev/null

log_info "Várakozás az indulásra (30 másodperc)..."
sleep 30

# Modell letöltése
log_info "AI modell letöltése: $SELECTED_MODEL"
log_warn "Ez 10-30 percig is eltarthat a modell méretétől függően!"
docker exec -it epub-ollama ollama pull "$SELECTED_MODEL" 2>/dev/null || log_warn "Modell letöltés figyelmeztetés (lehet, hogy már megvan)"

# Adatbázis inicializálása
log_info "Adatbázis inicializálása..."
sleep 10
docker exec -it epub-backend python3 -c "
from app import app, db, init_db
with app.app_context():
    init_db()
    print('Adatbázis inicializálva')
" 2>/dev/null || log_warn "Adatbázis inicializálás figyelmeztetés"

# Frissítési csatorna beállítása
if [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && [ -n "$GITHUB_REPO" ]; then
    log_info "GitHub frissítési csatorna beállítása..."
    docker exec -it epub-backend python3 -c "
from app import app, db
from models import UpdateChannel
from datetime import datetime

with app.app_context():
    channel = UpdateChannel.query.filter_by(name='stable').first()
    if not channel:
        channel = UpdateChannel(
            name='stable',
            github_repo='${GITHUB_REPO}',
            github_branch='${GITHUB_BRANCH}',
            github_token='${GITHUB_TOKEN}' if '${GITHUB_TOKEN}' else None,
            auto_check=True,
            check_interval=${UPDATE_CHECK_INTERVAL}
        )
        db.session.add(channel)
        db.session.commit()
        print('GitHub frissítési csatorna létrehozva')
    else:
        print('Frissítési csatorna már létezik')
" 2>/dev/null || log_warn "Frissítési csatorna beállítás figyelmeztetés"
fi

# Cron job beállítása
log_info "Automatikus karbantartás beállítása..."
(crontab -l 2>/dev/null; echo "0 3 * * 0 $PROJECT_DIR/scripts/backup.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 4 * * 0 docker system prune -f") | crontab -

# Verzió fájl
echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt

# ============================================================
# TELEPÍTÉS BEFEJEZVE
# ============================================================
clear
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║   🎉 EPUB Fordító v${VERSION} - Telepítve! 🎉                      ║"
echo "║   \"${CODENAME}\"                            ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌐 Web:        http://localhost"
echo "📧 Email UI:   http://localhost:8025"
[[ $ENABLE_TTS =~ ^[Ii]$ ]] && echo "🔊 TTS:        http://localhost:5001"
[[ $ENABLE_COLLABORATION =~ ^[Ii]$ ]] && echo "👥 WebSocket:  ws://localhost:3001"
[[ $INSTALL_MONITORING =~ ^[Ii]$ ]] && echo "📊 Grafana:    http://localhost:3000 (admin/admin)"
echo ""
echo "👤 Admin:       ${ADMIN_EMAIL}"
echo "🔑 Jelszó:      ${ADMIN_PASSWORD}"
echo "🤖 Modell:      ${SELECTED_MODEL}"
echo ""
echo "📡 Frissítések:"
if [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]]; then
    echo "   Auto-update: ENGEDÉLYEZVE"
    echo "   GitHub:      ${GITHUB_REPO}"
    echo "   Intervallum: ${UPDATE_CHECK_INTERVAL}s"
    echo "   Kezelés:     http://localhost/admin/updates"
else
    echo "   Auto-update: LETILTVA"
fi
echo ""
echo "📱 PWA: Telepíthető mobilon a böngészőből"
echo "   (Menü → Telepítés / Hozzáadás kezdőképernyőhöz)"
echo ""
echo "📋 Parancsok:"
echo "   Állapot:     ./scripts/status.sh"
echo "   Backup:      ./scripts/backup.sh"
echo "   Frissítés:   ./scripts/update.sh"
echo "   Logok:       docker compose logs -f backend"
echo ""
echo "💡 Tipp: A rendszer minél többet használod, annál okosabb lesz!"
echo "   A fordítási memória és a kontextus tanulás folyamatosan"
echo "   javítja a fordítások minőségét."
echo ""

log_success "Telepítés befejezve! 🚀📚"
