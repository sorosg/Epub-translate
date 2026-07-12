EPUB Fordító Rendszer v5.0

📚 Intelligens Könyvfordító Adatbázissal és Öntanuló Rendszerrel

https://img.shields.io/badge/version-5.0.0-blue
https://img.shields.io/badge/license-MIT-green
https://img.shields.io/badge/docker-ready-brightgreen
https://img.shields.io/badge/platform-Ubuntu%2022.04+-orange

---

🎯 Rendszer Áttekintés

Az EPUB Fordító Rendszer egy teljesen ingyenes, helyben futó megoldás EPUB könyvek fordítására. A DeepSeek AI modelleket használja, amelyek a saját gépeden futnak - nincs szükség API kulcsra, internetkapcsolatra (a modell letöltése után), vagy előfizetésre!

🌟 Legfontosabb Jellemzők

· ✅ 100% Ingyenes - Nincs rejtett költség, előfizetés vagy API díj
· ✅ Helyben Fut - Minden adat a saját gépeden marad
· ✅ Offline Működés - Internet csak a modell első letöltéséhez kell
· ✅ Intelligens - Minél többet használod, annál jobb lesz
· ✅ Biztonságos - Vírusellenőrzés, 2FA, rate limiting
· ✅ Öntanuló - A fordítási eredmények alapján folyamatosan fejlődik

---

📋 Tartalomjegyzék

1. Rendszerkövetelmények
2. Gyors Telepítés
3. Újdonságok a v5.0-ban
4. Architektúra
5. Konfiguráció
6. Használat
7. Könyv Adatbázis
8. Mintakönyv Rendszer
9. Email Beállítások
10. Admin Felület
11. API Dokumentáció
12. Karbantartás
13. Hibaelhárítás
14. GYIK

---

💻 Rendszerkövetelmények

Hardver

Komponens Minimum Ajánlott
RAM 16 GB 32 GB
CPU 4 mag, 2.5 GHz 8+ mag, 3.0+ GHz
Tárhely 50 GB 100+ GB SSD
GPU Nem szükséges NVIDIA (opcionális)

Szoftver

· Operációs Rendszer: Ubuntu 22.04 LTS vagy újabb (64 bit)
· Docker: 24.0+
· Docker Compose: 2.20+

DeepSeek Modellek Mérete

Modell Méret RAM Igény Sebesség Minőség
deepseek-r1:1.5b 1.5 GB 8 GB ⚡⚡⚡⚡⚡ ⭐⭐
deepseek-r1:7b 7 GB 16 GB ⚡⚡⚡⚡ ⭐⭐⭐
deepseek-r1:8b 8 GB 32 GB ⚡⚡⚡ ⭐⭐⭐⭐
deepseek-r1:14b 14 GB 32 GB ⚡⚡ ⭐⭐⭐⭐
deepseek-r1:32b 32 GB 64 GB ⚡ ⭐⭐⭐⭐⭐
deepseek-r1:70b 70 GB 128 GB 🐌 ⭐⭐⭐⭐⭐

---

🚀 Gyors Telepítés

Egy paranccsal:

```bash
curl -sSL https://raw.githubusercontent.com/sorosg/Epub-translate/main/install.sh | bash
```

Vagy lépésről lépésre:

```bash
# 1. Töltsd le a telepítőt
wget https://raw.githubusercontent.com/sorosg/Epub-translate/main/install.sh

# 2. Tedd futtathatóvá
chmod +x install.sh

# 3. Indítsd el a telepítő varázslót
./install.sh
```

Telepítés Után

```bash
# Ellenőrizd a szolgáltatásokat
docker compose ps

# Nyisd meg a webes felületet
# http://localhost

# Email felület (ha MailHog van)
# http://localhost:8025

# Admin belépés
# Email: admin@epub-translator.local
# Jelszó: Abrakadabra (változtasd meg!)
```

---

🆕 Újdonságok a v5.0-ban

📚 Könyv Adatbázis

· Automatikus metaadat kinyerés EPUB fájlokból
· Online keresés Google Books és OpenLibrary adatbázisokban
· AI alapú műfaj felismerés - 15+ műfaj automatikus észlelése
· Stílus elemzés - Irodalmi, egyszerű, technikai stílusok felismerése
· Duplikátum szűrés - SHA-256 hash alapján
· Borítókép kinyerés és tárolás

🧠 Intelligens Mintakönyv Kezelés

· Automatikus ajánlás a célkönyv műfaja és stílusa alapján
· Egyezési pontszám számítás (műfaj, stílus, komplexitás)
· Kontextus tanulás - A sikeres fordítások növelik a könyv súlyát
· Diverz választás - Különböző műfajokból választ mintát
· Használati statisztikák - Melyik mintakönyvek működnek legjobban

🔍 Több Forrásból Származó Metaadatok

· EPUB belső metaadatok (automatikus)
· Google Books API (online)
· OpenLibrary API (online)
· Helyi AI elemzés (offline)
· Felhasználói szerkesztés (manuális)

📊 Továbbfejlesztett Statisztikák

· Könyv statisztikák - Szavak, fejezetek, komplexitás
· Fordítási minőség műfajonként
· Mintakönyv hatékonyság mérése
· Rendszerhasználati riportok

---

🏗️ Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│                     Felhasználói Böngésző                      │
│                    http://localhost:80                        │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                         Nginx (80/443)                        │
│                    Reverse Proxy & Static Files              │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                    Flask Backend (5000)                       │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Fordítás     │  │ Könyv DB      │  │ Felhasználó      │   │
│  │ Kezelő       │  │ & Metaadatok  │  │ Kezelés          │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Email        │  │ API           │  │ Statisztikák     │   │
│  │ Szolgáltatás │  │ Végpontok     │  │ & Monitoring     │   │
│  └─────────────┘  └──────────────┘  └──────────────────┘   │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼──────┐   ┌────────▼────────┐   ┌─────▼──────┐
│  PostgreSQL  │   │     Ollama       │   │   Redis    │
│  Adatbázis   │   │  DeepSeek AI    │   │   Cache    │
└──────────────┘   └─────────────────┘   └────────────┘

┌──────────────┐   ┌─────────────────┐
│   MailHog    │   │  Postfix Relay  │
│ Helyi Email  │   │ Külső Email     │
└──────────────┘   └─────────────────┘
```

Szolgáltatások

Szolgáltatás Port Leírás
Nginx 80, 443 Web szerver és reverse proxy
Backend 5000 Flask alkalmazás (belső)
PostgreSQL 5432 Adatbázis (belső)
Ollama 11434 AI modell szerver (belső)
Redis 6379 Cache (belső)
MailHog 1025, 8025 Helyi email szerver és UI

---

⚙️ Konfiguráció

Környezeti Változók (.env)

```env
# Alkalmazás
SECRET_KEY=your-secret-key
FLASK_ENV=production
VERSION=5.0.0

# Admin
ADMIN_EMAIL=admin@epub-translator.local
ADMIN_PASSWORD=your-secure-password

# SMTP (Helyi MailHog)
SMTP_MODE=local
SMTP_HOST=mailhog
SMTP_PORT=1025

# Modell
SELECTED_MODEL=deepseek-r1:8b
MAX_WORKERS=3

# Könyv Adatbázis
ENABLE_BOOK_DB=true
MAX_SAMPLE_BOOKS=5
ENABLE_ONLINE_SEARCH=true

# Cache
ENABLE_CACHE=true
REDIS_URL=redis://redis:6379/0
```

SMTP Módok

```bash
# 1. Helyi (MailHog) - Alapértelmezett
SMTP_MODE=local
SMTP_HOST=mailhog
SMTP_PORT=1025
# Email UI: http://localhost:8025

# 2. Gmail Relay
SMTP_MODE=gmail
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=yourmail@gmail.com
SMTP_PASSWORD=your-app-password

# 3. Egyéni SMTP
SMTP_MODE=custom
SMTP_HOST=smtp.yourcompany.com
SMTP_PORT=587
SMTP_USER=your-user
SMTP_PASSWORD=your-password
```

---

📖 Használat

Felhasználói Felület

1. Bejelentkezés

```
1. Nyisd meg: http://localhost
2. Email: a regisztrált email címed
3. Jelszó: a kapott jelszó
```

2. Könyv Feltöltése

```
1. Kattints a "Fájl kiválasztása" gombra
2. Válaszd ki az EPUB fájlt
3. Opcionálisan tölts fel mintakönyveket
4. Kattints a "Fordítás indítása" gombra
```

3. Mintakönyvek Kezelése

```
1. Tölts fel saját mintakönyveket (.epub)
   VAGY
2. Válassz az adatbázisból ajánlott könyveket
   VAGY
3. Hagyd, hogy a rendszer automatikusan válasszon
```

4. Fordítás Követése

· Folyamatjelző mutatja a haladást
· Befejezéskor email értesítés
· A fájl letölthető a felületről

Parancssori Műveletek

```bash
# Státusz
docker compose ps

# Logok
docker compose logs -f backend

# Újraindítás
docker compose restart

# Leállítás
docker compose down

# Teljes újratelepítés
docker compose down -v
./install.sh
```

---

📚 Könyv Adatbázis

Automatikus Metaadat Kinyerés

A rendszer automatikusan kinyeri a következő adatokat minden feltöltött könyvből:

Adat Forrás Példa
Cím EPUB metaadat "A Nagy Gatsby"
Szerző EPUB / Online "F. Scott Fitzgerald"
ISBN EPUB / Számított "9780743273565"
Kiadó EPUB / Online "Scribner"
Nyelv EPUB metaadat "en"
Műfaj AI elemzés "literary_fiction"
Stílus AI elemzés "literary/complex"
Komplexitás AI elemzés "advanced"
Szavak száma Számított 47,094
Fejezetek Számított 9

Támogatott Műfajok

```
🎨 fiction              🔍 mystery
🚀 science_fiction      👻 horror
🧙 fantasy              📖 literary_fiction
💕 romance              📚 non_fiction
🎯 thriller             🔧 technical
```

Online Keresés

```bash
# ISBN alapú keresés (ha engedélyezve van)
curl "http://localhost:5000/api/books/search-online?isbn=9780743273565"
```

Válasz:

```json
{
    "found": true,
    "book": {
        "title": "The Great Gatsby",
        "authors": ["F. Scott Fitzgerald"],
        "publisher": "Scribner",
        "published_date": "1925",
        "categories": ["Fiction", "Classics"],
        "description": "The story of the mysteriously wealthy Jay Gatsby...",
        "page_count": 180,
        "average_rating": 3.93
    },
    "sources": {
        "google_books": true,
        "openlibrary": true
    }
}
```

---

🎯 Mintakönyv Rendszer

Működési Elv

1. Feltöltéskor a rendszer elemzi a célkönyvet
2. Adatbázisban keres hasonló könyveket
3. Pontozza a találatokat (műfaj, stílus, komplexitás alapján)
4. Kiválasztja a legjobb 3-5 mintát
5. Használja a fordításhoz kontextusként
6. Tanul az eredményekből a jövőbeli fordításokhoz

Egyezési Pontszám Számítás

```
Műfaj egyezés:      +30 pont
Stílus egyezés:     +25 pont
Komplexitás egyezés: +20 pont
Használati súly:    +15 pont (max)
Kontextus súly:     +10 pont (max)
─────────────────────────
Maximum:            100 pont
```

Ajánlási Példa

```
Célkönyv: "Dune" (science_fiction, complex, advanced)

Ajánlott minták:
1. "Foundation" - 92% egyezés (sci-fi, complex, advanced)
2. "Hyperion" - 87% egyezés (sci-fi, literary, advanced)
3. "Neuromancer" - 82% egyezés (sci-fi, descriptive, intermediate)
```

---

📧 Email Beállítások

MailHog (Alapértelmezett)

```
Előnyök:
✅ Azonnali kézbesítés
✅ Webes felület (http://localhost:8025)
✅ Nincs internet szükséges
✅ Összes email megtekinthető
✅ Nincs limit

Hátrányok:
⚠️ Csak helyben érhetők el az emailek
⚠️ Nem küld külső címekre
```

Gmail Relay

```
Előnyök:
✅ Helyi és külső email küldés
✅ Ingyenes (napi 500 email)
✅ Megbízható

Beállítás:
1. Gmail → Biztonság → Kétlépcsős azonosítás
2. Alkalmazás jelszó generálása
3. Használd az alkalmazás jelszót
```

Egyéni SMTP

```
Előnyök:
✅ Teljes kontroll
✅ Saját domain
✅ Korlátlan email

Beállítás:
SMTP_HOST=smtp.yourdomain.com
SMTP_PORT=587
SMTP_USER=your-user
SMTP_PASSWORD=your-password
```

---

👑 Admin Felület

Elérés

```
http://localhost/admin
```

Funkciók

Felhasználó Kezelés

· Új felhasználó létrehozása
· Token beállítás
· Fiók aktiválás/tiltás
· Jogosultság kezelés
· CSV import/export

Modell Kezelés

· Aktív modell megtekintése
· Modell váltás
· Új modell letöltése
· Modell törlése

Könyv Adatbázis

· Összes könyv listázása
· Műfaj szerinti szűrés
· Stílus szerinti szűrés
· Használati statisztikák
· Mintakönyv hatékonyság

Statisztikák

· Felhasználók száma
· Fordítások száma
· Sikeres/sikertelen arány
· Átlagos fordítási idő
· Rendszer erőforrások

SMTP Beállítások

· Mód választás
· Szerver konfiguráció
· Teszt email küldés

---

🔌 API Dokumentáció

Hitelesítés

```bash
# Bejelentkezés
curl -X POST http://localhost/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# API kulcs használata
curl -H "X-API-Key: your-api-key" \
  http://localhost/api/books
```

Végpontok

Könyvek

```bash
# Könyvek listázása
GET /api/books?genre=science_fiction&style=complex

# Könyv részletei
GET /api/books/123

# Könyv keresés online
GET /api/books/search-online?isbn=9780743273565

# Könyv elemzése
POST /api/books/analyze
Content-Type: multipart/form-data
epub_file: [fájl]
```

Fordítás

```bash
# Fordítás indítása
POST /api/translate
Content-Type: multipart/form-data
epub_file: [fájl]
sample_books: [fájlok]

# Fordítás állapota
GET /api/translation/123/progress

# Fordítás letöltése
GET /api/download/123
```

Admin

```bash
# Statisztikák
GET /api/stats

# Modell lista
GET /api/models

# Modell váltás
POST /api/models/switch
{"model": "deepseek-r1:14b"}

# Felhasználó létrehozás
POST /api/users
{
    "email": "user@example.com",
    "password": "SecurePass1!",
    "first_name": "John",
    "last_name": "Doe"
}
```

---

🔧 Karbantartás

Rendszeres Feladatok

```bash
# Heti biztonsági mentés (automatikus)
# Vasárnap 03:00 - cron job

# Manuális mentés
./scripts/backup.sh

# Mentések listázása
ls -la ~/epub-backups/

# Visszaállítás
./scripts/restore.sh ~/epub-backups/db_backup_20240101.sql

# Könyv adatbázis statisztika
./scripts/book-stats.sh
```

Frissítés

```bash
# Rendszer frissítése
cd ~/epub-translator
git pull
docker compose down
docker compose up -d --build

# Modell frissítése
docker exec -it epub-ollama ollama pull deepseek-r1:8b
```

Tisztítás

```bash
# Docker takarítás (automatikus vasárnap 04:00)
docker system prune -f

# Régi logok törlése
find logs/ -name "*.log" -mtime +30 -delete

# Ideiglenes fájlok
rm -rf uploads/tmp_*
```

---

🔍 Hibaelhárítás

Gyakori Problémák

1. "Port already in use"

```bash
# Ellenőrzés
sudo lsof -i :80
sudo lsof -i :5000

# Megoldás
sudo systemctl stop apache2
# vagy
sudo kill -9 [PID]
```

2. Memória Problémák

```bash
# Ellenőrzés
free -h
docker stats

# Megoldás
# Használj kisebb modellt
docker exec -it epub-ollama ollama pull deepseek-r1:7b
# Állítsd át az admin felületen
```

3. Email Nem Érkezik Meg

```bash
# Helyi módban
# Ellenőrizd: http://localhost:8025

# Teszt email
./scripts/test-email.sh

# Logok
docker compose logs mailhog
```

4. A Fordítás Lassú

```bash
# Ellenőrizd a CPU használatot
htop

# Csökkentsd a párhuzamos szálakat
# Admin felület → Beállítások → MAX_WORKERS=1

# Használj gyorsabb modellt
# deepseek-r1:7b vagy deepseek-r1:1.5b
```

5. Adatbázis Hibák

```bash
# Adatbázis újraindítás
docker compose restart postgres

# Táblák újraépítése
docker exec -it epub-backend python3 -c "
from app import app, db
with app.app_context():
    db.create_all()
"

# Teljes visszaállítás
docker compose down -v postgres
docker compose up -d postgres
```

Log Fájlok

```bash
# Alkalmazás log
tail -f logs/epub_translator.log

# Hiba log
tail -f logs/errors.log

# Nginx log
tail -f logs/nginx/error.log

# Összes log egyben
docker compose logs -f
```

---

❓ GYIK

Általános Kérdések

K: A rendszer tényleg teljesen ingyenes?
V: Igen! A DeepSeek modellek nyílt forráskódúak. Nincs API díj, előfizetés vagy rejtett költség.

K: Kell internet a fordításhoz?
V: Nem! Csak a modell első letöltéséhez. Utána teljesen offline működik.

K: Mennyi idő egy könyv fordítása?
V: Átlagos 300 oldalas könyv: 2-4 óra (deepseek-r1:8b, 32GB RAM).

K: Milyen nyelvekre fordít?
V: Alapértelmezetten magyarra. A fordítási profilokban módosítható.

Könyv Adatbázis

K: Mi történik a feltöltött könyvekkel?
V: Automatikusan elemzésre kerülnek, és bekerülnek a helyi adatbázisba. Minden adat a gépeden marad.

K: Hogyan működik a műfaj felismerés?
V: A rendszer kulcsszavak és AI elemzés alapján határozza meg a műfajt. Az eredményt ellenőrizheted és módosíthatod.

K: Honnan szerzi a metaadatokat?
V: Több forrásból: EPUB belső adatok, Google Books API, OpenLibrary, és helyi AI elemzés.

Mintakönyvek

K: Kötelező mintakönyvet feltölteni?
V: Nem, de ajánlott. A rendszer automatikusan ajánl hasonló könyveket az adatbázisból.

K: Hány mintakönyvet használhatok?
V: Maximum 5 mintakönyvet (konfigurálható). A rendszer automatikusan a legjobbakat választja.

K: A mintakönyvek is bekerülnek az adatbázisba?
V: Igen, elemzésre kerülnek és segítik a jövőbeli fordításokat.

Biztonság

K: Biztonságos a rendszer?
V: Igen! Minden adat helyben marad. Vírusellenőrzés, 2FA, rate limiting védi a rendszert.

K: Látják mások a könyveimet?
V: Nem! Minden helyben fut, nincs külső adatküldés.

K: Mi az a "token" a rendszerben?
V: Belső elszámolási egység, semmi köze a pénzhez. Az admin állítja be, ki hányat fordíthat.

---

📊 Verzió Történet

v5.0.0 (2024-01-15)

· 🆕 Könyv adatbázis automatikus metaadat kinyeréssel
· 🆕 Intelligens mintakönyv ajánló rendszer
· 🆕 AI alapú műfaj és stílus felismerés
· 🆕 Online könyv keresés (Google Books, OpenLibrary)
· 🆕 Kontextus tanuló rendszer
· 📈 Továbbfejlesztett statisztikák
· 🐛 Hibajavítások és stabilizálás

v4.0.0 (2024-01-01)

· Hibrid SMTP rendszer (MailHog + opcionális relay)
· Vírusellenőrzés
· 2FA támogatás
· API kulcs kezelés
· Monitoring rendszer

v3.0.0 (2023-12-15)

· Párhuzamos fordítás
· Redis cache
· Batch feldolgozás
· Több modell támogatás

v2.0.0 (2023-12-01)

· Felhasználó kezelés
· Token rendszer
· Email értesítések
· Webes felület

v1.0.0 (2023-11-15)

· Alap EPUB fordítás
· Egyszerű webes felület
· Docker konténerizáció

---

🤝 Közreműködés

Fejlesztői Környezet

```bash
# Repository klónozása
git clone https://github.com/sorosg/Epub-translate.git
cd Epub-translate

# Fejlesztői mód indítása
docker compose -f docker-compose.dev.yml up -d

# Tesztek futtatása
docker exec -it epub-backend pytest
```

Hibajelentés

Kérjük, a GitHub Issues oldalon jelentsd a hibákat:
https://github.com/sorosg/Epub-translate/issues

Feature Request

Új funkciók javaslása:
https://github.com/sorosg/Epub-translate/discussions

---

📄 Licensz

MIT License - Lásd a LICENSE fájlt.

---

🙏 Köszönetnyilvánítás

· DeepSeek - A kiváló nyílt forráskódú AI modellekért
· Ollama - A modellek egyszerű futtatásáért
· Flask - A webes keretrendszerért
· EbookLib - Az EPUB kezelésért

---

📞 Támogatás

· 📧 Email: sorosgergo@gmail.com
· 🌐 GitHub: https://github.com/sorosg/Epub-translate
· 📚 Dokumentáció: https://github.com/sorosg/Epub-translate/wiki

---

Készült ❤️-vel Magyarországon

---

Utolsó frissítés: 2024. január 15.
