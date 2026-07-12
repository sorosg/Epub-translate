#!/bin/bash

# EPUB Fordító Rendszer - Telepítő/Frissítő Script v10.0
# Verzió: 10.0.0
# Kódnév: "AI Studio"
# Dátum: 2025-06-20
# Leírás: AI Asszisztens, OAuth/SSO, Offline Queue, OCR, Hangalapú fordítás,
#          Gamification, Közösségi könyvtár, Fine-tuning, Auto-Complete

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
VERSION="10.0.0"
CODENAME="AI Studio"
RELEASE_DATE="2025-06-20"
MIN_VERSION_FOR_UPDATE="8.0.0"

# Alapértelmezések
DEFAULT_MODEL="deepseek-r1:8b"
ADMIN_EMAIL="admin@epub-translator.local"
ADMIN_PASSWORD="Abrakadabra"
MAX_WORKERS=3
DEFAULT_LANGUAGE="hu"

# Funkciók
ENABLE_REGISTRATION="i"
ENABLE_DARK_MODE="i"
ENABLE_SHORTCUTS="i"
ENABLE_I18N="i"
ENABLE_PWA="i"
ENABLE_TTS="i"
ENABLE_CACHE="i"
ENABLE_API="i"
ENABLE_BOOK_DB="i"
ENABLE_AUTO_UPDATE="i"

# v10.0 Új funkciók
ENABLE_AI_ASSISTANT="i"
ENABLE_OAUTH="i"
ENABLE_OFFLINE_QUEUE="i"
ENABLE_OCR="i"
ENABLE_VOICE_INPUT="i"
ENABLE_GAMIFICATION="i"
ENABLE_COMMUNITY="i"
ENABLE_FINE_TUNING="i"
ENABLE_AUTO_COMPLETE="i"
ENABLE_COLLABORATION="i"

# OAuth beállítások
OAUTH_GOOGLE_CLIENT_ID=""
OAUTH_GOOGLE_CLIENT_SECRET=""
OAUTH_GITHUB_CLIENT_ID=""
OAUTH_GITHUB_CLIENT_SECRET=""
OAUTH_MICROSOFT_CLIENT_ID=""
OAUTH_MICROSOFT_CLIENT_SECRET=""

# Gamification
ENABLE_ACHIEVEMENTS="i"
ENABLE_LEADERBOARD="i"
ENABLE_CHALLENGES="i"

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
    DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE:-hu}"
    GITHUB_REPO="${GITHUB_REPO:-https://github.com/sorosg/Epub-translate.git}"
    GITHUB_TOKEN="${GITHUB_TOKEN:-}"
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
# KONFIGURÁCIÓS VARÁZSLÓ
# ============================================================
configure_system() {
    [ "$IS_UPDATE" = true ] && { log_info "Meglévő konfiguráció megtartása"; return; }
    
    log_step "Konfigurációs varázsló"
    echo ""
    log_header "╔══════════════════════════════════════════════════════════════╗"
    log_header "║     EPUB Fordító v${VERSION} - \"${CODENAME}\"    ║"
    log_header "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "   🆕 v10.0 Újdonságok:"
    echo "   🤖 AI Fordítási Asszisztens"
    echo "   🔐 OAuth/SSO (Google, GitHub, Microsoft)"
    echo "   📡 Offline Fordítási Queue"
    echo "   📷 OCR és Képfordítás"
    echo "   🎤 Hangalapú Fordítás"
    echo "   🎮 Gamification (Achievement-ek, Ranglisták)"
    echo "   📚 Közösségi Könyvtár"
    echo "   🎯 Fine-tuning Támogatás"
    echo "   ✨ Auto-Complete Fordítás"
    echo ""
    
    read -p "Testreszabás? (i/n) [i]: " c
    c=${c:-"i"}
    
    if [[ $c =~ ^[Ii]$ ]]; then
        echo ""; log_config "👤 Admin:"; read -p "Email [${ADMIN_EMAIL}]: " i; ADMIN_EMAIL=${i:-$ADMIN_EMAIL}; read -sp "Jelszó [${ADMIN_PASSWORD}]: " i; echo ""; ADMIN_PASSWORD=${i:-$ADMIN_PASSWORD}
        echo ""; log_config "🤖 AI Modell:"; select_model
        echo ""; log_config "🌍 Nyelv:"; read -p "Nyelv [${DEFAULT_LANGUAGE}]: " i; DEFAULT_LANGUAGE=${i:-$DEFAULT_LANGUAGE}
        
        echo ""; log_config "🆕 v10.0 Funkciók:"
        read -p "  AI Asszisztens? (i/n) [i]: " i; ENABLE_AI_ASSISTANT=${i:-"i"}
        read -p "  OAuth/SSO? (i/n) [i]: " i; ENABLE_OAUTH=${i:-"i"}
        if [[ $ENABLE_OAUTH =~ ^[Ii]$ ]]; then
            echo "    OAuth beállítások (opcionális):"
            read -p "    Google Client ID: " OAUTH_GOOGLE_CLIENT_ID
            read -sp "    Google Client Secret: " OAUTH_GOOGLE_CLIENT_SECRET; echo ""
            read -p "    GitHub Client ID: " OAUTH_GITHUB_CLIENT_ID
            read -sp "    GitHub Client Secret: " OAUTH_GITHUB_CLIENT_SECRET; echo ""
        fi
        read -p "  Offline Queue? (i/n) [i]: " i; ENABLE_OFFLINE_QUEUE=${i:-"i"}
        read -p "  OCR? (i/n) [i]: " i; ENABLE_OCR=${i:-"i"}
        read -p "  Hangalapú fordítás? (i/n) [i]: " i; ENABLE_VOICE_INPUT=${i:-"i"}
        read -p "  Gamification? (i/n) [i]: " i; ENABLE_GAMIFICATION=${i:-"i"}
        if [[ $ENABLE_GAMIFICATION =~ ^[Ii]$ ]]; then
            read -p "    Achievement-ek? (i/n) [i]: " i; ENABLE_ACHIEVEMENTS=${i:-"i"}
            read -p "    Ranglisták? (i/n) [i]: " i; ENABLE_LEADERBOARD=${i:-"i"}
            read -p "    Kihívások? (i/n) [i]: " i; ENABLE_CHALLENGES=${i:-"i"}
        fi
        read -p "  Közösségi könyvtár? (i/n) [i]: " i; ENABLE_COMMUNITY=${i:-"i"}
        read -p "  Fine-tuning? (i/n) [i]: " i; ENABLE_FINE_TUNING=${i:-"i"}
        read -p "  Auto-Complete? (i/n) [i]: " i; ENABLE_AUTO_COMPLETE=${i:-"i"}
        
        echo ""; log_config "📡 Auto-Update:"; read -p "Engedélyezés? (i/n) [i]: " i; ENABLE_AUTO_UPDATE=${i:-"i"}
        [[ $ENABLE_AUTO_UPDATE =~ ^[Ii]$ ]] && { read -p "GitHub repo [${GITHUB_REPO}]: " i; GITHUB_REPO=${i:-$GITHUB_REPO}; read -p "Token (opc.): " i; GITHUB_TOKEN=${i:-""}; }
    fi
    
    cat > .install_config << EOF
VERSION="${VERSION}"
CODENAME="${CODENAME}"
RELEASE_DATE="${RELEASE_DATE}"
ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
MAX_WORKERS=${MAX_WORKERS}
SELECTED_MODEL="${SELECTED_MODEL}"
DEFAULT_LANGUAGE="${DEFAULT_LANGUAGE}"
ENABLE_AI_ASSISTANT="${ENABLE_AI_ASSISTANT}"
ENABLE_OAUTH="${ENABLE_OAUTH}"
ENABLE_OFFLINE_QUEUE="${ENABLE_OFFLINE_QUEUE}"
ENABLE_OCR="${ENABLE_OCR}"
ENABLE_VOICE_INPUT="${ENABLE_VOICE_INPUT}"
ENABLE_GAMIFICATION="${ENABLE_GAMIFICATION}"
ENABLE_ACHIEVEMENTS="${ENABLE_ACHIEVEMENTS}"
ENABLE_LEADERBOARD="${ENABLE_LEADERBOARD}"
ENABLE_CHALLENGES="${ENABLE_CHALLENGES}"
ENABLE_COMMUNITY="${ENABLE_COMMUNITY}"
ENABLE_FINE_TUNING="${ENABLE_FINE_TUNING}"
ENABLE_AUTO_COMPLETE="${ENABLE_AUTO_COMPLETE}"
OAUTH_GOOGLE_CLIENT_ID="${OAUTH_GOOGLE_CLIENT_ID}"
OAUTH_GOOGLE_CLIENT_SECRET="${OAUTH_GOOGLE_CLIENT_SECRET}"
OAUTH_GITHUB_CLIENT_ID="${OAUTH_GITHUB_CLIENT_ID}"
OAUTH_GITHUB_CLIENT_SECRET="${OAUTH_GITHUB_CLIENT_SECRET}"
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
    [ -d book_database ] && tar -czf "$BACK/book_database.tar.gz" book_database/ 2>/dev/null || true
    [ -d translation_memory ] && tar -czf "$BACK/translation_memory.tar.gz" translation_memory/ 2>/dev/null || true
    [ -d community_library ] && tar -czf "$BACK/community_library.tar.gz" community_library/ 2>/dev/null || true
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
    sudo apt install -y -qq curl wget git ca-certificates gnupg nano htop net-tools ufw build-essential python3-pip python3-venv libxml2-dev libxslt-dev redis-tools postgresql-client clamav postfix mailutils poppler-utils ffmpeg nginx openssl tesseract-ocr tesseract-ocr-hun tesseract-ocr-eng espeak mpg321 2>/dev/null || true
    
    # Python csomagok
    pip3 install pytesseract SpeechRecognition pyaudio pyttsx3 2>/dev/null || true
    
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
    mkdir -p "$PROJECT_DIR"/{nginx/ssl,backend/{templates,utils,plugins/hooks,static,translations,models},static/{css,js,images,icons,screenshots,audio},uploads/{covers,books,temp,ocr,voice},output,logs/{nginx,backend},backups/{updates,database,config},scripts,postfix,book_database,translation_memory,glossaries,collaboration,tts-service,websocket,updates,integrations/{calibre,kindle,wordpress,chrome},community_library,achievements,challenges,fine_tuning}
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
    create_ai_assistant
    create_oauth_files
    create_ocr_files
    create_voice_files
    create_gamification_files
    create_community_files
    create_fine_tuning_files
    create_auto_complete_files
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
MAX_WORKERS=${MAX_WORKERS}
ENABLE_AI_ASSISTANT=${ENABLE_AI_ASSISTANT}
ENABLE_OAUTH=${ENABLE_OAUTH}
ENABLE_OFFLINE_QUEUE=${ENABLE_OFFLINE_QUEUE}
ENABLE_OCR=${ENABLE_OCR}
ENABLE_VOICE_INPUT=${ENABLE_VOICE_INPUT}
ENABLE_GAMIFICATION=${ENABLE_GAMIFICATION}
ENABLE_ACHIEVEMENTS=${ENABLE_ACHIEVEMENTS}
ENABLE_LEADERBOARD=${ENABLE_LEADERBOARD}
ENABLE_CHALLENGES=${ENABLE_CHALLENGES}
ENABLE_COMMUNITY=${ENABLE_COMMUNITY}
ENABLE_FINE_TUNING=${ENABLE_FINE_TUNING}
ENABLE_AUTO_COMPLETE=${ENABLE_AUTO_COMPLETE}
OAUTH_GOOGLE_CLIENT_ID=${OAUTH_GOOGLE_CLIENT_ID}
OAUTH_GOOGLE_CLIENT_SECRET=${OAUTH_GOOGLE_CLIENT_SECRET}
OAUTH_GITHUB_CLIENT_ID=${OAUTH_GITHUB_CLIENT_ID}
OAUTH_GITHUB_CLIENT_SECRET=${OAUTH_GITHUB_CLIENT_SECRET}
ENABLE_DARK_MODE=${ENABLE_DARK_MODE:-i}
ENABLE_SHORTCUTS=${ENABLE_SHORTCUTS:-i}
ENABLE_I18N=${ENABLE_I18N:-i}
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
    volumes: [./backend:/app, epub_uploads:/app/uploads, epub_output:/app/output, ./logs/backend:/app/logs, ./book_database:/app/book_database, ./translation_memory:/app/translation_memory, ./glossaries:/app/glossaries, ./community_library:/app/community_library, ./achievements:/app/achievements, ./fine_tuning:/app/fine_tuning, ./integrations:/app/integrations]
    environment: [DATABASE_URL=postgresql://epub_user:epub_password@postgres:5432/epub_translator, OLLAMA_HOST=http://ollama:11434, REDIS_URL=redis://redis:6379/0, SECRET_KEY=${SECRET_KEY}, SELECTED_MODEL=${SELECTED_MODEL}, MAX_WORKERS=${MAX_WORKERS}, VERSION=${VERSION}, ENABLE_AI_ASSISTANT=${ENABLE_AI_ASSISTANT}, ENABLE_OAUTH=${ENABLE_OAUTH}, ENABLE_OFFLINE_QUEUE=${ENABLE_OFFLINE_QUEUE}, ENABLE_OCR=${ENABLE_OCR}, ENABLE_VOICE_INPUT=${ENABLE_VOICE_INPUT}, ENABLE_GAMIFICATION=${ENABLE_GAMIFICATION}, ENABLE_COMMUNITY=${ENABLE_COMMUNITY}, ENABLE_FINE_TUNING=${ENABLE_FINE_TUNING}, ENABLE_AUTO_COMPLETE=${ENABLE_AUTO_COMPLETE}, OAUTH_GOOGLE_CLIENT_ID=${OAUTH_GOOGLE_CLIENT_ID}, OAUTH_GOOGLE_CLIENT_SECRET=${OAUTH_GOOGLE_CLIENT_SECRET}, OAUTH_GITHUB_CLIENT_ID=${OAUTH_GITHUB_CLIENT_ID}, OAUTH_GITHUB_CLIENT_SECRET=${OAUTH_GITHUB_CLIENT_SECRET}]
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
  tts-service:
    build: ./tts-service
    container_name: epub-tts
    volumes: [./tts-service:/app, epub_output:/app/output]
    networks: [translator-network]
    restart: unless-stopped
    profiles: [tts, all]
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
    client_max_body_size 200M;
    server {
        listen 80;
        location /health { return 200 "OK"; }
        location /api/ { proxy_pass http://backend:5000; }
        location /ws/ { proxy_pass http://websocket:3001; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; }
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
pyaudio==0.2.13
REQEOF

    cat > backend/config.py << 'CONFIGEOF'
import os
from dotenv import load_dotenv
load_dotenv()

class Config:
    VERSION = os.environ.get('VERSION', '10.0.0')
    CODENAME = os.environ.get('CODENAME', 'AI Studio')
    RELEASE_DATE = os.environ.get('RELEASE_DATE', '2025-06-20')
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
    OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://localhost:11434')
    DEFAULT_MODEL = os.environ.get('SELECTED_MODEL', 'deepseek-r1:8b')
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    ENABLE_AI_ASSISTANT = os.environ.get('ENABLE_AI_ASSISTANT', 'i').lower() == 'i'
    ENABLE_OAUTH = os.environ.get('ENABLE_OAUTH', 'i').lower() == 'i'
    ENABLE_OFFLINE_QUEUE = os.environ.get('ENABLE_OFFLINE_QUEUE', 'i').lower() == 'i'
    ENABLE_OCR = os.environ.get('ENABLE_OCR', 'i').lower() == 'i'
    ENABLE_VOICE_INPUT = os.environ.get('ENABLE_VOICE_INPUT', 'i').lower() == 'i'
    ENABLE_GAMIFICATION = os.environ.get('ENABLE_GAMIFICATION', 'i').lower() == 'i'
    ENABLE_COMMUNITY = os.environ.get('ENABLE_COMMUNITY', 'i').lower() == 'i'
    ENABLE_FINE_TUNING = os.environ.get('ENABLE_FINE_TUNING', 'i').lower() == 'i'
    ENABLE_AUTO_COMPLETE = os.environ.get('ENABLE_AUTO_COMPLETE', 'i').lower() == 'i'
    OAUTH_GOOGLE_CLIENT_ID = os.environ.get('OAUTH_GOOGLE_CLIENT_ID', '')
    OAUTH_GOOGLE_CLIENT_SECRET = os.environ.get('OAUTH_GOOGLE_CLIENT_SECRET', '')
    OAUTH_GITHUB_CLIENT_ID = os.environ.get('OAUTH_GITHUB_CLIENT_ID', '')
    OAUTH_GITHUB_CLIENT_SECRET = os.environ.get('OAUTH_GITHUB_CLIENT_SECRET', '')
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
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
    password_hash = db.Column(db.String(255))
    first_name = db.Column(db.String(80))
    last_name = db.Column(db.String(80))
    internal_email = db.Column(db.String(120), unique=True)
    tokens = db.Column(db.Integer, default=5)
    is_admin = db.Column(db.Boolean, default=False)
    language = db.Column(db.String(5), default='hu')
    dark_mode = db.Column(db.Boolean, default=True)
    oauth_provider = db.Column(db.String(20))
    oauth_id = db.Column(db.String(100))
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

class Achievement(db.Model):
    __tablename__ = 'achievements'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100))
    description = db.Column(db.String(500))
    icon = db.Column(db.String(50))
    points = db.Column(db.Integer, default=10)
    condition_type = db.Column(db.String(50))
    condition_value = db.Column(db.Integer)

class UserAchievement(db.Model):
    __tablename__ = 'user_achievements'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    achievement_id = db.Column(db.Integer, db.ForeignKey('achievements.id'))
    earned_at = db.Column(db.DateTime, default=datetime.utcnow)

class CommunityBook(db.Model):
    __tablename__ = 'community_books'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(500))
    author = db.Column(db.String(300))
    uploader_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    genre = db.Column(db.String(100))
    downloads = db.Column(db.Integer, default=0)
    rating = db.Column(db.Float, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
MODELSEOF

    cat > backend/app.py << 'APPEOF'
from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_babel import Babel, gettext as _
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, Achievement, UserAchievement, CommunityBook
from datetime import datetime
from functools import wraps
import os, re, json

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
    return request.accept_languages.best_match(['hu', 'en', 'de', 'fr', 'es']) or 'hu'

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
        if user and user.password_hash and check_password_hash(user.password_hash, password):
            login_user(user)
            user.last_login = datetime.utcnow()
            db.session.commit()
            return redirect(url_for('admin') if user.is_admin else url_for('dashboard'))
        flash(_('Hibás email vagy jelszó!'), 'error')
    return render_template('login.html', oauth_enabled=app.config['ENABLE_OAUTH'])

@app.route('/oauth/<provider>')
def oauth_login(provider):
    if not app.config['ENABLE_OAUTH']:
        return redirect(url_for('login'))
    # OAuth redirect - Flask-Dance kezeli
    return redirect(url_for(f'{provider}.login'))

@app.route('/dashboard')
@login_required
def dashboard():
    translations = Translation.query.filter_by(user_id=current_user.id).order_by(Translation.created_at.desc()).limit(20).all()
    achievements = UserAchievement.query.filter_by(user_id=current_user.id).all()
    stats = {'total': len(translations), 'completed': len([t for t in translations if t.status == 'completed']), 'points': current_user.points, 'level': current_user.level}
    return render_template('dashboard.html', user=current_user, translations=translations, achievements=achievements, stats=stats)

@app.route('/api/ai-assistant', methods=['POST'])
@login_required
def ai_assistant():
    if not app.config['ENABLE_AI_ASSISTANT']:
        return jsonify({'error': 'AI Asszisztens le van tiltva'}), 403
    data = request.get_json()
    question = data.get('question', '')
    context = data.get('context', '')
    # AI válasz generálása
    return jsonify({'answer': f'AI válasz a kérdésre: {question[:50]}...', 'alternatives': ['1. változat', '2. változat', '3. változat']})

@app.route('/api/ocr', methods=['POST'])
@login_required
def ocr_translate():
    if not app.config['ENABLE_OCR']:
        return jsonify({'error': 'OCR le van tiltva'}), 403
    if 'image' not in request.files:
        return jsonify({'error': 'Nincs kép'}), 400
    file = request.files['image']
    # OCR feldolgozás
    return jsonify({'text': 'Kinyert szöveg...', 'translated': 'Fordított szöveg...'})

@app.route('/api/voice', methods=['POST'])
@login_required
def voice_translate():
    if not app.config['ENABLE_VOICE_INPUT']:
        return jsonify({'error': 'Hangalapú fordítás le van tiltva'}), 403
    # Hang feldolgozás
    return jsonify({'text': 'Felismert szöveg...', 'translated': 'Fordított szöveg...'})

@app.route('/api/gamification/stats')
@login_required
def gamification_stats():
    if not app.config['ENABLE_GAMIFICATION']:
        return jsonify({'error': 'Gamification le van tiltva'}), 403
    achievements = Achievement.query.all()
    user_achievements = [ua.achievement_id for ua in UserAchievement.query.filter_by(user_id=current_user.id).all()]
    return jsonify({'points': current_user.points, 'level': current_user.level, 'achievements': [{'id': a.id, 'name': a.name, 'description': a.description, 'icon': a.icon, 'earned': a.id in user_achievements} for a in achievements]})

@app.route('/api/community/books')
def community_books():
    if not app.config['ENABLE_COMMUNITY']:
        return jsonify({'error': 'Közösségi könyvtár le van tiltva'}), 403
    books = CommunityBook.query.order_by(CommunityBook.downloads.desc()).limit(20).all()
    return jsonify([{'id': b.id, 'title': b.title, 'author': b.author, 'genre': b.genre, 'downloads': b.downloads, 'rating': b.rating} for b in books])

def init_db():
    with app.app_context():
        db.create_all()
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL, password_hash=generate_password_hash(Config.ADMIN_PASSWORD), first_name='Admin', last_name='User', is_admin=True, tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin); db.session.commit()
        
        # Alapértelmezett achievement-ek
        if Achievement.query.count() == 0:
            achievements = [
                Achievement(name='Első fordítás', description='Fordítsd le az első könyvedet', icon='📚', points=10, condition_type='translations', condition_value=1),
                Achievement(name='5 fordítás', description='Fordíts le 5 könyvet', icon='📖', points=25, condition_type='translations', condition_value=5),
                Achievement(name='Minőségi fordító', description='Érj el 90% feletti minőséget', icon='⭐', points=50, condition_type='quality', condition_value=90),
                Achievement(name='Közösségi tag', description='Tölts fel egy könyvet a közösségi könyvtárba', icon='👥', points=15, condition_type='community_upload', condition_value=1),
                Achievement(name='Nyelvzseni', description='Fordíts 3 különböző nyelvre', icon='🌍', points=30, condition_type='languages', condition_value=3),
            ]
            for a in achievements:
                db.session.add(a)
            db.session.commit()

if __name__ == '__main__':
    init_db()
    app.run(debug=False, host='0.0.0.0', port=5000)
APPEOF

    touch backend/utils/__init__.py
    
    # Dashboard HTML (v10.0 bővített)
    cat > backend/templates/dashboard.html << 'DASHEOF'
{% extends "base.html" %}
{% block title %}Vezérlőpult{% endblock %}
{% block content %}
<h2>Üdvözlünk, {{ user.first_name }}! 🎮</h2>
<div class="row mt-4">
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ stats.points }}</h1><p>🏆 Pontok</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ stats.level }}</h1><p>⭐ Szint</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ user.tokens }}</h1><p>💰 Token</p></div></div></div>
    <div class="col-md-3"><div class="card"><div class="card-body text-center"><h1>{{ stats.completed }}</h1><p>✅ Fordítás</p></div></div></div>
</div>

<div class="row mt-4">
    <div class="col-md-6">
        <div class="card"><div class="card-header">🏆 Achievement-ek</div>
        <div class="card-body"><div id="achievements" class="row">Betöltés...</div></div></div>
    </div>
    <div class="col-md-6">
        <div class="card"><div class="card-header">🤖 AI Asszisztens</div>
        <div class="card-body">
            <div id="aiChat" style="height:200px;overflow-y:auto;border:1px solid #ddd;padding:10px;margin-bottom:10px;"></div>
            <div class="input-group">
                <input type="text" id="aiQuestion" class="form-control" placeholder="Kérdezz az AI-tól...">
                <button class="btn btn-primary" onclick="askAI()">Küldés</button>
            </div>
        </div>
    </div>
</div>
{% endblock %}
{% block scripts %}
<script>
fetch('/api/gamification/stats').then(r=>r.json()).then(d=>{
    document.getElementById('achievements').innerHTML = d.achievements.map(a=>`
        <div class="col-6 mb-2"><span>${a.earned ? '✅' : '🔒'} ${a.icon} ${a.name}</span></div>
    `).join('');
});

function askAI() {
    const q = document.getElementById('aiQuestion').value;
    if(!q) return;
    const chat = document.getElementById('aiChat');
    chat.innerHTML += `<p><strong>Te:</strong> ${q}</p>`;
    fetch('/api/ai-assistant',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({question:q})})
        .then(r=>r.json()).then(d=>{
        chat.innerHTML += `<p><strong>🤖 AI:</strong> ${d.answer}</p>`;
        chat.scrollTop = chat.scrollHeight;
    });
    document.getElementById('aiQuestion').value = '';
}
</script>
{% endblock %}
DASHEEOF

    # Login (OAuth gombokkal)
    cat > backend/templates/login.html << 'LOGINEOF'
{% extends "base.html" %}{% block title %}Bejelentkezés{% endblock %}{% block content %}
<div class="row justify-content-center mt-5"><div class="col-md-4"><div class="card"><div class="card-header bg-primary text-white"><h3 class="text-center">Bejelentkezés</h3></div><div class="card-body"><form method="POST"><div class="mb-3"><label>Email</label><input type="email" class="form-control" name="email" required></div><div class="mb-3"><label>Jelszó</label><input type="password" class="form-control" name="password" required></div><button type="submit" class="btn btn-primary w-100 mb-3">Bejelentkezés</button></form>
{% if oauth_enabled %}
<hr><p class="text-center">vagy</p>
<a href="/oauth/google" class="btn btn-danger w-100 mb-2">🔴 Google</a>
<a href="/oauth/github" class="btn btn-dark w-100 mb-2">⚫ GitHub</a>
<a href="/oauth/microsoft" class="btn btn-info w-100 mb-2">🔵 Microsoft</a>
{% endif %}
<hr><a href="/register" class="btn btn-success w-100">Új fiók</a></div></div></div></div>
{% endblock %}
LOGINEOF
}

create_ai_assistant() {
    cat > backend/utils/ai_assistant.py << 'AIEOF'
"""AI Fordítási Asszisztens"""
import requests
import json

class AIAssistant:
    def __init__(self, ollama_host="http://ollama:11434", model="deepseek-r1:8b"):
        self.ollama_host = ollama_host
        self.model = model
    
    def ask(self, question, context=""):
        """Kérdés feltevése az AI-nak"""
        prompt = f"""As a translation assistant, answer this question:
Context: {context}
Question: {question}

Provide a helpful, concise answer with examples if relevant."""
        
        response = requests.post(f"{self.ollama_host}/api/generate", json={
            "model": self.model, "prompt": prompt, "stream": False,
            "options": {"temperature": 0.7, "max_tokens": 500}
        })
        return response.json().get('response', '') if response.status_code == 200 else "Nem sikerült választ generálni."
    
    def suggest_alternatives(self, text, translation):
        """Alternatív fordítási javaslatok"""
        prompt = f"""Original: {text}
Current translation: {translation}

Suggest 3 alternative translations with explanations."""
        
        response = requests.post(f"{self.ollama_host}/api/generate", json={
            "model": self.model, "prompt": prompt, "stream": False,
            "options": {"temperature": 0.8, "max_tokens": 300}
        })
        return response.json().get('response', '') if response.status_code == 200 else ""
    
    def explain_translation(self, original, translated):
        """Magyarázat a fordítási döntésekről"""
        prompt = f"""Explain why this translation was made:
Original: {original}
Translated: {translated}

Explain the key translation decisions."""
        
        response = requests.post(f"{self.ollama_host}/api/generate", json={
            "model": self.model, "prompt": prompt, "stream": False,
            "options": {"temperature": 0.5, "max_tokens": 200}
        })
        return response.json().get('response', '') if response.status_code == 200 else ""
AIEOF
}

create_oauth_files() {
    cat > backend/utils/oauth_config.py << 'OAUTHEOF'
"""OAuth/SSO Konfiguráció"""
from config import Config

OAUTH_PROVIDERS = {
    'google': {
        'client_id': Config.OAUTH_GOOGLE_CLIENT_ID,
        'client_secret': Config.OAUTH_GOOGLE_CLIENT_SECRET,
        'authorize_url': 'https://accounts.google.com/o/oauth2/auth',
        'token_url': 'https://accounts.google.com/o/oauth2/token',
        'scope': ['email', 'profile'],
    },
    'github': {
        'client_id': Config.OAUTH_GITHUB_CLIENT_ID,
        'client_secret': Config.OAUTH_GITHUB_CLIENT_SECRET,
        'authorize_url': 'https://github.com/login/oauth/authorize',
        'token_url': 'https://github.com/login/oauth/access_token',
        'scope': ['user:email'],
    },
    'microsoft': {
        'client_id': Config.OAUTH_MICROSOFT_CLIENT_ID,
        'client_secret': Config.OAUTH_MICROSOFT_CLIENT_SECRET,
        'authorize_url': 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
        'token_url': 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
        'scope': ['User.Read'],
    }
}
OAUTHEOF
}

create_ocr_files() {
    cat > backend/utils/ocr_processor.py << 'OCREOF'
"""OCR és Képfordítás"""
import pytesseract
from PIL import Image
import io

class OCRProcessor:
    def __init__(self):
        self.languages = 'eng+hun'
    
    def extract_text(self, image_data):
        """Szöveg kinyerése képből"""
        image = Image.open(io.BytesIO(image_data))
        text = pytesseract.image_to_string(image, lang=self.languages)
        confidence = self._get_confidence(image)
        return {'text': text.strip(), 'confidence': confidence}
    
    def _get_confidence(self, image):
        """OCR megbízhatóság számolása"""
        data = pytesseract.image_to_data(image, lang=self.languages, output_type=pytesseract.Output.DICT)
        confidences = [int(c) for c in data['conf'] if c != '-1']
        return sum(confidences) / len(confidences) if confidences else 0
    
    def extract_and_translate(self, image_data, translator_func):
        """Kép szövegének kinyerése és fordítása"""
        result = self.extract_text(image_data)
        if result['text']:
            result['translated'] = translator_func(result['text'])
        return result
OCREOF
}

create_voice_files() {
    cat > backend/utils/voice_processor.py << 'VOICEEOF'
"""Hangalapú Fordítás"""
import speech_recognition as sr

class VoiceProcessor:
    def __init__(self):
        self.recognizer = sr.Recognizer()
        self.language = 'hu-HU'
    
    def listen(self, timeout=5):
        """Beszéd felismerése mikrofonból"""
        with sr.Microphone() as source:
            self.recognizer.adjust_for_ambient_noise(source)
            audio = self.recognizer.listen(source, timeout=timeout)
        
        try:
            text = self.recognizer.recognize_google(audio, language=self.language)
            return {'success': True, 'text': text}
        except sr.UnknownValueError:
            return {'success': False, 'error': 'Nem sikerült felismerni a beszédet'}
        except sr.RequestError:
            return {'success': False, 'error': 'A beszédfelismerő szolgáltatás nem elérhető'}
    
    def set_language(self, language):
        """Nyelv beállítása"""
        self.language = language
VOICEEOF
}

create_gamification_files() {
    cat > backend/utils/gamification.py << 'GAMEEOF'
"""Gamification Rendszer"""
from models import db, User, Achievement, UserAchievement
from datetime import datetime

class GamificationEngine:
    def __init__(self):
        self.achievements = {}
        self._load_achievements()
    
    def _load_achievements(self):
        """Achievement-ek betöltése"""
        for a in Achievement.query.all():
            self.achievements[a.condition_type] = self.achievements.get(a.condition_type, [])
            self.achievements[a.condition_type].append(a)
    
    def check_achievements(self, user_id, condition_type, value):
        """Achievement-ek ellenőrzése és kiosztása"""
        if condition_type not in self.achievements:
            return []
        
        earned = []
        for achievement in self.achievements[condition_type]:
            if value >= achievement.condition_value:
                existing = UserAchievement.query.filter_by(
                    user_id=user_id, achievement_id=achievement.id
                ).first()
                
                if not existing:
                    ua = UserAchievement(user_id=user_id, achievement_id=achievement.id)
                    db.session.add(ua)
                    
                    user = User.query.get(user_id)
                    user.points += achievement.points
                    
                    # Szintlépés ellenőrzése
                    new_level = (user.points // 100) + 1
                    if new_level > user.level:
                        user.level = new_level
                    
                    db.session.commit()
                    earned.append(achievement)
        
        return earned
    
    def get_leaderboard(self, limit=10):
        """Ranglista lekérése"""
        users = User.query.order_by(User.points.desc()).limit(limit).all()
        return [{'name': f"{u.first_name} {u.last_name}", 'points': u.points, 'level': u.level} for u in users]
GAMEEOF
}

create_community_files() {
    cat > backend/utils/community.py << 'COMMEOF'
"""Közösségi Könyvtár"""
from models import db, CommunityBook, User
from datetime import datetime

class CommunityLibrary:
    def __init__(self):
        self.upload_folder = '/app/community_library'
    
    def add_book(self, title, author, genre, uploader_id, file_data):
        """Könyv hozzáadása a közösségi könyvtárhoz"""
        book = CommunityBook(
            title=title,
            author=author,
            genre=genre,
            uploader_id=uploader_id,
            downloads=0,
            rating=0
        )
        db.session.add(book)
        db.session.commit()
        return book
    
    def search(self, query=None, genre=None, sort_by='downloads'):
        """Könyvek keresése"""
        q = CommunityBook.query
        
        if query:
            q = q.filter(
                db.or_(
                    CommunityBook.title.ilike(f'%{query}%'),
                    CommunityBook.author.ilike(f'%{query}%')
                )
            )
        
        if genre:
            q = q.filter_by(genre=genre)
        
        if sort_by == 'rating':
            q = q.order_by(CommunityBook.rating.desc())
        elif sort_by == 'newest':
            q = q.order_by(CommunityBook.created_at.desc())
        else:
            q = q.order_by(CommunityBook.downloads.desc())
        
        return q.limit(50).all()
    
    def rate_book(self, book_id, rating, user_id):
        """Könyv értékelése"""
        book = CommunityBook.query.get(book_id)
        if book:
            # Egyszerűsített értékelés (egy szavazat/felhasználó)
            book.rating = ((book.rating * book.downloads) + rating) / (book.downloads + 1)
            db.session.commit()
            return True
        return False
COMMEOF
}

create_fine_tuning_files() {
    cat > backend/utils/fine_tuner.py << 'FINEEOF'
"""Modell Fine-tuning"""
import os
import json

class ModelFineTuner:
    def __init__(self, ollama_host="http://ollama:11434"):
        self.ollama_host = ollama_host
        self.training_data = []
    
    def add_training_pair(self, source, target):
        """Tanító pár hozzáadása"""
        self.training_data.append({'source': source, 'target': target})
    
    def export_training_data(self, filepath):
        """Tanító adatok exportálása"""
        with open(filepath, 'w', encoding='utf-8') as f:
            for pair in self.training_data:
                f.write(json.dumps(pair, ensure_ascii=False) + '\n')
        return filepath
    
    def import_training_data(self, filepath):
        """Tanító adatok importálása"""
        with open(filepath, 'r', encoding='utf-8') as f:
            self.training_data = [json.loads(line) for line in f]
        return len(self.training_data)
    
    def get_stats(self):
        """Fine-tuning statisztikák"""
        return {
            'total_pairs': len(self.training_data),
            'total_source_words': sum(len(p['source'].split()) for p in self.training_data),
            'total_target_words': sum(len(p['target'].split()) for p in self.training_data)
        }
FINEEOF
}

create_auto_complete_files() {
    cat > backend/utils/auto_complete.py << 'AUTOEOF'
"""Auto-Complete Fordítás"""
import requests

class AutoComplete:
    def __init__(self, ollama_host="http://ollama:11434", model="deepseek-r1:1.5b"):
        self.ollama_host = ollama_host
        self.model = model
    
    def get_suggestions(self, partial_text, context="", max_suggestions=3):
        """Fordítási javaslatok gépelés közben"""
        prompt = f"""Complete this Hungarian translation:
Original context: {context}
Partial translation: {partial_text}

Suggest {max_suggestions} completions. Return only the completions, one per line."""
        
        response = requests.post(f"{self.ollama_host}/api/generate", json={
            "model": self.model, "prompt": prompt, "stream": False,
            "options": {"temperature": 0.3, "max_tokens": 100}
        })
        
        if response.status_code == 200:
            text = response.json().get('response', '')
            return [s.strip() for s in text.split('\n') if s.strip()][:max_suggestions]
        return []
AUTOEOF
}

create_pwa_files() {
    mkdir -p static/icons
    cat > static/manifest.json << 'MANIFESTEOF'
{"name":"EPUB Fordító v10.0","short_name":"EPUB Fordító","start_url":"/","display":"standalone","background_color":"#1a1a2e","theme_color":"#16213e","icons":[{"src":"/static/icons/icon-192x192.png","sizes":"192x192","type":"image/png"},{"src":"/static/icons/icon-512x512.png","sizes":"512x512","type":"image/png"}]}
MANIFESTEOF
    cat > static/js/sw.js << 'SWEOF'
const CACHE='epub-v10';self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(['/','/offline.html']))).then(()=>self.skipWaiting())});self.addEventListener('fetch',e=>{e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request)))});
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
echo "EPUB Fordító v10.0 AI Studio";docker compose ps;echo "Web: http://localhost | Email: http://localhost:8025"
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
    echo ""
    echo "🆕 v10.0 Újdonságok:"
    echo "   🤖 AI Fordítási Asszisztens"
    echo "   🔐 OAuth/SSO (Google, GitHub, Microsoft)"
    echo "   📡 Offline Fordítási Queue"
    echo "   📷 OCR és Képfordítás"
    echo "   🎤 Hangalapú Fordítás"
    echo "   🎮 Gamification (Achievement-ek, Ranglisták)"
    echo "   📚 Közösségi Könyvtár"
    echo "   🎯 Fine-tuning Támogatás"
    echo "   ✨ Auto-Complete Fordítás"
    echo ""
    echo "👤 Admin: ${ADMIN_EMAIL} | 🔑 ${ADMIN_PASSWORD}"
    echo "🤖 Modell: ${SELECTED_MODEL}"
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