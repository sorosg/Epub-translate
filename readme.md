# EPUB Fordító Rendszer v11.0

## 🧠 "Smart Optimizer" - Intelligens Optimalizáló

![Version](https://img.shields.io/badge/version-11.0.71-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-ready-brightgreen)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04+-orange)

---

## 🎯 Rendszer Áttekintés

Az EPUB Fordító Rendszer egy **teljesen ingyenes, helyben futó, öntanuló** megoldás EPUB könyvek fordítására angolról magyarra. A DeepSeek R1 AI modelleket használja az Ollama platformon keresztül, amelyek a saját gépeden futnak – **nincs szükség API kulcsra, internetkapcsolatra (a modell letöltése után), vagy előfizetésre!**

### Tervezési alapelvek

1. **Minőség a sebesség felett** – a rendszer kétmenetes fordítást végez (AI fordítás + minőségellenőrzés), a pontosság érdekében akár napokig is dolgozhat egy könyvön
2. **GPU nélkül is működik** – a hardver követelmények a RAM-ot veszik alapul a modell kiválasztásához, erős videókártya nem szükséges
3. **Közös könyvtár** – a feltöltött könyvekből deduplikált adatbázis épül, ami kontextusként szolgál a fordításokhoz
4. **Öntanuló** – glosszárium, fordítási memória és stílusminták automatikusan épülnek

### 🌟 Legfontosabb Jellemzők

- ✅ **100% Ingyenes** – Nincs rejtett költség, előfizetés vagy API díj
- ✅ **Helyben Fut** – Minden adat a saját gépeden marad
- ✅ **Kétmenetes fordítás** – AI fordítás + minőségellenőrzés a jobb minőségért
- ✅ **Közös könyvtár** – Minden felhasználó látja az összes feltöltött könyvet (deduplikációval)
- ✅ **Batch könyvtár feltöltés** – Több száz EPUB egyidejű behúzása, automatikus metaadat kinyerés
- ✅ **Interaktív review** – Lefordított fejezetek böngészése és inline szerkesztése
- ✅ **Email értesítések** – MailHog SMTP szerver a fordítás befejezésekor
- ✅ **Sötét/világos téma** – Felhasználónként mentett preferencia
- ✅ **Mobilbarát felület** – Sidebar navigáció, lebegő hamburger menü, alsó navigációs sáv
- ✅ **PWA támogatás** – Telepíthető webalkalmazás, offline cache
- ✅ **Önfrissítő** – GitHub frissítések ellenőrzése és telepítése
- ✅ **Hardver alapú modell ajánlás** – RAM mérettől függően

---

## ⏱️ Fordítási Idő Becslések (CPU-only, GPU nélkül)

A rendszer **kétmenetes fordítást** végez (első menet: AI fordítás, második menet: minőségellenőrzés), ami megnöveli a feldolgozási időt, de jelentősen javítja a minőséget. A sebesség elsősorban a CPU teljesítményétől és a választott modelltől függ.

### Átlagos fordítási idők egy 80 000 szavas könyvre

| Modell | CPU (i3 8. gen, 4 mag) | CPU (i7/Ryzen 7, 8+ mag) | Minőség |
|--------|------------------------|--------------------------|---------|
| deepseek-r1:7b | 1–2 nap | 12–24 óra | ⭐⭐⭐ |
| deepseek-r1:8b | 1,5–3 nap | 18–36 óra | ⭐⭐⭐ |
| deepseek-r1:14b | **2,5–4 nap** | 1,5–2,5 nap | ⭐⭐⭐⭐ |
| deepseek-r1:32b | 5–10 nap | 3–6 nap | ⭐⭐⭐⭐⭐ |

### Miért ilyen hosszú?

- **CPU-only futtatás**: GPU nélkül a deepseek-r1:14b ~1–3 tokent generál másodpercenként
- **Kétmenetes**: minden szövegrészt kétszer dolgoz fel (fordítás + ellenőrzés), ~6 000–10 000 API hívás könyvenként
- **Node-onkénti fordítás**: a megbízhatóság érdekében minden text node egyesével kerül fordításra (nem batch-ben)
- Szövegrészenként 15–45 másodperc feldolgozási idő a szöveghossztól függően

### Gyorsító tényezők

- **TM cache (Translation Memory)**: a már lefordított mondatokat SHA256 hash alapján azonnal visszaadja – második könyvtől jelentős gyorsulás
- **Glosszárium**: automatikusan épülő angol→magyar szópárak, terminológiai következetesség
- **Minél több könyvet fordítasz, a cache annál hatékonyabb** – a rendszer tanul a korábbi fordításokból

### Hardver ajánlás referencia időkkel

| Processzor | RAM | Ajánlott modell | Várható idő (80K szó) |
|-----------|-----|----------------|----------------------|
| i3 8. gen (4 mag) | 16 GB | 8b | 1,5–3 nap |
| i3 8. gen (4 mag) | 40 GB | **14b** ★ | **2,5–4 nap** |
| i7/Ryzen 7 (8+ mag) | 32 GB | 14b | 1,5–2,5 nap |
| i7/Ryzen 7 (8+ mag) | 64 GB | 32b | 3–6 nap |

> **Megjegyzés**: Az időbecslések tájékoztató jellegűek és erősen függenek a könyv szövegsűrűségétől, a fejezetek számától és a CPU egyéb terheltségétől. A rendszer a **minőséget helyezi előtérbe a sebességgel szemben**.

---

## 💻 Rendszerkövetelmények

### Hardver

| Komponens | Minimum | Ajánlott | Optimális (14b) | Maximális (32b) |
|-----------|---------|----------|-----------------|-----------------|
| **RAM** | 16 GB | 32 GB | 32 GB | 64 GB |
| **CPU** | 4 mag, 2.5 GHz | 8+ mag, 3.0+ GHz | 8 mag | 16 mag |
| **Tárhely** | 50 GB | 100+ GB SSD | 100 GB SSD | 200 GB SSD |
| **GPU** | Nem szükséges | NVIDIA (opcionális) | - | - |

### Szoftver

- **Operációs Rendszer:** Ubuntu 22.04 LTS vagy újabb (64 bit)
- **Docker:** 24.0+
- **Docker Compose:** 2.20+

### Automatikus Modell Ajánlás (RAM alapú, GPU nélkül)

| RAM | Ajánlott Modell | Minőség | Sebesség |
|-----|----------------|---------|----------|
| 8 GB | `deepseek-r1:1.5b` | ⭐⭐ | ⚡⚡⚡⚡⚡ |
| 16 GB | `deepseek-r1:7b` | ⭐⭐⭐ | ⚡⚡⚡⚡ |
| 32 GB | `deepseek-r1:14b` ★ | ⭐⭐⭐⭐ | ⚡⚡⚡ |
| 40 GB | `deepseek-r1:32b` | ⭐⭐⭐⭐⭐ | ⚡⚡ |
| 64 GB | `deepseek-r1:32b` | ⭐⭐⭐⭐⭐ | ⚡⚡ |

---

## 🚀 Gyors Telepítés

### Egy paranccsal (ajánlott):

```bash
curl -sSL https://raw.githubusercontent.com/sorosg/Epub-translate/main/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

> **Fontos:** Mindenképpen az egész sort másold ki, a `&&` jelekkel együtt! Ha a `curl ... | bash` parancs nem működik (csak kiírja a fájl tartalmát), használd a fenti sort.

### Vagy lépésről lépésre:

```bash
# 1. Töltsd le a telepítőt
wget https://raw.githubusercontent.com/sorosg/Epub-translate/main/install.sh

# 2. Tedd futtathatóvá
chmod +x install.sh

# 3. Indítsd el
bash install.sh
```

### Telepítés után

```bash
# Webes felület
http://localhost

# Email felület (MailHog)
http://localhost:8025

# Admin belépés
Email: admin@epub-translator.local
Jelszó: Abrakadabra (változtasd meg!)
```

---

## 🔄 Frissítés Meglévő Telepítésről

### Frissítés a Programból

1. Admin → Frissítés Kezelés
2. "Frissítések ellenőrzése"
3. "Telepítés"

### Frissítés Parancssorból

```bash
# Telepítő script
./install.sh
# Válaszd: 1) Frissítés

# VAGY gyorsfrissítő
./scripts/update.sh
```

---

## 🆕 Funkciók

### Fordítási funkciók
- **Kétmenetes fordítás**: AI fordítás + minőségellenőrzés és javítás
- **Glosszárium építés**: automatikus angol→magyar szópár kinyerés
- **Fordítási memória (TM cache)**: SHA256 alapú gyorsítótárazás
- **Hunspell helyesírás-ellenőrzés**: magyar nyelvi validáció (v11.0.62: libhunspell-dev build fix)
- **Stílusinstrukció**: referencia (minta) könyvekből
- **Terminológiai lista**: kiválasztott könyvtári könyvekből

### Könyvtár funkciók
- **Közös könyvtár**: minden felhasználó látja az összes feltöltött könyvet
- **Deduplikáció**: cím+szerző alapú ellenőrzés feltöltéskor
- **Felhasználónkénti kiválasztás**: mindenki saját maga jelölhet ki kontextus könyveket
- **Jogosultságkezelés**: szerkesztés/törlés csak a feltöltő vagy admin számára

### Felhasználói funkciók
- **Interaktív review felület**: lefordított fejezetek böngészése és inline szerkesztése
- **Email értesítések**: fordítás befejezésekor (MailHog)
- **Admin felület**: rendszerfigyelés, felhasználókezelés, modellváltás
- **Részletes progressz követés**: fejezet, szószám, node szintű visszajelzés

### Rendszer funkciók
- **Hardver alapú optimalizálás**: RAM, CPU detektálás, auto-konfiguráció
- **Önfrissítő**: GitHub API alapú verzióellenőrzés és frissítés
- **DNS konfiguráció**: backend konténer külső DNS feloldása a frissítésellenőrzéshez

---

## 🏗️ Architektúra

```
Böngésző (http://localhost:80)
        │
        ▼
┌───────────────────┐
│  Nginx (80/443)   │  Reverse Proxy + Statikus fájlok
└───────┬───────────┘
        │
        ▼
┌───────────────────┐     ┌──────────────┐
│  Flask Backend    │────▶│  PostgreSQL   │
│  (Gunicorn :5000) │     │  (Adatbázis)  │
└───────┬───────────┘     └──────────────┘
        │
        │ HTTP API hívások
        ▼
┌───────────────────┐     ┌──────────────┐     ┌──────────────┐
│  Ollama (CPU)     │     │  Redis       │     │  MailHog     │
│  deepseek-r1:14b  │     │  (Cache)     │     │  (SMTP:1025) │
│  ollama:11434     │     │              │     │  (Web:8025)  │
└───────────────────┘     └──────────────┘     └──────────────┘
```

Minden komponens Docker konténerben fut, a `translator-network` bridge hálózaton keresztül kommunikálnak.

---

## 🤖 Modell Konfigurációk

### deepseek-r1:14b (Ajánlott 32-40GB RAM-hoz) ★

```
Teljesítmény:
  Sebesség: 2,5–4 nap/könyv (i3 8. gen CPU-n)
  Minőség: ⭐⭐⭐⭐ (85-92%)
  RAM: 18-22 GB

Optimalizálás:
  memory_limit: 24G, max_workers: 3
  batch_size: 5, num_parallel: 2

Ajánlott:
  - Irodalmi művekhez, fontos fordításokhoz
  - 50 000 szó feletti könyvekhez
  - Jó egyensúly minőség és sebesség között
```

---

## 🔧 Karbantartás

```bash
# Státusz ellenőrzése
./scripts/status.sh

# Biztonsági mentés
./scripts/backup.sh

# Frissítés
./scripts/update.sh

# Monitor napló
tail -f logs/resource_monitor.log
```

### Modell Karbantartás

```bash
# Telepített modellek listázása
docker exec -it epub-ollama ollama list

# Új modell letöltése
docker exec -it epub-ollama ollama pull deepseek-r1:14b
```

---

## 📊 Verzió Történet

### v11.0.71 (2026-08-11) – "Smart Optimizer"
- 🤖 **DeepSeek Pro multi-model**: `deepseek-chat` (V3) és `deepseek-reasoner` (R1) választható távoli modellként, API kulcs kezelés a dashboardon
- 📊 **Progress bar live updates**: JavaScript DOM polling a fordítási kártyákon, becsült hátralévő idő kijelzéssel
- 📝 **Könyvtár szerkesztő modal**: Bootstrap modal dialog (`editBook`) a korábbi 6 db `prompt()` helyett – cím, szerző, műfaj, sorozat, nyelv mezők + opcionális EPUB fájlcsere
- 📁 **CSS/JS separáció**: `static/css/main.css` és `static/js/main.js` kiszervezve a `base.html`-ből, tisztább kódstruktúra
- 📸 **Snapshot script**: `scripts/snapshot.sh` – git commit + tag pillanatképek készítése, `git checkout tags/snapshot-xxx` visszatérés
- 📜 **Továbbfejlesztett logolás**: stdout StreamHandler a Docker `logs` parancs láthatóságához, `/api/events` fordítási esemény végpont
- 🐛 **Hibajavítások**: deepseek-reasoner temperature paraméter (nem támogatott), model_source perzisztencia feltöltés→fordítás között, psycopg2-binary visszaállítás Linux kompatibilitáshoz

### v11.0.70 (2026-08-10)
- 🔤 **Szélesebb sliding window**: előző fejezet 800 karakter + következő fejezet 500 karakter
- 📚 **Batch könyvtár feltöltés**: több száz EPUB egyidejű behúzása, automatikus metaadat kinyerés (cím, szerző, műfaj, sorozat)
- 🎨 **Sötét/világos téma váltó**: felhasználónként mentve, CSS változók, GitHub-szerű világos dizájn
- 📱 **Mobil optimalizálás**: sidebar navigáció, lebegő hamburger menü, alsó navigációs sáv
- ⚡ **Dashboard élő frissítés**: 10 másodperces polling a fordítási állapotokhoz
- 🖼️ **Könyvtár kártyás nézet**: táblázat ↔ kártya váltó gomb
- 👤 **Profil oldal**: saját adatok szerkesztése, API kulcs kezelés, jelszó változtatás
- 🔑 **API kulcs kezelés**: DeepSeek Pro API kulcs státusz és szerkesztő a dashboardon
- 📦 **PWA támogatás**: manifest.json, service worker, SVG ikonok, offline cache
- 🐛 **Hibajavítások**: users/dark_mode oszlop migráció, MailHog profiles, Ollama modell letöltés várakozás

### v11.0.62 (2026-07-19)
- 🔧 **Hunspell build javítás**: `libhunspell-dev` hozzáadva a Dockerfile-hoz, a `pip install hunspell` fordítási hiba javítva

### v11.0.61 (2026-07-17)
- 🔄 **Perzisztens modellváltás**: .env fájl frissítése, konténer újraindítás után is megmarad
- ✅ **Modell elérhetőség ellenőrzés**: váltás előtti Ollama /api/tags ellenőrzés, hiányzó modell auto-pull
- ⏳ **Folyamatjelző az admin felületen**: spinner, státusz visszajelzés a modellváltáskor
- 🔧 **OLLAMA_HOST**: config.py most környezeti változóból olvas

### v11.0.60 (2026-07-17)
- 🔧 **DNS javítás**: backend konténer külső DNS feloldása a frissítésellenőrzéshez
- 📖 **README.md frissítve**: fordítási idő becslések CPU-only hardverre

### v11.0.59 (2026-07-17)
- 📚 **Közös könyvtár**: minden felhasználó látja az összes feltöltött könyvet
- 🚫 **Deduplikáció**: cím+szerző alapú ellenőrzés feltöltéskor
- 👤 **UserBookPreference**: felhasználónkénti könyvbeállítások (kontextus kiválasztás)

### v11.0.56 (2026-07-16)
- 📝 **Interaktív review felület**: lefordított fejezetek böngészése és inline szerkesztése
- 📧 **Email értesítések**: fordítás befejezésekor (MailHog)

### v11.0.51 (2026-07-16)
- ✅ **Kétmenetes fordítás**: első menet AI fordítás + második menet minőségellenőrzés

### v11.0.50 (2026-07-16)
- 📖 **Glosszárium építés**: automatikus angol→magyar szópár kinyerés
- 💾 **Fordítási memória**: TM cache a konzisztens fordításokhoz
- 🔤 **Hunspell**: magyar helyesírás-ellenőrzés

### v11.0.27 (2026-07-16) - "Smart Optimizer"
- 🆕 Intelligens modell optimalizáló, erőforrás monitor, smart modellváltás

---

## 📞 Támogatás

- 📧 Email: sorosgergo@gmail.com
- 🌐 GitHub: https://github.com/sorosg/Epub-translate
- 🐛 Hibajelentés: https://github.com/sorosg/Epub-translate/issues

---

## 🛠️ Fejlesztői útmutató

### ⚡ Folytatás új ablakban (CTRL+N, másold be az egészet)

```bash
# === EPUB FORDÍTÓ FEJLESZTŐI KÖRNYEZET GYORSINDÍTÁS ===
# Másold be ezt az egész blokkot egy új TERMINÁL ablakba (CMD+T)!

cd ~/Desktop/Epub-translate

# Virtualenv létrehozása és aktiválás (ha még nincs)
cd src/backend
if [ ! -d venv ]; then python3 -m venv venv; fi
source venv/bin/activate

# Függőségek telepítése (látható hibákkal)
pip install -r requirements.txt

# Környezeti változók
export DATABASE_URL=postgresql://epub_user:epub_password@localhost:5432/epub_translator
export OLLAMA_HOST=http://localhost:11434
export SECRET_KEY=dev-secret-key
export VERSION=11.0.71

# Adatbázis inicializálás
python3 -c "from app import app, init_db; app.app_context().push(); init_db(); print('✅ DB OK')"

echo ""
echo "🌐 Backend: http://localhost:5000"
echo "👤 Admin: admin@epub-translator.local / Abrakadabra"
echo "📁 Projekt: ~/Desktop/Epub-translate"
echo ""

python3 app.py
```

### Fájlok pontos elérési útja (macOS)

| Fájl | Teljes elérési út | Leírás |
|------|-------------------|--------|
| **Projekt gyökér** | `~/Desktop/Epub-translate/` | A projekt főkönyvtára |
| **Telepítő** | `~/Desktop/Epub-translate/install.sh` | Telepítő/frissítő script |
| **Flask backend** | `~/Desktop/Epub-translate/src/backend/app.py` | API végpontok, fordítási logika |
| **Adatbázis modellek** | `~/Desktop/Epub-translate/src/backend/models.py` | User, Translation, Book, stb. |
| **Konfiguráció** | `~/Desktop/Epub-translate/src/backend/config.py` | Környezeti változók, VERSION |
| **Base layout** | `~/Desktop/Epub-translate/src/backend/templates/base.html` | Sidebar, téma váltó, PWA, CSS |
| **Dashboard** | `~/Desktop/Epub-translate/src/backend/templates/dashboard.html` | Vezérlőpult, könyvajánló |
| **Könyvtár** | `~/Desktop/Epub-translate/src/backend/templates/library.html` | Batch feltöltő, kártya/táblázat |
| **Profil** | `~/Desktop/Epub-translate/src/backend/templates/profile.html` | Felhasználói profil szerkesztő |
| **Felhasználók** | `~/Desktop/Epub-translate/src/backend/templates/users.html` | Admin felhasználókezelő |
| **Docker Compose** | `~/Desktop/Epub-translate/src/docker-compose.yml` | Konténer definíciók |
| **Nginx config** | `~/Desktop/Epub-translate/src/nginx/nginx.conf` | Reverse proxy |
| **Dokumentáció** | `~/Desktop/Epub-translate/README.md` | Ez a fájl |
| **Fejlesztési útiterv** | `~/Desktop/Epub-translate/ROADMAP.md` | Kész/tervezett fejlesztések |

### Fejlesztői mód (részletesen)

```bash
# 1. Repó klónozása (ha még nincs meg)
git clone https://github.com/sorosg/Epub-translate.git ~/Desktop/Epub-translate
cd ~/Desktop/Epub-translate

# 2. Backend indítása (Python virtualenv)
cd src/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 3. Környezeti változók
export DATABASE_URL=postgresql://epub_user:epub_password@localhost:5432/epub_translator
export OLLAMA_HOST=http://localhost:11434
export SECRET_KEY=dev-secret-key
export VERSION=11.0.71

# 4. Adatbázis inicializálás (Docker-ben futó PostgreSQL-hez)
python3 -c "from app import app, init_db; app.app_context().push(); init_db(); print('OK')"

# 5. Flask szerver indítása
python3 app.py
# Web: http://localhost:5000
# Admin: admin@epub-translator.local / Abrakadabra
```

### Projekt struktúra (főbb fájlok)

| Fájl | Leírás |
|------|--------|
| `install.sh` | **Telepítő/frissítő script** – ez generálja a telepítést. Ha módosítasz bármilyen forrásfájlt, a telepítőt is frissíteni kell (a `_create_files_from_script()` függvényben a heredoc-ok) |
| `src/backend/app.py` | **Flask backend** – API végpontok, fordítási logika (`translate_epub`), `init_db()` |
| `src/backend/models.py` | **Adatbázis modellek** – User, Translation, Book, GlossaryEntry, TranslationMemory, UserBookPreference |
| `src/backend/config.py` | **Konfiguráció** – VERSION, környezeti változók, alapértelmezések |
| `src/backend/templates/` | **HTML template-ek** – Jinja2 alapú, Bootstrap 5.3 + Inter font |
| `src/backend/templates/base.html` | **Alap layout** – sidebar, téma váltó, PWA meta tagek, responsive CSS |
| `src/backend/templates/dashboard.html` | **Vezérlőpult** – fordítások listája, élő frissítés, EPUB feltöltés, könyvajánló |
| `src/backend/templates/library.html` | **Könyvtár** – batch feltöltő (drag & drop), kártya/táblázat nézet, szűrők |
| `src/docker-compose.yml` | **Docker szolgáltatások** – nginx, backend, postgres, ollama, redis, mailhog |
| `src/nginx/nginx.conf` | **Nginx konfiguráció** – reverse proxy, statikus fájlok |
| `src/ollama/` | **Ollama konténer** – Dockerfile + healthcheck.sh |
| `ROADMAP.md` | **Fejlesztési útiterv** – kész, folyamatban lévő és tervezett fejlesztések |
| `README.md` | **Felhasználói dokumentáció** – ez a fájl |

### Fejlesztési munkafolyamat

1. **Forráskód módosítása** – a `src/` könyvtárban dolgozz
2. **Tesztelés** – futtasd a Flask szervert közvetlenül (`python3 app.py`)
3. **Verziószám növelése** – minden módosítás után:
   - `install.sh`: `VERSION="x.y.z"`
   - `src/backend/config.py`: `VERSION = os.environ.get('VERSION', 'x.y.z')`
   - `README.md`: badge + lábléc
   - `ROADMAP.md`: verzió és státusz frissítése
4. **Commit és push** – `git add -A && git commit -m "vX.Y.Z: leírás" && git push origin main`
5. **Telepítő frissítése** – ha új fájlokat adtál hozzá, ellenőrizd, hogy az `install.sh` `create_all_files()` függvénye másolja-e őket

### Fontos tudnivalók

- **A telepítő (install.sh) `_create_files_from_script()` függvénye** tartalmazza a fájlok heredoc generálását – ha új Python/HTML fájlt adsz hozzá, itt is fel kell venni!
- **Az install.sh mostantól git clone-t használ**, ha a `src/` mappa nem elérhető (wget-tel letöltve). A heredoc generálás csak fallback.
- **A `cp` parancsoknál nincs `2>/dev/null`** – ha egy fájl nem másolódik, a telepítő hibával leáll
- **A `set -euo pipefail` aktív** – minden hiba azonnali kilépést okoz
- **Mobil nézet**: a sidebar 1024px alatt elrejtve, lebegő hamburger gomb + alsó navigációs sáv
- **Téma váltó**: `User.dark_mode` mező az adatbázisban, CSS változók (`data-bs-theme`)

### Pillanatképek (snapshot) – biztonsági mentés működő állapotról

Amikor egy funkció működik, **készíts pillanatképet** – így ha később elromlik, egy paranccsal vissza tudsz térni:

```bash
# 🟢 MŰKÖDIK – mentsd el!
bash scripts/snapshot.sh "sliding-window-kesz"

# Több óra fejlesztés után elromlik valami...
# 🔴 VISSZATÉRÉS az előző működő verzióhoz:
git checkout tags/snapshot-sliding-window-kesz

# Pillanatképek listája:
git tag -l 'snapshot-*'

# Visszatérés a friss verzióra:
git checkout main
```

A snapshot automatikusan commit-ol és tag-et készít. A tag alapján `git checkout tags/snapshot-xxx` paranccsal bármikor visszaállítható a projekt.

### Git parancsok gyorsreferencia

| Parancs | Leírás |
|---------|--------|
| `git log --oneline -5` | Utolsó 5 commit |
| `git diff` | Módosítások megtekintése commit előtt |
| `git stash` | Módosítások ideiglenes elmentése |
| `git stash pop` | Elmentett módosítások visszaállítása |
| `git reset --hard HEAD~1` | Utolsó commit törlése (ha még nincs push-olva) |
| `bash scripts/snapshot.sh "név"` | Pillanatkép készítése |

### Gyakori hibák és megoldások

| Hiba | Ok | Megoldás |
|------|----|---------|
| `SECRET_KEY: unbound variable` | A változó nincs definiálva a `create_env_file()` előtt | `SECRET_KEY` generálás a függvény elején |
| `address already in use` (80-as port) | Host webszerver foglalja a portot | `systemctl mask nginx/apache2` + automatikus 8080-ra váltás |
| `Minimum memory limit` | `reservations.memory` > `limits.memory` | `reservations` törölve a docker-compose.yml-ből |
| 500 Internal Server Error | Hiányzó adatbázis oszlop | `init_db()` ALTER TABLE ADD COLUMN IF NOT EXISTS |
| TemplateNotFound | Új template fájl nincs az install.sh-ban | Hozzáadni a `create_all_files()` cp parancsaihoz |

---

Készült ❤️-vel Magyarországon – v11.0.71
