#!/bin/bash
# ============================================================
# EPUB Fordító - Szinkronizáló Script (macOS kompatibilis)
# ============================================================
# Feladat: A Desktop/Epub-translate mappából átmásolja a
# fájlokat a GitHub repóba (Documents/Github/Epub-translate),
# növeli a verziószámot MINDKÉT helyen, commit-ol és push-ol.
#
# Használat: ./sync-to-github.sh ["commit üzenet"]
# ============================================================

set -euo pipefail

# Elérési utak
DESKTOP_DIR="/Users/sorosgergo/Desktop/Epub-translate"
GITHUB_DIR="/Users/sorosgergo/Documents/Github/Epub-translate"

# Színek
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}  EPUB Fordító - Szinkronizáló Script${NC}"
echo -e "${CYAN}============================================================${NC}"
echo ""

# 1. Ellenőrzés: létezik-e mindkét könyvtár
if [ ! -d "$DESKTOP_DIR" ]; then
    echo -e "${RED}HIBA: A Desktop könyvtár nem található: $DESKTOP_DIR${NC}"
    exit 1
fi

if [ ! -d "$GITHUB_DIR" ]; then
    echo -e "${RED}HIBA: A GitHub könyvtár nem található: $GITHUB_DIR${NC}"
    exit 1
fi

if [ ! -d "$GITHUB_DIR/.git" ]; then
    echo -e "${RED}HIBA: A GitHub könyvtár nem egy git repó: $GITHUB_DIR${NC}"
    exit 1
fi

# 2. Ellenőrizzük, van-e eltérés a Desktop és a GitHub verzió között
#    macOS-en a BSD diff nem támogatja az --exclude-ot, ezért rsync dry-run-t használunk.
echo -e "${YELLOW}→ Változások keresése (rsync dry-run)...${NC}"

RSYNC_EXCLUDES=(
    --exclude='.git'
    --exclude='.DS_Store'
    --exclude='sync-to-github.sh'
    --exclude='Thumbs.db'
    --exclude='desktop.ini'
    --exclude='$RECYCLE.BIN'
)

# rsync dry-run: -n = nem másol, -i = itemize (részletes változáslista), -r = rekurzív
# Az outputból kiszűrjük a statisztika sorokat
DIFF_OUTPUT=$(rsync -avn --delete "${RSYNC_EXCLUDES[@]}" "$DESKTOP_DIR/" "$GITHUB_DIR/" 2>&1 \
    | grep -v "^building file list" \
    | grep -v "^$" \
    | grep -v "^sent " \
    | grep -v "^total size" \
    | grep -v "^\./$" \
    || true)

if [ -z "$DIFF_OUTPUT" ]; then
    echo -e "${GREEN}✓ Nincs változás a Desktop és a GitHub repó között.${NC}"
    echo -e "${GREEN}  A szinkronizálás nem szükséges.${NC}"
    exit 0
fi

echo -e "${YELLOW}  Változások találva:${NC}"
echo "$DIFF_OUTPUT" | head -30
TOTAL_CHANGES=$(echo "$DIFF_OUTPUT" | wc -l | tr -d ' ')
echo -e "${YELLOW}  Összesen ${TOTAL_CHANGES} eltérés.${NC}"
echo ""

# 3. Aktuális verzió kiolvasása a Desktop install.sh-ból
#    macOS grep nem támogatja a -P flaget, ezért sed-et használunk.
echo -e "${YELLOW}→ Verziószám kiolvasása...${NC}"

CURRENT_VERSION=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' "$DESKTOP_DIR/install.sh" | head -1)
if [ -z "$CURRENT_VERSION" ]; then
    echo -e "${RED}HIBA: Nem található VERSION az install.sh-ban!${NC}"
    exit 1
fi
echo -e "  Jelenlegi verzió: ${GREEN}${CURRENT_VERSION}${NC}"

# 4. Verziószám növelése
#    Formátum: MAJOR.MINOR.BUILD (pl. 11.0.66) – a BUILD számot növeljük.
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
BUILD=$(echo "$CURRENT_VERSION" | cut -d. -f3)

NEW_BUILD=$((BUILD + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_BUILD}"
TODAY=$(date +%Y-%m-%d)

echo -e "  Új verzió:       ${GREEN}${NEW_VERSION}${NC}"
echo -e "  Dátum:           ${GREEN}${TODAY}${NC}"
echo ""

# 5. Commit üzenet előkészítése
if [ $# -ge 1 ] && [ -n "$1" ]; then
    COMMIT_MSG="v${NEW_VERSION}: $1"
else
    COMMIT_MSG="v${NEW_VERSION}"
fi

echo -e "${YELLOW}→ Commit üzenet: ${COMMIT_MSG}${NC}"
echo ""

# 6. Verziószám frissítése a DESKTOP fájljaiban (mielőtt átmásolnánk a GitHub-ra)
echo -e "${YELLOW}→ Verziószám frissítése a Desktop fájlokban...${NC}"

update_version_in_file() {
    local file="$1"
    local dir="$2"
    local full_path="${dir}/${file}"

    if [ ! -f "$full_path" ]; then
        return
    fi

    case "$file" in
        install.sh)
            # VERSION="11.0.XX"
            sed -i '' -E "s/VERSION=\"[0-9]+\.[0-9]+\.[0-9]+\"/VERSION=\"${NEW_VERSION}\"/" "$full_path"
            # # Verzió: 11.0.XX
            sed -i '' -E "s/(# Verzió: )[0-9]+\.[0-9]+\.[0-9]+/\1${NEW_VERSION}/" "$full_path"
            # # Dátum: YYYY-MM-DD
            sed -i '' -E "s/(# Dátum: )[0-9]{4}-[0-9]{2}-[0-9]{2}/\1${TODAY}/" "$full_path"
            ;;
        config.py)
            # VERSION = os.environ.get('VERSION', '11.0.XX')
            sed -i '' -E "s/(VERSION = os\.environ\.get\('VERSION', ')[0-9]+\.[0-9]+\.[0-9]+('\))/\1${NEW_VERSION}\2/" "$full_path"
            # RELEASE_DATE = os.environ.get('RELEASE_DATE', 'YYYY-MM-DD')
            sed -i '' -E "s/(RELEASE_DATE = os\.environ\.get\('RELEASE_DATE', ')[0-9]{4}-[0-9]{2}-[0-9]{2}('\))/\1${TODAY}\2/" "$full_path"
            ;;
        ARCHITECTURE.md)
            # **Verzió:** 11.0.XX
            sed -i '' -E "s/(\*\*Verzió:\*\* )[0-9]+\.[0-9]+\.[0-9]+/\1${NEW_VERSION}/" "$full_path"
            # **Utolsó frissítés:** YYYY-MM-DD
            sed -i '' -E "s/(\*\*Utolsó frissítés:\*\* )[0-9]{4}-[0-9]{2}-[0-9]{2}/\1${TODAY}/" "$full_path"
            # ### Főbb képességek (v11.0.XX)
            sed -i '' -E "s/(\(v)[0-9]+\.[0-9]+\.[0-9]+(\))/\1${NEW_VERSION}\2/" "$full_path"
            # Lábjegyzet: *Ez a dokumentum ... (v11.0.XX)*
            sed -i '' -E "s/\(v[0-9]+\.[0-9]+\.[0-9]+\)\*/\(v${NEW_VERSION}\)\*/" "$full_path"
            ;;
        app.py)
            # Verzió hivatkozások a kódban (VERSION string)
            if grep -qE "VERSION.*[0-9]+\.[0-9]+\.[0-9]+" "$full_path" 2>/dev/null; then
                sed -i '' -E "s/(VERSION[^0-9]*)[0-9]+\.[0-9]+\.[0-9]+/\1${NEW_VERSION}/g" "$full_path"
            fi
            ;;
    esac
}

# Desktop fájlok frissítése (hogy a következő sync ne lássa őket változásnak)
update_version_in_file "install.sh" "$DESKTOP_DIR"
echo -e "  ${GREEN}✓${NC} install.sh frissítve (Desktop)"

update_version_in_file "src/backend/config.py" "$DESKTOP_DIR"
echo -e "  ${GREEN}✓${NC} config.py frissítve (Desktop)"

update_version_in_file "ARCHITECTURE.md" "$DESKTOP_DIR"
echo -e "  ${GREEN}✓${NC} ARCHITECTURE.md frissítve (Desktop)"

update_version_in_file "src/backend/app.py" "$DESKTOP_DIR"
echo -e "  ${GREEN}✓${NC} app.py ellenőrizve (Desktop)"

echo ""

# 7. Fájlok másolása a Desktop-ról a GitHub repóba
echo -e "${YELLOW}→ Fájlok másolása a GitHub repóba...${NC}"

rsync -av --delete "${RSYNC_EXCLUDES[@]}" "$DESKTOP_DIR/" "$GITHUB_DIR/" 2>&1 | tail -5

echo ""
echo -e "${GREEN}✓ Fájlok átmásolva.${NC}"
echo ""

# 8. Git műveletek a GitHub repóban
echo -e "${YELLOW}→ Git commit és push...${NC}"

cd "$GITHUB_DIR"

# Ellenőrizzük, hogy van-e tényleges változás commit-olni
if git diff --quiet && git diff --cached --quiet; then
    echo -e "${YELLOW}⚠ Nincs változás a commit-oláshoz (a fájlok már szinkronban vannak).${NC}"
    exit 0
fi

git add -A

echo -e "  Változások listája:"
git --no-pager diff --cached --stat

echo ""
echo -e "  Commit: ${GREEN}${COMMIT_MSG}${NC}"
git commit -m "$COMMIT_MSG"

echo ""
echo -e "${YELLOW}→ Push a GitHub-ra...${NC}"
git push origin main

echo ""
echo -e "${CYAN}============================================================${NC}"
echo -e "${GREEN}✓ Szinkronizálás kész!${NC}"
echo -e "${CYAN}  Verzió: ${NEW_VERSION}${NC}"
echo -e "${CYAN}  Dátum:  ${TODAY}${NC}"
echo -e "${CYAN}============================================================${NC}"