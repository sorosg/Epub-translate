#!/bin/bash

# EPUB Fordító Rendszer - Telepítő/Frissítő Script v9.1
# Verzió: 9.1.0
# Kódnév: "Enhanced Studio"
# Dátum: 2025-03-15
# Leírás: Dark Mode, Billentyűparancsok, Dashboard 2.0, Többnyelvű felület,
#          Calibre/Kindle integráció, WordPress plugin, Chrome bővítmény

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
VERSION="9.1.0"
CODENAME="Enhanced Studio"
RELEASE_DATE="2025-03-15"
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
ENABLE_DARK_MODE="i"
ENABLE_SHORTCUTS="i"
ENABLE_I18N="i"
DEFAULT_LANGUAGE="hu"
ENABLE_CALIBRE="i"
ENABLE_KINDLE="i"
ENABLE_WP_PLUGIN="i"
ENABLE_CHROME_EXT="i"
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
        echo "  1) Frissítés (adatok megőrzése) ⭐"
        echo "  2) Újratelepítés (minden törlődik)"
        echo "  3) Kilépés"
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
            3) exit 0;;
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
    SELECTED_MODEL="${SELECTED_MODEL:-$DEFAULT_MODEL}"
    SMTP_MODE="${SMTP_MODE:-local}"
    GITHUB_REPO="${GITHUB_REPO:-https://github.com/sorosg/Epub-translate.git}"
    GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    ENABLE_REGISTRATION="${ENABLE_REGISTRATION:-i}"
    DEFAULT_TOKENS="${DEFAULT_TOKENS:-5}"
    DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE:-hu}"
    log_success "Konfiguráció betöltve"
}

# ============================================================
# RENDSZER ERŐFORRÁSOK
# ============================================================
check_system_resources() {
    log_step "Erőforrások ellenőrzése"
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    log_info "RAM: ${TOTAL_RAM}GB"
    [ "$TOTAL_RAM" -lt 16 ] && { log_error "Minimum 16GB RAM kell!"; exit 1; }
    [ "$TOTAL_RAM" -lt 32 ] && { RECOMMENDED_MODEL="deepseek-r1:7b"; MAX_WORKERS=2; } || { RECOMMENDED_MODEL="deepseek-r1:8b"; MAX_WORKERS=3; }
    log_info "Szabad hely: $(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')GB"
    log_info "CPU: $(nproc) mag"
}

# ============================================================
# KONFIGURÁCIÓ
# ============================================================
configure_system() {
    [ "$IS_UPDATE" = true ] && { log_info "Meglévő konfiguráció megtartása"; return; }
    
    log_step "Konfigurációs varázsló"
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════╗"
    log_header "║     EPUB Fordító v${VERSION} - \"${CODENAME}\"    ║"
    log_header "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "   🆕 v9.1 Újdonságok:"
    echo "   🌙 Dark Mode támogatás"
    echo "   ⌨️  Billentyűparancsok"
    echo "   📊 Dashboard 2.0 (interaktív grafikonok)"
    echo "   🌍 Többnyelvű felület (hu, en, de, fr, es)"
    echo "   📚 Calibre integráció"
    echo "   📱 Kindle direkt feltöltés"
    echo "   🔌 WordPress plugin"
    echo "   🧩 Chrome bővítmény"
    echo ""
    
    read -p "Testreszabás? (i/n) [i]: " c
    c=${c:-"i"}
    
    if [[ $c =~ ^[Ii]$ ]]; then
        echo ""; log_config "👤 Admin:"; read -p "Email [${ADMIN_EMAIL}]: " i; ADMIN_EMAIL=${i:-$ADMIN_EMAIL}; read -sp "Jelszó [${ADMIN_PASSWORD}]: " i; echo ""; ADMIN_PASSWORD=${i:-$ADMIN_PASSWORD}
        echo ""; log_config "🌍 Nyelv:"; echo "hu=Magyar en=English de=Deutsch fr=Français es=Español"; read -p "Nyelv [${DEFAULT_LANGUAGE}]: " i; DEFAULT_LANGUAGE=${i:-$DEFAULT_LANGUAGE}
        echo ""; log_config "🌙 Dark Mode:"; read -p "Engedélyezés? (i/n) [i]: " i; ENABLE_DARK_MODE=${i:-"i"}
        echo ""; log_config "⌨️ Billentyűparancsok:"; read -p "Engedélyezés? (i/n) [i]: " i; ENABLE_SHORTCUTS=${i:-"i"}
        echo ""; log_config "🌍 Többnyelvűség:"; read -p "Engedélyezés? (i/n) [i]: " i; ENABLE_I18N=${i:-"i"}
        echo ""; log_config "🤖 Modell:"; select_model
        echo ""; log_config "👥 Regisztráció:"; read -p "Engedélyezés? (i/n) [i]: " i; ENABLE_REGISTRATION=${i:-"i"}; [[ $ENABLE_REGISTRATION =~ ^[Ii]$ ]] && { read -p "Kezdő tokenek [5]: " i; DEFAULT_TOKENS=${i:-5}; }
        echo ""; log_config "🔗 Integrációk:"
        read -p "  Calibre? (i/n) [i]: " i; ENABLE_CALIBRE=${i:-"i"}
        read -p "  Kindle? (i/n) [i]: " i; ENABLE_KINDLE=${i:-"i"}
        read -p "  WordPress plugin? (i/n) [i]: " i; ENABLE_WP_PLUGIN=${i:-"i"}
        read -p "  Chrome bővítmény? (i/n) [i]: " i; ENABLE_CHROME_EXT=${i:-"i"}
        echo ""; log_config "📡 Auto-Update:"; read -p "Engedélyezés? (i/n) [i]: " i; ENABLE_AUTO_UPDATE=${i:-"i"}; [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && { read -p "GitHub repo [${GITHUB_REPO}]: " i; GITHUB_REPO=${i:-$GITHUB_REPO}; read -p "Token (opc.): " i; GITHUB_TOKEN=${i:-""}; }
    fi
    
    cat > .install_config << EOF
VERSION="${VERSION}"
CODENAME="${CODENAME}"
RELEASE_DATE="${RELEASE_DATE}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
MAX_WORKERS=${MAX_WORKERS}
SELECTED_MODEL="${SELECTED_MODEL}"
ENABLE_REGISTRATION="${ENABLE_REGISTRATION}"
DEFAULT_TOKENS=${DEFAULT_TOKENS}
DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE}"
ENABLE_DARK_MODE="${ENABLE_DARK_MODE}"
ENABLE_SHORTCUTS="${ENABLE_SHORTCUTS}"
ENABLE_I18N="${ENABLE_I18N}"
ENABLE_CALIBRE="${ENABLE_CALIBRE}"
ENABLE_KINDLE="${ENABLE_KINDLE}"
ENABLE_WP_PLUGIN="${ENABLE_WP_PLUGIN}"
ENABLE_CHROME_EXT="${ENABLE_CHROME_EXT}"
ENABLE_PWA="${ENABLE_PWA}"
ENABLE_TTS="${ENABLE_TTS}"
ENABLE_COLLABORATION="${ENABLE_COLLABORATION}"
ENABLE_PLUGINS="${ENABLE_PLUGINS}"
ENABLE_API="${ENABLE_API}"
ENABLE_BOOK_DB="${ENABLE_BOOK_DB}"
ENABLE_CACHE="${ENABLE_CACHE}"
SMTP_MODE="${SMTP_MODE}"
SMTP_HOST="${SMTP_HOST:-mailhog}"
SMTP_PORT="${SMTP_PORT:-1025}"
ENABLE_AUTO_UPDATE="${ENABLE_AUTO_UPDATE}"
GITHUB_REPO="${GITHUB_REPO}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
INSTALL_DATE="$(date +%Y-%m-%d_%H:%M:%S)"
EOF
}

select_model() {
    echo "1) deepseek-r1:1.5b  2) deepseek-r1:7b  3) deepseek-r1:8b ★  4) deepseek-r1:14b  5) deepseek-r1:32b"
    read -p "Választás [3]: " c; c=${c:-3}
    case $c in 1) SELECTED_MODEL="deepseek-r1:1.5b";; 2) SELECTED_MODEL="deepseek-r1:7b";; 3) SELECTED_MODEL="deepseek-r1:8b";; 4) SELECTED_MODEL="deepseek-r1:14b";; 5) SELECTED_MODEL="deepseek-r1:32b";; *) SELECTED_MODEL="deepseek-r1:8b";; esac
}

# ============================================================
# FRISSÍTÉS
# ============================================================
perform_update() {
    log_step "Frissítés (${EXISTING_VERSION} → ${VERSION})"
    cd "$PROJECT_DIR"
    
    BACK="$PROJECT_DIR/backups/updates/pre_${EXISTING_VERSION}_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACK"
    docker compose ps 2>/dev/null | grep -q postgres && docker exec epub-postgres pg_dump -U epub_user epub_translator > "$BACK/database.sql" 2>/dev/null || true
    cp .env "$BACK/.env" 2>/dev/null || true
    cp .install_config "$BACK/.install_config" 2>/dev/null || true
    [ -d book_database ] && tar -czf "$BACK/book_database.tar.gz" book_database/ 2>/dev/null || true
    [ -d translation_memory ] && tar -czf "$BACK/translation_memory.tar.gz" translation_memory/ 2>/dev/null || true
    log_success "Mentés: $BACK"
    
    docker compose down 2>/dev/null || true
    [ -d .git ] && { git fetch origin 2>/dev/null && git pull origin main 2>/dev/null || log_warn "Git pull nem sikerült"; }
    
    create_all_files
    docker compose build 2>/dev/null || docker compose build --no-cache
    docker compose up -d
    sleep 15
    
    docker exec -it epub-backend python3 -c "from app import app, db; app.app_context().push(); db.create_all(); print('OK')" 2>/dev/null || log_warn "Migráció figyelmeztetés"
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
    
    sudo apt update -qq && sudo apt upgrade -y -qq
    sudo apt install -y -qq curl wget git ca-certificates gnupg nano htop net-tools ufw build-essential python3-pip python3-venv libxml2-dev libxslt-dev redis-tools postgresql-client clamav postfix mailutils poppler-utils ffmpeg nginx openssl 2>/dev/null || true
    
    if ! command -v docker &> /dev/null; then
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update -qq && sudo apt install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
        sudo systemctl enable docker && sudo systemctl start docker
        sudo usermod -aG docker $USER
    fi
    
    docker compose build 2>/dev/null || docker compose build --no-cache
    docker compose up -d
    sleep 20
    
    docker exec -it epub-ollama ollama pull "$SELECTED_MODEL" 2>/dev/null || log_warn "Modell figyelmeztetés"
    sleep 10
    docker exec -it epub-backend python3 -c "from app import app, init_db; app.app_context().push(); init_db(); print('OK')" 2>/dev/null || log_warn "DB figyelmeztetés"
    
    [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && [ -n "$GITHUB_REPO" ] && docker exec -it epub-backend python3 -c "from app import app, db; from models import UpdateChannel; app.app_context().push(); c=UpdateChannel.query.filter_by(name='stable').first() or UpdateChannel(name='stable',github_repo='${GITHUB_REPO}',github_branch='${GITHUB_BRANCH:-main}',github_token='${GITHUB_TOKEN}' or None,auto_check=True); db.session.add(c); db.session.commit()" 2>/dev/null || true
    
    (crontab -l 2>/dev/null; echo "0 3 * * 0 $PROJECT_DIR/scripts/backup.sh") | crontab -
    (crontab -l 2>/dev/null; echo "0 4 * * 0 docker system prune -f") | crontab -
    
    echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt
}

# ============================================================
# KÖNYVTÁR STRUKTÚRA
# ============================================================
create_directory_structure() {
    mkdir -p "$PROJECT_DIR"/{nginx/ssl,backend/{templates,utils,plugins/hooks,static,translations},static/{css,js,images,icons,screenshots},uploads/{covers,books,temp},output,logs/{nginx,backend},backups/{updates,database,config},scripts,postfix,book_database,translation_memory,glossaries,collaboration,tts-service,websocket,updates,integrations/{calibre,kindle,wordpress,chrome}}
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
    create_i18n_files
    create_dark_mode_css
    create_shortcuts_js
    create_dashboard_html
    create_integration_files
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
FLASK_ENV=production
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ENABLE_REGISTRATION=${ENABLE_REGISTRATION}
DEFAULT_TOKENS=${DEFAULT_TOKENS}
DEFAULT_LANGUAGE=${DEFAULT_LANGUAGE}
ENABLE_DARK_MODE=${ENABLE_DARK_MODE}
ENABLE_SHORTCUTS=${ENABLE_SHORTCUTS}
ENABLE_I18N=${ENABLE_I18N}
ENABLE_CALIBRE=${ENABLE_CALIBRE}
ENABLE_KINDLE=${ENABLE_KINDLE}
ENABLE_WP_PLUGIN=${ENABLE_WP_PLUGIN}
ENABLE_CHROME_EXT=${ENABLE_CHROME_EXT}
SELECTED_MODEL=${SELECTED_MODEL}
MAX_WORKERS=${MAX_WORKERS}
SMTP_MODE=${SMTP_MODE}
SMTP_HOST=${SMTP_HOST:-mailhog}
SMTP_PORT=${SMTP_PORT:-1025}
OLLAMA_HOST=http://ollama:11434
REDIS_URL=redis://redis:6379/0
ENABLE_AUTO_UPDATE=${ENABLE_AUTO_UPDATE}
GITHUB_REPO=${GITHUB_REPO}
GITHUB_TOKEN=${GITHUB_TOKEN:-}
ENVEOF
}

create_docker_compose() {
    cat > docker-compose.yml << 'DOCKEREOF'
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    container_name: epub-nginx
    ports: ["80:80", "443:443"]
    volumes: [./nginx/nginx.conf:/etc/nginx/nginx.conf:ro, ./static:/usr/share/nginx/html/static:ro, ./logs/nginx:/var/log/nginx]
    depends_on: {backend: {condition: service_healthy}}
    networks: [translator-network]
    restart: unless-stopped
  backend:
    build: ./backend
    container_name: epub-backend
    volumes: [./backend:/app, epub_uploads:/app/uploads, epub_output:/app/output, ./logs/backend:/app/logs, ./book_database:/app/book_database, ./translation_memory:/app/translation_memory, ./glossaries:/app/glossaries, ./integrations:/app/integrations]
    environment: [DATABASE_URL=postgresql://epub_user:epub_password@postgres:5432/epub_translator, OLLAMA_HOST=http://ollama:11434, REDIS_URL=redis://redis:6379/0, SMTP_MODE=${SMTP_MODE}, SMTP_HOST=${SMTP_HOST}, SMTP_PORT=${SMTP_PORT}, SECRET_KEY=${SECRET_KEY}, SELECTED_MODEL=${SELECTED_MODEL}, MAX_WORKERS=${MAX_WORKERS}, ENABLE_REGISTRATION=${ENABLE_REGISTRATION}, DEFAULT_TOKENS=${DEFAULT_TOKENS}, DEFAULT_LANGUAGE=${DEFAULT_LANGUAGE}, ENABLE_DARK_MODE=${ENABLE_DARK_MODE}, ENABLE_SHORTCUTS=${ENABLE_SHORTCUTS}, ENABLE_I18N=${ENABLE_I18N}, ENABLE_CALIBRE=${ENABLE_CALIBRE}, ENABLE_KINDLE=${ENABLE_KINDLE}, ENABLE_WP_PLUGIN=${ENABLE_WP_PLUGIN}, ENABLE_CHROME_EXT=${ENABLE_CHROME_EXT}, VERSION=${VERSION}]
    depends_on: {postgres: {condition: service_healthy}, ollama: {condition: service_healthy}, redis: {condition: service_started}}
    networks: [translator-network]
    restart: unless-stopped
    command: gunicorn -w 2 -b 0.0.0.0:5000 app:app --timeout 600 --worker-class eventlet
  postgres:
    image: postgres:15-alpine
    container_name: epub-postgres
    environment: [POSTGRES_DB=epub_translator, POSTGRES_USER=epub_user, POSTGRES_PASSWORD=epub_password]
    volumes: [postgres_data:/var/lib/postgresql/data, ./backups:/backups]
    networks: [translator-network]
    restart: unless-stopped
  ollama:
    build: ./ollama
    container_name: epub-ollama
    volumes: [ollama_data:/root/.ollama]
    environment: [OLLAMA_KEEP_ALIVE=24h, OLLAMA_HOST=0.0.0.0]
    networks: [translator-network]
    restart: unless-stopped
    deploy: {resources: {limits: {memory: 24G}, reservations: {memory: 16G}}}
    command: serve
  redis:
    image: redis:alpine
    container_name: epub-redis
    volumes: [redis_data:/data]
    networks: [translator-network]
    restart: unless-stopped
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
  postgres_data: {}; ollama_data: {}; redis_data: {}; epub_uploads: {}; epub_output: {}
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
        location /sw.js { alias /usr/share/nginx/html/static/js/sw.js; add_header Content-Type application/javascript; }
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
RUN apt-get update && apt-get install -y gcc libxml2-dev libxslt-dev curl git && rm -rf /var/lib/apt/lists/*
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
REQEOF

    cat > backend/config.py << 'CONFIGEOF'
import os
from dotenv import load_dotenv
load_dotenv()

class Config:
    VERSION = os.environ.get('VERSION', '9.1.0')
    CODENAME = os.environ.get('CODENAME', 'Enhanced Studio')
    RELEASE_DATE = os.environ.get('RELEASE_DATE', '2025-03-15')
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://localhost:11434')
    DEFAULT_MODEL = os.environ.get('SELECTED_MODEL', 'deepseek-r1:8b')
    ENABLE_REGISTRATION = os.environ.get('ENABLE_REGISTRATION', 'i').lower() == 'i'
    DEFAULT_TOKENS = int(os.environ.get('DEFAULT_TOKENS', 5))
    DEFAULT_LANGUAGE = os.environ.get('DEFAULT_LANGUAGE', 'hu')
    ENABLE_DARK_MODE = os.environ.get('ENABLE_DARK_MODE', 'i').lower() == 'i'
    ENABLE_SHORTCUTS = os.environ.get('ENABLE_SHORTCUTS', 'i').lower() == 'i'
    ENABLE_I18N = os.environ.get('ENABLE_I18N', 'i').lower() == 'i'
    ENABLE_CALIBRE = os.environ.get('ENABLE_CALIBRE', 'i').lower() == 'i'
    ENABLE_KINDLE = os.environ.get('ENABLE_KINDLE', 'i').lower() == 'i'
    ENABLE_WP_PLUGIN = os.environ.get('ENABLE_WP_PLUGIN', 'i').lower() == 'i'
    ENABLE_CHROME_EXT = os.environ.get('ENABLE_CHROME_EXT', 'i').lower() == 'i'
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    SMTP_MODE = os.environ.get('SMTP_MODE', 'local')
    MAIL_SERVER = os.environ.get('SMTP_HOST', 'mailhog')
    MAIL_PORT = int(os.environ.get('SMTP_PORT', 1025))
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
    BABEL_TRANSLATION_DIRECTORIES = 'translations'
    LANGUAGES = ['hu', 'en', 'de', 'fr', 'es']
CONFIGEOF

    cat > backend/models.py << 'MODELSEOF'
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
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
    language = db.Column(db.String(5), default='hu')
    dark_mode = db.Column(db.Boolean, default=True)
    last_login = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Book(db.Model):
    __tablename__ = 'books'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(500))
    language = db.Column(db.String(10))
    genre = db.Column(db.String(100))
    writing_style = db.Column(db.String(100))
    word_count = db.Column(db.Integer)
    file_hash = db.Column(db.String(64), unique=True)
    use_count = db.Column(db.Integer, default=0)
    first_uploaded = db.Column(db.DateTime, default=datetime.utcnow)

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

class InternalEmail(db.Model):
    __tablename__ = 'internal_emails'
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    recipient_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    subject = db.Column(db.String(500))
    body = db.Column(db.Text)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class UserSettings(db.Model):
    __tablename__ = 'user_settings'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), unique=True)
    dark_mode = db.Column(db.Boolean, default=True)
    language = db.Column(db.String(5), default='hu')
    shortcuts_enabled = db.Column(db.Boolean, default=True)
    dashboard_layout = db.Column(db.String(50), default='default')
MODELSEOF

    cat > backend/app.py << 'APPEOF'
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_babel import Babel, gettext as _
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, InternalEmail, UserSettings
from datetime import datetime
from functools import wraps
import os, re

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

@babel.localeselector
def get_locale():
    if current_user.is_authenticated and hasattr(current_user, 'language'):
        return current_user.language
    return request.accept_languages.best_match(app.config['LANGUAGES']) or app.config['DEFAULT_LANGUAGE']

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/health')
def health():
    return jsonify({'status': 'healthy', 'version': app.config['VERSION'], 'codename': app.config['CODENAME'], 'release_date': app.config['RELEASE_DATE']})

@app.route('/')
def index():
    return redirect(url_for('dashboard') if current_user.is_authenticated else url_for('login'))

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
        flash(_('Hibás email vagy jelszó!'), 'error')
    return render_template('login.html')

@app.route('/register')
def register_page():
    if current_user.is_authenticated: return redirect(url_for('dashboard'))
    if not app.config['ENABLE_REGISTRATION']:
        flash(_('A regisztráció le van tiltva!'), 'error')
        return redirect(url_for('login'))
    return render_template('register.html')

@app.route('/api/register', methods=['POST'])
@limiter.limit("5 per hour")
def register_user():
    if not app.config['ENABLE_REGISTRATION']:
        return jsonify({'error': _('A regisztráció le van tiltva!')}), 403
    data = request.get_json()
    for f in ['email', 'password', 'first_name', 'last_name']:
        if not data.get(f): return jsonify({'error': _('A(z) %(field)s mező kötelező!', field=f)}), 400
    if User.query.filter_by(email=data['email']).first():
        return jsonify({'error': _('Ez az email már regisztrálva van!')}), 400
    if len(data['password']) < 8:
        return jsonify({'error': _('A jelszó minimum 8 karakter!')}), 400
    
    base = data['email'].split('@')[0]
    username = base; c = 1
    while User.query.filter_by(username=username).first(): username = f"{base}{c}"; c += 1
    
    user = User(username=username, email=data['email'], password_hash=generate_password_hash(data['password']), first_name=data['first_name'].strip(), last_name=data['last_name'].strip(), tokens=app.config['DEFAULT_TOKENS'])
    db.session.add(user); db.session.commit()
    
    first = user.first_name.lower().replace(' ', '.')
    last = user.last_name.lower().replace(' ', '.')
    internal = f"{first}.{last}@epub.local"; c = 1
    while User.query.filter_by(internal_email=internal).first(): internal = f"{first}.{last}{c}@epub.local"; c += 1
    user.internal_email = internal; db.session.commit()
    
    settings = UserSettings(user_id=user.id, dark_mode=app.config['ENABLE_DARK_MODE'], language=app.config['DEFAULT_LANGUAGE'])
    db.session.add(settings); db.session.commit()
    
    return jsonify({'success': True, 'user_id': user.id, 'internal_email': internal, 'tokens': user.tokens})

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    if current_user.is_admin: return redirect(url_for('admin'))
    translations = Translation.query.filter_by(user_id=current_user.id).order_by(Translation.created_at.desc()).limit(20).all()
    stats = {'total': len(translations), 'completed': len([t for t in translations if t.status == 'completed']), 'failed': len([t for t in translations if t.status == 'failed'])}
    return render_template('dashboard.html', user=current_user, translations=translations, stats=stats)

@app.route('/api/settings', methods=['GET', 'PUT'])
@login_required
def user_settings():
    settings = UserSettings.query.filter_by(user_id=current_user.id).first()
    if not settings:
        settings = UserSettings(user_id=current_user.id)
        db.session.add(settings); db.session.commit()
    
    if request.method == 'PUT':
        data = request.get_json()
        if 'dark_mode' in data: settings.dark_mode = data['dark_mode']
        if 'language' in data: settings.language = data['language']
        if 'shortcuts_enabled' in data: settings.shortcuts_enabled = data['shortcuts_enabled']
        db.session.commit()
        return jsonify({'success': True})
    
    return jsonify({'dark_mode': settings.dark_mode, 'language': settings.language, 'shortcuts_enabled': settings.shortcuts_enabled})

@app.route('/api/stats/dashboard')
@login_required
def dashboard_stats():
    translations = Translation.query.filter_by(user_id=current_user.id).all()
    monthly = {}
    for t in translations:
        month = t.created_at.strftime('%Y-%m')
        monthly[month] = monthly.get(month, 0) + 1
    
    return jsonify({
        'total_translations': len(translations),
        'completed': len([t for t in translations if t.status == 'completed']),
        'avg_quality': sum([t.quality_score or 0 for t in translations]) // max(len(translations), 1),
        'monthly': monthly,
        'tokens_left': current_user.tokens
    })

def init_db():
    with app.app_context():
        db.create_all()
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL, password_hash=generate_password_hash(Config.ADMIN_PASSWORD), first_name='Admin', last_name='User', is_admin=True, tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin); db.session.commit()
            settings = UserSettings(user_id=admin.id, dark_mode=True, language='hu')
            db.session.add(settings); db.session.commit()

if __name__ == '__main__':
    init_db()
    app.run(debug=False, host='0.0.0.0', port=5000)
APPEOF

    touch backend/utils/__init__.py
    create_html_templates
}

create_html_templates() {
    # base.html (Dark Mode + Többnyelvű)
    cat > backend/templates/base.html << 'BASEEOF'
<!DOCTYPE html>
<html lang="{{ current_user.language or 'hu' }}" data-theme="{{ 'dark' if current_user.is_authenticated and current_user.dark_mode else 'light' }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EPUB Fordító - {% block title %}{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <link rel="stylesheet" href="/static/css/dark-mode.css">
    <link rel="manifest" href="/manifest.json">
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="/"><i class="fas fa-book-open"></i> EPUB Fordító v9.1</a>
            <div class="navbar-nav ms-auto">
                {% if current_user.is_authenticated %}
                <button class="btn btn-sm btn-outline-light me-2" onclick="toggleDarkMode()" title="Dark Mode">🌙</button>
                <span class="nav-link text-light"><i class="fas fa-coins"></i> {{ current_user.tokens }}</span>
                <a class="nav-link" href="/logout"><i class="fas fa-sign-out-alt"></i> Kilépés</a>
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
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <script src="/static/js/shortcuts.js"></script>
    <script src="/static/js/dark-mode.js"></script>
    {% block scripts %}{% endblock %}
</body>
</html>
BASEEEOF

    # dashboard.html (Dashboard 2.0)
    cat > backend/templates/dashboard.html << 'DASHEOF'
{% extends "base.html" %}
{% block title %}Vezérlőpult{% endblock %}
{% block content %}
<h2>Üdvözlünk, {{ user.first_name }}!</h2>
<div class="row mt-4">
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ user.tokens }}</h1><p>Token</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1 id="totalTrans">-</h1><p>Fordítás</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1 id="avgQuality">-</h1><p>Átlag minőség</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><code>{{ user.internal_email }}</code></div></div></div>
</div>
<div class="row mt-4">
    <div class="col-md-8"><div class="card"><div class="card-body"><canvas id="monthlyChart"></canvas></div></div></div>
    <div class="col-md-4"><div class="card"><div class="card-body"><canvas id="statusChart"></canvas></div></div></div>
</div>
{% endblock %}
{% block scripts %}
<script>
fetch('/api/stats/dashboard').then(r=>r.json()).then(d=>{
    document.getElementById('totalTrans').textContent=d.total_translations;
    document.getElementById('avgQuality').textContent=d.avg_quality+'%';
    new Chart(document.getElementById('monthlyChart'),{type:'line',data:{labels:Object.keys(d.monthly),datasets:[{label:'Fordítások',data:Object.values(d.monthly),borderColor:'#0d6efd'}]}});
    new Chart(document.getElementById('statusChart'),{type:'doughnut',data:{labels:['Kész','Sikertelen'],datasets:[{data:[d.completed,d.total_translations-d.completed],backgroundColor:['#198754','#dc3545']}]}});
});
</script>
{% endblock %}
DASHEEOF

    # register.html, login.html (egyszerűsített)
    cat > backend/templates/register.html << 'REGEOF'
{% extends "base.html" %}{% block title %}Regisztráció{% endblock %}{% block content %}
<div class="row justify-content-center mt-5"><div class="col-md-5"><div class="card"><div class="card-header bg-success text-white"><h3 class="text-center">Regisztráció</h3></div><div class="card-body"><form id="rf"><div class="row"><div class="col-md-6 mb-3"><label>Vezetéknév *</label><input type="text" class="form-control" id="ln" required></div><div class="col-md-6 mb-3"><label>Keresztnév *</label><input type="text" class="form-control" id="fn" required></div></div><div class="mb-3"><label>Email *</label><input type="email" class="form-control" id="em" required></div><div class="mb-3"><label>Jelszó *</label><input type="password" class="form-control" id="pw" required minlength="8"></div><button type="submit" class="btn btn-success w-100">Regisztráció</button><div class="text-center mt-3"><a href="/login">Bejelentkezés</a></div></form><div id="rs" class="d-none text-center py-4"><h4>✅ Sikeres!</h4><p id="ie"></p><a href="/login" class="btn btn-primary">Bejelentkezés</a></div></div></div></div></div>
<script>document.getElementById('rf').addEventListener('submit',async function(e){e.preventDefault();const r=await fetch('/api/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({first_name:document.getElementById('fn').value,last_name:document.getElementById('ln').value,email:document.getElementById('em').value,password:document.getElementById('pw').value})});const d=await r.json();if(d.success){document.getElementById('rf').classList.add('d-none');document.getElementById('rs').classList.remove('d-none');document.getElementById('ie').textContent=d.internal_email}else{alert(d.error)}});</script>
{% endblock %}
REGEOF

    cat > backend/templates/login.html << 'LOGINEOF'
{% extends "base.html" %}{% block title %}Bejelentkezés{% endblock %}{% block content %}
<div class="row justify-content-center mt-5"><div class="col-md-4"><div class="card"><div class="card-header bg-primary text-white"><h3 class="text-center">Bejelentkezés</h3></div><div class="card-body"><form method="POST"><div class="mb-3"><label>Email</label><input type="email" class="form-control" name="email" required></div><div class="mb-3"><label>Jelszó</label><input type="password" class="form-control" name="password" required></div><button type="submit" class="btn btn-primary w-100 mb-3">Bejelentkezés</button><hr><a href="/register" class="btn btn-success w-100">Új fiók</a></form></div></div></div></div>
{% endblock %}
LOGINEOF
}

create_i18n_files() {
    mkdir -p backend/translations/{hu,en,de,fr,es}/LC_MESSAGES
    
    # Magyar fordítások
    cat > backend/translations/hu/LC_MESSAGES/messages.po << 'POEOF'
msgid "Admin jogosultság szükséges!"
msgstr "Admin jogosultság szükséges!"

msgid "Hibás email vagy jelszó!"
msgstr "Hibás email vagy jelszó!"

msgid "A regisztráció le van tiltva!"
msgstr "A regisztráció le van tiltva!"

msgid "Ez az email már regisztrálva van!"
msgstr "Ez az email már regisztrálva van!"

msgid "A jelszó minimum 8 karakter!"
msgstr "A jelszó minimum 8 karakter!"

msgid "Üdvözlünk"
msgstr "Üdvözlünk"

msgid "Token"
msgstr "Token"

msgid "Fordítás"
msgstr "Fordítás"

msgid "Bejelentkezés"
msgstr "Bejelentkezés"

msgid "Regisztráció"
msgstr "Regisztráció"

msgid "Kilépés"
msgstr "Kilépés"

msgid "Vezérlőpult"
msgstr "Vezérlőpult"
POEOF

    # English translations
    cat > backend/translations/en/LC_MESSAGES/messages.po << 'POENEOF'
msgid "Admin jogosultság szükséges!"
msgstr "Admin privileges required!"

msgid "Hibás email vagy jelszó!"
msgstr "Invalid email or password!"

msgid "A regisztráció le van tiltva!"
msgstr "Registration is disabled!"

msgid "Ez az email már regisztrálva van!"
msgstr "This email is already registered!"

msgid "A jelszó minimum 8 karakter!"
msgstr "Password must be at least 8 characters!"

msgid "Üdvözlünk"
msgstr "Welcome"

msgid "Token"
msgstr "Tokens"

msgid "Fordítás"
msgstr "Translations"

msgid "Bejelentkezés"
msgstr "Login"

msgid "Regisztráció"
msgstr "Register"

msgid "Kilépés"
msgstr "Logout"

msgid "Vezérlőpult"
msgstr "Dashboard"
POENEOF

    # Német
    cat > backend/translations/de/LC_MESSAGES/messages.po << 'PODEEOF'
msgid "Üdvözlünk"
msgstr "Willkommen"
msgid "Token"
msgstr "Token"
msgid "Fordítás"
msgstr "Übersetzungen"
msgid "Bejelentkezés"
msgstr "Anmeldung"
msgid "Regisztráció"
msgstr "Registrierung"
msgid "Kilépés"
msgstr "Abmelden"
msgid "Vezérlőpult"
msgstr "Dashboard"
PODEEOF

    # Francia
    cat > backend/translations/fr/LC_MESSAGES/messages.po << 'POFREOF'
msgid "Üdvözlünk"
msgstr "Bienvenue"
msgid "Token"
msgstr "Jetons"
msgid "Fordítás"
msgstr "Traductions"
msgid "Bejelentkezés"
msgstr "Connexion"
msgid "Regisztráció"
msgstr "Inscription"
msgid "Kilépés"
msgstr "Déconnexion"
msgid "Vezérlőpult"
msgstr "Tableau de bord"
POFREOF

    # Spanyol
    cat > backend/translations/es/LC_MESSAGES/messages.po << 'POESEOF'
msgid "Üdvözlünk"
msgstr "Bienvenido"
msgid "Token"
msgstr "Tokens"
msgid "Fordítás"
msgstr "Traducciones"
msgid "Bejelentkezés"
msgstr "Iniciar sesión"
msgid "Regisztráció"
msgstr "Registro"
msgid "Kilépés"
msgstr "Cerrar sesión"
msgid "Vezérlőpult"
msgstr "Panel"
POESEOF
}

create_dark_mode_css() {
    cat > static/css/dark-mode.css << 'DMCSSEOF'
:root {
    --bg-primary: #ffffff;
    --bg-secondary: #f8f9fa;
    --text-primary: #212529;
    --text-secondary: #6c757d;
    --border-color: #dee2e6;
    --card-bg: #ffffff;
    --card-shadow: 0 0.125rem 0.25rem rgba(0,0,0,0.075);
}

[data-theme="dark"] {
    --bg-primary: #1a1a2e;
    --bg-secondary: #16213e;
    --text-primary: #e0e0e0;
    --text-secondary: #a0a0a0;
    --border-color: #2a2a4a;
    --card-bg: #1e1e3a;
    --card-shadow: 0 0.125rem 0.25rem rgba(0,0,0,0.3);
}

body {
    background-color: var(--bg-primary);
    color: var(--text-primary);
    transition: background-color 0.3s, color 0.3s;
}

.card {
    background-color: var(--card-bg);
    border-color: var(--border-color);
    box-shadow: var(--card-shadow);
}

.card-header {
    background-color: var(--bg-secondary);
    border-bottom-color: var(--border-color);
}

.table {
    color: var(--text-primary);
}

.text-muted {
    color: var(--text-secondary) !important;
}

.navbar {
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
}

.alert {
    border: none;
}
DMCSSEOF
}

create_shortcuts_js() {
    cat > static/js/shortcuts.js << 'SHORTEOF'
const shortcuts = {
    'Ctrl+Enter': { action: 'translate', desc: 'Fordítás indítása' },
    'Ctrl+D': { action: 'download', desc: 'Letöltés' },
    'Ctrl+N': { action: 'new', desc: 'Új fordítás' },
    'Ctrl+H': { action: 'home', desc: 'Vezérlőpult' },
    'Ctrl+L': { action: 'library', desc: 'Könyvtár' },
    'Ctrl+Shift+D': { action: 'darkMode', desc: 'Dark Mode váltás' },
    'Esc': { action: 'close', desc: 'Bezárás' },
    '?': { action: 'help', desc: 'Súgó' }
};

document.addEventListener('keydown', function(e) {
    const key = `${e.ctrlKey ? 'Ctrl+' : ''}${e.shiftKey ? 'Shift+' : ''}${e.key}`;
    
    if (shortcuts[key]) {
        e.preventDefault();
        handleShortcut(shortcuts[key].action);
    }
});

function handleShortcut(action) {
    switch(action) {
        case 'translate': document.querySelector('#translateBtn')?.click(); break;
        case 'download': document.querySelector('#downloadBtn')?.click(); break;
        case 'home': window.location.href = '/dashboard'; break;
        case 'library': window.location.href = '/admin/library'; break;
        case 'darkMode': toggleDarkMode(); break;
        case 'help': showShortcutsHelp(); break;
    }
}

function showShortcutsHelp() {
    let html = '<h5>Billentyűparancsok</h5><ul>';
    for (const [key, value] of Object.entries(shortcuts)) {
        html += `<li><kbd>${key}</kbd> - ${value.desc}</li>`;
    }
    html += '</ul>';
    
    const modal = document.createElement('div');
    modal.className = 'modal fade';
    modal.innerHTML = `<div class="modal-dialog"><div class="modal-content"><div class="modal-header"><h5>Billentyűparancsok</h5><button class="btn-close" data-bs-dismiss="modal"></button></div><div class="modal-body">${html}</div></div></div>`;
    document.body.appendChild(modal);
    new bootstrap.Modal(modal).show();
}
SHORTEOF
}

create_dark_mode_js() {
    cat > static/js/dark-mode.js << 'DMJSEOF'
function toggleDarkMode() {
    const html = document.documentElement;
    const current = html.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    html.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
    
    fetch('/api/settings', {
        method: 'PUT',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({dark_mode: next === 'dark'})
    });
}

// Betöltéskor alkalmazás
(function() {
    const saved = localStorage.getItem('theme');
    if (saved) {
        document.documentElement.setAttribute('data-theme', saved);
    }
})();
DMJSEOF
}

create_integration_files() {
    # Calibre integráció
    cat > integrations/calibre/calibre_plugin.py << 'CALEOF'
#!/usr/bin/env python3
"""
EPUB Translator - Calibre Plugin
Integráció a Calibre könyvtárkezelővel
"""

import os
import json
import requests

class EPUBTranslatorPlugin:
    def __init__(self, translator_url="http://localhost"):
        self.translator_url = translator_url
        self.api_key = None
    
    def send_to_translator(self, book_path, target_language="hu"):
        """Könyv küldése a fordítónak"""
        with open(book_path, 'rb') as f:
            files = {'epub_file': f}
            headers = {'X-API-Key': self.api_key} if self.api_key else {}
            response = requests.post(
                f"{self.translator_url}/api/translate",
                files=files,
                headers=headers,
                data={'target_language': target_language}
            )
        return response.json()
    
    def check_status(self, translation_id):
        """Fordítás állapotának ellenőrzése"""
        response = requests.get(
            f"{self.translator_url}/api/translation/{translation_id}/progress"
        )
        return response.json()
    
    def download_translation(self, translation_id, output_path):
        """Lefordított könyv letöltése"""
        response = requests.get(
            f"{self.translator_url}/api/download/{translation_id}",
            stream=True
        )
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return output_path

if __name__ == '__main__':
    print("EPUB Translator - Calibre Plugin v9.1")
    print("Helyezd ezt a fájlt a Calibre plugins mappájába")
CALEOF

    # Kindle integráció
    cat > integrations/kindle/kindle_send.py << 'KINDLEEOF'
#!/usr/bin/env python3
"""
EPUB Translator - Kindle Send
Fordított könyvek küldése Kindle eszközre
"""

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
import os

class KindleSender:
    def __init__(self, email, password, kindle_email):
        self.email = email
        self.password = password
        self.kindle_email = kindle_email
    
    def send_book(self, filepath, title):
        """Könyv küldése Kindle-re"""
        msg = MIMEMultipart()
        msg['From'] = self.email
        msg['To'] = self.kindle_email
        msg['Subject'] = f"Fordítás: {title}"
        
        with open(filepath, 'rb') as f:
            part = MIMEBase('application', 'octet-stream')
            part.set_payload(f.read())
            encoders.encode_base64(part)
            part.add_header('Content-Disposition', f'attachment; filename="{os.path.basename(filepath)}"')
            msg.attach(part)
        
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
            server.login(self.email, self.password)
            server.send_message(msg)
        
        return True

if __name__ == '__main__':
    print("EPUB Translator - Kindle Send v9.1")
KINDLEEOF

    # WordPress plugin
    mkdir -p integrations/wordpress
    cat > integrations/wordpress/epub-translator-wp.php << 'WPEOF'
<?php
/**
 * Plugin Name: EPUB Translator Integration
 * Plugin URI: https://github.com/sorosg/Epub-translate
 * Description: Fordított EPUB könyvek megjelenítése WordPress oldalon
 * Version: 9.1.0
 * Author: Soros Gergő
 */

// Shortcode: [epub_translator]
function epub_translator_shortcode($atts) {
    $atts = shortcode_atts(['url' => 'http://localhost'], $atts);
    
    ob_start();
    ?>
    <div id="epub-translator-widget" data-url="<?php echo esc_attr($atts['url']); ?>">
        <iframe src="<?php echo esc_url($atts['url']); ?>/embed" 
                width="100%" height="600" frameborder="0"></iframe>
    </div>
    <?php
    return ob_get_clean();
}
add_shortcode('epub_translator', 'epub_translator_shortcode');

// REST API végpont
add_action('rest_api_init', function() {
    register_rest_route('epub-translator/v1', '/books', [
        'methods' => 'GET',
        'callback' => function() {
            $response = wp_remote_get('http://localhost/api/books');
            return json_decode(wp_remote_retrieve_body($response));
        }
    ]);
});
WPEOF

    # Chrome bővítmény
    mkdir -p integrations/chrome
    cat > integrations/chrome/manifest.json << 'CHROMEOF'
{
    "manifest_version": 3,
    "name": "EPUB Translator",
    "version": "9.1.0",
    "description": "Fordíts EPUB könyveket egy kattintással",
    "permissions": ["contextMenus", "storage", "notifications"],
    "host_permissions": ["http://localhost/*"],
    "background": {
        "service_worker": "background.js"
    },
    "action": {
        "default_popup": "popup.html",
        "default_icon": {
            "16": "icons/icon16.png",
            "48": "icons/icon48.png",
            "128": "icons/icon128.png"
        }
    },
    "icons": {
        "16": "icons/icon16.png",
        "48": "icons/icon48.png",
        "128": "icons/icon128.png"
    }
}
CHROMEOF

    cat > integrations/chrome/background.js << 'CHROMEBGEOF'
chrome.contextMenus.create({
    id: 'translate-epub',
    title: 'Fordítás EPUB Translatorral',
    contexts: ['link']
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
    if (info.menuItemId === 'translate-epub' && info.linkUrl) {
        fetch('http://localhost/api/translate', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({url: info.linkUrl})
        }).then(r => r.json()).then(d => {
            chrome.notifications.create({
                type: 'basic',
                iconUrl: 'icons/icon48.png',
                title: 'EPUB Translator',
                message: 'Fordítás elindítva!'
            });
        });
    }
});
CHROMEBGEOF

    cat > integrations/chrome/popup.html << 'CHROMEPOPEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body { width: 300px; padding: 15px; font-family: Arial; }
        button { width: 100%; padding: 10px; background: #007bff; color: white; border: none; border-radius: 5px; cursor: pointer; }
        button:hover { background: #0056b3; }
    </style>
</head>
<body>
    <h3>EPUB Translator v9.1</h3>
    <p>Gyors hozzáférés a fordítóhoz</p>
    <button onclick="window.open('http://localhost')">Megnyitás</button>
    <button onclick="window.open('http://localhost/dashboard')" style="margin-top:5px;">Vezérlőpult</button>
</body>
</html>
CHROMEPOPEOF
}

create_pwa_files() {
    mkdir -p static/icons
    cat > static/manifest.json << 'MANIFESTEOF'
{"name":"EPUB Fordító v9.1","short_name":"EPUB Fordító","start_url":"/","display":"standalone","background_color":"#1a1a2e","theme_color":"#16213e","icons":[{"src":"/static/icons/icon-192x192.png","sizes":"192x192","type":"image/png"},{"src":"/static/icons/icon-512x512.png","sizes":"512x512","type":"image/png"}]}
MANIFESTEOF
    cat > static/js/sw.js << 'SWEOF'
const CACHE='epub-v9.1';self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(['/','/offline.html','/static/css/dark-mode.css','/static/js/shortcuts.js','/static/js/dark-mode.js'])).then(()=>self.skipWaiting()))});self.addEventListener('fetch',e=>{e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request)))});
SWEOF
}

create_scripts() {
    cat > scripts/backup.sh << 'BACKUPEOF'
#!/bin/bash
D=$(date +%Y%m%d_%H%M%S);mkdir -p ~/epub-backups
docker exec epub-postgres pg_dump -U epub_user epub_translator > ~/epub-backups/db_$D.sql 2>/dev/null
echo "✅ ~/epub-backups/db_$D.sql"
BACKUPEOF
    cat > scripts/update.sh << 'UPDATEEOF'
#!/bin/bash
cd ~/epub-translator&&docker compose down&&git pull 2>/dev/null&&docker compose build&&docker compose up -d&&echo "✅ Frissítve!"
UPDATEEOF
    cat > scripts/status.sh << 'STATUSEOF'
#!/bin/bash
echo "EPUB Fordító v9.1";docker compose ps;echo "Web: http://localhost | Email: http://localhost:8025"
STATUSEOF
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
    echo "👤 Regisztráció: http://localhost/register"
    echo ""
    echo "🆕 v9.1: Dark Mode | Billentyűparancsok | Dashboard 2.0 | Többnyelvű"
    echo "🔗 Integrációk: Calibre | Kindle | WordPress | Chrome"
    echo ""
    echo "👤 Admin: ${ADMIN_EMAIL} | 🔑 ${ADMIN_PASSWORD}"
    echo "🌍 Nyelv: ${DEFAULT_LANGUAGE} | 🌙 Dark Mode: ${ENABLE_DARK_MODE}"
    echo ""
    echo "📋 ./scripts/update.sh | ./scripts/backup.sh | ./scripts/status.sh"
    echo ""
    log_success "Kész! 🚀"
}

# ============================================================
# MAIN
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
}

main "$@"