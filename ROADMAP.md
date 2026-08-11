# 🗺️ EPUB Fordító – Fejlesztési Útiterv (Roadmap)

**Verzió:** 1.0.0 – "Smart Optimizer"  
**Utolsó frissítés:** 2026-08-11 (stabil 1.0.0 kiadás, új verziószámozás: MAJOR.MINOR.PATCH)  

### 🎯 Verziószámozási séma (1.0.0-tól)
- **PATCH** (1.0.x): hibajavítások
- **MINOR** (1.x.0): új funkciók  
- **MAJOR** (x.0.0): nagy változások (te döntöd el, mikor)

### v1.0.0 újdonságok (2026-08-11):
- 🎯 **Stabil 1.0.0 kiadás** – új verziószámozási séma bevezetése
- 👤 **Profil statisztika áthelyezés**: token, pont, szint, fordítás kompakt kártyák a profil oldalon a sidebar footer helyett
- 🎨 **Új .stat-card-mini CSS**: kisebb, esztétikus statisztika kártyák hover animációval
- 🐛 **Install.sh frissítési hiba javítva**: git reset --hard után már nem írja felül a fájlokat a create_all_files() – a GitHub-ról letöltött fájlok maradnak meg
- 🐛 **További hibajavítások**: MutationObserver/modal JS hiba, pip packaging verzió, DEBIAN_FRONTEND docker fix, Bootstrap Icons sidebar fallback

### v11.0.71 újdonságok (2026-08-11):
- 🤖 **DeepSeek Pro multi-model** – `deepseek-chat` (V3) és `deepseek-reasoner` (R1) választható távoli modellként, API kulcs kezelés a dashboardon
- 📊 **Progress bar live updates** – JavaScript DOM polling, becsült hátralévő idő kijelzéssel (formatTime, formatStageText)
- 📝 **Könyvtár szerkesztő modal** – Bootstrap modal (`editBook`) prompt() helyett, cím/szerző/műfaj/sorozat/nyelv mezők + opcionális fájlcsere
- 📁 **CSS/JS separáció** – `static/css/main.css` és `static/js/main.js` kiszervezve a `base.html`-ből
- 📸 **Snapshot script** – `scripts/snapshot.sh` git commit + tag pillanatképekhez, `git checkout` visszatérés
-  **Továbbfejlesztett logolás** – stdout StreamHandler a Docker logs láthatóságához, `/api/events` végpont
- 🐛 **Hibajavítások** – deepseek-reasoner temperature paraméter, deepseek-chat model_source perzisztencia, pszichopg2-binary visszaállítás

### v11.0.70 újdonságok (2026-08-10):
- 🔤 **#8 Szélesebb sliding window** – előző fejezet 800 + következő 500 karakter
- 📚 **#9 Batch könyvtár feltöltés** – több száz EPUB, automatikus metaadat kinyerés (cím, szerző, műfaj, sorozat)
- 🎨 **#10 Sötét/világos téma váltó** – CSS változók, felhasználónként mentve
- 📱 **Sidebar navigáció** – bal oldali fix sidebar + mobil hamburger menü + alsó navigációs sáv
- 📦 **PWA támogatás** – manifest.json, service worker, SVG ikonok, offline cache
- 💡 **Könyvajánló** – kapcsolódó könyvek ajánlása sorozat/szerző/műfaj alapján
- ⚡ **Dashboard élő frissítés** – 10mp polling, fordítási állapot követés
- 👤 **Profil oldal** – saját adatok, API kulcs, jelszó változtatás
- 🖼️ **Könyvtár kártyás nézet** – táblázat ↔ kártya váltó gomb
- 🐛 **Számos hibajavítás** – 500 hiba (users oszlopok), MailHog profiles, Ollama deploy/reservations, port foglaltság (retry + auto 8080), install.sh shebang, heredoc → git clone, SECRET_KEY, cp -a teljes másolás

---

## ✅ Már megvalósított fejlesztések (v11.0.34 – 11.0.61)

### Modellváltás perzisztencia + folyamatjelző (v11.0.62)
- [x] **Perzisztens modellváltás**: az `.env` fájl SELECTED_MODEL sorának frissítése, konténer újraindítás után is megmarad
- [x] **Modell elérhetőség ellenőrzés**: váltás előtt Ollama `/api/tags` ellenőrzés, hiányzó modell automatikus letöltése
- [x] **Folyamatjelző az admin felületen**: spinner, státusz visszajelzés (letöltés vs. sikeres váltás)
- [x] **OLLAMA_HOST konfiguráció**: config.py most környezeti változóból olvas (`os.environ.get`)

### DNS javítás – frissítésellenőrzés (v11.0.60)
- [x] **Backend konténer DNS konfiguráció**: `dns: [1.1.1.1, 8.8.8.8]` hozzáadva a `docker-compose.yml`-ben
- [x] A hiányzó DNS miatt a backend nem tudta elérni az `api.github.com`-ot (frissítésellenőrzés) és az OpenLibrary API-t
- [x] A `dns:` direktíva csak külső címekhez használatos, a belső Docker konténernevek (`ollama`, `postgres`, `redis`) feloldását nem befolyásolja

### Közös könyvtár deduplikációval (v11.0.59)
- [x] **Könyv modell átalakítása**: `is_selected` mező kivezetése a `Book` modellből, `uploader` reláció hozzáadása
- [x] **UserBookPreference modell**: felhasználónkénti könyvbeállítások (kiválasztás, jegyzetek) külön táblában
- [x] **Közös könyvtár API**: a `library_list` végpont már nem szűr `user_id`-ra – minden felhasználó látja az összes könyvet
- [x] **Deduplikáció**: feltöltéskor cím+szerző alapú ellenőrzés, duplikátum esetén 409-es válasz a feltöltő nevével
- [x] **Jogosultságkezelés**: szerkesztés/törlés csak a feltöltő vagy admin számára, a frontend csak a tulajdonosnak mutat gombokat
- [x] **Felhasználónkénti kiválasztás**: `UserBookPreference.is_selected` – minden felhasználó saját maga jelölhet ki könyveket fordítási kontextushoz
- [x] **Dashboard integráció**: saját + kiválasztott könyvek összefésült listája, `book_prefs` dict a template-ben

### Vizuális fejlesztések a könyvtárban (v11.0.59)
- [x] **Feltöltő neve** megjelenik a táblázatban
- [x] **Kontextus oszlop** ⭐/☆ gombbal a gyors kiválasztáshoz
- [x] **Deduplikációs figyelmeztetés** a frontenden: alert üzenet a felhasználónak


### Fordítási minőség
- [x] **HTML struktúra megőrzése** (v11.0.34) – text node batch fordítás, HTML elemek megtartása
- [x] **Fejlett prompt kontextus** (v11.0.35) – stílusinstrukció mintakönyvekből, terminológiai lista könyvtári könyvekből, sliding window
- [x] **Ollama paraméterek finomhangolása** (v11.0.44) – `temperature=0.2`, `num_predict=2048`, `repeat_penalty=1.1`, `top_p=0.9`
- [x] **Few-shot fordítási példák** (v11.0.44) – 2 angol→magyar példa a promptban
- [x] **Placeholder-alapú biztonságos text node csere** (v11.0.36)
- [x] **Timeout végtelenre állítása CPU-only deepseek-hez** (v11.0.47)

### Felhasználhatóság
- [x] **Modern UI/UX** – Bootstrap 5.3 + Icons, sötét téma, toast értesítések, stat kártyák, fade animációk
- [x] **Admin log oldal** (v11.0.34) – szintaxis kiemelés, auto-frissítés, vágólap másolás
- [x] **Kijelölt könyvek visszajelzése** (v11.0.43) – badge a dashboardon
- [x] **Részletes hibakezelés és logolás** (v11.0.34) – `/app/logs/app.log` + `translation.log`
- [x] **Flask-Limiter optimalizálás** (v11.0.46) – 2000 req/óra, dashboard 30mp frissítés

---

## ✅ Újabban megvalósított fejlesztések (v11.0.50 – 11.0.56)

### Batch darabszám eltérés javítása (v11.0.54)
- Batch fordítás (több node egy API hívásban) **teljes eltávolítása** – a deepseek-r1 nem használja megbízhatóan a NODE_SEP szeparátort
- **Node-onkénti fordítás**: minden text node egyesével kerül fordításra, TM cache-szel gyorsítva
- Glosszárium explicit használata minden egyedi promptban (`glossary_hint`)
- `num_predict` csökkentése 2048→1024 (rövidebb szövegek egyesével)

### Hardver alapú modell ajánlás javítása (v11.0.55)
- **40 GB RAM**: mostantól `deepseek-r1:32b` ajánlott (korábban hibásan 14b)
- Új RAM kategória: ≥40 GB → 32G memória limit, MAX_WORKERS=2
- **Frissítéskor hardver változás észlelése**: ha a RAM változott, a `configure_system()` felajánlja a modellváltást
- Modellváltáskor automatikus `apply_optimization()` – modell-specifikus OLLAMA_MEMORY, OLLAMA_PARALLEL, BATCH_SIZE

### Kétmenetes fordítás teljes implementáció (v11.0.51)
- Első menet (5-90%) + Második menet minőségellenőrzés és javítás (91-99%)
- Eredeti angol szövegek elmentése az első menet előtt
- Minőségi pontszám számítás a javítások aránya alapján (75-99)

---

## 🔴 Rövid távú fejlesztések (következő verziók) – Magas prioritás

### 1. Automatikus glosszárium építés ✅ (v11.0.50)
**Státusz:** KÉSZ
- `GlossaryEntry` modell a `models.py`-ban (angol→magyar szópárok)
- Automatikus szópár kinyerés a fordítás során (forrásszöveg > 3 karakter)
- Glosszárium betöltés a fordítás előtt (`glossary_terms` dict)
- Meglévő bejegyzések `source_count` frissítése
- **Minőségjavulás:** ⭐⭐⭐⭐ (terminológiai következetesség)

### 2. Kétmenetes fordítás (hibrid modell) ✅ (v11.0.51)
**Státusz:** KÉSZ
- **Első menet:** AI fordítás a jelenlegi `translate_epub()`-bal (struktúra-megőrző mód, fejlett prompt)
- **Második menet:** Minőségellenőrzés és javítás – a modell megkapja az eredeti angol szöveget (referencia) és a lefordított magyar szöveget, ellenőrzi a nyelvtant, stílust, terminológiát
- Eredeti szövegek elmentése az első menet előtt (`original_texts` lista)
- `current_stage` követés: `first_pass` → `second_pass` → `post_processing` → `completed`
- Minőségi pontszám számítás a javítások aránya alapján (75-99 pont)
- `first_pass_model` és `second_pass_model` mezők tárolása
- **Minőségjavulás:** ⭐⭐⭐⭐⭐ (két menetes ellenőrzés és javítás)

### 3. Magyar nyelvi utófeldolgozás ✅ (v11.0.50)
**Státusz:** KÉSZ
- `hunspell hunspell-hu` telepítve a Dockerfile-ban
- `hunspell==0.5.5` hozzáadva a requirements.txt-hez
- Hunspell inicializálás a `translate_epub` elején
- Helyesírás-ellenőrzés a lefordított szövegen (naplózás, automatikus javítás nélkül)
- **Minőségjavulás:** ⭐⭐⭐ (helyesírási hibák kiszűrése)

### 4. Fordítási memória (Translation Memory) ✅ (v11.0.50)
**Státusz:** KÉSZ
- `TranslationMemory` modell a `models.py`-ban (SHA256 hash + szöveg)
- `search_tm()` segédfüggvény a pontos egyezés kereséséhez
- Automatikus TM mentés minden sikeres fordítás után
- `usage_count` és `last_used` követés
- **Minőségjavulás:** ⭐⭐⭐ (konzisztencia + sebesség)

### 5. Részletes fordítási progressz követés ✅ (v11.0.50)
**Státusz:** KÉSZ
- `Translation` modell bővítve: `current_stage`, `current_chapter`, `total_chapters`, `words_processed`, `total_words`, `nodes_translated`, `nodes_failed`
- Valós idejű progressz frissítés minden batch fordítás után
- Becsült szószám számítás az első 5 dokumentum alapján
- Részletes státusz API (`/api/status/<id>`) bővítve az új mezőkkel
- **Használhatóság:** ⭐⭐⭐⭐ (pontos visszajelzés)

---

## 🔶 Opcionális fejlesztések – Hardverfüggő minőségjavítás

### 16. Nagyobb modellre váltás (deepseek-r1:14b → 32b) – részletes útmutató

**Státusz:** ⏳ TERVEZETT – a 14b modell tesztelése után döntés alapján

**Cél:** Jelentős fordítási minőség javítása a nagyobb (32 milliárd paraméteres) deepseek-r1 modellre váltással.

#### Miért jobb a 32b modell?
- **Több paraméter (32B vs 14B)** = jobb nyelvtani megértés, gazdagabb szókincs, pontosabb fordítás
- **Hosszabb kontextus ablak** = jobban érti a szövegkörnyezetet, kevesebb következetlenség
- **Jobb ritka szavak és idiómák kezelése** = természetesebb magyar fordítás
- **Minőségjavulás:** ⭐⭐⭐⭐⭐ (a legnagyobb elérhető minőség javulás)
- **Hátrány:** Extrém lassú CPU-n (i3-on akár 3-5x lassabb, mint a 14b), ~20 GB modellméret

#### Hardver követelmények 40 GB RAM-hoz
| Erőforrás | 14b modell | 32b modell | Megjegyzés |
|-----------|-----------|-----------|------------|
| Modell méret | ~14 GB | ~20 GB | Letöltendő |
| Ollama futási memória | ~22-28 GB | ~28-35 GB | Modell + overhead |
| Maradék a többi konténernek | ~12-18 GB | ~5-12 GB | PostgreSQL, Redis, Nginx, Backend |
| CPU igény | i3 8. gen elegendő | i3 8. gen elegendő, de lassú | GPU nélkül |
| Fordítási idő (átlag könyv) | 1-3 nap | 3-10 nap | Erősen szövegmennyiség függő |

#### Szükséges fájlmódosítások

**1. `install.sh` – Új RAM kategória hozzáadása (≥40 GB → 32G limit)**
```bash
# analyze_and_optimize() függvényben, a RAM optimalizálás részhez:
elif [ "$TOTAL_RAM" -ge 40 ]; then
    OPTIMAL_MEMORY_LIMIT="32G"
    OPTIMAL_REDIS="512mb"
    OPTIMAL_PG_BUFFERS="512MB"
```
Módosítandó sor: a `>=32` ág ELÉ kell beszúrni, hogy a 40 GB-os gépek a nagyobb limitet kapják.

**2. `docker-compose.yml` – Ollama konténer memória limit**
```yaml
# Az ollama szekcióban:
deploy:
  resources:
    limits:
      memory: ${OPTIMAL_MEMORY_LIMIT}  # ez automatikusan 32G lesz az .env-ből
    reservations:
      memory: 24G  # 20G-ról 24G-ra növelve
```

**3. `config.py` – Alapértelmezett memória limit**
```python
OPTIMAL_MEMORY_LIMIT = os.environ.get('OPTIMAL_MEMORY_LIMIT', '32G')
```

**4. `.env` – Környezeti változó frissítése**
```bash
OPTIMAL_MEMORY_LIMIT=32G
SELECTED_MODEL=deepseek-r1:32b
```

**5. `backend/Dockerfile` – Gunicorn timeout növelése**
```dockerfile
CMD ["gunicorn", "-w", "1", "-b", "0.0.0.0:5000", "app:app", "--timeout", "14400", "--worker-class", "eventlet"]
```
A 32b modellnél egy-egy API hívás akár 1-2 órát is igénybe vehet, ezért a Gunicorn timeout-nak extrém magasnak kell lennie (14400 mp = 4 óra).

**6. Modell letöltése**
```bash
docker exec epub-ollama ollama pull deepseek-r1:32b
# Letöltési idő: 1-3 óra (internet sebességtől függően, ~20 GB)
```

**7. Admin felületen modell váltás**
Az admin oldalon (`/admin`) lehet átváltani a 32b modellre, vagy a `.env` fájlban beállítani.

#### A program kompatibilitása 32b modellel

A jelenlegi kód **teljes mértékben kompatibilis** a 32b modellel. Nincs szükség kódolási változtatásra, mert:
- A `translate_epub()` függvény a `Config.DEFAULT_MODEL`-t használja, ami dinamikusan állítható
- A timeout már `None` (végtelen) – nem lesz timeout probléma
- A kétmenetes fordítás ugyanúgy működik 32b-vel is (az első menet fordít, a második ellenőriz)
- A glosszárium, TM cache, Hunspell mind modell-független

#### Kockázatok és megfontolások
- **Memória kimerülés:** Ha a rendszer swap-olni kezd, a fordítás gyakorlatilag leáll. Figyelni kell a RAM használatot (`htop`-pal)
- **Több napos fordítási idő:** Egy átlagos regény fordítása 3-10 napig is eltarthat
- **Áramkimaradás:** Nincs checkpoint mechanizmus – ha leáll a gép, a fordítás elölről kezdődik
- **Ajánlás:** Először egy rövidebb könyvvel (50-100 oldal) tesztelni a 32b modellt

---

## 🟡 Középtávú fejlesztések – Közepes prioritás

### 6. Interaktív fordítás-javítási felület ✅ (v11.0.56)
**Státusz:** KÉSZ
- **`/review/<id>`**: Webes felület a lefordított könyv fejezetenkénti böngészésére
- Inline szerkesztés: "Szerkesztés" gombra kattintva textarea jelenik meg
- **`POST /api/review/save/<id>`**: Módosított fejezet visszaírása az EPUB-ba
- Változtatások azonnal menthetők – az EPUB fájl frissül
- **Használhatóság:** ⭐⭐⭐⭐⭐ (emberi korrektúra lehetősége)

### 7. Értesítések a fordítás befejezésekor ✅ (v11.0.56)
**Státusz:** KÉSZ
- **Email értesítés** Flask-Mail-en keresztül (MailHog SMTP: localhost:1025)
- A `translate_epub()` végén automatikusan emailt küld a felhasználónak
- Az email tartalmazza: fájlnevet, modellt, minőségi pontszámot, linkeket (letöltés, review)
- Böngésző Notification API: a dashboard oldal értesíthet a fordítás végén
- **Használhatóság:** ⭐⭐⭐⭐ (nem kell folyamatosan figyelni a dashboardot)

### 8. Kontextus-érzékeny fordítás (szélesebb sliding window) ✅ (v11.0.69)
**Státusz:** KÉSZ
- Előző fejezet teljes első bekezdése (max 800 karakter) – korábban 300 karakter
- Következő fejezet első bekezdése (max 500 karakter, előretekintő kontextus) – ÚJ
- A `surrounding_context` változó most előretekintő + visszatekintő kontextust is tartalmaz
- Ez segít a narratív folytonosság fenntartásában és jobb kontextust ad a modellnek
- **Minőségjavulás:** ⭐⭐⭐ (jobb kontextus = jobb fordítás)

### 9. Drag & drop + Batch könyvtár feltöltés ✅ (v11.0.69)
**Státusz:** KÉSZ
- **Több fájl egyidejű behúzása**: drop zóna egyszerre több EPUB-ot fogad
- **Automatikus metaadat kinyerés**: EPUB belső `dc:title`, `dc:creator`, `dc:language` mezők olvasása
- **OpenLibrary automatikus keresés**: "Összes keresése" gomb az internetes metaadat kiegészítéshez
- **Batch feldolgozási lista**: kártyás nézet, státusz jelzőkkel (kinyerés, keresés, menthető, duplikátum, hiba)
- **Progress bar**: vizuális visszajelzés a feldolgozás állapotáról
- **"Összes mentése" gomb**: egy kattintással az összes feldolgozott könyv mentése
- **Backend API**: `/api/library/extract-metadata` – EPUB metaadat kinyerés, `/api/library/batch-upload` – batch feltöltés
- **Használhatóság:** ⭐⭐⭐⭐⭐ (több száz könyv percek alatt)

### 10. Sötét/világos téma váltó ✅ (v11.0.69)
**Státusz:** KÉSZ
- **CSS változós témakezelés**: `:root` / `[data-bs-theme="dark"]` és `[data-bs-theme="light"]` változók
- **Felhasználói preferencia mentése**: `User.dark_mode` oszlop az adatbázisban, `/api/user/settings` API
- **Témaváltó gomb**: 🌙/☀️ ikon a navbar jobb oldalán, Bootstrap `data-bs-theme` attribútummal
- **Világos téma dizájn**: GitHub-szerű világos színséma (fehér háttér, sötét szöveg, kék akcentus)
- **Perzisztencia**: bejelentkezés után automatikusan visszaáll a mentett preferencia
- **Használhatóság:** ⭐⭐⭐⭐ (személyre szabható megjelenés)

---

## 🟢 Hosszú távú fejlesztések – Alacsony prioritás

### 11. Gépi tanulás alapú minőségbecslés
**Cél:** Automatikus minőségi pontszám a fordításra (BLEU, szószám-arány, passzív szerkezetek).
- BLEU score számítás (ha van referencia fordítás)
- Szószám-arány ellenőrzése (a magyar fordítás általában hosszabb)
- Túl sok passzív szerkezet detektálása
- **Minőségjavulás:** ⭐⭐ (objektív minőségi metrika)

### 12. Többnyelvű felület bővítése
**Cél:** A felület több nyelven is elérhető legyen.
- Flask-Babel meglévő integráció kihasználása
- Angol, német, francia fordítások a UI-hoz
- Nyelv-választó a bejelentkezési oldalon

### 13. Közösségi glosszárium megosztás
**Cél:** A felhasználók megoszthassák egymással a glosszáriumaikat.
- Export/import funkció (JSON, CSV)
- Könyv-specifikus glosszáriumok (pl. Harry Potter univerzum terminusok)
- Opcionális közösségi adatbázis

### 14. Stílus-transzfer (formális ↔ informális)
**Cél:** A fordítás stílusának testreszabása.
- Formális (hivatalos) vs. informális (baráti) stílus választása
- Tegezés/magázás konzisztens kezelése
- Prompt szintű vezérlés: "Fordítsd le magyarra INFORMÁLIS stílusban..."

### 15. Fejezetek párhuzamos fordítása
**Cél:** Több fejezet egyidejű fordítása külön szálakon.
- Thread pool a fejezetek párhuzamos feldolgozásához
- Ollama num_parallel kihasználása
- Összességében gyorsabb fordítás (bár a felhasználónak az idő nem számít)

---

## 📊 Prioritási mátrix

| Fejlesztés | Minőségjavulás | Használhatóság | Implementációs idő | Priorítás |
|-----------|---------------|----------------|-------------------|-----------|
| Glosszárium építés | ⭐⭐⭐⭐ | ⭐⭐ | 2-3 óra | 🔴 |
| Kétmenetes fordítás | ⭐⭐⭐⭐⭐ | ⭐ | 3-4 óra | 🔴 |
| Magyar utófeldolgozás | ⭐⭐⭐ | ⭐⭐ | 1-2 óra | 🔴 |
| Fordítási memória | ⭐⭐⭐ | ⭐⭐ | 2-3 óra | 🔴 |
| Progressz követés | ⭐ | ⭐⭐⭐⭐ | 2-3 óra | 🔴 |
| Interaktív javítás | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 5-8 óra | 🟡 |
| Értesítések | ⭐ | ⭐⭐⭐⭐ | 1 óra | 🟡 |
| Szélesebb sliding window | ⭐⭐⭐ | ⭐ | 0.5 óra | 🟡 |
| Drag & drop | ⭐ | ⭐⭐⭐ | 1 óra | 🟡 |
| Téma váltó | ⭐ | ⭐⭐⭐ | 1 óra | 🟡 |
| Minőségbecslés | ⭐⭐ | ⭐⭐ | 3-4 óra | 🟢 |
| Többnyelvű UI | ⭐ | ⭐⭐⭐ | 2-3 óra | 🟢 |
| Közösségi glosszárium | ⭐⭐ | ⭐⭐⭐ | 2-3 óra | 🟢 |
| Stílus-transzfer | ⭐⭐⭐⭐ | ⭐⭐ | 1-2 óra | 🟢 |
| Párhuzamos fejezetek | ⭐ | ⭐⭐ | 3-4 óra | 🟢 |

---

## 🎯 Ajánlott következő lépések (v1.0.0 után)

Az alábbi koncepciók a **használhatóságot** és a **fordítási pontosságot** helyezik előtérbe. A korábbi rövid távú célok (kétmenetes fordítás, glosszárium, TM cache, Hunspell, sliding window, batch feltöltés, dark/light téma, PWA, stb.) mind megvalósultak.

---

### 🔴 Magas prioritás – Fordítási pontosság

#### A) Ellenőrző/megerősítő API hívások (confidence scoring)
**Probléma:** A DeepSeek R1 (Ollama) 7b/8b/14b modellek gyakran hallucinálnak – kihagynak mondatokat, félrefordítanak, vagy nem követik a prompt utasításait. A 32b modell pontosabb, de extrém lassú CPU-n.

**Javaslat:** Minden egyes text node fordítás után egy második, **ellenőrző API hívást** küldeni (olcsóbb/gyorsabb modellel, pl. 1.5b vagy akár deepseek-chat API), ami:
- Összehasonlítja a forrás- és célszöveg hosszát (karakterszám-arány)
- Detektálja az angolul maradt szavakat (regex: `[a-zA-Z]{3,}`)
- Ellenőrzi, hogy a fordítás értelmes magyar mondat-e (nem csak random tokenek)
- Ha az ellenőrzés megbukik, újrafordítja a node-ot (max 3 próbálkozás)

**Várható hatás:** ⭐⭐⭐⭐ (kihagyott/félrefordított mondatok száma drasztikusan csökken)
**Implementációs idő:** 3-5 óra

#### B) Regiszter- és stílustudatos fordítás
**Probléma:** A jelenlegi prompt nem különbözteti meg a regisztereket (párbeszéd vs. narráció, formális vs. informális).

**Javaslat:**
1. **Fejezet szintű stílusdetekció** fordítás előtt: a forrásszöveg alapján a modell meghatározza a domináns stílust (elbeszélő, párbeszédes, technikai, lírai)
2. **Per-node stílus-címkézés**: minden text node kap egy `style_tag`-et (`narration`, `dialogue`, `thought`, `description`)
3. **Stílus-specifikus prompt**: a fordítási prompt tartalmazza a stílus-címkét, pl. *"Ez egy párbeszéd. Használj közvetlen, élő magyar beszélt nyelvet."*
4. **Tegezés/magázás konzisztencia**: a felhasználó kiválaszthatja a preferált regisztert (tegezés/magázás), és a prompt ezt következetesen érvényesíti

**Várható hatás:** ⭐⭐⭐⭐⭐ (természetesebb, konzisztensen stílusos fordítás)
**Implementációs idő:** 4-6 óra

#### C) Entitás-felismerés és következetes névfordítás (NER)
**Probléma:** A DeepSeek modellek inkonzisztensen fordítják a tulajdonneveket, helyszíneket, fantasy terminusokat. Ugyanazt a nevet egyik fejezetben lefordítják, a másikban megtartják angolul.

**Javaslat:**
1. **Első menet**: NER (Named Entity Recognition) futtatása az egész könyvre – személynevek, helyszínek, szervezetek, egyedi terminusok kigyűjtése
2. **Glosszárium automatikus bővítése**: a NER által talált entitások bekerülnek a glosszáriumba a felhasználó által jóváhagyott fordítással
3. **Entitás-helyettesítés fordítás előtt**: a forrásszövegben az ismert entitásokat placeholder-ekre cseréljük, fordítás után visszaállítjuk – így a modell nem tudja "elrontani" a már ismert neveket
4. **Interaktív entitás-jóváhagyás**: a dashboardon a felhasználó áttekintheti és jóváhagyhatja a NER által talált entitásokat fordítás előtt

**Várható hatás:** ⭐⭐⭐⭐⭐ (megszűnik a "Szürke Gandalf" ↔ "Grey Gandalf" típusú inkonzisztencia)
**Implementációs idő:** 5-8 óra

---

### 🟡 Közepes prioritás – Használhatóság

#### D) Fordítási checkpoint/folytatás
**Probléma:** Ha a fordítás félbeszakad (áramkimaradás, konténer újraindulás), az egész folyamat elölről kezdődik. Egy 3-5 napos fordításnál ez katasztrofális.

**Javaslat:**
1. Minden fejezet fordítása után **checkpoint fájl** mentése (fejezet_index, lefordított HTML, timestamp)
2. A `Translation` modell bővítése `checkpoint_data` JSON mezővel
3. Ha a fordítás újraindul, a checkpoint alapján onnan folytatja, ahol abbahagyta
4. A dashboardon "Folytatás" gép a félbemaradt fordításokhoz

**Várható hatás:** ⭐⭐⭐⭐⭐ (kritikus használhatósági fejlesztés hosszú fordításoknál)
**Implementációs idő:** 3-4 óra

#### E) Több könyv párhuzamos fordítási sora (queue)
**Probléma:** Jelenleg egyszerre csak egy fordítás fut. Ha a felhasználó több könyvet tölt fel, azok sorban várakoznak, de nincs vizuális visszajelzés a sorrendről.

**Javaslat:**
1. **Translation queue** a Redis-ben (FIFO sor)
2. A dashboardon **"Fordítási sor"** panel: mutatja a sorban álló könyveket, becsült kezdési idővel
3. **Prioritás állítás**: a felhasználó átrendezheti a sort (drag & drop)
4. **Párhuzamos fordítás opció**: ha a hardver engedi (sok RAM + CPU), több fordítás is mehet egyszerre (max 2)

**Várható hatás:** ⭐⭐⭐⭐ (professzionális munkafolyamat több könyv esetén)
**Implementációs idő:** 4-6 óra

#### F) Fordítási statisztika és minőség dashboard
**Probléma:** A felhasználó nem látja, hogy mennyire volt sikeres a fordítás – csak egy quality_score számot kap.

**Javaslat:**
1. **Részletes fordítási riport** minden könyvhöz:
   - Szószám forrás/cél nyelven
   - TM cache találati arány (hány százalék volt cache-elve)
   - Glosszárium találatok száma
   - Újrafordított node-ok száma (confidence check miatt)
   - Második menetben javított mondatok száma
   - Fejezetenkénti statisztika
2. **Vizuális dashboard**: grafikonok a fordítási teljesítményről (Chart.js)
3. **Exportálható riport** PDF/HTML formátumban

**Várható hatás:** ⭐⭐⭐ (átláthatóság, minőségbiztosítás)
**Implementációs idő:** 3-5 óra

---

### 🟢 Alacsonyabb prioritás – Kényelmi funkciók

#### G) WebSocket alapú valós idejű frissítés
**Probléma:** A jelenlegi 10 másodperces polling felesleges hálózati forgalmat generál és késleltetett.

**Javaslat:** Flask-SocketIO integráció – a fordítási események (`node_translated`, `chapter_complete`, `pass_complete`) valós időben, WebSocketen keresztül érkeznek a böngészőbe. Nincs polling, azonnali UI frissítés.

**Várható hatás:** ⭐⭐ (szebb, de nem kritikus)
**Implementációs idő:** 2-3 óra

#### H) OCR támogatás scan-nelt PDF-ekhez
**Javaslat:** Tesseract OCR integráció a feltöltési folyamatba – ha a felhasználó PDF-et vagy képet tölt fel, automatikus OCR → EPUB konverzió, majd fordítás.

**Várható hatás:** ⭐⭐⭐ (új felhasználási mód)
**Implementációs idő:** 4-6 óra

#### I) DeepSeek Pro API költségbecslés
**Javaslat:** A dashboardon a felhasználó láthatja, hogy mennyibe fog kerülni a fordítás DeepSeek Pro API-val (token alapú becslés), mielőtt elindítja. API árazás alapján valós idejű kalkuláció.

**Várható hatás:** ⭐⭐⭐ (költségtudatosság)
**Implementációs idő:** 1-2 óra

---

### 📊 Összesített prioritási mátrix (új koncepciók)

| Fejlesztés | Minőség | Használhatóság | Idő | Prioritás |
|-----------|---------|---------------|-----|-----------|
| A) Confidence scoring / ellenőrző hívás | ⭐⭐⭐⭐ | ⭐⭐ | 3-5h | 🔴 |
| B) Regiszter/stílus tudatos fordítás | ⭐⭐⭐⭐⭐ | ⭐⭐ | 4-6h | 🔴 |
| C) NER + entitás konzisztencia | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 5-8h | 🔴 |
| D) Checkpoint/folytatás | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 3-4h | 🟡 |
| E) Fordítási sor (queue) | ⭐ | ⭐⭐⭐⭐ | 4-6h | 🟡 |
| F) Statisztika dashboard | ⭐⭐ | ⭐⭐⭐⭐ | 3-5h | 🟡 |
| G) WebSocket valós idejű frissítés | ⭐ | ⭐⭐ | 2-3h | 🟢 |
| H) OCR PDF támogatás | ⭐⭐ | ⭐⭐⭐ | 4-6h | 🟢 |
| I) API költségbecslés | ⭐ | ⭐⭐⭐ | 1-2h | 🟢 |

### 🎯 TOP 3 ajánlott következő fejlesztés

1. **C) NER + entitás konzisztencia** – a legnagyobb hatás a fordítási minőségre (⭐⭐⭐⭐⭐), megszünteti a tulajdonnév inkonzisztenciát
2. **D) Checkpoint/folytatás** – kritikus használhatósági fejlesztés, 3-5 napos fordításoknál létfontosságú
3. **B) Regiszter/stílus tudatos fordítás** – a párbeszédek és narráció megkülönböztetése drámaian javítja az olvashatóságot

---

*Ez a dokumentum folyamatosan frissül az új verziókkal. A kész fejlesztések a [README.md](README.md) Verzió Történet szekciójában is megtalálhatók.*