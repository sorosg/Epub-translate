# 📚 EPUB Fordító Rendszer – Felhasználói Kézikönyv

**Verzió:** 11.0.13 – "Smart Optimizer"
**Utolsó frissítés:** 2026-07-16

---

## Tartalomjegyzék

1. [Rendszerkövetelmények](#1-rendszerkövetelmények)
2. [Telepítés](#2-telepítés)
   - [Első telepítés](#21-első-telepítés)
   - [Frissítés meglévő verzióról](#22-frissítés-meglévő-verzióról)
   - [Csak optimalizálás](#23-csak-optimalizálás)
3. [Konfiguráció](#3-konfiguráció)
   - [Admin fiók](#31-admin-fiók)
   - [AI modell kiválasztása](#32-ai-modell-kiválasztása)
   - [Teljesítmény beállítások](#33-teljesítmány-beállítások)
   - [Funkciók engedélyezése/tiltása](#34-funkciók-engedélyezésetiltása)
4. [Használat](#4-használat)
   - [Webes felület elérése](#41-webes-felület-elérése)
   - [Admin felület](#42-admin-felület)
   - [Fordítás folyamata](#43-fordítás-folyamata)
5. [Hasznos parancsok](#5-hasznos-parancsok)
6. [Hibaelhárítás](#6-hibaelhárítás)
7. [Architektúra áttekintés](#7-architektúra-áttekintés)

---

## 1. Rendszerkövetelmények

| Erőforrás | Minimum | Ajánlott | Optimális |
|-----------|---------|----------|-----------|
| **RAM** | 8 GB | 16 GB | 32+ GB |
| **CPU** | 2 mag | 4 mag | 8+ mag |
| **Szabad lemezterület** | 30 GB | 50 GB | 100+ GB |
| **Operációs rendszer** | Ubuntu 20.04+ | Ubuntu 22.04+ | Ubuntu 24.04 |
| **Docker** | Docker CE 24+ | Docker CE 26+ | Legfrissebb |
| **Internet** | Szélessávú | Szélessávú | Gigabit |

### Ajánlott modell RAM-igény szerint

| RAM | Ajánlott modell | Minőség |
|-----|-----------------|---------|
| 8 GB | `deepseek-r1:1.5b` (teszt) | Alap |
| 16 GB | `deepseek-r1:7b` vagy `deepseek-r1:8b` | Jó |
| 32 GB | `deepseek-r1:14b` ★ | Nagyon jó |
| 64+ GB | `deepseek-r1:32b` | Kiváló |
| 128+ GB | `deepseek-r1:70b` | Professzionális |

> **Megjegyzés:** A telepítő automatikusan felismeri a hardvered és javasolja az optimális beállításokat. A Docker és a szükséges csomagok telepítése automatikusan megtörténik.

---

## 2. Telepítés

### 2.1 Első telepítés (és ismételt futtatás)

```bash
# 1. Töltsd le vagy frissítsd a telepítő scriptet
if [ -d "Epub-translate" ]; then
    # Már letöltötted korábban – frissítsd és lépj be
    cd Epub-translate && git pull
else
    # Első letöltés
    git clone https://github.com/sorosg/Epub-translate.git
    cd Epub-translate
fi

# 2. Tedd futtathatóvá (csak ha még nem az)
chmod +x install.sh

# 3. Futtasd a telepítőt (NE root-ként!)
./install.sh
```

> ⚠️ **Ismételt futtatás:** Ha már korábban lefuttattad a telepítőt, **ne klónozd újra** a repository-t! Egyszerűen lépj be a meglévő könyvtárba:
> ```bash
> cd Epub-translate
> ./install.sh
> ```
> A telepítő felismeri a meglévő telepítést és felajánlja a frissítést vagy újratelepítést.

A telepítő végigvezet a következő lépéseken:

1. **Rendszer analízis** – automatikusan felméri a hardvert
2. **Optimális beállítások javaslata** – RAM, CPU, lemez alapján
3. **Konfigurációs varázsló** – egyedi beállítások megadása
4. **Függőségek telepítése** – Docker, Python, Tesseract OCR, stb.
5. **Docker konténerek indítása** – Nginx, Backend, PostgreSQL, Ollama, Redis, MailHog
6. **AI modell letöltése** – a kiválasztott modell automatikus letöltése
7. **Adatbázis inicializálása** – admin fiók létrehozása

> ⚠️ **Fontos:** A telepítőt **NE root-ként** futtasd! Ha root-ként indítod, a script leáll. A `sudo` jogosultságot a Docker telepítéséhez kérheti.

**Teljes telepítési idő:** 10-30 perc (internetkapcsolattól és a modell méretétől függően).

---

### 2.2 Frissítés meglévő verzióról

Ha már van telepített verziód (9.0.0+), a script felismeri és választási lehetőséget ad:

```bash
./install.sh
```

Válassz az alábbiak közül:

```
  1) Frissítés (adatok megőrzése) ⭐ Ajánlott
  2) Újratelepítés (minden törlődik)
  3) Csak optimalizálás (megtart mindent, csak hangol)
  4) Kilépés
```

**1. opció (Frissítés):**
- Biztonsági mentést készít az adatbázisról, `.env` fájlról, fordítási memóriáról
- Leállítja a konténereket
- Frissíti a fájlokat a Git repository-ból
- Újraépíti a konténereket
- Megtartja az összes meglévő adatot

**2. opció (Újratelepítés):**
- Biztonsági mentést készít, majd **töröl mindent**
- Tiszta telepítést végez

---

### 2.3 Csak optimalizálás

Ha a rendszer már működik, de optimalizálni szeretnéd a beállításokat:

```bash
./install.sh
# Válaszd a 3-as opciót: "Csak optimalizálás"
```

Ez:
- Újraelemzi a hardvert
- Frissíti az `.env` és `docker-compose.yml` fájlokat
- Alkalmazza az új memória- és szálbeállításokat
- Újraindítja az érintett konténereket

VAGY használd a külön scriptet:

```bash
cd ~/epub-translator
./scripts/optimize.sh
```

---

## 3. Konfiguráció

### 3.1 Admin fiók

A telepítés során az alábbi alapértelmezett admin fiók jön létre:

| Mező | Alapértelmezett érték |
|------|----------------------|
| Email | `admin@epub-translator.local` |
| Jelszó | A telepítéskor megadott jelszó |

> ⚠️ **Biztonság:** Az első bejelentkezés után **azonnal változtasd meg** az admin jelszót!

### 3.2 AI modell kiválasztása

A telepítő az alábbi modelleket támogatja:

| # | Modell | Méret | RAM igény |
|---|-------|-------|-----------|
| 1 | `deepseek-r1:1.5b` | 1.5 GB | 8 GB |
| 2 | `deepseek-r1:7b` | 7 GB | 12 GB |
| 3 | `deepseek-r1:8b` | 8 GB | 16 GB |
| 4 | `deepseek-r1:14b` ★ | 14 GB | 24 GB |
| 5 | `deepseek-r1:32b` | 32 GB | 48 GB |
| 6 | `deepseek-r1:70b` | 70 GB | 80 GB |

A kiválasztott modellt a script automatikusan letölti az Ollama konténerbe. A modell később az admin felületen is váltható.

### 3.3 Teljesítmény beállítások

A telepítő automatikusan optimalizál az alábbiak alapján:

| Beállítás | Leírás | Auto érték |
|-----------|--------|------------|
| **Szálak száma** | Párhuzamos fordítások száma | CPU magok alapján |
| **RAM limit** | Ollama konténer memória korlátja | Teljes RAM alapján |
| **Batch méret** | Egyszerre feldolgozott szövegrészek | Modell méret alapján |
| **Redis cache** | Gyorsítótár mérete | RAM alapján |
| **PostgreSQL buffer** | Adatbázis gyorsítótár | RAM alapján |

Az automatikus beállításokat a telepítés során felülbírálhatod.

### 3.4 Funkciók engedélyezése/tiltása

A telepítő az alábbi funkciókat kínálja (mind alapértelmezetten engedélyezett):

- **🧠 Auto-optimalizálás** – automatikus modell- és erőforrás optimalizálás
- **📊 Erőforrás monitor** – valós idejű rendszerfigyelés
- **🔄 Intelligens modellváltás** – automatikus modellváltás terhelés alapján
- **🤖 AI Asszisztens** – segítő funkciók a fordítás során
- **🔐 OAuth** – közösségi bejelentkezés (Google, GitHub)
- **📷 OCR** – képek szövegfelismerése
- **🎙️ Hang bemenet** – diktálás támogatása
- **🏆 Gamifikáció** – pontok, szintek, kihívások
- **👥 Közösség** – fordítások megosztása
- **🎯 Fine-tuning** – modell testreszabása

---

## 4. Használat

### 4.1 Webes felület elérése

A sikeres telepítés után:

| Szolgáltatás | URL |
|-------------|-----|
| **Webes felület** | http://localhost |
| **Email teszt (MailHog)** | http://localhost:8025 |
| **Rendszer monitor** | http://localhost/admin |

### 4.2 Admin felület

Az admin felületen (`http://localhost/admin`) elérhető:

- **Rendszer információk** – CPU, RAM, lemez kihasználtság
- **Modell kezelés** – modellváltás, modellek listázása
- **Erőforrás monitor** – valós idejű rendszerfigyelés
- **Teljesítmény optimalizálás** – automatikus és kézi hangolás

### 4.3 Fordítás folyamata

1. Jelentkezz be a webes felületre
2. Tölts fel egy EPUB fájlt
3. Válaszd ki a célnyelvet (alapértelmezett: magyar)
4. Kattints a "Fordítás indítása" gombra
5. A rendszer automatikusan feldolgozza a könyvet:
   - Kibontja az EPUB formátumot
   - Felismeri a fejezeteket és bekezdéseket
   - Lefordítja a szöveget a kiválasztott AI modellel
   - Megőrzi a formázást és a képeket
   - Összeállítja a lefordított EPUB fájlt
6. Töltsd le az eredményt

---

## 5. Hasznos parancsok

A telepítés után a `~/epub-translator/scripts/` mappában az alábbi scriptek érhetők el:

### Státusz ellenőrzése
```bash
cd ~/epub-translator
./scripts/status.sh
```
Megjeleníti a konténerek állapotát, webes címeket, CPU/RAM használatot.

### Rendszer monitorozása
```bash
./scripts/monitor.sh
```
Erőforrás használat naplózása (`logs/resource_monitor.log`).

### Biztonsági mentés
```bash
./scripts/backup.sh
```
Adatbázis és közösségi könyvtár mentése a `~/epub-backups/` mappába.

### Frissítés
```bash
./scripts/update.sh
```
Gyors frissítés: leállítás → git pull → build → indítás.

### Optimalizálás
```bash
./scripts/optimize.sh
```
Modell ajánlás kérése és optimalizálási javaslatok.

### Docker parancsok

```bash
# Konténerek állapota
docker compose ps

# Konténerek leállítása
docker compose down

# Konténerek indítása
docker compose up -d

# Konténerek újraindítása
docker compose restart

# Logok megtekintése
docker compose logs -f backend    # Backend logok
docker compose logs -f ollama     # Ollama logok
docker compose logs -f postgres   # Adatbázis logok

# Belépés egy konténerbe
docker exec -it epub-backend bash
docker exec -it epub-postgres psql -U epub_user epub_translator
```

### Ollama modell kezelés

```bash
# Elérhető modellek listázása
docker exec epub-ollama ollama list

# Új modell letöltése
docker exec epub-ollama ollama pull deepseek-r1:14b

# Modell törlése
docker exec epub-ollama ollama rm deepseek-r1:7b
```

---

## 6. Hibaelhárítás

### A telepítő nem indul

**Hiba:** `Ne futtasd root-ként!`
- **Megoldás:** Futtasd a scriptet normál felhasználóként. A Docker telepítéséhez a script maga fog `sudo`-t kérni.

### Docker hiba

**Hiba:** `docker: command not found`
- **Megoldás:** A telepítő automatikusan telepíti a Dockert. Ha manuálisan szeretnéd:
  ```bash
  sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  ```

### Konténerek nem indulnak el

**Hiba:** valamelyik konténer `unhealthy` állapotban van
- **Megoldás:** Ellenőrizd a logokat:
  ```bash
  docker compose logs <konténer_név>
  ```
  Majd indítsd újra:
  ```bash
  docker compose restart
  ```

### Ollama modell túl lassú

- **Megoldás 1:** Válts kisebb modellre (`deepseek-r1:8b` vagy `deepseek-r1:7b`)
- **Megoldás 2:** Növeld a rendszer RAM-ját
- **Megoldás 3:** Futtasd az optimalizáló scriptet: `./scripts/optimize.sh`

### Túl kevés a szabad hely

- **Megoldás:** Tisztítsd meg a Docker erőforrásokat:
  ```bash
  docker system prune -f
  docker volume prune -f
  ```
  Vagy törölj nem használt modelleket az Ollama-ból.

### Az admin felület nem elérhető

1. Ellenőrizd, hogy futnak-e a konténerek: `docker compose ps`
2. Várd meg, amíg az összes konténer `healthy` állapotba kerül
3. Ellenőrizd a backend logokat: `docker compose logs backend`
4. Próbáld újraindítani: `docker compose restart`

### Fordítási hibák

- Ellenőrizd, hogy az EPUB fájl nem sérült-e
- Ellenőrizd, hogy a kiválasztott modell le van-e töltve
- Nézd meg a backend logokat a hibaüzenetekért:
  ```bash
  docker compose logs -f backend | grep -i error
  ```

---

## 7. Architektúra áttekintés

```
┌─────────────────────────────────────────────────────┐
│                     Felhasználó                      │
│              (Böngésző: http://localhost)             │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                Nginx (epub-nginx)                     │
│          Port 80 (HTTP) | 443 (HTTPS)                 │
│          Statikus fájlok kiszolgálása                 │
│          Proxy: /api/* → Backend:5000                │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│           Backend (epub-backend) :5000                │
│        Flask + Gunicorn + Eventlet                    │
│        - Felhasználókezelés (Flask-Login)             │
│        - EPUB feldolgozás (EbookLib)                  │
│        - AI fordítás (Ollama API)                     │
│        - OCR feldolgozás (Tesseract)                  │
│        - Hang felismerés (SpeechRecognition)          │
│        - Teljesítmény monitor (psutil)                │
└──┬──────────────┬──────────────┬────────────────────┘
   │              │              │
   ▼              ▼              ▼
┌────────┐ ┌────────────┐ ┌──────────┐
│PostgreSQL│ │  Ollama    │ │  Redis   │
│:5432    │ │  :11434    │ │  :6379   │
│         │ │            │ │          │
│Adatbázis│ │ AI Modellek│ │Cache     │
│Felhaszn.│ │ deepseek-r1│ │Session   │
│Fordítások│ │ Fordítás   │ │Queue     │
│Beállítások│ │            │ │          │
└────────┘ └────────────┘ └──────────┘
   │              │              │
   ▼              ▼              ▼
┌─────────────────────────────────────────────────────┐
│              Docker Volume-ok                         │
│  postgres_data | ollama_data | redis_data            │
│  epub_uploads  | epub_output                         │
└─────────────────────────────────────────────────────┘
```

### Szolgáltatások összefoglalója

| Konténer | Port | Leírás |
|----------|------|--------|
| **epub-nginx** | 80, 443 | Web szerver és proxy |
| **epub-backend** | 5000 | Flask alkalmazás (Gunicorn) |
| **epub-postgres** | 5432 | PostgreSQL adatbázis |
| **epub-ollama** | 11434 | Ollama AI szerver |
| **epub-redis** | 6379 | Redis cache és session tároló |
| **epub-mailhog** | 1025, 8025 | Email tesztelő (fejlesztői) |

### Fájlstruktúra

```
~/epub-translator/
├── .env                    # Környezeti változók
├── .install_config         # Telepítési konfiguráció
├── docker-compose.yml      # Docker Compose definíció
├── .optimization_profile   # Optimalizálási profil
├── nginx/
│   ├── nginx.conf          # Nginx konfiguráció
│   └── ssl/                # SSL tanúsítványok
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py              # Flask alkalmazás
│   ├── config.py           # Konfiguráció
│   ├── models.py           # Adatbázis modellek
│   ├── templates/          # HTML sablonok
│   └── utils/              # Segédmodulok
├── ollama/
│   ├── Dockerfile
│   └── healthcheck.sh
├── scripts/
│   ├── backup.sh           # Biztonsági mentés
│   ├── update.sh           # Frissítés
│   ├── status.sh           # Státusz ellenőrzés
│   ├── monitor.sh          # Erőforrás monitor
│   └── optimize.sh         # Optimalizálás
├── static/                 # Statikus fájlok
├── uploads/                # Feltöltött fájlok
├── output/                 # Fordítások kimenete
├── logs/                   # Rendszer logok
├── backups/                # Biztonsági mentések
├── book_database/          # Könyv adatbázis
├── translation_memory/     # Fordítási memória
├── glossaries/             # Szószedetek
├── community_library/      # Közösségi könyvtár
├── achievements/           # Eredmények
└── fine_tuning/            # Modell testreszabás
```

---

## 📞 Támogatás

Ha hibát tapasztalsz, ellenőrizd a log fájlokat:

```bash
# Backend logok
tail -f ~/epub-translator/logs/backend/*.log

# Erőforrás monitor log
tail -f ~/epub-translator/logs/resource_monitor.log

# Docker konténer logok
docker compose logs -f --tail=100
```

---

**Készítette:** EPUB Fordító Rendszer v11.0 – "Smart Optimizer"