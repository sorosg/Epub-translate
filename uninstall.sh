#!/bin/bash
# EPUB Fordító Rendszer - Törlő Script v1.0
# Leírás: Teljes körű eltávolítás

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     ⚠️  EPUB Fordító - TELJES ELTÁVOLÍTÁS  ⚠️              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}FIGYELEM: Ez a script véglegesen törli az EPUB Fordító rendszert,${NC}"
echo -e "${YELLOW}beleértve az adatbázist, a fordításokat és a beállításokat.${NC}"
echo ""
read -p "Biztosan folytatod? (igen/NEM): " confirm

if [ "$confirm" != "igen" ]; then
    echo -e "${GREEN}✅ Törlés megszakítva.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}[1/6] Docker konténerek leállítása és törlése...${NC}"
DOCKER=$(docker ps &>/dev/null 2>&1 && echo "docker" || echo "sudo docker")
$DOCKER compose -f ~/epub-translator/docker-compose.yml down -v --remove-orphans 2>/dev/null || true
$DOCKER rm -f epub-nginx epub-backend epub-postgres epub-ollama epub-redis epub-mailhog 2>/dev/null || true
echo -e "${GREEN}   ✅ Konténerek törölve${NC}"

echo ""
echo -e "${CYAN}[2/6] Docker volume-ok törlése...${NC}"
$DOCKER volume rm epub-translator_postgres_data epub-translator_ollama_data epub-translator_redis_data epub-translator_epub_uploads epub-translator_epub_output 2>/dev/null || true
$DOCKER volume ls | grep epub-translator | awk '{print $2}' | xargs -r $DOCKER volume rm 2>/dev/null || true
echo -e "${GREEN}   ✅ Volume-ok törölve${NC}"

echo ""
echo -e "${CYAN}[3/6] Telepítési könyvtár törlése (~/epub-translator)...${NC}"
rm -rf ~/epub-translator
echo -e "${GREEN}   ✅ Telepítési könyvtár törölve${NC}"

echo ""
echo -e "${CYAN}[4/6] Backup könyvtárak törlése...${NC}"
rm -rf ~/epub-backups 2>/dev/null || true
rm -rf ~/epub-translator-backup-* 2>/dev/null || true
echo -e "${GREEN}   ✅ Backup-ok törölve${NC}"

echo ""
echo -e "${CYAN}[5/6] Docker image-ek törlése (opcionális)...${NC}"
read -p "Szeretnéd törölni a Docker image-eket is? (i/n) [n]: " remove_images
if [[ $remove_images =~ ^[Ii]$ ]]; then
    $DOCKER rmi epub-translator-backend epub-translator-ollama 2>/dev/null || true
    $DOCKER image prune -f 2>/dev/null || true
    echo -e "${GREEN}   ✅ Image-ek törölve${NC}"
else
    echo -e "${YELLOW}   ⏭️  Image-ek megtartva${NC}"
fi

echo ""
echo -e "${CYAN}[6/6] Cron jobok törlése...${NC}"
if command -v crontab &>/dev/null; then
    crontab -l 2>/dev/null | grep -v "epub-translator" | crontab - 2>/dev/null || true
    echo -e "${GREEN}   ✅ Cron jobok törölve${NC}"
else
    echo -e "${YELLOW}   ⏭️  Crontab nem elérhető${NC}"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     ✅ EPUB Fordító rendszer teljesen eltávolítva!           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "A következők kerültek törlésre:"
echo "  🗑️  Docker konténerek (epub-nginx, epub-backend, epub-postgres, epub-ollama, epub-redis, epub-mailhog)"
echo "  🗑️  Docker volume-ok (postgres, ollama, redis, uploads, output)"
echo "  🗑️  Telepítési könyvtár (~/epub-translator)"
echo "  🗑️  Backup könyvtárak (~/epub-backups, ~/epub-translator-backup-*)"
echo "  🗑️  Cron jobok"
echo ""
echo "Az Epub-translate forráskönyvtár (ez, ahonnan a scriptet futtattad) MEGMARADT."
echo "Ezt manuálisan törölheted: rm -rf ~/Documents/Github/Epub-translate"
echo ""
echo "Újratelepítéshez:"
echo "  cd ~/Documents/Github/Epub-translate && ./install.sh"
echo ""