# 📋 EPUB Fordító – Fejlesztési Napló (Changelog)

## v3.0.0 – 2026-08-16 (aktuális)

### 🖥️ Desktop kiadás (Windows/macOS) – MAJOR
- Önálló asztali alkalmazás (Electron + PyInstaller + SQLite), egyfelhasználós,
  Docker és helyi AI nélkül; DeepSeek Pro a fő motor, a helyi GPU opcionális.
- Platformfüggetlen backend (DATA_DIR, SQLite fallback, DESKTOP_MODE),
  GPU-detektálás, desktop scaffold + CI (desktop-build.yml).
- A v2.6.x fordítási minőségi javításai is ebbe a MAJOR-ba foglalva.

---
## v2.6.12 – 2026-08-16 (aktuális)

### 🐛 Kritikus: fejezet-duplikáció javítva
- **Hiba**: a node-onkénti prompt a „szélesebb sliding window" (előző fejezet
  800 + következő fejezet 500 karakter) kontextusát is tartalmazta, amit a
  modell lefordítva visszamondott → minden fejezetben 2–5×-ös duplikáció és
  rossz helyen lévő részek (pl. a „Dauntless konferenciaterem" és a „Merlon
  csata" váltakozó ismétlődése).
- **Javítás**: a szomszédos fejezet kontextusa ki lett kapcsolva; a prompt már
  csak az aktuális node szövegét + glosszárium/stílus/regiszter kapja.

---
## v2.6.11 – 2026-08-16 (aktuális)

### 🖥️ Desktop: GPU-detektálás + Beállítások figyelmeztetés
- **Backend**: `Config.gpu_available()` statikus metódus (`nvidia-smi` VRAM-
  detektálás) + a `/health` mostantól `desktop_mode` és `gpu_available`
  mezőket is visszaad (login nélkül elérhető, az Electron is látja).
- **Frontend**: a `SettingsPage` a `/health`-ből kiolvassa ezeket; desktop
  módban, GPU hiányában a „Helyi (Ollama)" opció alatt figyelmeztet, hogy a
  CPU-s fordítás hetekig tart, ezért DeepSeek Pro vagy GPU ajánlott.
- **Hotfix**: a `gpu_available` először modul-szintű volt, ami 500-at okozott
  (ugyanaz a minta, mint a korábbi DESKTOP_MODE). Most a `Config` osztályban van.

---
## v2.6.10 – 2026-08-16 (aktuális)

### 🐛 Kritikus hotfix: bejelentkezés javítva (HTTP 500)
- **Hiba**: a `DESKTOP_MODE` modul-szintre került a config-ban, de az
  `app.py` `Config.DESKTOP_MODE`-ként hivatkozott rá → minden kérés
  `AttributeError` → 500, ezért nem lehetett belépni.
- **Javítás**: a `DESKTOP_MODE` a `Config` osztályba került; a
  `_resolve_data_dir()` Docker-detektálása `/app/app.py` alapú (a backend
  közvetlenül `/app` alatt van, nem `/app/backend`).
- **Eredmény**: a `/api/login` újra működik, a `DATA_DIR` Dockerben `/app`.

---
## v2.6.9 – 2026-08-16 (aktuális)

### 🖥️ Desktop (asztali) alkalmazás – alapozó fázis
- **Platformfüggetlen backend**: a `DATA_DIR` (~/.epub-translator) kezeli a
  mappákat és logot natív környezetben; SQLite fallback `DATABASE_URL` nélkül.
- **DESKTOP_MODE**: egyfelhasználós mód, automatikus helyi bejelentkezés a
  `before_request` hook-ban (az Electron nem akad login-nél).
- **Desktop scaffold** (`desktop/`): `backend_entry.py` (Flask sidecar + SPA
  kiszolgálás egy porton), `main.js` (Electron), `package.json`
  (electron-builder), `.github/workflows/desktop-build.yml` (Win+Mac CI).
- A közös `backend/app.py` és `frontend/` VÁLTOZATLAN – egy kódbázis.

---
## v2.6.7 – 2026-08-15 (aktuális)

### 🐛 Fordítási log fájl javítva
- **Hiba**: a `translation.log` fájl üres maradt, bár a fordítás futott. A
  `logging` modul handlerjei gunicorn worker + háttérszál környezetben nem
  írták ki a fordítási eseményeket (sem a fájlba, sem a stdout-ra).
- **Javítás**: új `_trans_log()` helper, amely KÖZVETLENÜL a
  `translation.log` fájlba és a stdout-ra ír `flush`-sel. A `translate_epub`
  összes loghívása erre állt át.
- **Eredmény**: a fordítási események (fejezetszám, node-ok, hibák) mostantól
  az Admin → Fordítási log fülön is élőben láthatók.

---
## v2.6.6 – 2026-08-15 (aktuális)

### 🐛 Kritikus hibajavítás: DeepSeek kulcs maszkolási visszaírás
- **Hiba**: a Beállítások oldal a DeepSeek kulcsot MASZKOLVA (*** + utolsó 4
  karakter) küldte vissza, és a `POST /api/user/settings` ezt elmentette → a
  valódi `sk-...` kulcs felülíródott → a fordítás érvénytelen kulccsal hívódott,
  és minden szöveg ANGOL maradt (`nodes_translated = 0`).
- **Javítás**:
  - Backend: a maszkolt (`***`) kulcs NEM kerül mentésre.
  - Frontend: a maszkolt kulcs nem töltődik az inputba, és nem küldődik vissza.
- **Adattisztítás**: a sérült felhasználói kulcsok törlésre kerültek; a
  felhasználónak újra be kell írnia a valódi kulcsot.

---
## v2.6.5 – 2026-08-15 (aktuális)

### 🧱 Platformfüggetlenné tétel (az asztali alkalmazás alapja)
- **DB absztrakció**: a `DATABASE_URL` flag dönt — ha be van állítva Postgres
  (Docker), ha nincs, a backend automatikusan **SQLite**-ra vált
  (`epub_translator.db`), egyfelhasználós desktop módhoz.
- **Migráció platformtudatossá téve**: új `_ensure_column()` helper — SQLite-on
  `PRAGMA table_info` ellenőrzés, Postgres-en `ADD COLUMN IF NOT EXISTS`.
- **Mappák**: `UPLOAD_FOLDER`/`OUTPUT_FOLDER` környezeti változóval felülírhatók.
- **Megállapítás**: a Redis NEM a fő futtatási útvonalon fut (csak a nem használt
  `model_optimizer.py` utility hivatkozik rá), így az asztali portnál nem akadály.

### 📚 Dokumentáció
- `ROADMAP.md`, `DEV_CONTEXT.md`: az „Asztali alkalmazás (Electron + PyInstaller
  + SQLite, távoli DeepSeek)" koncepció rögzítve opcióként.

---
## v2.6.4 – 2026-08-15 (aktuális)

### ✨ Könyvtár fejlesztések
- **Több fájl feltöltése**: a könyvtár feltöltő inputja `multiple` lett, és a
  rendszer minden kiválasztott EPUB-ot egyesével feldolgoz (metaadat + feltöltés).
- **Sorozat kinyerés**: ha az EPUB-ból hiányzik a Calibre sorozat, a rendszer a
  címből próbálja kinyerni (pl. „The Lost Fleet: Relentless" → sorozat:
  „The Lost Fleet"; „Title 3" / „Title #3" / „Book 3" → sorozat + sorszám).
- **Régi könyvek szerkesztése**: a szerkesztés/törlés gomb mostantól a
  **tulajdonosnak ÉS az adminnak** is megjelenik (korábban csak `is_owner`,
  ezért a más fiókkal feltöltött könyveket nem lehetett szerkeszteni).
  A backend jogosultság már eddig is engedte (owner/admin), a frontend most már
  megjeleníti a gombot.

---
## v2.6.3 – 2026-08-15 (aktuális)

### 🐛 Olvasó oldaltördelés javítva (JS-alapú)
- A v2.6.2 CSS-oszlopos lapozás hibás volt (mindig „1/1 oldal"), mert a
  `Range.getClientRects()` a CSS multi-column elrendezésben nem adott
  oszloponkénti (oldalankénti) pozíciót.
- Új: megbízható JS-alapú tördelés — a fejezet tartalmát blokkonként mérjük a
  fix magasságú lapozó ablakhoz (offsetTop + offsetHeight), így az oldalszám
  a tényleges elrendezésből adódik.
- Lapozás `translateY`-nal (függőleges oldalak), ResizeObserver-rel a
  felbontásváltásra (mobil/desktop) újramér.
- Oldal-navigáció: „Előző/Következő oldal" + pontos „X / Y" számláló.

---
## v2.6.2 – 2026-08-15 (aktuális)

### ✨ Olvasó: felbontás-függő oldaltördelés (lapozás)
- A `ReaderPage` mostantól **oldalakra tördeli** a fejezet szövegét (CSS
  oszlop-tördelés + fix magasság), a folyamatos görgetés helyett.
- **Felbontáshoz alkalmazkodik**: mobilnál 1 oszlop, nagyobb kijelzőn több
  oszlop (ResizeObserver + Range API méri az oldalszámot).
- Új **oldal-navigáció** (Oldal előző/következő + „X / Y oldal" számláló).

---
## v2.6.1 – 2026-08-15 (aktuális)

### ✨ Finomítások + GPU-felkészítés
- **Azonnali frissítés a Dashboardon**: a Fordítás **Stop/Resume** után a lista
  mostantól rögtön frissül (a `onStopped` callback bekötve), nem kell várni az
  5 mp-es pollingra vagy a böngésző-frissítésre.
- **NVIDIA GPU-felkészítés** (RTX 3060 12GB előkészítve):
  - `docker-compose.yml`: az ollama szolgáltatás `deploy.resources` GPU-
    passthrough-t kapott (nvidia driver, `capabilities: [gpu]`). GPU hiányában
    a blokk figyelmen kívül marad, az Ollama CPU-val fut.
  - `OLLAMA_NUM_PARALLEL=1` (a VRAM miatt).
  - `install.sh`: `nvidia-smi` alapú GPU-detekció + VRAM-hoz igazított modell-
    ajánlás (12 GB VRAM → `deepseek-r1:8b` a biztonságos választás).

---
## v2.6.0 – 2026-08-15 (aktuális)

### ✨ Lefordított könyvek jóváhagyási folyamata
- **Közös könyvtár vezérelt kialakítása**: minden befejezett fordítás automatikusan
  `pending` (jóváhagyásra váró) állapotba kerül, de a letöltés továbbra is működik.
- **Admin panel**: új „Könyvtár jóváhagyás" fül, ahol a várakozó fordítások
  listájában letölthetők a fájlok, és **Jóváhagyás** / **Elutasítás** gombbal kezelhetők.
- Jóváhagyáskor a lefordított EPUB a közös könyvtárba másolódik (`Book` rekord),
  a fordító felhasználó mint tulajdonos. A duplikációt (cím+szerző) figyeli.
- Új végpontok: `GET /api/admin/pending-library`,
  `POST /api/admin/library/approve/<id>`, `POST /api/admin/library/reject/<id>`.
- Új mező: `Translation.library_status` (`none`/`pending`/`approved`/`rejected`).

---
## v2.5.7 – 2026-08-15 (aktuális)

### ✨ Könyvtár metaadat-kiegészítés (OpenLibrary)
- **Automatikus pótlás feltöltéskor**: ha az EPUB-ból hiányzik a szerző/műfaj,
  a rendszer a cím+szerző alapján lekérdezi az OpenLibrary-t, és kitölti.
- **Batch visszatöltés adminnak**: új `POST /api/library/enrich-missing`
  végpont a meglévő, hiányos metaadatú könyvek egy menetes pótlására.

### 📚 Dokumentáció (elavult MD-ek frissítve)
- `README.md`, `USER_GUIDE.md`, `ROADMAP.md`, `DEV_CONTEXT.md` aktualizálva v2.5.7-re.

---
## v2.5.6 – 2026-08-15 (aktuális)

### 🐛 Hibajavítás: angol köznevek maradtak a fordításban
- **Hiba:** a v2.4.0 NER entitás-védelem regex-e minden nagybetűvel kezdődő
  KÖZNEVET is tulajdonnévnek nézett („Could", „Another", „There"), és a prompt
  „NE fordítsd le" listájába tette → ezek angolul maradtak.
- **Javítás:** a regex-alapú NER-védelem KI VAN KAPCSOLVA (placeholder-csere +
  hamis terminológia-lista eltávolítva). A glosszárium-védelem (megerősített
  terminusok) TÖRETLENÜL megmarad.
- **Továbbfejlesztési terv (rögzítve):** később glosszárium-alapú, igazi név-védelem.

---
## v2.5.5 – 2026-08-15 (aktuális)

### ✨ Apró finomítás
- **Élő fejezetszám**: a fejezet feldolgozásának KEZDETÉN azonnal frissül a
  `current_chapter` + log-sor (`📖 Fejezet X/Y feldolgozása…`) + flush, így a
  progressz-sáv és a Fordítási log nem tűnik „beragadtnak" egy hosszú fejezet
  közben (korábban a fejezetszám csak a fejezet VÉGÉN frissült).

---
## v2.5.4 – 2026-08-15 (aktuális)

### ✨ Funkciók + hibajavítás
- **Admin „Logok" fül**: új alsó váltó (Fordítási log ↔ Alkalmazás log), a
  fordítási log **alapból kiválasztva**, és **5 mp-enként auto-frissül**,
  így a fejezetszámos előrehaladás élőben követhető.
- **Budapest időzóna**: minden dátum (fordítás, könyv, előzmény, felhasználó)
  mostantól `Europe/Budapest` (DST-helyes) időben kerül megjelenítésre. Új
  segédfüggvény: `to_budapest()` (zoneinfo + fix UTC+2 fallback).

---
## v2.5.3 – 2026-08-14 (aktuális)

### 🐛 Hibajavítás: TM UniqueViolation elakadás + hiányzó log
- **Hiba:** a `translation_memory.source_hash` GLOBÁLISAN unique, de a mentés
  INSERT-elt → amikor egy másik felhasználó már lefordította ugyanazt, a szál
  `UniqueViolation` miatt elakadt, a fordítás `processing` (0 fejezet) maradt.
- **Megoldás:** a TM mentés előtt `source_hash` létezés-ellenőrzés + rollback.
- **Log:** a fordítási log mostantól az indításnál és minden fejezet után
  azonnal flushölve van a `translation.log` fájlba (fejezetszám is látszik).

---
## v2.5.2 – 2026-08-14 (aktuális)

### 🐛 Hibajavítás: szövegduplikáció (második menet kikapcsolása)
- **Hiba:** a második menet (review) a teljes fejezetet akarta „javítva” visszaadni,
  de csak csonkolt bemenetet kapott (eredeti[:800] + fordítás[:1500]). A modell így
  összefűzte és többszörözte a szöveget (pl. „TartalomjegyzékTartalomjegyzék”,
  „A Berkley Publishing Group” 32×, csonkolt „Ote”/„Kote”).
- **Megoldás:** a review menet ALAPBÓL KIKAPCSOLVA. Új konfig: `ENABLE_SECOND_PASS`
  (alapértelmezetten `n`); visszaépítéshez `i`/`true`/`1`.
- **Minőségi pontszám review nélkül:** a hibás node-ok arányából becsül.

---
## v2.5.1 – 2026-08-14 (aktuális)

### 🐛 Hibajavítások
- **TM fuzzy matching kikapcsolva**: a 80%+ hasonlóságú találat téves fordításokat
  illesztett be rövid, hasonló párbeszédeknél (pl. katonai sci-fiben). Mostantól
  csak a **pontos SHA256** egyezést használja a fordítási memória (Relentless eset).
- **Leállítás (Stop) megbízhatóság**: a leállítási kérés mostantól **node-szinten**
  is ellenőrződik, és a flag frissen kerül újraolvasásra az adatbázisból. A Stop
  után a fordítás **`paused`** állapotba kerül → megjelenik a **„Folytatás" gomb**.
- **Logolás javítva**: a hibák traceback-je `ERROR` szinten a `translation.log`-ba
  is bekerül, és az írás azonnal flushölve van.

---

## v2.5.0 – 2026-08-14

### ✨ Regiszter + megszólítás
- **Tegezés/magázás**: a felhasználó a Beállításokban választhat megszólítást
  (`User.formality` = `informal`/`formal`), és a fordítási prompt ezt következetesen
  érvényesíti.
- **Párbeszéd/narráció felismerés**: az idézőjelet tartalmazó szövegrészek
  „párbeszéd" címkét kapnak a promptban, így élőbb, beszélt nyelvi stílust kapnak.

### 📧 Email a fordítás végén (+ csatolmány)
- A fordítás befejezésekor a **felhasználó emailjére** értesítés megy (a külső
  SMTP az `.env`-ben konfigurálható: `SMTP_MODE=remote`, `SMTP_HOST/PORT`,
  `SMTP_USER/PASSWORD`, `SMTP_USE_TLS/SSL`).
- A lefordított EPUB **csatolmányként** megy, ha **24 MB alatt** van; felette
  csak értesítő üzenet a fiókbeli letöltésről.
- Új konfig: `EMAIL_ATTACHMENT_MAX_BYTES` (alapértelmezés 24 MB).

### 🔧 install.sh
- `VERSION` frissítve a tényleges projektverzióra.

---

## v2.4.0 – 2026-08-14

### ✨ NER entitás-védelem (placeholder-alapú)
- A glosszáriumból + terminológia-gyűjtésből ismert entitásokat (tulajdonnevek,
  terminusok) a fordítás **előtt** `__ENTn__` placeholder-ekre cseréljük, így a
  modell nem tudja őket félrefordítani vagy inkonzisztensen kezelni.
- A fordítás visszaérkezése után a placeholder-eket visszaállítjuk az eredeti
  formára → megszűnik a „Szürke Gandalf ↔ Grey Gandalf" típusú inkonzisztencia.
- Segédfüggvények: `protect_entities()` + `restore_entities()`.

---

## v2.3.0 – 2026-08-14

### ✨ Checkpoint / folytatás
- **Fejezetenkénti checkpoint mentés**: minden feldolgozott fejezet HTML
  tartalma + az eredeti szövegek a `checkpoint_data` JSON mezőbe kerülnek.
- **Megszakadt fordítás folytatása**: a konténer-újraindítás után a beragadt
  `processing` sorok `paused` státuszt kapnak (ha van checkpoint), és a
  Dashboard kártyán **„Folytatás" gomb** indítja újra onnan, ahol abbahagyta.
- Új végpont: `POST /api/translations/<id>/resume`.
- Az `init_db()` önjavítás már checkpoint-érzékeny: `processing` → `paused`
  (folytatható) vagy `failed` (nincs checkpoint).

---

## v2.2.0 – 2026-08-13

### ✨ Fordítási fejlesztések
- **TM fuzzy matching**: a pontos (SHA256) egyezés mellett a rendszer most már
  80%+ hasonlóságú, korábban lefordított mondatokat is felhasznál (`difflib`,
  hosszarány-szűréssel és `last_used` szerinti előszűréssel a gyorsaságért).
- **Retry logika**: a DeepSeek/Ollama hívások átmeneti hibáknál (429/5xx,
  kapcsolódási hiba) exponenciális háttal (1s, 2s, 4s) újrapróbálkoznak.
  A 400-as hiba (pl. érvénytelen JSON/surrogate) nem próbálkozik újra.
- **Token/költség napló**: a fordítás a DeepSeek `usage` (és Ollama
  `prompt_eval_count`/`eval_count`) adatait gyűjti, a tényleges költséget
  számolja, és megjeleníti a Dashboard kártyán.

### 🗄️ Adatbázis
- Új `translations` oszlopok: `input_tokens_used`, `output_tokens_used`,
  `cost_usd` (az `init_db()` automatikusan hozzáadja őket).

### 🐛 Hibajavítások
- **Elárvult `processing` fordítások**: a backend konténer újraindítása korábban
  félbehagyott, `processing` státuszban ragadó sorokat hagyott az adatbázisban.
  Az `init_db()` mostantól indításkor automatikusan `failed` állapotba állítja
  ezeket, így törölhetők/újraindíthatók.
- **Fordítás törlése**: az nginx nem proxizta a `/delete` végpontot, ezért a
  Dashboard törlése csendben elhasalt. Hozzáadtuk a proxy blokkot, a frontend
  pedig mostantól ellenőrzi a választ (csak valós siker esetén jelez).
- **Admin „Új felhasználó"**: az űrlap megjelenítési feltétele hibás volt, így a
  gomb nem csinált semmit. Külön `showForm` állapot vezetve be, a gomb működik.

---

## v2.1.0 – 2026-08-13

### ✨ Új funkciók
- **Fordítási becslés** (`POST /api/estimate`): a feltöltött EPUB szószáma, becsült
  tokenmennyiség és becsült idő alapján előzetes kalkuláció.
  - Helyi (Ollama) modellnél **csak időbecslés**.
  - DeepSeek Pro-nál **becsült költség** (USD, tokenenkénti be/kimenet árral).
- A feltöltő zóna így a fordítás indítása előtt megmutatja a becslést,
  és továbbra is lehetővé teszi a modell + kontextus-könyv kiválasztását.

### 🐛 Hibajavítás
- `stop_requested` oszlop hozzáadva a `translations` ALTER TABLE migrációhoz
  (megszünteti a 500-as `column "stop_requested" does not exist` hibát).
- **Unicode védelem**: `sanitize_text` a kimenő promptokhoz, hogy az EPUB-ból
  származó sérült/félbevágott karakterek ne okozzanak `lone leading surrogate`
  JSON parse hibát a DeepSeek felé.

### ⚙️ Konfiguráció
- A DeepSeek modellek tokenárazása konfigurálható (`DEEPSEEK_PRICING` környezeti
  változó, USD / 1M token, bemenet + kimenet).

---

## v2.0.0 – 2026-08-12 – Teljes UI redesign + végleges telepíthető verzió

### 🎨 React 18 SPA frontend (teljes újraírás)
- **Keretrendszer**: React 18 + Vite 5 + TypeScript 5 + Tailwind CSS 3
- **Állapotkezelés**: Zustand 4 + TanStack Query 5 (élő polling 5 mp)
- **Routing**: React Router 6 + auth őr (session cookie)
- **i18n**: i18next (magyar/angol nyelvváltó)
- **Design**: modern sötét téma (nincs sötét/világos váltó), mobilbarát (44px érintési cél, alsó navigáció)

### 📱 Új oldalak
- **Dashboard** – aktivitás + drag & drop feltöltés + élő progressz
- **Könyvtár** – szűrés, szerkesztés, törlés, kiválasztás
- **Olvasó** – EPUB olvasás + TOC panel + könyvjelző
- **Beállítások** – modellválasztás EGY HELYEN (helyi Ollama / DeepSeek Pro)
- **Előzmények** – olvasási előzmények (új `ReadingHistory` tábla)
- **Statisztika** – fordítási statisztikák
- **Admin** – felhasználók, logok, rendszer monitor

### 🐳 Docker multi-stage build (végleges telepítés)
- A React frontend a **Dockerben** épül meg (`node:20-alpine` → `nginx:alpine`), így a hostra **NEM kell Node.js**
- SPA nginx routing (`try_files $uri /index.html`) a mélylinkekhez
- Az API és WebSocket kérések a backend konténerre proxizódnak

### 🔌 Új backend JSON végpontok
- `POST /api/login` – JSON alapú bejelentkezés
- `GET /api/profile`, `GET /api/user/settings`
- `GET/POST /api/history`, `GET /api/stats/summary`
- `GET /api/review/:id`, `GET /api/library/:id/toc`
- `GET /api/admin/users`, `GET /api/admin/logs`

### 📚 Dokumentáció
- `docs/UI_REDESIGN_PLAN.md`, `docs/ARCHITECTURE.md`, `docs/DEVELOPMENT_LOG.md`
- `frontend/README.md` – frontend fejlesztői útmutató

---

## v1.3.5 – 2026-08-12

### 🐛 Hibajavítás: Könyvtár szerkesztő modal nem nyílt meg
- **A hiba gyökere**: A `library.html` JavaScript kódja a `{% block content %}` blokkban volt, ami a Bootstrap JS betöltése **előtt** futott le. A `bootstrap` objektum ezért mindig `undefined` volt.
- **A javítás**: A scriptet áthelyeztük a `{% block scripts %}` blokkba, ami a base.html-ben a Bootstrap JS és a main.js **után** renderelődik.
- Emellett a `typeof bootstrap` ellenőrzés + natív DOM fallback is benne maradt (v1.3.4-ből).

### 🎨 Téma váltó + értesítő (harang) javítás
- A scriptek betöltési sorrendje javított, így a `toggleTheme()` és `toggleNotifications()` függvények is elérhetők a gombokra kattintáskor.
- `static/css/main.css`: `[data-bs-theme="light"]` felülírások a fix Bootstrap osztályokra.

### 📝 Dokumentáció
- **README.md**: Sérült első sor javítva, verzió badge 1.3.5, lábléc frissítve
- **ROADMAP.md**: Verzió 1.3.5-re frissítve
- **CHANGELOG.md**: Ez a fájl

### 🔧 Verziószám egységesítés (1.3.5)
- install.sh, backend/config.py, VERSION.txt, static/js/main.js, static/css/main.css

---

## v1.3.4 – 2026-08-12

### 🐛 Library szerkesztő modal – typeof bootstrap őr
- `typeof bootstrap` ellenőrzés az editBook()/saveBookEdit() függvényekben
- Natív DOM fallback, ha a Bootstrap még nem elérhető

### 🎨 Téma váltó CSS javítások
- 8 Bootstrap osztály felülírása light módban (bg-dark, text-light, table-dark, stb.)

---

## v1.3.3 – 2026-08-12
- main.js teljes újraírás (Toast fix, DOMContentLoaded összevonás, null guard)

## v1.3.2 – 2026-08-12
- VSCode fejlesztői kézikönyv (VSCode_DEV_GUIDE.md)

## v1.3.1 – 2026-08-12
- VSCode fejlesztői fájlok (settings.json + launch.json)

## v1.3.0 – 2026-08-12
- Értesítési központ, gyorsműveletek gomb, skeleton screen-ek

## v1.2.1 – 2026-08-12
- Téma váltó ternary hiba javítás

## v1.2.0 – 2026-08-12
- Könyvjelző funkció

## v1.1.1 – 2026-08-12
- EPUB olvasó formázás javítás

## v1.1.0 – 2026-08-11
- Stabil 1.0.0 kiadás, új verziószámozási séma

## Korábbi (v11.x)
- v11.0.71: DeepSeek Pro multi-model, progress bar, modal
- v11.0.70: Batch feltöltés, téma váltó, PWA
- v11.0.62: Hunspell build fix
- v11.0.61: Perzisztens modellváltás
- v11.0.60: DNS javítás
- v11.0.59: Közös könyvtár deduplikációval
- v11.0.56: Review + email
- v11.0.51: Kétmenetes fordítás
- v11.0.50: Glosszárium + TM cache
- v11.0.27: Smart Optimizer

---

*Utolsó frissítés: 2026-08-16 · v3.0.0*
