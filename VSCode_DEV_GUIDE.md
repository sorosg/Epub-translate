# 🖥️ EPUB Fordító – Fejlesztői környezet beállítása (Windows + VSCode + WSL)

**Verzió:** v3.0.1
**Cél:** a projekt helyi fejlesztői környezetének felállítása Windows-gépen,
a VSCode + WSL (Ubuntu) + Docker kombinációjával.

---

## 1. Fogalmak és elrendezés (fontos!)

A projekt **egy közös kódbázis**, ami két módon fut (Docker szerver / asztali app),
de a fejlesztés **mindig a WSL-ben** történik, onnan szinkronizálunk.

| Hely | Mappa | Szerep |
|------|-------|--------|
| **WSL (kanonikus forrás)** | `/home/sorosg/epub-translator/` | itt szerkesztünk, itt buildelünk |
| **Windows Desktop (git-push forrás)** | `/mnt/c/Users/soros/Desktop/Epub-translate/` | ide szinkronizálunk, innen commit + tag + push |

- A kódmódosítás **mindig a WSL-ben** történik.
- Minden módosítás után **szinkron** a Desktop repóba, majd **commit + push** onnan
  (lásd a 6. szakaszt). A `.env` SOHA nem kerül a gitbe.

---

## 2. Előfeltételek (Windows)

- **Windows 10 (2004+) vagy Windows 11** — WSL 2 támogatással.
- **VSCode** — a legfrissebb stabil (https://code.visualstudio.com/).
- (Opcionális, de hasznos) **Git for Windows**: https://git-scm.com/

---

## 3. WSL telepítése és indítása

Nyisd meg a **PowerShell**-t **adminisztrátorként**, és:

```powershell
# 1) WSL + Ubuntu telepítése (WSL 2 az alapértelmezett)
wsl --install -d Ubuntu

# ha már telepítve volt, de frissíteni kell:
wsl --update

# 2) A telepített disztribúciók listája
wsl -l -v
```

Ezután indítsd el az Ubuntut (a Start menüből, vagy `wsl` a PowerShellből),
és az első indításkor hozz létre egy Linux-felhasználót (pl. `sorosg`).

### WSL leállítása / újraindítása
```powershell
wsl --shutdown        # teljes leállítás
```
(A `wsl` parancs újra elindítja.)

---

## 4. VSCode + Remote-WSL (a kulcs)

A VSCode a **Remote - WSL** bővítménnyel csatlakozik a Linux-fájlrendszerhez,
így minden parancs és fájl a WSL-en belül fut.

### 4.1 Kötelező bővítmény (ez mindennek az alapja)
| Bővítmény | Kiadó | Mire való |
|-----------|-------|-----------|
| **Remote - WSL** | `ms-vscode-remote.remote-wsl` | a VSCode WSL-ben nyitja meg a mappát |

### 4.2 Ajánlott bővítmények (a projekthez)
| Bővítmény | Kiadó | Mire való |
|-----------|-------|-----------|
| **Python** | `ms-python.python` | Flask backend szerkesztés/debug |
| **Pylance** | `ms-python.vscode-pylance` | Python IntelliSense |
| **ESLint** | `dbaeumer.vscode-eslint` | React/TS frontend lint |
| **Prettier** | `esbenp.prettier-vscode` | kódformázás |
| **Tailwind CSS IntelliSense** | `bradlc.vscode-tailwindcss` | Tailwind osztályok |
| **Docker** | `ms-azuretools.vscode-docker` | konténerek kezelése |

### 4.3 A mappa megnyitása WSL-ben

**Első alkalommal:** nyisd meg a VSCode-ot, nyomd meg:
- `Ctrl+Shift+P` → **„Remote-WSL: Connect to WSL"**, majd
- a VSCode-ban újra `Ctrl+Shift+P` → **„Remote-WSL: Reopen Folder in WSL"**,
  és válaszd a `/home/sorosg/epub-translator` mappát.

**Vagy parancssorból (Windows PowerShell):**
```powershell
code --remote wsl+Ubuntu
```

> **Fontos:** ha látod, hogy bal lent a zöld sarokban „WSL: Ubuntu" van, akkor jó helyen vagy.

---

## 5. Projekt beállítása a WSL-ben

```bash
# 1) Rendszerfrissítés
sudo apt update && sudo apt upgrade -y

# 2) Docker telepítése (a Docker Desktop WSL backend-je is jó)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# (jelentkezz ki-be, vagy indíts új WSL terminált, hogy a docker jog érvényes legyen)

# 3) Git telepítése
sudo apt install -y git

# 4) A repó klónozása
cd ~
git clone https://github.com/sorosg/Epub-translate.git epub-translator
cd epub-translator
```

### SSH-hitelesítés a git-push-hoz
A push a **Desktop mappából** történik, SSH remote-tal. Ha még nincs kulcsod:

```bash
# kulcs létrehozása (ha nincs)
ssh-keygen -t ed25519 -C "sorosgergo@gmail.com"

# a publikus kulcs kiírása (ezt add hozzá a GitHub → Settings → SSH keys-hez)
cat ~/.ssh/id_ed25519.pub

# kapcsolat teszt
ssh -T git@github.com   # → "Hi sorosg! You've successfully authenticated..."
```

---

## 6. A mindennapi munkafolyamat (WSL → Desktop → GitHub)

```bash
# 1) Szerkeszd a kódot a WSL-ben:
#    /home/sorosg/epub-translator/backend  és /frontend

# 2) Szinkron a Desktop git-forrásba:
S=/home/sorosg/epub-translator
T=/mnt/c/Users/soros/Desktop/Epub-translate
rsync -a "$S/backend/" "$T/src/backend/"
rsync -a "$S/frontend/src/" "$T/src/frontend/src/"
rsync -a "$S"/*.md "$S/install.sh" "$S/VERSION.txt" "$T/"
rsync -a "$S/desktop/" "$T/desktop/"
rsync -a "$S/.github/" "$T/.github/"
rsync -a "$S/docs/" "$T/docs/"

# 3) Commit + (ha kódváltozás volt) tag + push a Desktop repóból:
cd "$T"
git add -A
git commit -m "vX.Y.Z: rövid leírás" || echo "nincs commit"
git tag -f vX.Y.Z          # CSAK kódmódosításnál emeld a verziót
git push origin main
git push origin vX.Y.Z --force   # a tag push indítja a CI desktop-buildet
```

### Verziószabály röviden
- **Verzióbump CSAK kódmódosításnál** (dokumentum-frissítés nem emel).
- Séma: PATCH = hibajavítás, MINOR = új funkció, MAJOR = nagy áttörés.
- A friss verziót az alábbi helyeken írd át: `backend/config.py`, `.env`,
  `VERSION.txt`, `CHANGELOG.md`, `README.md`, `install.sh`.

---

## 7. Build / teszt / verifikáció (WSL-ben)

```bash
cd /home/sorosg/epub-translator

# Backend + frontend build
docker compose build backend nginx

# Újraindítás
docker compose up -d backend nginx

# Állapot
docker compose ps

# Health check
curl -s -m 15 -w '\nHTTP:%{http_code}\n' http://localhost:8080/health
# → OK / HTTP:200

# Python szintaxis
python3 -m py_compile backend/app.py backend/config.py backend/models.py

# Frontend build (ha a desktop SPA kell)
cd frontend && npm ci && npm run build
```

---

## 8. Gyakori problémák és megoldások

### 8.1 `spawn /bin/bash ENOENT` (minden parancs hibázik)
- **Oka:** a VSCode Remote-WSL kapcsolat szakadt meg — nem a projekt, nem a git.
- **Megoldás:** zárd be és nyisd újra a mappát WSL-ben
  (`Ctrl+Shift+P` → „Remote-WSL: Reopen Folder in WSL", vagy PowerShellből `code --remote wsl+Ubuntu`).

### 8.2 A docker parancs „permission denied"
```bash
sudo usermod -aG docker $USER
# majd jelentkezz ki-be, vagy: newgrp docker
```

### 8.3 A push „denied / Resource not accessible by integration"
- A Desktop repó remote SSH-val menjen (nem HTTPS), és a tag push-t a Desktop repóból végezd.

### 8.4 A `.env` véletlenül a gitbe kerülne
```bash
git ls-files | grep -E '^\.env$'
```
Ha bármit kiír, azonnal távolítsd el: `git rm --cached .env`.

---

*Készült ❤️-vel Magyarországon – v3.0.1*