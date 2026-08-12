# 🖥️ VSCode + WSL Fejlesztői Környezet – Felhasználói Kézikönyv

**Verzió:** 1.3.0+  
**Platform:** Windows 10/11 + WSL 2 (Ubuntu 22.04+)  
**Cél:** EPUB Fordító Rendszer fejlesztése, tesztelése és debuggolása

---

## 📋 Tartalomjegyzék

1. [Előfeltételek](#1-előfeltételek)
2. [VSCode telepítése és konfigurálása](#2-vscode-telepítése-és-konfigurálása)
3. [WSL beállítása](#3-wsl-beállítása)
4. [Projekt beállítása](#4-projekt-beállítása)
5. [Fejlesztői munkafolyamat](#5-fejlesztői-munkafolyamat)
6. [Hibakeresés (Debugging)](#6-hibakeresés-debugging)
7. [Gyakori problémák és megoldások](#7-gyakori-problémák-és-megoldások)

---

## 1. Előfeltételek

### 1.1 Windows oldalon

- **Windows 10 (2004+) vagy Windows 11** – WSL 2 támogatással
- **VSCode** – legújabb stabil verzió (https://code.visualstudio.com/)
- **Git for Windows** (opcionális, de ajánlott: https://git-scm.com/)

### 1.2 WSL oldalon (Ubuntu)

```bash
# WSL telepítése (PowerShell-ben, adminisztrátorként)
wsl --install -d Ubuntu-22.04

# Ubuntu frissítése
sudo apt update && sudo apt upgrade -y

# Docker telepítése WSL-ben
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# (jelentkezz ki-be, vagy indíts új WSL terminált)

# Git telepítése
sudo apt install -y git

# Projekt klónozása
cd ~
git clone https://github.com/sorosg/Epub-translate.git
cd epub-translator
```

---

## 2. VSCode telepítése és konfigurálása

### 2.1 Kötelező bővítmények

Nyisd meg a VSCode-ot, majd `Ctrl+Shift+X` (Extensions), keresd és telepítsd az alábbiakat:

| Bővítmény | Kiadó | Leírás |
|-----------|-------|--------|
| **Remote - WSL** | Microsoft | WSL fájlrendszer és terminál elérése VSCode-ból | ⭐ Kötelező |
| **Python** | Microsoft | Python IntelliSense, debug, linting |
| **Docker** | Microsoft | Docker konténerek, compose fájlok kezelése |
| **Jinja** | wholroyd | Jinja2 template szintaxis kiemelés (HTML fájlokhoz) |
| **ShellCheck** | timonwong | Bash script ellenőrzés (`.sh` fájlok) |
| **GitLens** | GitKraken | Git blame, történet, vizuális diff |
| **Thunder Client** | rangav | REST API tesztelés (Postman alternatíva) |
| **Prettier** | Prettier | Kód formázás |
| **markdownlint** | David Anson | Markdown fájlok ellenőrzése |

### 2.2 Ajánlott VSCode beállítások

A projekt már tartalmazza a szükséges `.vscode/settings.json` és `.vscode/launch.json` fájlokat, amiket a VSCode automatikusan betölt. Ezek a beállítások:

- Python linting és formázás (4 space indent)
- JavaScript és Shell formázás (2 space indent)
- Nem releváns mappák kizárása a figyelőből (`logs/`, `uploads/`, `output/`)
- Flask debug konfiguráció (lokális + Docker attach)

### 2.3 Téma és betűkészlet (opcionális)

```json
{
  "workbench.colorTheme": "One Dark Pro",
  "editor.fontFamily": "JetBrains Mono, 'Fira Code', Consolas",
  "editor.fontLigatures": true
}
```

---

## 3. WSL beállítása

### 3.1 Projekt elérése WSL-ből

```bash
# WSL terminál megnyitása (Windows Terminal-ban vagy PowerShell-ből: `wsl`)
cd ~/epub-translator
code .
```

> A `code .` parancs megnyitja a VSCode-ot **Remote-WSL módban**, ami azt jelenti, hogy a VSCode a WSL Linux fájlrendszerben dolgozik – pontosan ugyanott, ahol a Docker konténerek futnak!

### 3.2 Docker konténerek indítása

```bash
# Ha még nincs telepítve az alkalmazás:
./install.sh
# Válaszd: Friss telepítés

# Ha már telepítve van:
./install.sh
# Válaszd: 1) Frissítés
```

### 3.3 Ellenőrzés

```bash
# Konténerek állapota
sudo docker compose ps

# Webes felület: http://localhost:8080
# MailHog: http://localhost:8025
```

---

## 4. Projekt beállítása

### 4.1 VSCode munkaterület megnyitása

A projekt gyökérkönyvtárát kell megnyitni WSL-ből:

```bash
cd ~/epub-translator
code .
```

A VSCode automatikusan:
- Felismeri a Python környezetet
- Betölti a `.vscode/settings.json`-t
- A bal oldali sávban megjeleníti a Git változásokat (`Ctrl+Shift+G`)
- A terminál (`Ctrl+``) automatikusan WSL bash-t nyit

### 4.2 Fájlszerkezet a VSCode-ban

```
~/epub-translator/
├── .vscode/
│   ├── settings.json    # VSCode projekt beállítások
│   └── launch.json      # Debug konfigurációk
├── src/
│   ├── backend/
│   │   ├── app.py       # Flask backend (fő fejlesztési fájl)
│   │   ├── models.py    # Adatbázis modellek
│   │   ├── config.py    # Konfiguráció
│   │   ├── templates/   # HTML/Jinja2 template-ek
│   │   └── static/      # CSS, JS, képek (a szülő src/static/-ből másolva)
│   ├── docker-compose.yml
│   └── nginx/nginx.conf
├── install.sh           # Telepítő/frissítő script
├── README.md            # Felhasználói dokumentáció
├── ROADMAP.md           # Fejlesztési útiterv
└── VSCode_DEV_GUIDE.md  # Ez a fájl
```

### 4.3 Gyorsbillentyűk

| Billentyű | Művelet |
|-----------|---------|
| `Ctrl+P` | Fájl gyors megnyitása (pl. `app.py`) |
| `Ctrl+Shift+F` | Keresés az összes fájlban |
| `Ctrl+Shift+G` | Git Source Control panel |
| `Ctrl+`` | Terminál megnyitása |
| `F5` | Debug indítása |
| `Ctrl+Shift+D` | Debug panel megnyitása |
| `Ctrl+Shift+X` | Extensions panel |
| `F1` / `Ctrl+Shift+P` | Parancspaletta |

---

## 5. Fejlesztői munkafolyamat

### 5.1 Mindennapi fejlesztés

1. **Nyisd meg a projektet**
   ```bash
   cd ~/epub-translator && code .
   ```

2. **Módosítsd a forráskódot**
   - `src/backend/app.py` – API végpontok, fordítási logika
   - `src/backend/templates/*.html` – HTML frontend
   - `src/static/css/main.css` – Stílusok
   - `src/static/js/main.js` – JavaScript
   - `install.sh` – Telepítő script

3. **Teszteld a változásokat**
   ```bash
   # Konténerek újraépítése és indítása
   cd ~/epub-translator
   ./install.sh  # válaszd: 1) Frissítés
   ```

4. **Commit és push**
   ```bash
   git add -A
   git commit -m "v1.3.2: rövid leírás a változásról"
   git push origin main
   ```

### 5.2 Verziószám növelése

**Minden módosítás után** növeld a verziószámot az alábbi fájlokban:

| Fájl | Hol | Példa |
|------|-----|-------|
| `install.sh` | `VERSION="x.y.z"` | `VERSION="1.3.2"` |
| `src/backend/config.py` | `VERSION = os.environ.get('VERSION', 'x.y.z')` | `'1.3.2'` |
| `README.md` | badge + lábléc | `version-1.3.2-blue` |
| `ROADMAP.md` | verzió fejléc | `1.3.2` |

**Verziószámozási szabályok**:
- **MAJOR** (x.0.0): nagy változások (te döntöd el)
- **MINOR** (1.x.0): új funkciók
- **PATCH** (1.0.x): hibajavítások

### 5.3 API tesztelés Thunder Client-tel

1. Nyisd meg a Thunder Client-et (bal oldali sávban a villám ikon)
2. Hozz létre egy új request-et
3. Példa: `GET http://localhost:8080/api/notifications` (az értesítési központ tesztelése)
4. Az Admin felület konténerek füle a `GET /api/system/containers` végpontot használja

---

## 6. Hibakeresés (Debugging)

### 6.1 Flask backend lokális debug

A `.vscode/launch.json` tartalmaz egy "Flask Backend (Lokális)" konfigurációt:

1. **Állíts le minden Docker konténert** (kivéve a postgres-t és ollama-t):
   ```bash
   sudo docker compose stop backend nginx redis mailhog
   ```

2. **Nyisd meg az `app.py`-t**, kattints egy sor mellé (bal oldalon piros pont = breakpoint)

3. **Nyomd meg az `F5`-öt** → válaszd a "Flask Backend (Lokális)" konfigurációt

4. A VSCode elindítja a Flask-et, és megáll a töréspontnál. A Debug panelen (`Ctrl+Shift+D`) láthatod a változók értékét, a call stack-et, és lépésenként haladhatsz (`F10`, `F11`).

### 6.2 Docker konténer debug (haladó)

A "Flask Backend (Docker Attach)" konfiguráció a Docker konténerbe való távoli debuggoláshoz van. Ehhez a `debugpy` csomagot kell telepíteni és a Docker konténert speciális paraméterekkel indítani. Részletek a hivatalos VSCode dokumentációban.

### 6.3 Böngésző Developer Tools

1. Nyisd meg a webes felületet: `http://localhost:8080`
2. Nyomd meg az **F12**-t (Developer Tools)
3. **Console** fül: JavaScript hibák
4. **Network** fül: API kérések és válaszok
5. **Application** fül: LocalStorage, cache

### 6.4 Docker logok

```bash
# Backend logok valós időben
sudo docker logs -f epub-backend

# Nginx logok
sudo docker logs -f epub-nginx

# Minden konténer logja
sudo docker compose logs -f
```

---

## 7. Gyakori problémák és megoldások

### 7.1 "A böngésző nem frissül"

**Ok:** A böngésző cache-eli a statikus fájlokat (CSS, JS).

**Megoldás:**
- **Hard refresh**: `Ctrl+Shift+R` (Windows/Linux) vagy `Cmd+Shift+R` (Mac)
- **Fejlesztői módban** nyisd meg a DevTools-t (`F12`), kattints a Network fülre, és pipáld be a "Disable cache" opciót
- A projekt `base.html`-ben a statikus fájlok verziózott URL-lel töltődnek be: `?v={{ config.VERSION }}`

### 7.2 "A Docker konténerek nem indulnak el"

```bash
# Teljes takarítás és újraindítás
sudo docker compose down --volumes --remove-orphans
sudo docker system prune -af --volumes
cd ~/epub-translator
./install.sh  # válaszd: Frissítés
```

### 7.3 "WSL nem látja a Docker-t"

```bash
# Ellenőrizd, hogy a Docker fut-e
sudo service docker status

# Ha nem, indítsd el
sudo service docker start
```

### 7.4 "VSCode Remote-WSL nem csatlakozik"

1. Zárd be az összes VSCode ablakot
2. Nyiss egy új WSL terminált
3. Futtasd: `code --remote wsl+Ubuntu ~/epub-translator`

### 7.5 "A Flask nem látja az adatbázist"

```bash
# Ellenőrizd, hogy a postgres konténer fut-e
sudo docker ps | grep postgres

# Ha nem, indítsd el
sudo docker compose up -d postgres
```

---

## 📝 Összefoglaló parancsok

```bash
# === GYORSINDÍTÁS ===
cd ~/epub-translator && code .                 # VSCode megnyitása
./install.sh                                    # Telepítés/frissítés

# === TESZTELÉS ===
curl http://localhost:8080/health               # Backend health check
xdg-open http://localhost:8080                  # Webes felület megnyitása

# === DEBUG ===
sudo docker logs -f epub-backend               # Backend logok követése
sudo docker compose ps                          # Konténerek listája

# === GIT ===
git status                                       # Változások listája
git diff                                         # Változások részletesen
git log --oneline -5                             # Utolsó 5 commit

# === TAKARÍTÁS ===
sudo docker compose down                       # Konténerek leállítása
sudo docker system prune -f                     # Docker cache törlése
```

---

*Készült az EPUB Fordító Rendszer fejlesztői csapata számára – v1.3.0+*