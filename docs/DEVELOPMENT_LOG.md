# 📓 EPUB Fordító – Fejlesztési Napló

> A frontend UI-redesign projekt fejlesztése során az összes fontos lépés és döntés dokumentálása.

## 2026-08-16 — Desktop A-fázis: PyInstaller Linux próbalegépítés SIKERES

### Elkészült
- backend/requirements-desktop.txt: a desktop build szerver-függőségek nélkül
  (nincs psycopg2/gunicorn/redis -> kisebb, stabilabb PyInstaller bináris).
- .github/workflows/desktop-build.yml: a PyInstaller lépés ezt használja.

### Próbalegépítés (python:3.10-slim + binutils/gcc/libxml-dev + PyInstaller)
- A 'desktop/backend_entry.py' -> egyfájlos 'backend' bináris (36 MB) SIKERESEN buildelt.
- A bináris FUT: GET /health -> HTTP 200, desktop_mode=true, version=2.6.12.
  => a lxml/ebooklib C-bővítmények megfelelően becsomagolódtak.

### Következtetés / következő
A desktop bináris csomagolása Linuxon ellenőrizve; a Windows/macOS .exe/.dmg
build a CI-vel (desktop-build.yml) futtatható tag push után. Nincs több blokkoló
a WSL-oldalon. A build-melléktermékek (dist/build/spec) kitakarítva.

## 2026-08-16 — desktop E2E teszt SIKERES

### Teszt (throwaway konténer, DESKTOP_MODE=1 + SQLite + buildelt SPA)
- backend_entry.py futtatása: SQLite-vel inicializálódott, fut 127.0.0.1:5000-en.
- GET /health -> HTTP 200, benne: desktop_mode=true, gpu_available=false.
- GET /api/profile (login_required) -> HTTP 200, auto-login 'desktop@local'
  (is_admin, tokens=999999, preferred=remote).
=> Az egyfelhasználós desktop mód END-TO-END működik: login nélkül, azonnal használható.

### Megjegyzés
A tesztkonténerben a Flask 127.0.0.1-re köt, ezért a hostról a port-mapping nem
érte el (a teszt a konténer belső loopback-jén futott). Natív desktop esetén ez
nem gond: az Electron és a sidecar ugyanazon a gépen fut.

## 2026-08-16 — desktop end-to-end: frontend build + sidecar flow

### Elkészült / tesztelve
- A frontend host-oldali build (`npm ci && npm run build`) sikeres: tsc átment,
  dist/index.html + assets (338 KB JS) legyártva.
- A desktop architektúra megerősítve: backend_entry.py a Flask sidecar-t
  DESKTOP_MODE=1-gyel indítja, és a buildelt frontend/dist SPA-t szolgálja ki
  (relative /api útvonalakkal) egy porton. Nincs szükség file:// base-re.

### Hátralévő (desktop, még nem kezdve)
- PyInstaller + electron-builder telepítő build (CI-ben/natív gépen).
- A helyi modell VRAM-alapú szűrése a SettingsPage modellek listájában.

## 2026-08-16 — v3.0.0 fejezet-duplikáció javítás

### Tünet (a felhasználó mintája)
A Relentless fordításban ugyanaz a bekezdés (Dauntless konferenciaterem /
Merlon csata) 3×-szor ismétlődött, rossz helyen lévő részekkel.

### Diagnózis
Fejezetenkénti „Dauntless" szószám a forrásban vs outputban:
chapter_08: 7 -> 35, frontmatter: 1 -> 20, chapter_01: 7 -> 38, stb.
=> a modell a szomszédos fejezet szövegét is visszamondta a fordítás után.

### Gyökér ok
A `translate_epub` node-onkénti promptjában a „szélesebb sliding window"
(előző fejezet 800 + következő fejezet 500 karakter) is benne volt, amit a
modell lefordítva visszaadott -> duplikáció + rossz helyen lévő részek.

### Javítás
A szomszédos fejezet kontextus (surrounding_context) KI VAN KAPCSOLVA; a node-prompt
már csak: few-shot + glosszárium + stílus + formality + regiszter + az aktuális node.

## 2026-08-16 — desktop UI: GPU-figyelmeztetés a Beállításokban

### Elkészült
- SettingsPage: a /health-ből kiolvassa a desktop_mode + gpu_available értékeket.
- Desktop módban, GPU hiányában a „Helyi (Ollama)" opció alatt figyelmeztető
  szöveg: CPU-n hetekig tart, ezért DeepSeek Pro ajánlott, vagy GPU szükséges.
- Build: nginx OK (a frontend tsc build átment).

### Hátralévő (desktop, még nem kezdve)
- A helyi modell listájának VRAM-hoz szabása (a SettingsPage modellek szekció),
  és a „GPU használat közben ne terheld másra" szigorúbb jelzés a fordítás alatt.
- PyInstaller + electron-builder tényleges build (CI-ben vagy natív gépen).

## 2026-08-16 — desktop AI-motor irányelvek (backend alap, folytatás)

### Elkészült
- config.py: `gpu_available()` helper (nvidia-smi alapú VRAM-detektálás).
- app.py: `GET /health` bővítve `desktop_mode` + `gpu_available` mezőkkel
  (login nélkül elérhető, az Electron waitForHealth is látja).

### Következő lépés (desktop UI)
- A frontend `SettingsPage` a `health`-ből kiolvassa a desktop_mode + gpu_available
  értékeket, és GPU hiányában a „Helyi (Ollama)" opciót figyelmeztetéssel tünteti
  fel (CPU-n hetekig tart). Ez a desktop-UI réteg következő iterációja.

## 2026-08-16 — desktop sidecar FUNKCIONÁLIS teszt (kulcslogika)

### Teszt (throwaway konténer, DESKTOP_MODE=1 + SQLite)
- `app.py` futtatása DESKTOP_MODE=1, DATABASE_URL üres, DATA_DIR=/tmp/dt-data.
- `GET /health` -> HTTP 200 (SQLite-vel inicializálódott).
- `GET /api/profile` (login_required!) -> HTTP 200, automatikusan létrehozott
  `desktop@local` felhasználó (is_admin, tokens=999999, preferred=remote).
  => az egyfelhasználós desktop mód MAGJA működik (automatikus bejelentkezés).

### Következtetés
A desktop-oldali login-elkerülés és a SQLite fallback igazoltan működik.
Hátralévő (még nem tesztelt): PyInstaller + electron-builder tényleges build
(a Python C-bővítmények (lxml/psycopg2) becsomagolása a fő kockázat).

## 2026-08-16 — desktop scaffold validálva (2. fázis, folytatás)

### Elvégzett
- main.js: a Python indító platformfüggő (Windows: python, egyébként: python3).
- Szintaktikai validáció: node --check main.js OK, package.json JSON OK,
  backend_entry.py py_compile OK.

### Állapot
A desktop scaffold teljesen szintaktikailag érvényes; a következő fázisban a
tényleges PyInstaller + electron-builder build + futtatás tesztelése jön
(ideális esetben CI-ben, vagy egy Windowson/gépen).

## 2026-08-16 — v2.6.9 desktop alapozó fázis

### Elkészült
- config.py: DATA_DIR feloldás (Docker -> /app, natív -> ~/.epub-translator);
  SQLite fallback; DESKTOP_MODE flag; mappák/LOG_DIR a Config-ból.
- app.py: a mappák a Config-ból; LOG_DIR a Config-ból; _desktop_auto_login hook.
- desktop/: backend_entry.py + main.js + package.json + README + CI workflow.

### Architektúra döntés (rögzítve a ROADMAP/DEV_CONTEXT-ben)
- Egy kódbázis; a desktop-specifikus réteg a desktop/ almappában.
- AI-motor: DeepSeek alapértelmezett, helyi GPU opcionális (VRAM-modell + figyelmeztetés).

### Hátralévő (következő fázis)
- PyInstaller + electron-builder tényleges futtatás/tesztelés a hoston/CI-ben.
- AI-motor irányelvek UI-ba (GPU-kapcsoló, VRAM-alapú modelllista, figyelmeztetés).
- macOS notarization (Apple fiók).

## 2026-08-16 — AI-motor irányelvek (desktop koncepció)

### Döntés (felhasználóval egyeztetve)
1. DeepSeek Pro az alapértelmezett.
2. Helyi GPU-fordítás OPCIONÁLIS (haladó kapcsoló), nem kötelező.
3. A modellméret a VRAM-hoz igazodik (install.sh nvidia-smi már detektál).
4. GPU-nál figyelmeztetés, hogy fordítás közben ne használd másra.
5. CPU-s helyi fordítás kizárva/elrejtve (túl lassú).

### Állapot
A kód már támogatja mindkét útvonalat (model_source + use_deepseek), a GPU-alap
(docker-compose.gpu.yml + install.sh VRAM-detektálás) élesben van. A fenti
szabályokat a desktop UI-építésnél alkalmazzuk (még nincs implementálva).

## 2026-08-15 — v2.6.7 fordítási log fájl javítás

### Tünet
A fordítás (id=12) futott (251 node, 4/21 fejezet), de a translation.log fájl
üres volt (0 bájt), és a docker logs-ban sem volt [ID:] sor.

### Diagnózis
- A fájl ÍRHATÓ (közvetlen echo >> translation.log működött, host is látta).
- A logging.FileHandler + StreamHandler nem írt a gunicorn worker +
  háttérszál környezetben (a logger néma maradt).

### Javítás
Új `_trans_log()` direktíró helper (open append + print flush), a translate_epub
minden translation_logger hívása erre állva. Verifikálva: a teszt sor a fájlban
és a host-on is megjelent.

## 2026-08-15 — v2.6.6 DeepSeek kulcs maszkolási bug

### Tünet
A sorosgergo fiók egy könyve teljesen ANGOL maradt (nodes_translated=0),
model_used=deepseek-chat, remote forrás.

### Gyökér ok
A SettingsPage a kulcsot maszkolva kapta meg (***XXXX), és a
POST /api/user/settings ezt elmentette, felülírva a valódi sk-... kulcsot.
A DeepSeek így érvénytelen kulccsal hívódott → üres/hibás válasz → angol maradt.

### Javítás
1. Backend: user_settings csak nem-*** kulcsot ment.
2. Frontend: SettingsPage nem tölti be és nem küldi vissza a maszkolt kulcsot.
3. A sérült kulcs törölve (UPDATE users SET deepseek_api_key='').

### Tanulság
A maszkolt érték visszaírás-védelmet MINDEN kulcsot kezelő végpontnál kell
alkalmazni (a profile végpont már eddig is szűrt, a settings nem).

## 2026-08-15 — v2.6.5 platformfüggetlen DB-réteg (desktop alap)

### Cél
Önálló asztali alkalmazás (Windows/Mac) előkészítése: telepítve, Docker és
helyi AI nélkül fusson, csak távoli DeepSeek + SQLite.

### Amit csináltunk
1. `config.py`: DATABASE_URL flag → Postgres vagy SQLite fallback.
   Mappa-konfig környezeti változóval.
2. `app.py`: `_is_sqlite()` + `_ensure_column()` helper a platformfüggetlen
   migrációhoz (PRAGMA vs IF NOT EXISTS).
3. Redis vizsgálat: a fő kód nem függ a Redistől (csak a nem használt
   model_optimizer.py hivatkozik rá), tehát a desktop portnál nem akadály.

### Tervezett következő lépések (még NINCS megcsinálva)
- Electron wrapper + PyInstaller (Flask sidecar) + telepítő (Windows/Mac).
- Egyfelhasználós mód (automatikus bejelentkezés, saját könyvtár).
- CI build (GitHub Actions) mindkét platformra.

### Fontos: NEM külön mappa/fork!
Egy kódbázis marad; a desktop-specifikus réteg a repon belüli `desktop/` almappába
kerül később. Így a hibajavítás/funkcióbővítés továbbra is egyszer történik.

## 2026-08-15 — v2.6.4 könyvtár feltöltés + sorozat + szerkesztés

### 1) Több fájl feltöltés
LibraryPage input multiple + handleUpload ciklus (File[] típus).

### 2) Sorozat kinyerés
extract-metadata: ha a Calibre series üres, a címből (":", "-", "#", "Book N")
minták alapján próbál sorozatot + sorszámot kinyerni.

### 3) Régi könyv szerkesztése
A BookCard korábban csak is_owner esetén mutatta a szerkesztés/törlés gombot.
Most canManage = is_owner || is_admin (a backend már eddig is engedte adminnak).

## 2026-08-15 — v2.6.3 olvasó oldaltördelés javítás

### Probléma (v2.6.2)
A CSS multi-column + Range.getClientRects() nem adott oszloponkénti pozíciót,
ezért az oldalszám mindig 1/1 volt, és nem lehetett lapozni.

### Megoldás
JS-alapú tördelés: a prose blokkgyerekeit (p, h, div) offsetTop+offsetHeight
alapján mérjük a fix 60vh lapozó magassághoz, ebből adjuk az oldalszámot.
A lapozás translateY-val történik. ResizeObserver-rel felbontásváltásra újramér.

## 2026-08-15 — v2.6.2 olvasó oldaltördelés

### Cél
A fejezetek folyamatos görgetés helyett felbontás-függő oldalakra tördelése,
mobilnál 1, desktopon több oszlop.

### Megoldás
- ReaderPage: fix 60vh magasságú lapozó konténer + CSS columnWidth/vw,
  columnFill: auto, translateX lapozás (transform + transition).
- ResizeObserver a pager szélességéhez, Range API az oszlopok (oldalak) számához.
- Oldal-navigáció gombok + oldalszámláló. Könyvjelző/TOC fejezetszinten marad.

## 2026-08-15 — v2.6.1 azonnali frissítés + GPU-felkészítés

### 1) Dashboard azonnali frissítés (polling-fix)
A DashboardPage nem adta át az onStopped callbacket a TranslationCard-nak, ezért
Stop/Resume után csak az 5 mp-es polling frissített. Bekötve: onStopped=handleUploaded
→ azonnali invalidálás.

### 2) GPU-felkészítés (RTX 3060 12GB)
- GPU passthrough KÜLÖN `docker-compose.gpu.yml` override fájlban (nem a fő compose-ban),
  mert a `driver: nvidia` GPU hiányában hibát dob (nem fallbackel automatikusan).
- A fő docker-compose.yml tisztán CPU-s (OLLAMA_NUM_PARALLEL=2).
- Az install.sh nvidia-smi-vel detektál; ha van GPU, `-f docker-compose.gpu.yml` override-ot alkalmaz.
- Modellajánlás: 12 GB VRAM → deepseek-r1:8b (biztos), 16 GB felett 14b.
- Használathoz a hoston kell: NVIDIA driver + nvidia-container-toolkit.

## 2026-08-15 — v2.6.0 könyvtár-jóváhagyási folyamat

### Cél (felhasználói kérés)
A könyvtár legyen közös, kerüljük a felesleges feltöltéseket/fordításokat.
Minden fordítás pendingre kerül (letölthető marad); az admin olvassa el, és ha
jó, jóváhagyja → bekerül a könyvtárba.

### Megvalósítás
1. `Translation.library_status` mező (none/pending/approved/rejected) + migráció.
2. A fordítás befejezésekor `pending` állapot.
3. Admin végpontok: pending lista + approve/reject.
4. Approve: EPUB másolás a könyvtárba + Book rekord (tulajdonos = fordító),
   dedup (cím+szerző) figyeléssel.
5. Frontend Admin fül: „Könyvtár jóváhagyás" listával + letöltés/gombok.

## 2026-08-15 — v2.5.7 OpenLibrary metaadat-kiegészítés

### Probléma
A könyvtárban sok könyvnek hiányzott a műfaja (57/134) és a szerzője (1/134);
a Calibre sorozat-mező szinte egyiknél sem volt kitöltve.

### Megoldás
1. `openlibrary_enrich()` helper (cím+szerző → OpenLibrary, 3 találat limit).
2. Feltöltéskor automatikus pótlás (hiányzó szerző/műfaj esetén).
3. Admin batch végpont: `POST /api/library/enrich-missing` (rate-limit 0.2s).

### Prioritás (a felhasználó döntése)
cím → író → műfaj (sorozat később, mert a forrás-EPUB-ok nem tartalmazzák).

## 2026-08-15 — v2.5.6 NER-védelem ki (angol köznév hiba)

### Hiba tünete
A fordításban gyakori mondatkezdő/angolos KÖZNEVEK maradtak angolul:
„THere", „Could", „Another". A valódi nevek (Syndic, Merlon) helyesen angolul maradtak.

### Gyökér ok
A v2.4.0 NER entitás-védelem a kontextus-könyvekből regex-szel gyűjtött
„tulajdonneveket", de a regex minden nagybetűvel kezdődő szót bevett; a
stopword-lista hiányos volt. Ezek a hamis nevek bekerültek:
1. a protected_entities listába (placeholder-védelem → angol marad),
2. a terminology_list prompt-utasításba („ezeket NE fordítsd le").

### Javítás (A opció)
- protect_entities/restore_entities hívás eltávolítva a fordítási ciklusból.
- A regex-alapú terminology_list („NE fordítsd le") kikerült a promptból.
- A glosszárium-védelem (glossary_hint + megerősített terminusok) MEGMARADT.

### Terv (ha később kell név-védelem)
Glosszárium-alapú védelem: csak a felhasználó által jóváhagyott terminusokat
védjük, nyers regex heurisztika nélkül.

## 2026-08-15 — v2.5.5 élő fejezetszám

### Probléma
A progressz-sáv (és a fejezetszám) csak a fejezet VÉGÉN frissült, ezért egy
hosszú, sok node-ot tartalmazó fejezet közben a fordítás „beragadtnak" tűnt
(nodes_translated nőtt, de progress/current_chapter nem).

### Megoldás
A fejezet-ciklus elejére azonnali `current_chapter` frissítés + log + flush.

## 2026-08-15 — v2.5.4 logfül + Budapest időzóna

### Probléma
1. Az Admin „Logok" fül mindig `type=app`-ot kért a backendtől, így a fordítási
   log (`type=translation`) soha nem jelent meg, holott a backend támogatta.
2. Minden dátum UTC-ben volt (`datetime.utcnow()`), ami a budapesti időhöz
   képest 2 órával korábbinak tűnt.

### Megoldás
1. Frontend: `logType` állapot + váltógombok + `refetchInterval: 5000`.
2. Backend: `to_budapest()` segéd minden `isoformat()` időmezőre.

## 2026-08-14 — v2.5.2 szövegduplikáció javítás (review kikapcsolás)

### Probléma
Az első menet (node-onkénti fordítás) rendben, de a második menet (review) a
teljes fejezetet akarta visszaadni csonkolt bemenetből, és duplikálta a szöveget.

### Megoldási próbálkozások (időrendben)
1. TM fuzzy matching kikapcsolása (v2.5.1) — nem oldotta meg, a duplikáció maradt.
2. Review menet kikapcsolása `ENABLE_SECOND_PASS` kapcsolóval (v2.5.2, alapból 'n').

### Visszaépítés
Ha később node-szintű review-t akarunk, a `Config.ENABLE_SECOND_PASS` + `.env`
`ENABLE_SECOND_PASS=i` beállítással visszaállítható; az app.py-ban a review blokk
megtartva (second_pass_enabled guard mögött).

## 2026-08-14 — v2.2.0 hibajavítások + fordítási fejlesztések

### Fordítási fejlesztések (v2.2.0)
- **TM fuzzy matching**: `fuzzy_search_tm()` – difflib alapú 80%+ hasonlóságú egyezés
- **Retry logika**: `request_with_retry()` – 429/5xx/conn hibáknál exponenciális backoff
- **Token/költség napló**: DeepSeek `usage` + Ollama `eval_count` gyűjtése, `cost_usd` számítás

### Hibajavítások
- Elárvult `processing` fordítások: `init_db()` önjavítás (`failed`-re állítás)
- `/delete` proxy hiányzott az nginx-ből
- Admin „Új felhasználó" form megjelenítési feltétel bugja
- Előzetes becslés (`/api/estimate`), kontextus-könyv ajánló, Unicode `sanitize_text`

## 2026-08-12 — Projekt indítás + 0. fázis

### Döntések
| Téma | Döntés |
|------|--------|
| Keretrendszer | React 18 + Vite 5 + TypeScript 5 + Tailwind CSS 3 |
| Téma | Modern sötét (nincs sötét/világos váltó) |
| Állapotkezelés | Zustand 4 |
| Adatlekérés | TanStack Query 5 |
| i18n | i18next (hu/en) |
| Backend érintés | Engedélyezve (HTML→JSON + új végpontok) |

### Elkészült (0. fázis)
- [x] `docs/UI_REDESIGN_PLAN.md` – a teljes terv
- [x] `frontend/` scaffold (Vite + React + TS + Tailwind)
- [x] App Shell (Topbar + Sidebar + MobileNav + Toast)
- [x] Routing (React Router 6) + auth őr
- [x] Login oldal (session-alapú)
- [x] Váz oldalak (Dashboard, Library, Settings, History, Stats)
- [x] i18n (hu/en nyelvi fájlok)
- [x] API client + típusdefiníciók
- [x] Build validálva: `npm run build` ✅ (1611 modul, hibátlan)

### Telepített függőségek
- Node.js v22.22.1 + npm 9.2.0 (NodeSource setup_20.x)

### Backend bővítés (a React SPA-hoz)
- [x] `ReadingHistory` modell hozzáadva (`backend/models.py`) – olvasási előzmény
- [x] Új JSON végpontok (`backend/app.py`):
  - `GET /api/profile` – profil adat (session ellenőrzés)
  - `GET /api/user/settings` – beállítások olvasása
  - `GET /api/library/:id/toc` – címtáblázat
  - `GET /api/review/:id` – fejezetek JSON-ban
  - `GET /api/history` + `POST /api/history` – olvasási előzmény
  - `GET /api/stats/summary` – statisztika
  - `GET /api/admin/users` + `GET /api/admin/logs` – admin JSON
- [x] Python szintaxis validálva (`py_compile` ✅)
- [x] Backend konténer újraépítve + újraindítva (Alembic migráció lefutott)

### 1. fázis – Dashboard bekötve (frontend)
- [x] `frontend/src/api/translations.ts` – fordítás API (list, events, status, stats, upload)
- [x] `frontend/src/components/translation/TranslationCard.tsx` – fordítás kártya (progressz sáv, minőség, letöltés/törlés)
- [x] `frontend/src/components/translation/UploadZone.tsx` – drag & drop feltöltő zóna
- [x] `frontend/src/pages/DashboardPage.tsx` – élő frissítés (TanStack Query polling 5 mp) + feltöltés + törlés
- [x] `GET /api/translations` új backend végpont (teljes fordítási lista)
- [x] Frontend build validálva ✅ (1614 modul)

### 2. fázis – Könyvtár bekötve (frontend)
- [x] `frontend/src/api/library.ts` – könyvtár API (list, upload, edit, delete, toggle, metadata)
- [x] `frontend/src/components/library/BookCard.tsx` – könyv kártya
- [x] `frontend/src/components/library/BookEditModal.tsx` – szerkesztő modal
- [x] `frontend/src/pages/LibraryPage.tsx` – szűrés + feltöltés + lista

### 3. fázis – Olvasó + előzmény
- [x] `frontend/src/api/reader.ts` – olvasó API (fejezetek, tartalom, könyvjelző, előzmény)
- [x] `frontend/src/pages/ReaderPage.tsx` – EPUB olvasó + TOC panel
- [x] `frontend/src/pages/HistoryPage.tsx` – olvasási előzmények
- [x] `GET/POST /api/history` – ReadingHistory használatban

### 4. fázis – Beállítások (modellválasztás egy helyen)
- [x] `frontend/src/api/settings.ts` – modell + beállítás API
- [x] `frontend/src/pages/SettingsPage.tsx` – modellválasztás + API kulcs
- [x] Modellválasztás EGYETLEN helyen (a dashboard + admin duplikáció megszüntetve)

### 5. fázis – Statisztika + Review
- [x] `frontend/src/pages/StatsPage.tsx` – statisztika mini-kártyák
- [x] `frontend/src/pages/ReviewPage.tsx` – fejezetek átnézése + inline szerkesztés

### 6. fázis – Admin
- [x] `frontend/src/pages/AdminPage.tsx` – felhasználók + logok + rendszer monitor

### Végleges telepíthető verzió (v2.0.0)
- [x] `frontend/Dockerfile` – multi-stage build (node:20-alpine → nginx:alpine)
- [x] `frontend/nginx.conf` – SPA routing (try_files fallback) + API proxy
- [x] `frontend/.dockerignore` – tiszta build context
- [x] `docker-compose.yml` – nginx `build: ./frontend` (hoston nem kell Node.js)
- [x] `POST /api/login` JSON endpoint + admin jelszó visszaállító
- [x] Verzió egységesítés: v2.0.0 (VERSION.txt, config.py, .env, install.sh, CHANGELOG, README)
- [x] Multi-stage build validálva (`docker compose build nginx` ✅)
- [x] A React SPA élesben a 8080-as porton (curl ellenőrzés ✅)
- [x] Szinkronizálás a GitHub repóba (src/frontend + backend + docs + install.sh)

---

## Dokumentációs fájlok jegyzéke

| Fájl | Cél |
|------|-----|
| `docs/UI_REDESIGN_PLAN.md` | A teljes áttervezési terv |
| `docs/ARCHITECTURE.md` | Az új frontend+backend architektúra |
| `docs/DEVELOPMENT_LOG.md` | Ez a napló |
| `frontend/README.md` | Frontend fejlesztői útmutató |