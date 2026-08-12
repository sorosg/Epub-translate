# 🏗️ EPUB Fordító – Architektúra Dokumentáció

**Verzió:** 11.0.67 – "Smart Optimizer"  
**Utolsó frissítés:** 2026-07-20  

> Ez a dokumentum a rendszer teljes architektúráját írja le. Célja, hogy a Cline AI asszisztens kontextuskeretből való kiesése esetén is gyorsan áttekinthető legyen a kódbázis szerkezete, a főbb komponensek és azok kapcsolatai.

---

## 1. Áttekintés

### A projekt célja és filozófiája

Az EPUB Fordító egy **Linux rendszeren futó, Docker-alapú ekönyv fordító program**, amely az **Ollama AI platformon keresztül helyi deepseek-r1 modelleket** használ angol nyelvű EPUB könyvek magyarra fordítására. A program **nem cloud API-kat vagy külső szolgáltatásokat vesz igénybe** – minden komponens (AI modell, adatbázis, webszerver) lokálisan, a felhasználó saját hardverén fut.

#### Tervezési alapelvek

1. **Minőség az elsődleges prioritás – nem a sebesség.** A fordítási folyamat kétmenetes (első menet: AI fordítás, második menet: minőségellenőrzés és javítás). A rendszer szándékoltan lassabb, de pontosabb fordítást végez. Nincs időkorlát (timeout=None) – egy átlagos regény fordítása akár napokig is tarthat CPU-n.

2. **Hardver-optimalizálás GPU nélkül.** Mivel a célhardver jellemzően nem rendelkezik erős videókártyával (GPU hiánya), illetve költséghatékonysági okokból, a **rendszer a rendelkezésre álló RAM memóriát veszi alapul a modell kiválasztásánál**. Az install.sh automatikusan detektálja a RAM méretét és ajánlja a megfelelő modellt (8GB→7b, 16GB→8b, 32GB→14b, 40GB+→32b). Minden fordítás CPU-n történik, a deepseek-r1 modellek kifejezetten jó teljesítményt nyújtanak GPU nélkül is.

3. **Közös könyvtár mint kontextus-adatbázis.** A felhasználók által feltöltött könyvekből egy **közös, deduplikált könyvtári adatbázis épül**. A felhasználók kiválaszthatják, mely könyveket szeretnék fordítási kontextusként használni – ezekből a rendszer terminológiát (tulajdonnevek, speciális kifejezések) és stílusmintákat nyer ki, jelentősen javítva a fordítás minőségét és következetességét. A deduplikáció (cím+szerző alapján) megakadályozza ugyanazon könyv többszöri feltöltését.

4. **Verziókövetés és dokumentáltság.** Minden változtatás után az `install.sh` verziószámát növelni kell, a `ROADMAP.md`-ben rögzíteni kell az új fejlesztéseket, és az `ARCHITECTURE.md`-t frissíteni kell. A kód részletesen kommentezett a későbbi közérthetőség és bővíthetőség érdekében – a projekt célja, hogy hosszú távon fenntartható és bővíthető legyen.

#### Technikai összefoglaló

Az EPUB Fordító Flask backenddel, PostgreSQL adatbázissal, Nginx webszerverrel és számos segédszolgáltatással (Redis, MailHog) működik Docker konténerekben.

### Főbb képességek (v11.0.67)
- EPUB fájlok feltöltése és automatikus AI fordítása (kétmenetes: fordítás + minőségellenőrzés)
- Felhasználókezelés (token alapú, admin/user szerepkörök)
- Közös könyvtár deduplikációval – minden felhasználó látja az összes feltöltött könyvet
- Felhasználónkénti könyvbeállítások (`UserBookPreference`) – fordítási kontextus kiválasztása
- Automatikus glosszárium építés a lefordított szövegekből
- Fordítási memória (TM cache) a konzisztens újrafordításhoz
- Interaktív review felület a lefordított fejezetek szerkesztéséhez
- Email értesítések a fordítás befejezésekor (MailHog)
- Admin felület rendszerfigyeléssel, felhasználókezeléssel, modellváltással
- Hardver alapú automatikus optimalizálás (RAM, CPU függő)

---

## 2. Konténer Architektúra (docker-compose)

```
┌──────────────────────────────────────────────────────────┐
│                  HOST GÉP (Ubuntu)                        │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │              Docker Network (translator-network)  │    │
│  │                                                  │    │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │    │
│  │  │  NGINX   │  │  BACKEND │  │   POSTGRES    │  │    │
│  │  │  :80     │──│  :5000   │──│   :5432       │  │    │
│  │  │  :443    │  │ (Flask)  │  │ (epub_transl) │  │    │
│  │  └──────────┘  └────┬─────┘  └───────────────┘  │    │
│  │                     │                            │    │
│  │                     │ HTTP API                   │    │
│  │                     ▼                            │    │
│  │          ┌──────────────────┐                    │    │
│  │          │     OLLAMA       │                    │    │
│  │          │  host.docker     │                    │    │
│  │          │  .internal:11434 │                    │    │
│  │          └──────────────────┘                    │    │
│  │                                                  │    │
│  │  ┌──────────┐  ┌──────────────────┐              │    │
│  │  │  REDIS   │  │    MAILHOG       │              │    │
│  │  │  :6379   │  │  :1025  :8025    │              │    │
│  │  └──────────┘  └──────────────────┘              │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

| Konténer | Port | Szerep |
|----------|------|--------|
| **nginx** | 80, 443 | Reverse proxy, statikus fájlok, SSL termináció |
| **backend** | 5000 (belső) | Flask API, fordítási logika, Gunicorn + eventlet |
| **postgres** | 5432 (belső) | Adatbázis (felhasználók, fordítások, könyvtár, glosszárium) |
| **ollama** | 11434 (host.docker.internal) | AI modell futtatása (deepseek-r1) |
| **redis** | 6379 (belső) | Cache, rate limiting |
| **mailhog** | 1025, 8025 | Email tesztelés (SMTP + web UI) |

### Memória limit (Ollama konténer)
- Automatikusan a rendelkezésre álló RAM alapján (`.env`: `OPTIMAL_MEMORY_LIMIT`)
- 32 GB RAM: 24-28G, 40 GB RAM: 32G, 64 GB RAM: 48G

---

## 3. Adatbázis Modellek (`backend/models.py`)

### 3.1. User
Felhasználói fiók, Flask-Login integrációval.
- `id`, `username`, `email` (unique), `password_hash`
- `first_name`, `last_name`, `address`, `birth_date`, `tax_id`, `phone`
- `tokens` (fordítási tokenek), `is_admin`, `language` (alapértelmezett: hu)
- `points`, `level` (gamification), `dark_mode`
- `created_at`

### 3.2. Translation
Egy fordítási feladat rekordja.
- `id`, `user_id` → User
- `original_filename`, `output_filename`
- `status`: pending → processing → completed / failed
- `progress` (0–100), `model_used`
- `current_stage`: first_pass, second_pass, post_processing, completed
- `current_chapter`, `total_chapters`, `words_processed`, `total_words`
- `nodes_translated`, `nodes_failed`
- `first_pass_model`, `second_pass_model`
- `quality_score` (75–99)
- `created_at`

### 3.3. Book
Közös könyvtárba feltöltött EPUB könyv.
- `id`, `user_id` → User (feltöltő), `uploader` reláció
- `filename`, `file_path` (`/app/uploads/library/`)
- `title`, `author`, `language`, `genre`, `series`, `series_number`
- `uploaded_at`
- **Nincs** `is_selected` mező! (lásd UserBookPreference)

### 3.4. UserBookPreference (ÚJ v11.0.62)
Felhasználónkénti könyvbeállítások.
- `id`, `user_id` → User, `book_id` → Book
- `is_selected` – felhasználó által kiválasztva fordítási kontextushoz
- `notes` (szöveges jegyzet)
- `updated_at`
- **UNIQUE constraint**: `(user_id, book_id)`

### 3.5. GlossaryEntry
Angol→magyar szópárok, automatikusan épül a fordításokból.
- `id`, `user_id` → User
- `source_term` (angol), `target_term` (magyar)
- `language_pair` (en-hu), `category`
- `source_count`, `confidence`
- `created_at`, `updated_at`

### 3.6. TranslationMemory
Fordítási memória – mondatok SHA256 hash-elése.
- `id`, `user_id` → User
- `source_text`, `translated_text`, `source_hash` (SHA256, unique)
- `language_pair`, `usage_count`, `created_at`, `last_used`

### 3.7. ReferenceBook
Mintakönyv a fordítási stílus meghatározásához.
- `id`, `user_id` → User
- `filename`, `title`, `language`, `file_path`
- `extracted_text`, `created_at`

### 3.8. SystemSettings, OptimizationLog
- `SystemSettings`: kulcs-érték párok (rendszerbeállítások)
- `OptimizationLog`: modelloptimalizálás naplózása

---

## 4. API Végpontok (`backend/app.py`)

### 4.1. Autentikáció
| Útvonal | Metódus | Leírás |
|---------|---------|--------|
| `/login` | GET/POST | Bejelentkezés |
| `/logout` | GET | Kijelentkezés |
| `/health` | GET | Health check (JSON) |

### 4.2. Dashboard & Fordítás
| Útvonal | Metódus | Leírás |
|---------|---------|--------|
| `/dashboard` | GET | Főoldal (fordítások, könyvek, mintakönyvek) |
| `/upload` | POST | EPUB feltöltés és fordítás indítása (token -1) |
| `/api/status/<id>` | GET | Fordítás állapota (JSON, részletes progress mezőkkel) |
| `/download/<id>` | GET | Lefordított EPUB letöltése (csak kész státuszú) |
| `/delete/<id>` | POST | Fordítás törlése |

### 4.3. Könyvtár (Library)
| Útvonal | Metódus | Leírás |
|---------|---------|--------|
| `/library` | GET | Könyvtár oldal |
| `/api/library/list` | GET | **Összes könyv** listázása (közös könyvtár, user_id szűrés nélkül) |
| `/api/library/upload` | POST | EPUB feltöltés a könyvtárba (deduplikáció cím+szerző alapján) |
| `/api/library/edit/<id>` | POST | Könyv metaadatainak szerkesztése (csak tulajdonos/admin) |
| `/api/library/delete/<id>` | POST | Könyv törlése (csak tulajdonos/admin, preferenciákat is törli) |
| `/api/library/toggle/<id>` | POST | Könyv kiválasztásának átkapcsolása (UserBookPreference) |
| `/api/library/fetch-metadata` | POST | Metaadatok keresése OpenLibrary API-n keresztül |

### 4.4. Review (Fordítás-javítás)
| Útvonal | Metódus | Leírás |
|---------|---------|--------|
| `/review/<id>` | GET | Lefordított könyv fejezeteinek böngészése |
| `/api/review/save/<id>` | POST | Szerkesztett fejezet visszaírása az EPUB-ba |

### 4.5. Reference (Mintakönyvek)
| Útvonal | Metódus | Leírás |
|---------|---------|--------|
| `/reference/upload` | POST | Mintakönyv feltöltése |
| `/reference/delete/<id>` | POST | Mintakönyv törlése |

### 4.6. Admin
| Útvonal | Metódus | Leírás |
|---------|---------|--------|
| `/admin` | GET | Admin vezérlőpult (rendszerinfók, modell lista) |
| `/admin/users` | GET | Felhasználók listája |
| `/admin/users/add` | GET/POST | Új felhasználó létrehozása |
| `/admin/users/edit/<id>` | GET/POST | Felhasználó szerkesztése |
| `/admin/users/delete/<id>` | POST | Felhasználó törlése |
| `/admin/logs` | GET | Log fájlok böngészése (translation.log, app.log) |
| `/admin/logs/clear` | POST | Log fájl törlése |
| `/admin/update` | GET | Frissítés ellenőrző oldal |
| `/api/models/list` | GET | Elérhető AI modellek listája |
| `/api/models/pull` | POST | Új modell letöltése |
| `/api/models/switch` | POST | Aktuális modell váltása |
| `/api/update/check` | GET | GitHub frissítés ellenőrzése |
| `/api/update/run` | POST | Frissítés futtatása |
| `/api/system/monitor` | GET | Rendszer erőforrás monitorozás (CPU, RAM, disk) |

---

## 5. Fordítási Folyamat (`translate_epub()`)

```
Feltöltés
  │
  ▼
1. EPUB olvasása (ebooklib)
  │
  ├── Összes ITEM_DOCUMENT (type=9) kigyűjtése
  ├── Eredeti angol szövegek elmentése (original_texts)
  └── Becsült szószám számítás (első 5 dokumentum alapján)
  │
  ▼
2. Kontextus előkészítés
  │
  ├── Glosszárium betöltés (user saját glossary-jéből, max 100 bejegyzés)
  ├── TM cache inicializálás (SHA256 alapú keresés)
  ├── Stílusinstrukció referencia könyvekből (max 3 db, első fejezet)
  ├── Terminológiai lista (kiválasztott könyvtári könyvekből, tulajdonnevek)
  └── Hunspell helyesírás-ellenőrző inicializálás
  │
  ▼
3. ELSŐ MENET (first_pass) – AI fordítás
  │
  ├── Minden text node egyesével fordítva (node-onkénti mód)
  ├── Placeholder-alapú biztonságos csere (__TNPLACEHOLDER_xxx__)
  ├── TM cache találat esetén azonnali visszaadás (__CACHED_xxx__)
  ├── Ollama API: /api/generate, temperature=0.2, num_predict=1024
  ├── Sliding window kontextus: előző fejezet első 300 karaktere
  ├── Few-shot példák + glosszárium + stílus + terminológia
  │
  ├── Progress: 5% → 90% (chapter arányosan)
  └── Glosszárium építés + TM mentés minden sikeres node után
  │
  ▼
4. MÁSODIK MENET (second_pass) – Minőségellenőrzés
  │
  ├── Eredeti szöveg (original_texts) + lefordított szöveg összehasonlítás
  ├── Ollama API: temperature=0.15, num_predict=2048
  ├── Javított szöveg visszaírása (ha változott)
  │
  ├── Progress: 91% → 99%
  └── Minőségi pontszám: 75 + (javítások / összes) * 20
  │
  ▼
5. Post-processing & Mentés
  │
  ├── EPUB írása (epub.write_epub)
  ├── Státusz: completed, progress: 100%
  ├── Email értesítés küldése (Flask-Mail)
  └── Ideiglenes fájl törlése
```

### Ollama konfiguráció
- **Több modell támogatott**: deepseek-r1:1.5b, 7b, 8b, 14b, 32b, 70b
- **Timeout**: None (végtelen) – CPU-only futtatáshoz optimalizálva
- **OLLAMA_KEEP_ALIVE**: 24h (modell memóriában tartása)
- **OLLAMA_NUM_PARALLEL**: 2 (alapértelmezett)
- **API host**: `http://host.docker.internal:11434`

---

## 6. Frontend Template-ek (`backend/templates/`)

| Fájl | Útvonal | Leírás |
|------|---------|--------|
| `base.html` | (minden oldal) | Alap layout: Bootstrap 5.3 dark theme, navbar, flash üzenetek |
| `login.html` | `/login` | Bejelentkezési űrlap |
| `dashboard.html` | `/dashboard` | Vezérlőpult: stat kártyák, EPUB feltöltés, mintakönyvek, könyvtári könyvek kiválasztása, fordítások listája |
| `library.html` | `/library` | Közös könyvtár: drag&drop feltöltés, szűrés, ⭐ kiválasztás, feltöltő neve |
| `review.html` | `/review/<id>` | Fordítás-javító felület: fejezetek böngészése, inline szerkesztés |
| `admin.html` | `/admin` | Admin: rendszerinfók, modellek, modellváltás |
| `users.html` | `/admin/users` | Felhasználók listája |
| `users_form.html` | `/admin/users/add/edit` | Felhasználó űrlap |
| `update.html` | `/admin/update` | Frissítés ellenőrző |
| `logs.html` | `/admin/logs` | Log böngésző |

### JavaScript funkciók a template-ekben
- **dashboard.html**: `toggleBook(bookId, checked)` – könyv kiválasztás API hívás
- **library.html**: `uploadBook()`, `loadBooks()`, `renderBooks()`, `editBook(id)`, `deleteBook(id)`, `toggleBook(id)`, `fetchMetadata()`, `fillMetadata(idx)`
- **update.html**: `checkUpdate()`, `runUpdate()` – frissítés ellenőrzés és telepítés
- **admin.html**: modellváltás gombok (`.switch-model`)

---

## 7. Fájlszerkezet

```
epub-translator/
├── install.sh                    # Telepítő/frissítő script (2300 sor, v11.0.62)
├── uninstall.sh                  # Eltávolító script
├── README.md                     # Felhasználói dokumentáció
├── USER_GUIDE.md                 # Részletes használati útmutató
├── ROADMAP.md                    # Fejlesztési útiterv
├── ARCHITECTURE.md               # Ez a dokumentum
│
├── src/
│   ├── docker-compose.yml        # Konténer definíciók (nginx, backend, postgres, ollama, redis, mailhog)
│   │
│   ├── nginx/
│   │   └── nginx.conf            # Reverse proxy konfiguráció
│   │
│   ├── ollama/
│   │   ├── Dockerfile            # Ollama konténer build
│   │   └── healthcheck.sh       # Ollama health check
│   │
│   └── backend/
│       ├── Dockerfile            # Flask alkalmazás build
│       ├── requirements.txt      # Python függőségek
│       ├── config.py             # Konfigurációs osztály (Config)
│       ├── models.py             # SQLAlchemy adatbázis modellek
│       ├── app.py                # Flask alkalmazás (API végpontok, translate_epub)
│       │
│       ├── utils/
│       │   ├── __init__.py
│       │   ├── model_optimizer.py    # Automatikus modell optimalizáló
│       │   └── resource_monitor.py   # Erőforrás figyelő
│       │
│       └── templates/
│           ├── base.html             # Alap layout
│           ├── login.html            # Bejelentkezés
│           ├── dashboard.html        # Vezérlőpult
│           ├── library.html          # Közös könyvtár
│           ├── review.html           # Fordítás-javító felület
│           ├── admin.html            # Admin főoldal
│           ├── users.html            # Felhasználók listája
│           ├── users_form.html       # Felhasználó űrlap
│           ├── update.html           # Frissítés ellenőrző
│           └── logs.html             # Log böngésző
│
└── scripts/
    ├── backup.sh                 # Adatbázis mentés
    ├── update.sh                 # Frissítési script
    ├── status.sh                 # Állapot ellenőrzés
    ├── monitor.sh                # Erőforrás monitorozás
    └── optimize.sh               # Optimalizálás futtatása
```

---

## 8. Konfiguráció (`backend/config.py`)

A `Config` osztály környezeti változókból olvassa a beállításokat (`.env` fájl):

| Változó | Alapérték | Leírás |
|---------|-----------|--------|
| `VERSION` | 11.0.41 | Alkalmazás verzió |
| `SECRET_KEY` | (generált) | Flask session titkosítás |
| `SQLALCHEMY_DATABASE_URI` | postgresql://... | Adatbázis kapcsolat |
| `OLLAMA_HOST` | host.docker.internal:11434 | Ollama API cím |
| `DEFAULT_MODEL` (SELECTED_MODEL) | deepseek-r1:14b | Aktuális AI modell |
| `MAX_WORKERS` | 3 | Párhuzamos fordítási szálak |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | (konfigurálható) | Admin belépés |
| `ENABLE_AUTO_OPTIMIZE` | i | Automatikus modell optimalizálás |
| `ENABLE_RESOURCE_MONITOR` | i | Erőforrás figyelés |
| `OPTIMAL_MEMORY_LIMIT` | 24G | Ollama konténer memória limit |

### Könyvtárak (konténeren belül)
| Útvonal | Tartalom |
|---------|----------|
| `/app/uploads/books/` | Feltöltött EPUB-ok (ideiglenes) |
| `/app/uploads/library/` | Könyvtári EPUB-ok (tartós) |
| `/app/uploads/reference/` | Mintakönyvek |
| `/app/output/` | Lefordított EPUB-ok |
| `/app/logs/` | app.log, translation.log |

---

## 9. Telepítési Folyamat (`install.sh`)

1. **Telepítési mód észlelése**: friss vs. frissítés
2. **Rendszer analízis**: RAM, CPU, lemez automatikus detektálása
3. **Modell ajánlás**: hardver alapján (8GB→7b, 16GB→8b, 32GB→14b, 40GB→32b)
4. **Konfigurációs varázsló**: admin email/jelszó, modell, szálak, funkciók
5. **Függőségek**: Docker, Python, rendszercsomagok
6. **Konténerek építése és indítása**: `docker compose up -d`
7. **Modell letöltése**: háttérben (`ollama pull`)
8. **Adatbázis inicializálás**: `db.create_all()` + admin felhasználó
9. **Cron jobok**: backup, monitor, cleanup

### Frissítési folyamat
1. Adatbázis mentés (pg_dump)
2. Konténerek leállítása
3. Git fetch/pull
4. Fájlok újramásolása (src/ könyvtárból)
5. Újraépítés (`--no-cache` a backend-re)
6. Indítás + migráció

---

## 10. Adatfolyamok

### Feltöltés → Fordítás
```
Böngésző ──POST /upload──▶ Backend ──INSERT Translation──▶ PostgreSQL
                              │
                              ├── Token -1 (User)
                              ├── UserBookPreference.is_selected = False
                              └── Thread: translate_epub(app, translation_id, filepath, context_files)
                                    │
                                    ├── EPUB olvasás (ebooklib)
                                    ├── Minden chapter: Ollama API hívás
                                    ├── Glosszárium + TM mentés
                                    ├── Minőségellenőrzés (második menet)
                                    ├── EPUB mentés (/app/output/)
                                    └── Email értesítés (MailHog)
```

### Könyvtár használata
```
Felhasználó A ──▶ feltölt EPUB-t ──▶ Book (user_id=A)
                                     └── Deduplikáció: cím+szerző ellenőrzés

Felhasználó B ──▶ library_list() ──▶ látja A könyvét is
                ──▶ toggle(id)   ──▶ UserBookPreference(user_id=B, book_id=id, is_selected=True)
                ──▶ upload EPUB  ──▶ Fordítás B felhasználó kiválasztott könyveivel mint kontextus
```

---

## 11. Biztonság

- **Jelszavak**: Werkzeug `generate_password_hash` / `check_password_hash` (SHA256)
- **Session**: Flask-Login (titkosított cookie)
- **Rate limiting**: Flask-Limiter (5000/nap, 2000/óra)
- **Jogosultságok**: `admin_required` dekorátor admin végpontokhoz
- **Könyvtár**: szerkesztés/törlés csak `user_id == current_user.id` vagy `is_admin`
- **Fordítások**: más felhasználó fordításai nem érhetők el (user_id ellenőrzés)

---

## 12. Fejlesztési Megjegyzések

### Adatbázis migráció v11.0.58 → v11.0.62
```sql
-- A db.create_all() automatikusan létrehozza az új táblát
-- Régi mező manuális törlése (opcionális):
ALTER TABLE books DROP COLUMN IF EXISTS is_selected;
```

### Új modell hozzáadásának lépései
1. `models.py` – osztály definiálása
2. `app.py` – import sor bővítése
3. API végpontok implementálása
4. Template frissítése (ha szükséges)
5. `db.create_all()` automatikusan létrehozza a táblát

### Kontextus visszaállítás Cline számára
Ha a Cline kontextus ablaka kiürül, ezeket a fájlokat olvasd be sorrendben:
1. `ARCHITECTURE.md` (ez a fájl) – átfogó kép
2. `backend/models.py` – adatbázis struktúra (125 sor)
3. `backend/app.py` – API és fordítási logika (1269 sor)
4. `ROADMAP.md` – fejlesztési útiterv

---

*Ez a dokumentum a projekttel együtt frissítendő. Utolsó módosítás: 2026-07-17 (v11.0.67)*