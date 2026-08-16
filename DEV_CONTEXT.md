# 📋 DEV_CONTEXT.md — Fejlesztési koncepció és munkaegyezmény az AI számára

> **Cél:** Ezt a fájlt **bemásolhatod egy új AI-ablakba**, és az AI azonnal tudni fogja a projekt kereteit, konvencióit és a veled való együttműködés szabályait — anélkül, hogy újra el kellene magyaráznod.

---

## ⚡ AI ELVÁRÁSOK (először ezt olvassa el az AI!)

1. **Kérdezz, mielőtt döntesz** – ha bármilyen bizonytalanság van (mappa, verzió, funkció), kérdezz a felhasználótól; ne feltételezz hallgatólagosan.
2. **Jelezd, ha Act mód kell** – módosítás/futtatás előtt mindig jelezd, hogy a felhasználó kapcsoljon Act módba.
3. **Ne találj ki adatot** – ne generálj jelszót, API-kulcsot, útvonalat vagy verziószámot; a valós értékeket ellenőrizd a fájlokban.
4. **Ne törölj ellenőrzés nélkül** – törlés/felülírás előtt jelezd, hogy mi és miért törlődik.
5. **A kanonikus mappa = WSL build-forrás** – minden kódmódosítást ITT végezz, szinkronizáld a Desktop-ra, és a Desktop repóból commit+push (branch `main`, SSH).
6. **Verzió** – minden módosításkor ellenőrizd a verziókezelési szabályt lent, és írd át az érintett 6 helyen.
7. **Légy tömör, technikai** – magyarul kommunikálj, ahol lehet, tényekkel és fájlhivatkozásokkal.
8. **Tesztelés** – a kód módosítása után futtasd a verifikációt (`py_compile`, build, `/health`).

---

## 🎯 Projekt áttekintés

| Mező | Érték |
|------|-------|
| Név | EPUB Fordító Rendszer |
| Cél | EPUB könyvek fordítása angolról magyarra (helyi Ollama DeepSeek + opcionális DeepSeek Pro API) |
| **Aktuális verzió** | **v3.0.0** |
| Tech stack | Flask (Gunicorn) + React 18 (Vite/TS/Tailwind) + PostgreSQL + Ollama + Redis + Nginx + MailHog |

---

## 📁 Kanonikus mappák + SZINKRONIZÁLÁSI SZABÁLY

### A hivatalos (kanonikus) forrás
```
/home/sorosg/epub-translator/
├── backend/          # Flask app (app.py, config.py, models.py, requirements.txt, Dockerfile)
├── frontend/         # React SPA (src/, package.json, Dockerfile, nginx.conf)
├── nginx/            # (a backend oldali nginx config, ha van)
├── docs/             # DEVELOPMENT_LOG, UI_REDESIGN_PLAN, WORKSPACE_LAYOUT, ARCHITECTURE
├── CHANGELOG.md
├── ROADMAP.md
├── README.md
├── USER_GUIDE.md
├── DEV_CONTEXT.md    # ez a fájl
└── .env
```
- **Ez a Docker build-forrás.** A futó konténerek innen épülnek (`docker compose build` → `frontend/` és `backend/`).

### A Windows Desktop másolat (MINDIG AKTUÁLIS legyen)
```
/mnt/c/Users/soros/Desktop/Epub-translate/
├── src/
│   ├── backend/   # ← ugyanaz a backend, amit a WSL-ben szerkesztünk
│   ├── frontend/  # ← ugyanaz a frontend
│   └── ...
├── CHANGELOG.md, ROADMAP.md, README.md, ...
```

### ⚠️ SZINKRONIZÁLÁSI SZABÁLY (fontos!)
- **A WSL `backend/` és `frontend/src/` a forrás.**
- **Minden kód- és MD-módosítás után a Desktop `src/backend/` és `src/frontend/` mappát is frissíteni kell**, hogy a Desktop másolat mindig egyezzen a futó példánnyal.
- **Irány: WSL → Desktop** (a Desktop NEM a hivatalos forrás, csak tükör).
- Tipikus szinkron-parancs (Act módban, módosítás után):
  ```bash
  cp -r /home/sorosg/epub-translator/backend/* /mnt/c/Users/soros/Desktop/Epub-translate/src/backend/
  cp -r /home/sorosg/epub-translator/frontend/src/* /mnt/c/Users/soros/Desktop/Epub-translate/src/frontend/src/
  ```
- Az MD-fájlokat is tükrözd (CHANGELOG, ROADMAP, README, USER_GUIDE, DEV_CONTEXT), plusz `desktop/` és `.github/` is.

### 🔄 PUSH szabály (2026-08-16-tól MINDIG)
A Desktop másolat a git push-forrás (SSH `git@github.com:sorosg/Epub-translate.git`, branch `main`).
A WSL → Desktop szinkron után a commit + push a Desktop repóból történik:
```bash
T=/mnt/c/Users/soros/Desktop/Epub-translate
# 1. szinkron (lásd fent), majd:
git -C "$T" add -A
git -C "$T" commit -m "vX.Y.Z: rövid leírás"
git -C "$T" push origin main
```
- A `.env` SOSEM kerül commitba (a Desktop .gitignore kizárja; push előtt ellenőrizd: `git -C "$T" ls-files | grep env` üres legyen).
- A CI (`desktop-build.yml`) a `main` tag/push-ra indul; a Windows/macOS telepítőt tag (`git tag vX.Y.Z && git -C "$T" push origin vX.Y.Z`) triggereli.

---

## 🔢 Verziókezelési koncepció

### Séma: MAJOR.MINOR.PATCH
- **PATCH** (x.y.Z): hibajavítás
- **MINOR** (x.Y.z): új funkció
- **MAJOR** (X.y.z): nagy áttörés (a felhasználó dönt)

### 🏷️ TAG és verziószabály (2026-08-16-tól MINDIG)
- A tag-et és a push-t az AI kezeli (a Desktop repóból: `git tag vX.Y.Z && git push origin vX.Y.Z`).
- **Verzióbump CSAK kódmódosításnál**; a dokumentum-frissítés önmagában NEM növel verziót.
- A tag push (v*) elindítja a CI-t (Windows .exe + macOS .dmg buildet).
- Aktuális verzió: **v3.0.0**.

### Hol kell frissíteni a verziót (mind a 6 helyen!)
1. `backend/config.py` → `VERSION = os.environ.get('VERSION', 'x.y.z')`
2. `.env` → `VERSION=x.y.z`
3. `VERSION.txt`
4. `CHANGELOG.md` → új szekció felülre
5. `README.md` → verzió badge + lábléc + Verzió Történet
6. `install.sh` → `VERSION="x.y.z"` (ha van)

> Jelenlegi: **v2.5.7**

---

## 🧪 Tesztkörnyezet jellemzői

| Cím | Érték |
|-----|-------|
| Webes felület | `http://localhost:8080` |
| Backend (konténer belső) | `:5000` (nem publikált a hostra) |
| Health | `curl http://localhost:8080/health` → `OK` / `HTTP:200` |
| MailHog | `http://localhost:8025` |
| Admin belépés | `admin@epub-translator.local` / `Abrakadabra` |

### Build / restart parancsok
```bash
cd /home/sorosg/epub-translator

# Backend + frontend build
docker compose build backend nginx

# Újraindítás
docker compose up -d backend nginx

# Státusz
docker compose ps
```

### Verifikáció
```bash
# Python szintaxis
python3 -m py_compile backend/app.py backend/models.py backend/config.py

# A futó konténerben tényleg benne van-e a módosítás
docker exec epub-backend grep -c "<kulcsszó>" /app/app.py

# End-to-end
curl -s -m 15 -w '\nHTTP:%{http_code}\n' http://localhost:8080/health
```

### Adatbázis elérés
```bash
docker exec epub-postgres psql -U epub_user -d epub_translator -c "..."
```

---

## 🧩 Kódkonvenciók (a jelenlegi v3.0.02 állapothoz)

- **Endpointok**: törekedj az egységesítésre `/api/` alá (a `/delete`, `/upload`, `/download` még külön van — ismert téma).
- **Unicode védelem**: `sanitize_text()` — minden kimenő promptot tisztíts (surrogate-hiba megelőzése).
- **Retry**: `request_with_retry()` — DeepSeek/Ollama hívásokhoz (429/5xx/conn → backoff, 400 → nem retry).
- **Fordítási memória**: `search_tm()` (SHA256) + `fuzzy_search_tm()` (difflib, 80%+).
- **Token/költség**: `tokens_in_total`/`tokens_out_total`/`cost_total` gyűjtés + `Translation` mezők (`input_tokens_used`, `output_tokens_used`, `cost_usd`).
- **Önjavítás**: `init_db()` indításkor a beragadt `processing` sorokat `failed`-re állítja.
- **Kontextus-könyv**: az `UploadZone` metaadatkinyeréssel + `/api/library/recommend` ajánlással működik.

---

## 📚 Gyors hivatkozások

| Fájl | Mire jó |
|------|---------|
| `ROADMAP.md` | fejlesztési javaslatok + prioritások |
| `ARCHITECTURE.md` | rendszer-architektúra |
| `CHANGELOG.md` | verziótörténet |
| `docs/DEVELOPMENT_LOG.md` | fejlesztési napló |
| `docs/WORKSPACE_LAYOUT.md` | mappaszerkezet / tiszta klón út |
| `USER_GUIDE.md` | felhasználói kézikönyv |

---

*Fájl célja: egyetlen bemásolható kontextus az AI-nak. Frissítsd, ha a verzió vagy a koncepció változik.*

## 🎮 GPU (NVIDIA)
- A `docker-compose.yml` ollama szolgáltatása GPU-passthrough-t használ
  (`deploy.resources.reservations.devices`, nvidia, capabilities: [gpu]).
- GPU hiányában a blokk inaktív (CPU futás). A hoston NVIDIA driver +
  `nvidia-container-toolkit` szükséges a GPU-hoz.
- Modell: 12 GB VRAM-ig `deepseek-r1:8b` (biztos), 16 GB felett `14b` is mehet.
- `install.sh` `nvidia-smi`-vel detektálja a GPU-t és VRAM-hoz igazítja a modellt.

## 🖥️ Asztali (desktop) koncepció
- Cél: önálló alkalmazás (Win/Mac), Docker/helyi AI nélkül, távoli DeepSeek + SQLite.
- DB: `DATABASE_URL` flag (Postgres/SQLite); desktopban SQLite (`epub_translator.db`).
- A desktop-specifikus réteg a `desktop/` almappában van (Electron + PyInstaller).
- E2E állapot: a sidecar (DESKTOP_MODE=1 + SQLite + SPA) működik; a PyInstaller/electron-builder telepítő-build még hátravan (CI/natív gép).
- NEM külön kódbázis/fork — a közös kód marad a gyökérben.

### 🎯 AI-motor döntések (desktop)
- Alapértelmezett: DeepSeek Pro (távoli).
- Helyi GPU: opcionális, haladó kapcsoló. Modell a VRAM-hoz igazítva.
- CPU-s helyi: elrejtve (lassú).
- GPU-nál figyelmeztetés: fordítás közben ne terheld másra.
