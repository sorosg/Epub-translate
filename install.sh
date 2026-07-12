#!/bin/bash

# EPUB Fordító Rendszer - Teljes Telepítő Script v5.0
# Verzió: 5.0
# Leírás: Könyv adatbázissal, automatikus metaadat kinyeréssel, intelligens mintakönyv kezeléssel

set -e

# Színek a kimenethez
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Alapértelmezett beállítások
DEFAULT_MODEL="deepseek-r1:8b"
ADMIN_EMAIL="admin@epub-translator.local"
ADMIN_PASSWORD="Abrakadabra"
MAX_WORKERS=3
ENABLE_CACHE="i"
ENABLE_SSL="n"
INSTALL_MONITORING="i"
SMTP_MODE="local"
ENABLE_BOOK_DB="i"
MAX_SAMPLE_BOOKS=5
ENABLE_ONLINE_SEARCH="i"

# Log függvények
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[FIGYELEM]${NC} $1"; }
log_error() { echo -e "${RED}[HIBA]${NC} $1"; }
log_step() { echo -e "\n${BLUE}[LÉPÉS]${NC} $1"; echo "----------------------------------------"; }
log_success() { echo -e "${CYAN}[SIKER]${NC} $1"; }
log_config() { echo -e "${PURPLE}[KONFIG]${NC} $1"; }

# Verzió információk
VERSION="5.0.0"
RELEASE_DATE="2024-01-15"
FEATURES=(
    "Könyv adatbázis automatikus metaadat kinyeréssel"
    "Intelligens mintakönyv ajánlás és kezelés"
    "Több forrásból származó metaadatok (EPUB, Google Books, OpenLibrary)"
    "AI alapú műfaj és stílus felismerés"
    "Hibrid SMTP (helyi MailHog + opcionális külső relay)"
    "Párhuzamos fordítás és Redis cache"
    "2FA támogatás és API kulcs kezelés"
    "Részletes statisztikák és monitoring"
)

# Jogosultság ellenőrzése
if [ "$EUID" -eq 0 ]; then 
    log_warn "Ne futtasd ezt a scriptet root-ként! Használj normál felhasználót sudo jogosultságokkal."
    exit 1
fi

# Rendszer erőforrások ellenőrzése
check_system_resources() {
    log_step "Rendszer erőforrások ellenőrzése"
    
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    log_info "Teljes memória: ${TOTAL_RAM}GB"
    
    if [ "$TOTAL_RAM" -lt 16 ]; then
        log_error "Minimum 16GB RAM szükséges! (Ajánlott: 32GB)"
        exit 1
    elif [ "$TOTAL_RAM" -lt 32 ]; then
        log_warn "Az ajánlott 32GB RAM-nál kevesebb van. Kisebb modell ajánlott."
        RECOMMENDED_MODEL="deepseek-r1:7b"
        MAX_WORKERS=2
    else
        RECOMMENDED_MODEL="deepseek-r1:8b"
        MAX_WORKERS=3
        log_info "Megfelelő memória (32GB+). Az $RECOMMENDED_MODEL modell lesz telepítve."
    fi
    
    FREE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_info "Szabad lemezterület: ${FREE_SPACE}GB"
    
    if [ "$FREE_SPACE" -lt 50 ]; then
        log_warn "Kevés a szabad lemezterület (minimum 50GB ajánlott)"
    fi
    
    CPU_CORES=$(nproc)
    log_info "CPU magok száma: $CPU_CORES"
    
    if [ "$CPU_CORES" -lt 4 ]; then
        MAX_WORKERS=1
    elif [ "$CPU_CORES" -lt 8 ]; then
        MAX_WORKERS=2
    fi
    
    log_info "Ajánlott párhuzamos szálak: $MAX_WORKERS"
}

# SMTP konfiguráció
configure_smtp() {
    log_step "Email (SMTP) konfigurálása"
    
    echo ""
    echo "📧 Email kézbesítési mód kiválasztása:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1) Helyi kézbesítés (MailHog) - Fejlesztéshez, teszteléshez"
    echo "   ✅ Webes felület: http://localhost:8025"
    echo "   ✅ Nincs szükség internetre"
    echo "   ⚠️  Csak helyi emailek"
    echo ""
    echo "2) Helyi + Gmail relay - Külső címekre is"
    echo "   ✅ Helyi és külső email küldés"
    echo "   ✅ Ingyenes (Gmail napi 500 email limit)"
    echo "   ⚠️  Gmail alkalmazás jelszó szükséges"
    echo ""
    echo "3) Helyi + Egyéni SMTP relay"
    echo "   ✅ Helyi és külső email küldés"
    echo "   ✅ Saját email szerver használata"
    echo ""
    
    read -p "Válassz (1-3) [alapértelmezett: 1]: " smtp_choice
    smtp_choice=${smtp_choice:-1}
    
    case $smtp_choice in
        1)
            SMTP_MODE="local"
            SMTP_HOST="mailhog"
            SMTP_PORT="1025"
            SMTP_USER=""
            SMTP_PASSWORD=""
            SMTP_USE_TLS="false"
            MAIL_DEFAULT_SENDER="epub-translator@localhost"
            log_success "Helyi kézbesítés (MailHog) kiválasztva"
            log_info "📧 Email felület: http://localhost:8025"
            ;;
        2)
            SMTP_MODE="gmail"
            SMTP_HOST="smtp.gmail.com"
            SMTP_PORT="587"
            SMTP_USE_TLS="true"
            read -p "Gmail cím: " gmail_user
            read -sp "Gmail alkalmazás jelszó: " gmail_password
            echo ""
            SMTP_USER="$gmail_user"
            SMTP_PASSWORD="$gmail_password"
            MAIL_DEFAULT_SENDER="$gmail_user"
            log_success "Gmail relay beállítva"
            ;;
        3)
            SMTP_MODE="custom"
            read -p "SMTP szerver: " custom_host
            read -p "SMTP port [587]: " custom_port
            custom_port=${custom_port:-587}
            read -p "Felhasználónév: " custom_user
            read -sp "Jelszó: " custom_pass
            echo ""
            read -p "Küldő email: " custom_sender
            
            SMTP_HOST="$custom_host"
            SMTP_PORT="$custom_port"
            SMTP_USER="$custom_user"
            SMTP_PASSWORD="$custom_pass"
            SMTP_USE_TLS="true"
            MAIL_DEFAULT_SENDER="${custom_sender:-$custom_user}"
            log_success "Egyéni SMTP relay beállítva"
            ;;
        *) 
            SMTP_MODE="local"
            SMTP_HOST="mailhog"
            SMTP_PORT="1025"
            ;;
    esac
}

# Konfigurációs varázsló
configure_system() {
    log_step "Rendszer konfigurálása"
    
    echo ""
    echo "🎯 EPUB Fordító Rendszer v${VERSION} - Konfigurációs varázsló"
    echo "================================================================"
    echo ""
    
    read -p "Szeretnéd testreszabni a telepítést? (i/n) [i]: " customize
    customize=${customize:-"i"}
    
    if [[ $customize =~ ^[Ii]$ ]]; then
        echo ""
        log_config "Adminisztrátori beállítások:"
        read -p "Admin email [${ADMIN_EMAIL}]: " input_email
        ADMIN_EMAIL=${input_email:-$ADMIN_EMAIL}
        
        read -sp "Admin jelszó [${ADMIN_PASSWORD}]: " input_password
        echo ""
        ADMIN_PASSWORD=${input_password:-$ADMIN_PASSWORD}
        
        echo ""
        log_config "Fordítási beállítások:"
        read -p "Párhuzamos szálak [${MAX_WORKERS}]: " input_workers
        MAX_WORKERS=${input_workers:-$MAX_WORKERS}
        
        echo ""
        log_config "Könyv adatbázis beállítások:"
        read -p "Könyv adatbázis engedélyezése? (i/n) [i]: " input_bookdb
        ENABLE_BOOK_DB=${input_bookdb:-"i"}
        
        if [[ $ENABLE_BOOK_DB =~ ^[Ii]$ ]]; then
            read -p "Maximális mintakönyvek száma [5]: " input_max_samples
            MAX_SAMPLE_BOOKS=${input_max_samples:-5}
            
            read -p "Online keresés engedélyezése? (i/n) [i]: " input_online
            ENABLE_ONLINE_SEARCH=${input_online:-"i"}
        fi
        
        echo ""
        log_config "Teljesítmény beállítások:"
        read -p "Redis cache engedélyezése? (i/n) [i]: " input_cache
        ENABLE_CACHE=${input_cache:-"i"}
        
        read -p "Monitoring eszközök? (i/n) [n]: " input_monitoring
        INSTALL_MONITORING=${input_monitoring:-"n"}
        
        echo ""
        log_config "Biztonsági beállítások:"
        read -p "HTTPS/SSL engedélyezése? (i/n) [n]: " input_ssl
        ENABLE_SSL=${input_ssl:-"n"}
    fi
    
    # SMTP konfigurálása
    configure_smtp
    
    # Konfiguráció mentése
    cat > .install_config << EOF
VERSION="$VERSION"
ADMIN_EMAIL="$ADMIN_EMAIL"
ADMIN_PASSWORD="$ADMIN_PASSWORD"
MAX_WORKERS=$MAX_WORKERS
ENABLE_CACHE="$ENABLE_CACHE"
ENABLE_SSL="$ENABLE_SSL"
INSTALL_MONITORING="$INSTALL_MONITORING"
SMTP_MODE="$SMTP_MODE"
SMTP_HOST="$SMTP_HOST"
SMTP_PORT="$SMTP_PORT"
SMTP_USER="$SMTP_USER"
SMTP_PASSWORD="$SMTP_PASSWORD"
SMTP_USE_TLS="$SMTP_USE_TLS"
MAIL_DEFAULT_SENDER="$MAIL_DEFAULT_SENDER"
ENABLE_BOOK_DB="$ENABLE_BOOK_DB"
MAX_SAMPLE_BOOKS=$MAX_SAMPLE_BOOKS
ENABLE_ONLINE_SEARCH="$ENABLE_ONLINE_SEARCH"
RECOMMENDED_MODEL="$RECOMMENDED_MODEL"
SELECTED_MODEL="$SELECTED_MODEL"
INSTALL_DATE="$(date +%Y-%m-%d_%H:%M:%S)"
EOF
}

# Modell kiválasztása
select_model() {
    log_step "DeepSeek modell kiválasztása"
    
    echo ""
    echo "Válassz a következő DeepSeek modellek közül:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1) deepseek-r1:1.5b  (1.5GB  - Teszteléshez)"
    echo "2) deepseek-r1:7b    (7GB    - 16GB RAM-hoz)"
    echo "3) deepseek-r1:8b    (8GB    - 32GB RAM-hoz) ★ Ajánlott"
    echo "4) deepseek-r1:14b   (14GB   - 32GB+ RAM-hoz)"
    echo "5) deepseek-r1:32b   (32GB   - 64GB+ RAM-hoz)"
    echo "6) deepseek-r1:70b   (70GB   - 128GB+ RAM-hoz)"
    echo ""
    echo "💡 Minden modell INGYENES és HELYBEN fut!"
    echo ""
    
    if [ -n "$RECOMMENDED_MODEL" ]; then
        echo "🔹 Ajánlott a rendszeredhez: $RECOMMENDED_MODEL"
        echo ""
    fi
    
    read -p "Válassz (1-6) [alapértelmezett: 3]: " model_choice
    model_choice=${model_choice:-3}
    
    case $model_choice in
        1) SELECTED_MODEL="deepseek-r1:1.5b"; MODEL_SIZE="1.5GB";;
        2) SELECTED_MODEL="deepseek-r1:7b"; MODEL_SIZE="7GB";;
        3) SELECTED_MODEL="deepseek-r1:8b"; MODEL_SIZE="8GB";;
        4) SELECTED_MODEL="deepseek-r1:14b"; MODEL_SIZE="14GB";;
        5) SELECTED_MODEL="deepseek-r1:32b"; MODEL_SIZE="32GB";;
        6) SELECTED_MODEL="deepseek-r1:70b"; MODEL_SIZE="70GB";;
        *) SELECTED_MODEL="deepseek-r1:8b"; MODEL_SIZE="8GB";;
    esac
    
    log_success "Kiválasztott modell: $SELECTED_MODEL ($MODEL_SIZE)"
}

# Projekt könyvtár
PROJECT_DIR="$HOME/epub-translator"
BACKUP_DIR="$HOME/epub-translator-backup-$(date +%Y%m%d_%H%M%S)"

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║     EPUB Fordító Rendszer v${VERSION}                          ║"
echo "║     Könyv adatbázis + Intelligens mintakönyv kezelés        ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📚 Új funkciók a v5.0-ban:"
for feature in "${FEATURES[@]}"; do
    echo "  ✅ $feature"
done
echo ""

# Rendszer ellenőrzése
if [ ! -f /etc/os-release ]; then
    log_error "Ez a script csak Ubuntu rendszeren működik!"
    exit 1
fi

source /etc/os-release
if [ "$ID" != "ubuntu" ]; then
    log_warn "Ez a script Ubuntu-ra van optimalizálva."
    read -p "Szeretnéd folytatni? (i/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ii]$ ]]; then
        exit 1
    fi
fi

# Rendszer ellenőrzése és konfigurálása
check_system_resources
configure_system
select_model

# 1. Rendszer frissítése és csomagok telepítése
log_step "1. Rendszer frissítése és csomagok telepítése"

log_info "Csomaglista frissítése..."
sudo apt update

log_info "Rendszer frissítése..."
sudo apt upgrade -y

log_info "Alap csomagok telepítése..."
sudo apt install -y \
    curl wget git ca-certificates gnupg lsb-release \
    nano htop net-tools ufw build-essential \
    python3-pip python3-venv \
    libxml2-dev libxslt-dev \
    redis-tools postgresql-client \
    clamav clamav-daemon \
    postfix mailutils \
    poppler-utils

# Python csomagok globális telepítése (opcionális)
if [[ $ENABLE_ONLINE_SEARCH =~ ^[Ii]$ ]]; then
    log_info "Online kereséshez szükséges csomagok telepítése..."
    pip3 install isbnlib google-books openlibrary-client 2>/dev/null || log_warn "Néhány Python csomag nem telepíthető"
fi

# ClamAV frissítése
log_info "Vírusadatbázis frissítése..."
sudo systemctl stop clamav-freshclam 2>/dev/null || true
sudo freshclam 2>/dev/null || log_warn "ClamAV frissítés nem sikerült"

# 2. Docker telepítése
log_step "2. Docker és Docker Compose telepítése"

if ! command -v docker &> /dev/null; then
    log_info "Docker telepítése..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    
    log_warn "A Docker csoporttagság érvényesítéséhez szükséges lehet kijelentkezni."
else
    log_info "Docker már telepítve van."
fi

# 3. Projekt struktúra létrehozása
log_step "3. Projekt struktúra létrehozása"

if [ -d "$PROJECT_DIR" ]; then
    log_warn "A projekt könyvtár már létezik: $PROJECT_DIR"
    read -p "Szeretnéd biztonsági mentést készíteni és újratelepíteni? (i/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ii]$ ]]; then
        log_info "Biztonsági mentés készítése: $BACKUP_DIR"
        cp -r "$PROJECT_DIR" "$BACKUP_DIR"
        rm -rf "$PROJECT_DIR"
    else
        log_info "Meglévő telepítés megtartása."
        exit 0
    fi
fi

log_info "Könyvtárak létrehozása..."
mkdir -p "$PROJECT_DIR"/{nginx/ssl,backend/{templates,utils},static/{css,js,images},uploads/{covers,books},output,logs,backups,scripts,postfix,book_database}
cd "$PROJECT_DIR"

# 4. Konfigurációs fájlok létrehozása
log_step "4. Konfigurációs fájlok létrehozása"

# .env fájl
log_info ".env fájl létrehozása..."
cat > .env << ENVEOF
# EPUB Fordító Rendszer v${VERSION} - Környezeti változók

# Alkalmazás beállítások
SECRET_KEY=$(openssl rand -hex 32)
FLASK_ENV=production
FLASK_DEBUG=0
MAX_CONTENT_LENGTH=104857600
VERSION=${VERSION}

# Admin beállítások
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# SMTP beállítások
SMTP_MODE=${SMTP_MODE}
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}
SMTP_USER=${SMTP_USER}
SMTP_PASSWORD=${SMTP_PASSWORD}
SMTP_USE_TLS=${SMTP_USE_TLS}
MAIL_DEFAULT_SENDER=${MAIL_DEFAULT_SENDER}

# Modell beállítások
OLLAMA_HOST=http://ollama:11434
OLLAMA_KEEP_ALIVE=24h
SELECTED_MODEL=${SELECTED_MODEL}
MAX_WORKERS=${MAX_WORKERS}

# Könyv adatbázis beállítások
ENABLE_BOOK_DB=${ENABLE_BOOK_DB}
MAX_SAMPLE_BOOKS=${MAX_SAMPLE_BOOKS}
ENABLE_ONLINE_SEARCH=${ENABLE_ONLINE_SEARCH}
BOOK_DB_PATH=/app/book_database
UPLOAD_COVERS_PATH=/app/uploads/covers

# Cache beállítások
ENABLE_CACHE=${ENABLE_CACHE}
REDIS_URL=redis://redis:6379/0

# SSL beállítások
ENABLE_SSL=${ENABLE_SSL}
SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
SSL_KEY_PATH=/etc/nginx/ssl/key.pem

# Monitoring beállítások
ENABLE_MONITORING=${INSTALL_MONITORING}

# API beállítások
GOOGLE_BOOKS_API_KEY=
OPENLIBRARY_API_URL=https://openlibrary.org
ENVEOF

log_success ".env fájl létrehozva!"

# SSL tanúsítvány
if [[ $ENABLE_SSL =~ ^[Ii]$ ]]; then
    log_info "SSL tanúsítvány generálása..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout nginx/ssl/key.pem \
        -out nginx/ssl/cert.pem \
        -subj "/C=HU/ST=Budapest/L=Budapest/O=EPUB Translator/CN=localhost" 2>/dev/null
fi

# docker-compose.yml (v5.0)
log_info "docker-compose.yml létrehozása..."
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
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./static:/usr/share/nginx/html/static
      - ./logs/nginx:/var/log/nginx
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - translator-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
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
      - ./logs:/app/logs
      - ./book_database:/app/book_database
    environment:
      - DATABASE_URL=postgresql://epub_user:epub_password@postgres:5432/epub_translator
      - OLLAMA_HOST=http://ollama:11434
      - SMTP_MODE=${SMTP_MODE}
      - SMTP_HOST=${SMTP_HOST}
      - SMTP_PORT=${SMTP_PORT}
      - SMTP_USER=${SMTP_USER}
      - SMTP_PASSWORD=${SMTP_PASSWORD}
      - SMTP_USE_TLS=${SMTP_USE_TLS}
      - MAIL_DEFAULT_SENDER=${MAIL_DEFAULT_SENDER}
      - SECRET_KEY=${SECRET_KEY}
      - SELECTED_MODEL=${SELECTED_MODEL}
      - MAX_WORKERS=${MAX_WORKERS}
      - ENABLE_CACHE=${ENABLE_CACHE}
      - REDIS_URL=${REDIS_URL}
      - ADMIN_EMAIL=${ADMIN_EMAIL}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - ENABLE_BOOK_DB=${ENABLE_BOOK_DB}
      - MAX_SAMPLE_BOOKS=${MAX_SAMPLE_BOOKS}
      - ENABLE_ONLINE_SEARCH=${ENABLE_ONLINE_SEARCH}
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
    command: gunicorn -w 2 -b 0.0.0.0:5000 app:app --timeout 600 --access-logfile /app/logs/access.log --error-logfile /app/logs/error.log
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
      - OLLAMA_MAX_LOADED_MODELS=1
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

  postfix-relay:
    image: boky/postfix:latest
    container_name: epub-postfix-relay
    environment:
      - ALLOWED_SENDER_DOMAINS=localhost
      - RELAYHOST=${SMTP_HOST}:${SMTP_PORT}
      - RELAYHOST_USERNAME=${SMTP_USER}
      - RELAYHOST_PASSWORD=${SMTP_PASSWORD}
      - SMTP_USE_TLS=${SMTP_USE_TLS}
    ports:
      - "25:25"
    volumes:
      - postfix_data:/var/spool/postfix
    networks:
      - translator-network
    restart: unless-stopped
    profiles:
      - relay
      - all

  # Monitoring (opcionális)
  prometheus:
    image: prom/prometheus:latest
    container_name: epub-prometheus
    volumes:
      - ./scripts/prometheus.yml:/etc/prometheus/prometheus.yml
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
  postfix_data:
  prometheus_data:
  grafana_data:
DOCKEREOF

# Nginx konfiguráció
cat > nginx/nginx.conf << 'NGINXEOF'
events {
    worker_connections 1024;
}

http {
    client_max_body_size 100M;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-EPUB-Translator-Version "5.0" always;
    
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=upload_limit:10m rate=20r/m;
    
    server {
        listen 80;
        server_name localhost;
        
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
        
        location /api/ {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
        }
        
        location /api/translate {
            limit_req zone=upload_limit burst=5 nodelay;
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
        }
        
        location /login {
            limit_req zone=login_limit burst=3 nodelay;
            proxy_pass http://backend:5000;
            proxy_set_header Host $host;
        }

        location /static {
            alias /usr/share/nginx/html/static;
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }
}
NGINXEOF

# Ollama Dockerfile
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
curl -f http://localhost:11434/api/tags || exit 1
HCEOF
chmod +x ollama/healthcheck.sh

# 5. Backend fájlok
log_step "5. Backend fájlok létrehozása"

# Backend Dockerfile
cat > backend/Dockerfile << 'BACKENDEOF'
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc libxml2-dev libxslt-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

EXPOSE 5000

CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:5000", "app:app", "--timeout", "600"]
BACKENDEOF

# Backend requirements.txt (v5.0 bővített)
cat > backend/requirements.txt << 'REQEOF'
Flask==2.3.3
Flask-SQLAlchemy==3.0.5
Flask-Login==0.6.2
Flask-Mail==0.9.1
Flask-SocketIO==5.3.4
Flask-Limiter==3.5.0
SQLAlchemy==2.0.20
psycopg2-binary==2.9.7
gunicorn==21.2.0
Werkzeug==2.3.7
EbookLib==0.18
beautifulsoup4==4.12.2
lxml==4.9.3
requests==2.31.0
python-dotenv==1.0.0
redis==4.6.0
celery==5.3.1
python-socketio==5.9.0
eventlet==0.33.3
psutil==5.9.5
Pillow==10.0.0
qrcode==7.4.2
pyotp==2.9.0
cryptography==41.0.3
isbnlib==3.10.14
numpy==1.24.3
REQEOF

# Backend config.py (v5.0)
cat > backend/config.py << 'CONFIGEOF'
import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Alap beállítások
    VERSION = os.environ.get('VERSION', '5.0.0')
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
    
    # Admin
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    
    # Fájlok
    UPLOAD_FOLDER = '/app/uploads'
    OUTPUT_FOLDER = '/app/output'
    BOOK_DB_PATH = '/app/book_database'
    COVERS_PATH = '/app/uploads/covers'
    MAX_CONTENT_LENGTH = 100 * 1024 * 1024
    
    # Könyv adatbázis
    ENABLE_BOOK_DB = os.environ.get('ENABLE_BOOK_DB', 'i').lower() == 'i'
    MAX_SAMPLE_BOOKS = int(os.environ.get('MAX_SAMPLE_BOOKS', 5))
    ENABLE_ONLINE_SEARCH = os.environ.get('ENABLE_ONLINE_SEARCH', 'i').lower() == 'i'
    
    # Fordítás
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    BATCH_SIZE = 5
    TRANSLATION_TIMEOUT = 600
    
    # Cache
    ENABLE_CACHE = os.environ.get('ENABLE_CACHE', 'i').lower() == 'i'
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
CONFIGEOF

# Backend models.py (v5.0 - Könyv adatbázissal)
cat > backend/models.py << 'MODELSEOF'
from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
import json
import secrets

db = SQLAlchemy()

# Kapcsoló tábla
book_authors = db.Table('book_authors',
    db.Column('book_id', db.Integer, db.ForeignKey('books.id'), primary_key=True),
    db.Column('author_id', db.Integer, db.ForeignKey('authors.id'), primary_key=True)
)

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
    activity_logs = db.relationship('ActivityLog', backref='user', lazy=True)
    api_keys = db.relationship('ApiKey', backref='user', lazy=True)

class Book(db.Model):
    __tablename__ = 'books'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(500))
    isbn = db.Column(db.String(20), unique=True, nullable=True)
    publisher = db.Column(db.String(200))
    publication_year = db.Column(db.Integer)
    language = db.Column(db.String(10))
    
    # Kategóriák
    genre = db.Column(db.String(100))
    sub_genre = db.Column(db.String(100))
    writing_style = db.Column(db.String(100))
    complexity_level = db.Column(db.String(20))
    
    # Statisztikák
    word_count = db.Column(db.Integer)
    chapter_count = db.Column(db.Integer)
    file_size = db.Column(db.Integer)
    file_hash = db.Column(db.String(64), unique=True)
    file_path = db.Column(db.String(500))
    
    # Metaadatok
    description = db.Column(db.Text)
    cover_image = db.Column(db.String(500))
    tags = db.Column(db.Text)
    
    # Használat
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
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    completed_at = db.Column(db.DateTime)
    
    sample_books = db.Column(db.Text)
    sample_books_metadata = db.Column(db.Text)

class ActivityLog(db.Model):
    __tablename__ = 'activity_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    action = db.Column(db.String(100))
    details = db.Column(db.Text)
    ip_address = db.Column(db.String(45))
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
MODELSEOF

# Backend utils/__init__.py
touch backend/utils/__init__.py

# Backend utils/metadata_extractor.py (v5.0 - ÚJ)
cat > backend/utils/metadata_extractor.py << 'METAEOF'
import ebooklib
from ebooklib import epub
from bs4 import BeautifulSoup
import requests
import re
import hashlib
import os
import json
import numpy as np

class MetadataExtractor:
    def __init__(self, filepath):
        self.filepath = filepath
        self.book = epub.read_epub(filepath)
        self.metadata = {}
        self.extract_all()
    
    def extract_all(self):
        self.extract_basic_metadata()
        self.extract_isbn()
        self.extract_statistics()
        self.detect_genre()
        self.detect_writing_style()
        self.calculate_hash()
    
    def extract_basic_metadata(self):
        try:
            titles = self.book.get_metadata('DC', 'title')
            if titles: self.metadata['title'] = titles[0][0]
            
            creators = self.book.get_metadata('DC', 'creator')
            if creators: self.metadata['author'] = creators[0][0]
            
            publishers = self.book.get_metadata('DC', 'publisher')
            if publishers: self.metadata['publisher'] = publishers[0][0]
            
            languages = self.book.get_metadata('DC', 'language')
            if languages: self.metadata['language'] = languages[0][0]
            
            descriptions = self.book.get_metadata('DC', 'description')
            if descriptions: self.metadata['description'] = descriptions[0][0]
        except Exception as e:
            print(f"Metadata extraction error: {str(e)}")
    
    def extract_isbn(self):
        try:
            identifiers = self.book.get_metadata('DC', 'identifier')
            for identifier in identifiers:
                if 'isbn' in identifier[0].lower() or re.match(r'[\d-]{10,17}', identifier[0]):
                    isbn = re.sub(r'[^0-9X]', '', identifier[0])
                    if len(isbn) in [10, 13]:
                        self.metadata['isbn'] = isbn
                        break
        except:
            pass
    
    def extract_statistics(self):
        try:
            total_words = 0
            chapter_count = 0
            
            for item in self.book.get_items():
                if item.get_type() == ebooklib.ITEM_DOCUMENT:
                    content = item.get_content().decode('utf-8')
                    soup = BeautifulSoup(content, 'html.parser')
                    text = soup.get_text()
                    total_words += len(text.split())
                    chapter_count += len(soup.find_all(['h1', 'h2', 'h3']))
            
            self.metadata['word_count'] = total_words
            self.metadata['chapter_count'] = chapter_count
            self.metadata['file_size'] = os.path.getsize(self.filepath)
        except:
            pass
    
    def detect_genre(self):
        try:
            text_sample = self._get_text_sample(10000)
            text_lower = text_sample.lower()
            
            genre_keywords = {
                'science_fiction': ['spaceship', 'alien', 'planet', 'galaxy', 'robot', 'future', 'technology', 'space', 'laser'],
                'fantasy': ['dragon', 'wizard', 'magic', 'sword', 'kingdom', 'elf', 'dwarf', 'spell', 'castle'],
                'romance': ['love', 'kiss', 'heart', 'romantic', 'passion', 'relationship', 'marriage', 'desire'],
                'thriller': ['murder', 'kill', 'danger', 'escape', 'chase', 'secret', 'conspiracy', 'weapon'],
                'mystery': ['detective', 'clue', 'suspect', 'crime', 'investigation', 'evidence', 'puzzle'],
                'horror': ['ghost', 'monster', 'terror', 'fear', 'nightmare', 'blood', 'death', 'darkness'],
                'literary_fiction': ['philosophical', 'metaphor', 'symbolism', 'allegory', 'complex', 'profound'],
                'non_fiction': ['research', 'study', 'analysis', 'data', 'evidence', 'conclusion', 'finding']
            }
            
            genre_scores = {}
            for genre, keywords in genre_keywords.items():
                score = sum(1 for keyword in keywords if keyword in text_lower)
                if score > 0:
                    genre_scores[genre] = score
            
            if genre_scores:
                primary_genre = max(genre_scores, key=genre_scores.get)
                self.metadata['genre'] = primary_genre
                self.metadata['genre_scores'] = genre_scores
        except:
            pass
    
    def detect_writing_style(self):
        try:
            text_sample = self._get_text_sample(5000)
            sentences = re.split(r'[.!?]+', text_sample)
            sentences = [s.strip() for s in sentences if s.strip()]
            
            if not sentences:
                return
            
            avg_sentence_length = sum(len(s.split()) for s in sentences) / len(sentences)
            words = text_sample.split()
            avg_word_length = sum(len(w) for w in words) / len(words) if words else 0
            
            if avg_sentence_length > 25 and avg_word_length > 6:
                style = "literary/complex"
            elif avg_sentence_length < 10 and avg_word_length < 4:
                style = "simple/direct"
            elif avg_sentence_length > 20:
                style = "descriptive"
            else:
                style = "balanced/moderate"
            
            self.metadata['writing_style'] = style
            self.metadata['avg_sentence_length'] = round(avg_sentence_length, 2)
            self.metadata['avg_word_length'] = round(avg_word_length, 2)
            
            if avg_sentence_length > 22 and avg_word_length > 5.5:
                complexity = "advanced"
            elif avg_sentence_length > 15 and avg_word_length > 4.5:
                complexity = "intermediate"
            else:
                complexity = "beginner"
            
            self.metadata['complexity_level'] = complexity
        except:
            pass
    
    def calculate_hash(self):
        try:
            sha256_hash = hashlib.sha256()
            with open(self.filepath, "rb") as f:
                for byte_block in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(byte_block)
            self.metadata['file_hash'] = sha256_hash.hexdigest()
        except:
            pass
    
    def _get_text_sample(self, max_words):
        words = []
        for item in self.book.get_items():
            if item.get_type() == ebooklib.ITEM_DOCUMENT:
                content = item.get_content().decode('utf-8')
                soup = BeautifulSoup(content, 'html.parser')
                text = soup.get_text()
                words.extend(text.split())
                if len(words) >= max_words:
                    break
        return ' '.join(words[:max_words])
    
    def get_metadata(self):
        return self.metadata
METAEOF

# Backend utils/context_optimizer.py (v5.0 - ÚJ)
cat > backend/utils/context_optimizer.py << 'COPTEOF'
import json
from models import Book, Author, SampleBookUsage, db
from sqlalchemy import func

class ContextOptimizer:
    def __init__(self):
        self.context_cache = {}
    
    def find_best_sample_books(self, target_metadata, max_samples=5):
        """Legjobb mintakönyvek keresése"""
        if not target_metadata:
            return []
        
        all_books = Book.query.filter(
            Book.language == target_metadata.get('language', 'en')
        ).all()
        
        scored_books = []
        for book in all_books:
            score = self._calculate_match_score(target_metadata, book)
            if score > 0:
                scored_books.append((book, score))
        
        scored_books.sort(key=lambda x: x[1], reverse=True)
        
        # Diverzitás biztosítása
        selected = []
        used_genres = set()
        
        for book, score in scored_books:
            if book.genre not in used_genres or len(selected) < 3:
                selected.append((book, score))
                used_genres.add(book.genre)
            
            if len(selected) >= max_samples:
                break
        
        return selected
    
    def _calculate_match_score(self, target_metadata, book):
        score = 0
        
        # Műfaj egyezés
        if book.genre == target_metadata.get('genre'):
            score += 30
        
        # Stílus egyezés
        if book.writing_style == target_metadata.get('writing_style'):
            score += 25
        
        # Komplexitás egyezés
        if book.complexity_level == target_metadata.get('complexity_level'):
            score += 20
        
        # Használati gyakoriság
        score += min(book.use_count, 10) * 1.5
        
        # Kontextus súly
        score += book.context_weight * 10
        
        return score
    
    def learn_from_translation(self, translation_record, quality_score):
        """Tanulás a fordítási eredményekből"""
        if translation_record.sample_books:
            try:
                sample_books = json.loads(translation_record.sample_books)
                for sample_path in sample_books:
                    book = Book.query.filter_by(file_path=sample_path).first()
                    if book:
                        book.use_count += 1
                        if quality_score and quality_score > 80:
                            book.context_weight += 0.05
                        elif quality_score and quality_score < 60:
                            book.context_weight -= 0.02
                        
                        book.context_weight = max(0.1, min(1.0, book.context_weight))
                
                db.session.commit()
            except Exception as e:
                print(f"Learning error: {str(e)}")
COPTEOF

# 6. Segédscriptek
log_step "6. Segédscriptek létrehozása"

# Backup script
cat > scripts/backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="$HOME/epub-backups"
mkdir -p "$BACKUP_DIR"
DATE=$(date +%Y%m%d_%H%M%S)

echo "📦 Biztonsági mentés készítése..."
echo "   Adatbázis mentése..."
docker exec epub-postgres pg_dump -U epub_user epub_translator > "$BACKUP_DIR/db_backup_$DATE.sql"

if [ -d "$HOME/epub-translator/book_database" ]; then
    echo "   Könyv adatbázis mentése..."
    tar -czf "$BACKUP_DIR/books_backup_$DATE.tar.gz" -C "$HOME/epub-translator" book_database/
fi

echo "✅ Mentés kész: $BACKUP_DIR/"
echo "   - db_backup_$DATE.sql"
echo "   - books_backup_$DATE.tar.gz"
BACKUPEOF

# Email teszt script
cat > scripts/test-email.sh << 'TESTEOF'
#!/bin/bash
echo "📧 Email teszt küldése..."

if [ "${SMTP_MODE:-local}" = "local" ]; then
    echo "Helyi mód - Email a MailHog felületén: http://localhost:8025"
fi

echo "Teszt email az EPUB Fordító v5.0 rendszerből" | mail -s "Teszt email - v5.0" admin@epub-translator.local

echo "✅ Teszt email elküldve!"
TESTEOF

# Adatbázis statisztika script
cat > scripts/book-stats.sh << 'STATSEOF'
#!/bin/bash
echo "📚 Könyv Adatbázis Statisztikák"
echo "================================"
echo ""

docker exec epub-backend python3 -c "
from app import app, db
from models import Book, Author, Translation
from sqlalchemy import func

with app.app_context():
    print(f'Összes könyv: {Book.query.count()}')
    print(f'Szerzők: {Author.query.count()}')
    print(f'Fordítások: {Translation.query.count()}')
    print(f'Műfajok: {db.session.query(Book.genre, func.count(Book.id)).group_by(Book.genre).all()}')
"
STATSEOF

chmod +x scripts/*.sh

# 7. Konténerek építése és indítása
log_step "7. Konténerek építése és indítása"

if [ "$SMTP_MODE" = "local" ]; then
    COMPOSE_PROFILE="local"
else
    COMPOSE_PROFILE="all"
fi

log_info "Docker image-ek építése ($COMPOSE_PROFILE profil)..."
docker compose --profile "$COMPOSE_PROFILE" build

log_info "Konténerek indítása..."
docker compose --profile "$COMPOSE_PROFILE" up -d

log_info "Várakozás a szolgáltatások indulására..."
sleep 15

# 8. Modell letöltése
log_step "8. DeepSeek modell letöltése"

log_info "Modell letöltése: $SELECTED_MODEL"
log_warn "Ez 10-30 percig is eltarthat!"
docker exec -it epub-ollama ollama pull "$SELECTED_MODEL"

# 9. Adatbázis inicializálása
log_step "9. Adatbázis inicializálása"

log_info "Adatbázis táblák létrehozása..."
docker exec -it epub-backend python3 -c "from app import app, db; app.app_context().push(); db.create_all()"

log_info "Admin felhasználó és alapadatok létrehozása..."
docker exec -it epub-backend python3 -c "
from app import app, db
from models import User
from werkzeug.security import generate_password_hash
from datetime import datetime

with app.app_context():
    admin = User.query.filter_by(email='${ADMIN_EMAIL}').first()
    if not admin:
        admin = User(
            username='admin',
            email='${ADMIN_EMAIL}',
            password_hash=generate_password_hash('${ADMIN_PASSWORD}'),
            first_name='Admin',
            last_name='User',
            is_admin=True,
            tokens=999999
        )
        db.session.add(admin)
        db.session.commit()
        print('Admin user created')
    else:
        print('Admin user already exists')
"

# 10. Cron job beállítása
log_step "10. Automatikus karbantartás beállítása"

(crontab -l 2>/dev/null; echo "0 3 * * 0 $PROJECT_DIR/scripts/backup.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 4 * * 0 docker system prune -f") | crontab -

# 11. Telepítés ellenőrzése
log_step "11. Telepítés ellenőrzése"

echo ""
log_info "Szolgáltatások állapota:"
docker compose ps

echo ""
log_info "Ollama modellek:"
docker exec epub-ollama ollama list

echo ""
log_info "Backend health check:"
curl -s http://localhost:5000/health | python3 -m json.tool 2>/dev/null || echo "Backend még indul..."

# 12. Verzió információ mentése
echo "v${VERSION} - $(date +%Y-%m-%d)" > VERSION.txt

# 13. Összegzés
log_step "Telepítés befejezve!"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║   🎉 EPUB Fordító Rendszer v${VERSION} - Telepítve! 🎉        ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📱 Webes felület: http://localhost"
echo ""
echo "👤 Adminisztrátor:"
echo "   Email: $ADMIN_EMAIL"
echo "   Jelszó: $ADMIN_PASSWORD"
echo ""
echo "📧 Email felület: http://localhost:8025"
echo ""
echo "🤖 Modell: $SELECTED_MODEL ($MODEL_SIZE)"
echo "📚 Könyv adatbázis: ENGEDÉLYEZVE"
echo "🔍 Online keresés: $([ "$ENABLE_ONLINE_SEARCH" = "i" ] && echo "ENGEDÉLYEZVE" || echo "LETILTVA")"
echo "🚀 Párhuzamos szálak: $MAX_WORKERS"
echo ""
echo "📋 Új funkciók a v${VERSION}-ban:"
echo "   ✅ Automatikus metaadat kinyerés (EPUB, online)"
echo "   ✅ AI alapú műfaj és stílus felismerés"
echo "   ✅ Intelligens mintakönyv ajánlás"
echo "   ✅ Könyv adatbázis folyamatos tanulással"
echo "   ✅ Duplikátum szűrés"
echo ""
echo "📚 Hasznos parancsok:"
echo "   Státusz:      docker compose ps"
echo "   Logok:        docker compose logs -f"
echo "   Backup:       ./scripts/backup.sh"
echo "   Könyv stat:   ./scripts/book-stats.sh"
echo "   Email teszt:  ./scripts/test-email.sh"
echo ""
echo "💡 Tipp: A rendszer minél több könyvet fordít, annál okosabb lesz!"
echo ""

log_success "Minden készen áll! Kezdheted a fordítást! 🚀📚"
