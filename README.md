```markdown
# EPUB Fordító Rendszer v9.0

## 📚 "User Portal" - Felhasználói Portál és Regisztrációs Rendszer

![Version](https://img.shields.io/badge/version-9.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-ready-brightgreen)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04+-orange)
![PWA](https://img.shields.io/badge/PWA-ready-purple)
![Update](https://img.shields.io/badge/auto--update-ready-success)
![Registration](https://img.shields.io/badge/registration-open-brightgreen)

---

## 🎯 Rendszer Áttekintés

Az EPUB Fordító Rendszer egy **teljesen ingyenes, helyben futó, öntanuló** megoldás EPUB könyvek fordítására. A DeepSeek AI modelleket használja, amelyek a saját gépeden futnak - **nincs szükség API kulcsra, internetkapcsolatra (a modell letöltése után), vagy előfizetésre!**

### 🌟 Legfontosabb Jellemzők

- ✅ **100% Ingyenes** - Nincs rejtett költség, előfizetés vagy API díj
- ✅ **Helyben Fut** - Minden adat a saját gépeden marad
- ✅ **Offline Működés** - Internet csak a modell első letöltéséhez kell
- ✅ **Öntanuló** - A fordítási memória és kontextus tanulás folyamatosan javul
- ✅ **Önfrissítő** - Automatikus GitHub frissítések, egykattintásos frissítés
- ✅ **Felhasználói Regisztráció** - Önálló regisztráció, belső email cím
- ✅ **Könyvtárkezelő** - Drag & drop könyvfeltöltés fordítás nélkül is
- ✅ **Belső Email** - Saját email rendszer a felhasználók között
- ✅ **Biztonságos** - Vírusellenőrzés, 2FA, rate limiting
- ✅ **Mobilbarát** - Teljes PWA támogatás, telepíthető mobilon
- ✅ **Kollaboratív** - Valós idejű közös fordítás

---

## 📋 Tartalomjegyzék

1. [Rendszerkövetelmények](#-rendszerkövetelmények)
2. [Gyors Telepítés](#-gyors-telepítés)
3. [Frissítés Meglévő Telepítésről](#-frissítés-meglévő-telepítésről)
4. [Újdonságok a v9.0-ban](#-újdonságok-a-v90-ban)
5. [Felhasználói Regisztráció](#-felhasználói-regisztráció)
6. [Belső Email Rendszer](#-belső-email-rendszer)
7. [Architektúra](#-architektúra)
8. [Konfiguráció](#-konfiguráció)
9. [Használat](#-használat)
10. [Könyvtár Kezelés](#-könyvtár-kezelés)
11. [Auto-Update Rendszer](#-auto-update-rendszer)
12. [PWA Mobil Támogatás](#-pwa-mobil-támogatás)
13. [API Dokumentáció](#-api-dokumentáció)
14. [Karbantartás](#-karbantartás)
15. [Hibaelhárítás](#-hibaelhárítás)
16. [GYIK](#-gyik)
17. [Verzió Történet](#-verzió-történet)

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

# 3. Indítsd el (friss telepítés)
./install.sh
```

Telepítés Után

```bash
# Webes felület
http://localhost

# Regisztráció
http://localhost/register

# Email felület (MailHog)
http://localhost:8025

# Admin belépés
Email: admin@epub-translator.local
Jelszó: Abrakadabra (változtasd meg!)
```

---

🔄 Frissítés Meglévő Telepítésről

Automatikus Frissítés (Webes Felületről)

1. Jelentkezz be adminisztrátorként
2. Navigálj: Admin → Frissítés Kezelés
3. Kattints: "Frissítések ellenőrzése"
4. Ha elérhető új verzió: "Telepítés"

Frissítés Parancssorból

```bash
# 1. lehetőség: Telepítő script
./install.sh
# Válaszd: 1) Frissítés meglévő telepítésről

# 2. lehetőség: Gyorsfrissítő
./scripts/update.sh

# 3. lehetőség: Csak konfiguráció frissítése
./install.sh
# Válaszd: 3) Csak konfiguráció frissítése
```

Frissítési Lehetőségek

Opció Leírás Adatmegőrzés
1) Frissítés Teljes frissítés, adatok megőrzése ✅ Igen
2) Újratelepítés Minden törlése, friss telepítés ❌ Nem
3) Konfig frissítés Csak konfigurációs fájlok frissítése ✅ Igen

Frissítési Folyamat

```
1. Meglévő verzió észlelése
2. Frissítés előtti biztonsági mentés
   ├── Adatbázis mentése
   ├── Konfiguráció mentése
   ├── Könyvtár mentése
   └── Fordítási memória mentése
3. Konténerek leállítása
4. Új fájlok telepítése
5. Konténerek újraépítése
6. Adatbázis migráció
7. Szolgáltatások újraindítása
8. Verzió frissítése
```

---

🆕 Újdonságok a v9.0-ban

👤 Felhasználói Regisztráció

· Önálló regisztrációs oldal (/register)
· Regisztrációs űrlap validációval
· Jelszó erősség ellenőrzés
· Automatikus belső email generálás
· Kezdő tokenek (alapértelmezett: 5)
· Üdvözlő üzenet regisztráció után
· Rate limiting (5 regisztráció/óra)

📧 Belső Email Cím

· Automatikus generálás: keresztnev.vezeteknev@epub.local
· Egyedi cím minden felhasználónak
· Ütközéskezelés (számozás azonos neveknél)

🎨 Továbbfejlesztett Felhasználói Felület

· Regisztrációs gomb a bejelentkezés oldalon
· Modern, letisztult design
· Reszponzív mobil nézet
· Font Awesome ikonok

🔄 Továbbfejlesztett Frissítés

· Három frissítési mód (teljes, újratelepítés, konfig)
· Részletes frissítési napló
· Automatikus mentés frissítés előtt

---

👤 Felhasználói Regisztráció

Regisztráció Menete

```
1. Nyisd meg: http://localhost/register
2. Töltsd ki az űrlapot:
   ├── Vezetéknév (kötelező)
   ├── Keresztnév (kötelező)
   ├── Email cím (kötelező)
   ├── Jelszó (minimum 8 karakter)
   └── Jelszó megerősítése
3. Kattints a "Regisztráció" gombra
4. Azonnal megkapod:
   ├── Belső email címed (@epub.local)
   ├── 5 kezdő token
   └── Üdvözlő üzenet
5. Jelentkezz be az email címeddel
```

Regisztrációs Adatok

Mező Kötelező Megjegyzés
Vezetéknév ✅ -
Keresztnév ✅ -
Email ✅ Egyedi kell legyen
Jelszó ✅ Minimum 8 karakter
Jelszó újra ✅ Egyeznie kell

Kezdő Jogosultságok

Jogosultság Érték
Tokenek 5 fordítás
Belső email nev@epub.local
Könyvtár hozzáférés Olvasás
Mintakönyv feltöltés ✅
Kollaboráció ✅

Regisztráció Letiltása

Az adminisztrátor letilthatja a regisztrációt:

```env
# .env fájlban
ENABLE_REGISTRATION=false
```

Vagy az admin felületen: Beállítások → Regisztráció

---

📧 Belső Email Rendszer

Email Cím Generálás

Minden felhasználó automatikusan kap egy belső email címet:

```
Formátum: keresztnev.vezeteknev@epub.local
Példa: gabor.kiss@epub.local
       anna.nagy@epub.local
```

Ha már létezik azonos cím:

```
gabor.kiss@epub.local
gabor.kiss1@epub.local  ← automatikus számozás
gabor.kiss2@epub.local
```

Belső Email Funkciók

· 📨 Üzenetküldés felhasználók között
· 📬 Bejövő üzenetek (/api/internal-mail/inbox)
· 📤 Elküldött üzenetek (/api/internal-mail/sent)
· ⭐ Csillagozás fontos üzenetekhez
· ✅ Olvasott/Olvasatlan állapot
· 🔔 Értesítések új üzenetről

Rendszerüzenetek

Automatikus üzenetek:

· 🎉 Regisztrációkor üdvözlő üzenet
· 📚 Könyv feltöltésekor
· ✅ Fordítás befejezésekor
· ❌ Fordítási hiba esetén
· 🔄 Rendszerfrissítéskor

---

🏗️ Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│                     Felhasználói Böngésző                      │
│                    http://localhost:80                        │
│                    📱 PWA Támogatás                           │
│                    👤 Regisztráció                            │
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
│  │ Regisztráció │ │ Belső Email  │ │ Felhasználó       │    │
│  │ Kezelő       │ │ Rendszer     │ │ Kezelés           │    │
│  ├──────────────┤ ├──────────────┤ ├──────────────────┤    │
│  │ Könyvtár     │ │ Fordítás     │ │ Auto-Update       │    │
│  │ Kezelő       │ │ Kezelő       │ │ Manager           │    │
│  ├──────────────┤ ├──────────────┤ ├──────────────────┤    │
│  │ Token        │ │ Kollaboráció │ │ Statisztikák      │    │
│  │ Rendszer     │ │ (WebSocket)  │ │                   │    │
│  └──────────────┘ └──────────────┘ └──────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼──────┐   ┌────────▼────────┐   ┌─────▼──────┐
│  PostgreSQL  │   │     Ollama       │   │   Redis    │
│  + Users     │   │  DeepSeek AI    │   │   Cache    │
│  + Books     │   │  Modellek       │   │            │
│  + Email     │   │                 │   │            │
└──────────────┘   └─────────────────┘   └────────────┘

┌──────────────┐   ┌─────────────────┐
│   MailHog    │   │   TTS Service    │
│ Helyi Email  │   │  (opcionális)    │
└──────────────┘   └─────────────────┘
```

---

⚙️ Konfiguráció

.env Fájl

```env
# Verzió
VERSION=9.0.0
CODENAME="User Portal"

# Admin
ADMIN_EMAIL=admin@epub-translator.local
ADMIN_PASSWORD=your-secure-password

# Regisztráció
ENABLE_REGISTRATION=true      # true/false - regisztráció engedélyezése
DEFAULT_TOKENS=5               # Kezdő tokenek száma

# AI Modell
SELECTED_MODEL=deepseek-r1:8b
MAX_WORKERS=3

# Auto-Update
ENABLE_AUTO_UPDATE=true
GITHUB_REPO=https://github.com/sorosg/Epub-translate.git
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
UPDATE_CHECK_INTERVAL=3600

# SMTP
SMTP_MODE=local
SMTP_HOST=mailhog
SMTP_PORT=1025

# Funkciók
ENABLE_PWA=true
ENABLE_TTS=true
ENABLE_COLLABORATION=true
ENABLE_BOOK_DB=true
ENABLE_CACHE=true
```

Regisztráció Testreszabása

```env
# Regisztráció teljes letiltása
ENABLE_REGISTRATION=false

# Kezdő tokenek módosítása
DEFAULT_TOKENS=10

# Regisztráció limitálása
# (a Flask-Limiter kezeli: 5 regisztráció/óra)
```

---

📖 Használat

Új Felhasználó Regisztrációja

```
1. Nyisd meg: http://localhost
2. Kattints a "Regisztráció" gombra
3. Töltsd ki az adatokat
4. Kattints a "Regisztráció" gombra
5. Jelentkezz be az email címeddel
```

Bejelentkezés

```
1. Nyisd meg: http://localhost/login
2. Add meg az email címed
3. Add meg a jelszavad
4. Kattints a "Bejelentkezés" gombra
```

Dashboard

Bejelentkezés után a dashboard-on láthatod:

· 👤 Neved
· 💰 Token egyenleged
· 📧 Belső email címed
· 📚 Fordítási előzményeid
· 🔔 Értesítéseid

Token Kérés

Ha elfogytak a tokenjeid:

1. Kattints a "Tokenek kérése" gombra
2. Az adminisztrátor értesítést kap
3. Az admin jóváhagyja és beállítja az új tokeneket

---

📚 Könyvtár Kezelés

Drag & Drop Feltöltés (Admin)

```
1. Admin → Könyvtár Kezelés
2. Húzd az EPUB fájlokat a drop zónába
3. VAGY kattints a zónára
4. Több fájl is kiválasztható (Ctrl+A)
5. Kattints a "Feltöltés Indítása" gombra
```

Könyvtár Statisztikák

Statisztika Leírás
Összes könyv Adatbázisban lévő könyvek
Szerzők Egyedi szerzők száma
Feltöltések Összes feltöltés száma
Műfajok Különböző műfajok száma

---

🔄 Auto-Update Rendszer

Frissítési Módok

Mód Leírás
Teljes frissítés Új fájlok + adatbázis migráció
Konfig frissítés Csak .env és konfig fájlok
Újratelepítés Minden törlése, friss telepítés

Frissítés a Webes Felületről

```
1. Admin → Frissítés Kezelés
2. "Frissítések ellenőrzése"
3. Ha elérhető: "Telepítés"
```

Frissítés Parancssorból

```bash
# Ellenőrzés
curl http://localhost/api/admin/updates/check

# Telepítés
./scripts/update.sh

# Visszaállítás
cp backups/updates/pre_update_*/database.sql .
docker exec -i epub-postgres psql -U epub_user epub_translator < database.sql
docker compose restart
```

---

📱 PWA Mobil Támogatás

Telepítés Mobilra

```
1. Nyisd meg böngészőben: http://[IP]
2. Menü → "Telepítés"
3. Ikon a kezdőképernyőn
4. Offline is működik
```

---

🔌 API Dokumentáció

Regisztráció

```bash
# Regisztráció
curl -X POST http://localhost/api/register \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Gábor",
    "last_name": "Kiss",
    "email": "gabor.kiss@example.com",
    "password": "SecurePass1!"
  }'

# Válasz
{
    "success": true,
    "user_id": 2,
    "internal_email": "gabor.kiss@epub.local",
    "tokens": 5
}
```

Bejelentkezés

```bash
curl -X POST http://localhost/login \
  -d "email=gabor.kiss@example.com" \
  -d "password=SecurePass1!"
```

Belső Email

```bash
# Bejövő üzenetek
curl http://localhost/api/internal-mail/inbox \
  -H "Cookie: session=..."

# Üzenet küldése
curl -X POST http://localhost/api/internal-mail/send \
  -H "Content-Type: application/json" \
  -d '{
    "recipient": "admin@epub.local",
    "subject": "Token kérés",
    "body": "Szeretnék több tokent kérni."
  }'
```

Fő API Végpontok

Végpont Módszer Leírás
/api/register POST Felhasználó regisztráció
/api/internal-mail/inbox GET Bejövő üzenetek
/api/internal-mail/send POST Belső email küldése
/api/internal-mail/unread-count GET Olvasatlanok száma
/api/library/batch-upload POST Kötegelt feltöltés
/api/library/stats GET Könyvtár statisztikák
/api/admin/updates/check POST Frissítés ellenőrzése
/api/admin/updates/install POST Frissítés telepítése

---

🔧 Karbantartás

Automatikus Feladatok

Feladat Gyakoriság Időpont
Biztonsági mentés Hetente Vasárnap 03:00
Docker takarítás Hetente Vasárnap 04:00
Frissítés ellenőrzés Állítható Óránként

Kézi Parancsok

```bash
# Státusz
./scripts/status.sh

# Biztonsági mentés
./scripts/backup.sh

# Frissítés
./scripts/update.sh

# Logok
docker compose logs -f backend
```

---

🔍 Hibaelhárítás

Regisztrációs Problémák

```bash
# Regisztráció le van tiltva?
grep ENABLE_REGISTRATION .env

# Rate limit elérve?
# Várj 1 órát, vagy állítsd át a limitet

# Email már létezik?
curl http://localhost/api/register \
  -d '{"email": "existing@email.com", ...}'
```

Frissítési Hibák

```bash
# Visszaállítás mentésből
ls backups/updates/
# Használd a legfrissebb mentést

# Konténerek újraindítása
docker compose restart
```

Email Nem Érkezik

```bash
# MailHog ellenőrzése
curl http://localhost:8025

# API ellenőrzése
curl http://localhost/api/internal-mail/inbox \
  -H "Cookie: session=..."
```

---

❓ GYIK

Regisztráció

K: Ingyenes a regisztráció?
V: Igen! A rendszer teljesen ingyenes, a tokenek belső elszámolási egységek.

K: Mennyi token jár regisztrációnál?
V: Alapértelmezetten 5 token (5 fordítás).

K: Mi az a belső email cím?
V: Egy @epub.local végű cím a rendszeren belüli kommunikációhoz.

K: Hogyan kaphatok több tokent?
V: A dashboard-on kattints a "Tokenek kérése" gombra.

Frissítés

K: Hogyan frissíthetek v8-ról v9-re?
V: Futtasd az install.sh-t és válaszd az "1) Frissítés" lehetőséget.

K: Elvesznek az adataim frissítéskor?
V: Nem, a frissítés megőrzi az adatbázist és a konfigurációt.

---

📊 Verzió Történet

v9.0.0 (2025-01-15) - "User Portal"

· 🆕 Felhasználói regisztrációs oldal
· 🆕 Belső email automatikus generálás
· 🆕 Kezdő tokenek új felhasználóknak
· 🆕 Regisztrációs gomb a bejelentkezésnél
· 🆕 Továbbfejlesztett frissítési rendszer
· 🎨 Modernizált felhasználói felület

v8.0.0 (2024-12-01) - "Library Manager"

· Drag & Drop könyvtárfeltöltés
· Belső email rendszer alapok
· MailHog integráció

v7.0.0 (2024-09-15) - "Self-Evolving Translator"

· GitHub Auto-Update
· Öntanuló fordítási memória
· Glosszárium kezelés
· Valós idejű kollaboráció

v6.0.0 (2024-06-15)

· Hibrid fordítási stratégia
· Kollaboratív fordítás

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

```bash
git clone https://github.com/sorosg/Epub-translate.git
cd Epub-translate
docker compose up -d
```

· Hibajelentés: https://github.com/sorosg/Epub-translate/issues
· Feature Request: https://github.com/sorosg/Epub-translate/discussions

---

📄 Licensz

MIT License

---

🙏 Köszönetnyilvánítás

· DeepSeek - Nyílt forráskódú AI modellek
· Ollama - Modell futtatás
· Flask - Web keretrendszer
· EbookLib - EPUB kezelés
· MailHog - Helyi email szerver

---

📞 Támogatás

· 📧 Email: sorosgergo@gmail.com
· 🌐 GitHub: https://github.com/sorosg/Epub-translate
· 📚 Dokumentáció: https://github.com/sorosg/Epub-translate/wiki

---

Készült ❤️-vel Magyarországon

Utolsó frissítés: 2026. július 12.

```
```