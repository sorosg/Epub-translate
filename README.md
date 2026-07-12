```markdown
# EPUB Fordító Rendszer v7.0

## 📚 "Self-Evolving Translator" - Az Öntanuló Fordító

![Version](https://img.shields.io/badge/version-7.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-ready-brightgreen)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04+-orange)
![PWA](https://img.shields.io/badge/PWA-ready-purple)

---

## 🎯 Rendszer Áttekintés

Az EPUB Fordító Rendszer egy **teljesen ingyenes, helyben futó, öntanuló** megoldás EPUB könyvek fordítására. A DeepSeek AI modelleket használja, amelyek a saját gépeden futnak - **nincs szükség API kulcsra, internetkapcsolatra (a modell letöltése után), vagy előfizetésre!**

### 🌟 Legfontosabb Jellemzők

- ✅ **100% Ingyenes** - Nincs rejtett költség, előfizetés vagy API díj
- ✅ **Helyben Fut** - Minden adat a saját gépeden marad
- ✅ **Offline Működés** - Internet csak a modell első letöltéséhez kell
- ✅ **Öntanuló** - A fordítási memória és kontextus tanulás folyamatosan javul
- ✅ **Önfrissítő** - Automatikus GitHub frissítések, verziókövetés
- ✅ **Biztonságos** - Vírusellenőrzés, 2FA, rate limiting
- ✅ **Mobilbarát** - Teljes PWA támogatás, telepíthető mobilon
- ✅ **Kollaboratív** - Valós idejű közös fordítás

---

## 📋 Tartalomjegyzék

1. [Rendszerkövetelmények](#-rendszerkövetelmények)
2. [Gyors Telepítés](#-gyors-telepítés)
3. [Újdonságok a v7.0-ban](#-újdonságok-a-v70-ban)
4. [Architektúra](#-architektúra)
5. [Konfiguráció](#-konfiguráció)
6. [Használat](#-használat)
7. [Auto-Update Rendszer](#-auto-update-rendszer)
8. [Fordítási Memória](#-fordítási-memória)
9. [Glosszárium Kezelés](#-glosszárium-kezelés)
10. [Kollaboratív Fordítás](#-kollaboratív-fordítás)
11. [PWA Mobil Támogatás](#-pwa-mobil-támogatás)
12. [TTS Hangoskönyv](#-tts-hangoskönyv)
13. [Plugin Rendszer](#-plugin-rendszer)
14. [API Dokumentáció](#-api-dokumentáció)
15. [Karbantartás](#-karbantartás)
16. [Hibaelhárítás](#-hibaelhárítás)
17. [GYIK](#-gyik)
18. [Verzió Történet](#-verzió-történet)

---

## 💻 Rendszerkövetelmények

### Hardver

| Komponens | Minimum | Ajánlott |
|-----------|---------|----------|
| **RAM** | 16 GB | 32 GB |
| **CPU** | 4 mag, 2.5 GHz | 8+ mag, 3.0+ GHz |
| **Tárhely** | 50 GB | 100+ GB SSD |
| **GPU** | Nem szükséges | NVIDIA (opcionális) |

### Szoftver

- **Operációs Rendszer:** Ubuntu 22.04 LTS vagy újabb (64 bit)
- **Docker:** 24.0+ 
- **Docker Compose:** 2.20+

### DeepSeek Modellek

| Modell | Méret | RAM Igény | Sebesség | Minőség |
|--------|-------|-----------|----------|---------|
| `deepseek-r1:1.5b` | 1.5 GB | 8 GB | ⚡⚡⚡⚡⚡ | ⭐⭐ |
| `deepseek-r1:7b` | 7 GB | 16 GB | ⚡⚡⚡⚡ | ⭐⭐⭐ |
| `deepseek-r1:8b` | 8 GB | 32 GB | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| `deepseek-r1:14b` | 14 GB | 32 GB | ⚡⚡ | ⭐⭐⭐⭐ |
| `deepseek-r1:32b` | 32 GB | 64 GB | ⚡ | ⭐⭐⭐⭐⭐ |
| `deepseek-r1:70b` | 70 GB | 128 GB | 🐌 | ⭐⭐⭐⭐⭐ |

---

## 🚀 Gyors Telepítés

### Egy paranccsal:

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

Telepítési Varázsló

A telepítő interaktív varázslóval rendelkezik, ami végigvezet a beállításokon:

· 👤 Adminisztrátori fiók beállítása
· 🤖 AI modell kiválasztása
· 📡 GitHub auto-update konfigurálása
· 📱 PWA beállítások
· 🔊 TTS engedélyezése
· 👥 Kollaboráció beállítása
· 🔌 Plugin rendszer
· 📧 Email konfiguráció
· ⚡ Teljesítmény beállítások
· 🔒 Biztonsági beállítások

Telepítés Után

```bash
# Webes felület
http://localhost

# Email felület (MailHog)
http://localhost:8025

# Admin belépés
Email: admin@epub-translator.local
Jelszó: Abrakadabra (változtasd meg!)

# Frissítés kezelés
http://localhost/admin/updates
```

---

🆕 Újdonságok a v7.0-ban

📡 GitHub Auto-Update Rendszer

· Automatikus frissítés GitHub repository-ból
· Több frissítési csatorna (stable, beta, nightly)
· Verziókövetés és frissítési előzmények
· Visszaállítási pontok automatikus mentéssel
· GitHub token támogatás privát repository-khoz
· Ütemezett ellenőrzés (állítható intervallum)
· Egy kattintásos frissítés az admin felületen

🧠 Öntanuló Fordítási Memória

· Mondat szintű fordítás tárolás
· Fuzzy matching hasonló szövegekhez
· Minőségi pontszám alapú súlyozás
· Automatikus tanulás a fordításokból
· Kontextus alapú fordítás újrafelhasználás

📚 Intelligens Glosszárium

· Domain-specifikus terminológia
· Automatikus kifejezés felismerés
· Konzisztens fordítás biztosítása
· Publikus és privát glosszáriumok
· Import/Export támogatás

👥 Valós Idejű Kollaboráció

· Több felhasználós egyidejű fordítás
· WebSocket alapú valós idejű kommunikáció
· Szavazás a legjobb fordításra
· Kommentek és megjegyzések
· Verziókövetés a változtatásokhoz

📱 Teljes PWA Támogatás

· Telepíthető mobilon és asztali gépen
· Offline működés Service Worker-rel
· Push értesítések a fordítás állapotáról
· Háttér szinkronizálás
· Reszponzív design minden eszközön

🔊 TTS Hangoskönyv Generálás

· Edge TTS integráció (ingyenes, jó minőség)
· Több nyelv és hang támogatása
· Audiobook generálás EPUB-ból
· Streaming lejátszás

🔌 Plugin Rendszer

· Bővíthető architektúra
· Hook rendszer (pre/post fordítás, stb.)
· Egyedi pluginok fejlesztése
· Manifest alapú plugin kezelés

---

🏗️ Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│                     Felhasználói Böngésző                      │
│                    http://localhost:80                        │
│                    📱 PWA Támogatás                           │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                      Nginx (80/443)                          │
│              Reverse Proxy + Statikus Fájlok                 │
│              Rate Limiting + Biztonsági Fejlécek              │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                  Flask Backend (5000)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐    │
│  │ Fordítás     │ │ Auto-Update  │ │ Felhasználó       │    │
│  │ Kezelő       │ │ Manager      │ │ Kezelés           │    │
│  ├──────────────┤ ├──────────────┤ ├──────────────────┤    │
│  │ Fordítási    │ │ Verzió       │ │ Kollaboráció      │    │
│  │ Memória      │ │ Követés      │ │ (WebSocket)       │    │
│  ├──────────────┤ ├──────────────┤ ├──────────────────┤    │
│  │ Glosszárium  │ │ Biztonsági   │ │ Plugin            │    │
│  │ Kezelő       │ │ Mentések     │ │ Manager           │    │
│  └──────────────┘ └──────────────┘ └──────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼──────┐   ┌────────▼────────┐   ┌─────▼──────┐
│  PostgreSQL  │   │     Ollama       │   │   Redis    │
│  Adatbázis   │   │  DeepSeek AI    │   │   Cache    │
│  + TM +      │   │  Modellek       │   │            │
│  Glosszárium │   │                 │   │            │
└──────────────┘   └─────────────────┘   └────────────┘

┌──────────────┐   ┌─────────────────┐   ┌──────────────┐
│   MailHog    │   │   TTS Service    │   │  WebSocket   │
│ Helyi Email  │   │  Edge TTS        │   │  Szerver     │
└──────────────┘   └─────────────────┘   └──────────────┘
```

Szolgáltatások

Szolgáltatás Port Leírás
Nginx 80, 443 Web szerver és reverse proxy
Backend 5000 Flask alkalmazás (belső)
PostgreSQL 5432 Adatbázis (belső)
Ollama 11434 AI modell szerver (belső)
Redis 6379 Cache (belső)
MailHog 1025, 8025 Helyi email szerver és UI
TTS Service 5001 Hangoskönyv generálás
WebSocket 3001 Kollaboráció

---

⚙️ Konfiguráció

Környezeti Változók (.env)

```env
# Alkalmazás
VERSION=7.0.0
SECRET_KEY=your-secret-key
FLASK_ENV=production

# Admin
ADMIN_EMAIL=admin@epub-translator.local
ADMIN_PASSWORD=your-secure-password

# AI Modell
SELECTED_MODEL=deepseek-r1:8b
MAX_WORKERS=3

# Auto-Update
ENABLE_AUTO_UPDATE=true
GITHUB_REPO=https://github.com/sorosg/Epub-translate.git
GITHUB_BRANCH=main
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
UPDATE_CHECK_INTERVAL=3600

# Funkciók
ENABLE_PWA=true
ENABLE_TTS=true
ENABLE_COLLABORATION=true
ENABLE_PLUGINS=true
ENABLE_API=true
ENABLE_BOOK_DB=true
ENABLE_CACHE=true

# SMTP (Helyi MailHog)
SMTP_MODE=local
SMTP_HOST=mailhog
SMTP_PORT=1025
```

Frissítési Csatornák

Csatorna Leírás Frissítési Gyakoriság
stable Stabil, tesztelt verziók Hetente
beta Előzetes verziók Naponta
nightly Fejlesztői verziók Óránként

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
2. Válaszd ki az EPUB fájlt (max 100MB)
3. Opcionálisan tölts fel mintakönyveket
4. Válassz glosszáriumot (opcionális)
5. Kattints a "Fordítás indítása" gombra
```

3. Fordítás Követése

· Folyamatjelző mutatja a haladást
· Élő előnézet a fordításról
· Befejezéskor email és push értesítés
· A fájl letölthető a felületről

Parancssori Műveletek

```bash
# Státusz
./scripts/status.sh

# Biztonsági mentés
./scripts/backup.sh

# Frissítés
./scripts/update.sh

# Logok
docker compose logs -f backend

# Újraindítás
docker compose restart

# Leállítás
docker compose down
```

---

📡 Auto-Update Rendszer

Beállítás

1. Admin felületen: Admin → Frissítés Kezelés
2. GitHub csatorna hozzáadása:
   · Repository URL: https://github.com/sorosg/Epub-translate.git
   · Branch: main
   · Token: ghp_xxxxxxxxxxxx (opcionális, privát repóhoz)
3. Ellenőrzési intervallum: 3600 másodperc (1 óra)

Frissítési Folyamat

```
1. Rendszer ellenőrzi a GitHub repository-t
2. Ha új verzió elérhető:
   ├── Automatikus biztonsági mentés készül
   ├── Új verzió letöltése
   ├── Konténerek újraépítése
   ├── Szolgáltatások újraindítása
   └── Sikeres frissítés → értesítés
3. Ha hiba történik:
   └── Automatikus visszaállítás az előző verzióra
```

Kézi Frissítés

```bash
# Frissítések ellenőrzése
curl -X POST http://localhost/api/admin/updates/check-all

# Frissítés telepítése
curl -X POST http://localhost/api/admin/updates/install/1

# Visszaállítás
curl -X POST http://localhost/api/admin/updates/rollback/1
```

---

🧠 Fordítási Memória

Működés

A fordítási memória (TM - Translation Memory) egy öntanuló rendszer, amely:

1. Tárolja a korábbi fordításokat mondat szinten
2. Fuzzy kereséssel megtalálja a hasonló szövegeket
3. Újrafelhasználja a korábbi fordításokat
4. Minőségi pontszám alapján súlyoz

Előnyök

· ⚡ Gyorsabb fordítás - nem kell mindent újrafordítani
· 📈 Konzisztensebb - ugyanazt a szöveget ugyanúgy fordítja
· 🧠 Folyamatosan tanul - minél többet használod, annál jobb

---

📚 Glosszárium Kezelés

Domain-specifikus Terminológia

```python
# Példa glosszárium
glossary = {
    "technical": {
        "algorithm": "algoritmus",
        "database": "adatbázis",
        "framework": "keretrendszer"
    },
    "medical": {
        "diagnosis": "diagnózis",
        "treatment": "kezelés",
        "symptom": "tünet"
    }
}
```

---

👥 Kollaboratív Fordítás

Munkamenet Létrehozása

```
1. Fordítás elindítása
2. "Megosztás" gomb → munkamenet létrehozása
3. Meghívó link küldése a résztvevőknek
4. Valós idejű közös szerkesztés
```

Funkciók

· 👥 Több felhasználó egyidejű szerkesztése
· 💬 Valós idejű chat és kommentek
· 🗳️ Szavazás a legjobb fordításra
· 📝 Verziókövetés
· 🔔 Értesítések a változásokról

---

📱 PWA Mobil Támogatás

Telepítés Mobilra

```
1. Nyisd meg böngészőben: http://[SZERVER_IP]
2. Menü → "Telepítés" vagy "Hozzáadás a kezdőképernyőhöz"
3. Az ikon megjelenik a kezdőképernyőn
4. Egy kattintással indítható, offline is működik
```

PWA Funkciók

· 📱 Telepíthető - Nincs szükség App Store-ra
· 📡 Offline - Internet nélkül is működik
· 🔔 Push értesítések - Fordítás állapotáról
· 📲 Reszponzív - Alkalmazkodik a képernyőmérethez

---

🔊 TTS Hangoskönyv

Hangoskönyv Generálás

```
1. Fordítás befejezése után
2. "Hangoskönyv generálása" gomb
3. Nyelv és hang kiválasztása
4. MP3 letöltése
```

Támogatott Nyelvek

Nyelv Női Hang Férfi Hang
Magyar Szilvia Tamás
Angol Jenny Guy
Német Katja Conrad

---

🔌 Plugin Rendszer

Plugin Struktúra

```
plugins/
├── my-plugin/
│   ├── manifest.json
│   ├── hooks/
│   │   ├── pre_translate.py
│   │   ├── post_translate.py
│   │   └── on_complete.py
│   └── static/
│       ├── css/
│       └── js/
```

Plugin Manifest

```json
{
    "name": "my-plugin",
    "version": "1.0.0",
    "description": "Egyedi fordítási szabályok",
    "author": "Your Name",
    "hooks": ["pre_translate", "post_translate"],
    "config": {
        "target_language": "hu",
        "style": "formal"
    }
}
```

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

Fő Végpontok

Végpont Módszer Leírás
/api/translate POST Fordítás indítása
/api/translation/{id}/progress GET Fordítás állapota
/api/download/{id} GET Fordítás letöltése
/api/books GET Könyvek listázása
/api/books/search-online GET Online könyv keresés
/api/models GET Elérhető modellek
/api/models/switch POST Modell váltás
/api/admin/updates/check POST Frissítés ellenőrzése
/api/admin/updates/install POST Frissítés telepítése
/api/admin/backups GET Biztonsági mentések

---

🔧 Karbantartás

Automatikus Feladatok

Feladat Gyakoriság Időpont
Biztonsági mentés Hetente Vasárnap 03:00
Docker takarítás Hetente Vasárnap 04:00
Frissítés ellenőrzés Állítható Alapértelmezett: óránként

Kézi Karbantartás

```bash
# Teljes biztonsági mentés
./scripts/backup.sh

# Rendszer állapot
./scripts/status.sh

# Frissítés
./scripts/update.sh

# Adatbázis optimalizálás
docker exec -it epub-postgres vacuumdb -U epub_user epub_translator
```

---

🔍 Hibaelhárítás

Gyakori Problémák

1. "Port already in use"

```bash
sudo lsof -i :80
sudo systemctl stop apache2
```

2. Memória Problémák

```bash
# Kisebb modell használata
docker exec -it epub-ollama ollama pull deepseek-r1:7b
```

3. Frissítési Hibák

```bash
# Visszaállítás az előző verzióra
curl -X POST http://localhost/api/admin/updates/rollback/1

# Vagy kézzel
./scripts/backup.sh  # először mentés
docker compose down
docker compose up -d --build
```

4. PWA Nem Telepíthető

```bash
# Ellenőrizd a Service Worker-t
# Chrome: F12 → Application → Service Workers
# Győződj meg róla, hogy HTTPS-en vagy localhost-on fut
```

---

❓ GYIK

Általános

K: A rendszer tényleg teljesen ingyenes?
V: Igen! A DeepSeek modellek nyílt forráskódúak. Nincs API díj, előfizetés vagy rejtett költség.

K: Hogyan frissül a rendszer?
V: Automatikusan a GitHub repository-ból. Beállíthatsz stable, beta vagy nightly csatornát.

K: Mi történik, ha megszakad a frissítés?
V: A rendszer automatikusan visszaáll az előző verzióra a biztonsági mentésből.

PWA

K: Telepíthetem iPhone-ra?
V: Igen, iOS 16.4-től a Safari támogatja a PWA telepítést.

K: Működik offline?
V: Igen, a Service Worker cache-eli a fontos fájlokat.

Fordítás

K: Mennyi idő egy könyv fordítása?
V: Átlagos 300 oldalas könyv: 2-4 óra (deepseek-r1:8b, 32GB RAM).

K: Használhatom a korábbi fordításokat?
V: Igen, a fordítási memória automatikusan újrafelhasználja őket.

---

📊 Verzió Történet

v7.0.0 (2024-09-15) - "Self-Evolving Translator"

· 🆕 GitHub Auto-Update rendszer
· 🆕 Öntanuló fordítási memória
· 🆕 Glosszárium kezelés
· 🆕 Valós idejű kollaboráció
· 🆕 Teljes PWA támogatás
· 🆕 TTS hangoskönyv generálás
· 🆕 Plugin rendszer
· 🆕 Verziókövetés és visszaállítás

v6.0.0 (2024-06-15)

· Hibrid fordítási stratégia
· Fordítási memória alapok
· Kollaboratív fordítás
· TTS alapok

v5.0.0 (2024-01-15)

· Könyv adatbázis
· Intelligens mintakönyv ajánlás
· AI műfaj felismerés

v4.0.0 (2024-01-01)

· Hibrid SMTP
· Vírusellenőrzés
· 2FA támogatás

v3.0.0 (2023-12-15)

· Párhuzamos fordítás
· Redis cache

v2.0.0 (2023-12-01)

· Felhasználó kezelés
· Token rendszer

v1.0.0 (2023-11-15)

· Alap EPUB fordítás
· Webes felület

---

🤝 Közreműködés

Fejlesztői Környezet

```bash
git clone https://github.com/sorosg/Epub-translate.git
cd Epub-translate
docker compose -f docker-compose.dev.yml up -d
```

Hibajelentés

https://github.com/sorosg/Epub-translate/issues

Feature Request

https://github.com/sorosg/Epub-translate/discussions

---

📄 Licensz

MIT License

---

🙏 Köszönetnyilvánítás

· DeepSeek - Nyílt forráskódú AI modellek
· Ollama - Modell futtatás
· Flask - Web keretrendszer
· EbookLib - EPUB kezelés
· Edge TTS - Ingyenes szövegfelolvasás

---

📞 Támogatás

· 📧 Email: sorosgergo@gmail.com
· 🌐 GitHub: https://github.com/sorosg/Epub-translate

---

Készült ❤️-vel Magyarországon

Utolsó frissítés: 2024. szeptember 15.

```

Ez a README.md tartalmazza a v7.0 összes új funkciójának részletes leírását, a telepítési útmutatót, a konfigurációs lehetőségeket, az API dokumentációt és a hibaelhárítási tippeket.
```
