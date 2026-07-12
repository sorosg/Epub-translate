```markdown
# EPUB Fordító Rendszer v9.1

## 📚 "Enhanced Studio" - Továbbfejlesztett Stúdió

![Version](https://img.shields.io/badge/version-9.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-ready-brightgreen)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04+-orange)
![PWA](https://img.shields.io/badge/PWA-ready-purple)
![Update](https://img.shields.io/badge/auto--update-ready-success)
![Dark Mode](https://img.shields.io/badge/dark%20mode-supported-black)
![i18n](https://img.shields.io/badge/i18n-5%20languages-blue)

---

## 🎯 Rendszer Áttekintés

Az EPUB Fordító Rendszer egy **teljesen ingyenes, helyben futó, öntanuló** megoldás EPUB könyvek fordítására. A DeepSeek AI modelleket használja, amelyek a saját gépeden futnak - **nincs szükség API kulcsra, internetkapcsolatra (a modell letöltése után), vagy előfizetésre!**

### 🌟 Legfontosabb Jellemzők

- ✅ **100% Ingyenes** - Nincs rejtett költség, előfizetés vagy API díj
- ✅ **Helyben Fut** - Minden adat a saját gépeden marad
- ✅ **Offline Működés** - Internet csak a modell első letöltéséhez kell
- ✅ **Öntanuló** - A fordítási memória és kontextus tanulás folyamatosan javul
- ✅ **Önfrissítő** - Automatikus GitHub frissítések, egykattintásos frissítés
- ✅ **Dark Mode** - Sötét és világos téma támogatás
- ✅ **Többnyelvű** - Magyar, Angol, Német, Francia, Spanyol felület
- ✅ **Billentyűparancsok** - 8 gyorsbillentyű a hatékony munkához
- ✅ **Dashboard 2.0** - Interaktív grafikonok és statisztikák
- ✅ **Integrációk** - Calibre, Kindle, WordPress, Chrome bővítmény

---

## 📋 Tartalomjegyzék

1. [Rendszerkövetelmények](#-rendszerkövetelmények)
2. [Gyors Telepítés](#-gyors-telepítés)
3. [Frissítés Meglévő Telepítésről](#-frissítés-meglévő-telepítésről)
4. [Újdonságok a v9.1-ben](#-újdonságok-a-v91-ben)
5. [Dark Mode](#-dark-mode)
6. [Billentyűparancsok](#-billentyűparancsok)
7. [Dashboard 2.0](#-dashboard-20)
8. [Többnyelvű Felület](#-többnyelvű-felület)
9. [Integrációk](#-integrációk)
10. [Architektúra](#-architektúra)
11. [Konfiguráció](#-konfiguráció)
12. [API Dokumentáció](#-api-dokumentáció)
13. [Karbantartás](#-karbantartás)
14. [Hibaelhárítás](#-hibaelhárítás)
15. [GYIK](#-gyik)
16. [Verzió Történet](#-verzió-történet)

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

### Böngésző Támogatás

| Böngésző | Dark Mode | PWA | Billentyűparancsok |
|----------|-----------|-----|-------------------|
| Chrome 90+ | ✅ | ✅ | ✅ |
| Firefox 88+ | ✅ | ✅ | ✅ |
| Safari 14+ | ✅ | ✅ | ⚠️ Részleges |
| Edge 90+ | ✅ | ✅ | ✅ |

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

# 3. Indítsd el
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

Frissítés a Programból (Webes Felület)

```
1. Admin → Frissítés Kezelés
2. "Frissítések ellenőrzése"
3. Ha van új verzió → "Telepítés"
4. Automatikus mentés → Letöltés → Telepítés
```

Frissítés Parancssorból

```bash
# 1. lehetőség: Telepítő script (automatikus észlelés)
./install.sh
# Válaszd: 1) Frissítés

# 2. lehetőség: Gyorsfrissítő
./scripts/update.sh

# 3. lehetőség: API-n keresztül
curl -X POST http://localhost/api/admin/updates/install/1
```

Frissítési Csatornák

Csatorna Leírás Frissítési Gyakoriság
stable Stabil, tesztelt verziók Havonta
beta Előzetes verziók Hetente
nightly Fejlesztői verziók Naponta

---

🆕 Újdonságok a v9.1-ben

🌙 Dark Mode

· Sötét és világos téma támogatása
· Automatikus váltás a rendszer beállításai alapján
· Egyéni beállítás felhasználónként
· CSS változók a könnyű testreszabhatóságért
· Gyorsbillentyű: Ctrl+Shift+D

⌨️ Billentyűparancsok

· 8 gyorsbillentyű a hatékony munkához
· Súgó ablak (? billentyű)
· Testreszabható parancsok
· Kontextus függő műveletek

📊 Dashboard 2.0

· Interaktív grafikonok (Chart.js)
· Havi fordítási statisztikák
· Minőségi mutatók
· Token felhasználás követése
· Valós idejű frissítés

🌍 Többnyelvű Felület

· 5 nyelv támogatása:
  · 🇭🇺 Magyar
  · 🇬🇧 Angol
  · 🇩🇪 Német
  · 🇫🇷 Francia
  · 🇪🇸 Spanyol
· Automatikus nyelvfelismerés
· Flask-Babel integráció
· Könnyen bővíthető új nyelvekkel

🔗 Integrációk

📚 Calibre Plugin

· Könyvek küldése közvetlenül Calibre-ból
· Automatikus formátum felismerés
· Könyvtár szinkronizálás

📱 Kindle Send

· Fordított könyvek küldése Kindle eszközre
· Email alapú kézbesítés
· Több Kindle eszköz támogatása

🔌 WordPress Plugin

· Shortcode: [epub_translator]
· REST API végpontok
· Beágyazható iframe

🧩 Chrome Bővítmény

· Egy kattintásos fordítás
· Jobb klikk menü integráció
· Értesítések a fordítás állapotáról

---

🌙 Dark Mode

Használat

```
1. Kattints a 🌙 gombra a navigációs sávban
   VAGY
2. Használd a Ctrl+Shift+D billentyűkombinációt
   VAGY
3. Állítsd be a Felhasználói beállításokban
```

Színséma

Elem Világos Téma Sötét Téma
Háttér #ffffff #1a1a2e
Kártya #ffffff #1e1e3a
Szöveg #212529 #e0e0e0
Fejléc #f8f9fa #16213e

API Vezérlés

```bash
# Dark mode beállítása
curl -X PUT http://localhost/api/settings \
  -H "Content-Type: application/json" \
  -d '{"dark_mode": true}'
```

---

⌨️ Billentyűparancsok

Billentyű Művelet Leírás
Ctrl+Enter Fordítás indítása Elindítja a kiválasztott könyv fordítását
Ctrl+D Letöltés Legutóbbi fordítás letöltése
Ctrl+N Új fordítás Új fordítási oldal megnyitása
Ctrl+H Vezérlőpult Vissza a dashboard-ra
Ctrl+L Könyvtár Könyvtár kezelő megnyitása
Ctrl+Shift+D Dark Mode Sötét/világos téma váltás
Esc Bezárás Modális ablakok bezárása
? Súgó Billentyűparancsok listája

---

📊 Dashboard 2.0

Grafikonok

```javascript
// Havi fordítások vonaldiagram
new Chart(ctx, {
    type: 'line',
    data: {
        labels: ['Jan', 'Feb', 'Már', ...],
        datasets: [{
            label: 'Fordítások',
            data: [5, 12, 8, ...],
            borderColor: '#0d6efd'
        }]
    }
});

// Státusz eloszlás fánkdiagram
new Chart(ctx, {
    type: 'doughnut',
    data: {
        labels: ['Kész', 'Sikertelen', 'Folyamatban'],
        datasets: [{
            data: [15, 3, 2],
            backgroundColor: ['#198754', '#dc3545', '#ffc107']
        }]
    }
});
```

Statisztikai Kártyák

Kártya Adat Forrás
Tokenek Felhasználható tokenek száma /api/stats/dashboard
Fordítások Összes fordítás száma /api/stats/dashboard
Átlag Minőség Fordítások átlagos minősége (%) /api/stats/dashboard
Belső Email Felhasználó belső email címe Felhasználói adatok

---

🌍 Többnyelvű Felület

Támogatott Nyelvek

Kód Nyelv Teljesség
hu Magyar 100%
en English 100%
de Deutsch 80%
fr Français 80%
es Español 80%

Nyelv Váltás

```
1. Felhasználói beállítások → Nyelv
2. Böngésző automatikus felismerés
3. URL paraméter: ?lang=en
```

Új Nyelv Hozzáadása

```bash
# 1. Fordítási fájl létrehozása
cp backend/translations/en/LC_MESSAGES/messages.po \
   backend/translations/XX/LC_MESSAGES/messages.po

# 2. Fordítások szerkesztése
nano backend/translations/XX/LC_MESSAGES/messages.po

# 3. Fordítások fordítása
msgfmt backend/translations/XX/LC_MESSAGES/messages.po \
      -o backend/translations/XX/LC_MESSAGES/messages.mo

# 4. Újraindítás
docker compose restart backend
```

---

🔗 Integrációk

📚 Calibre Plugin

```bash
# Telepítés
cp integrations/calibre/calibre_plugin.py ~/.config/calibre/plugins/

# Használat
python3 calibre_plugin.py --send book.epub --target hu
```

📱 Kindle Send

```python
from integrations.kindle.kindle_send import KindleSender

sender = KindleSender(
    email="your@gmail.com",
    password="app-password",
    kindle_email="your@kindle.com"
)

sender.send_book("translated_book.epub", "A Nagy Gatsby")
```

🔌 WordPress Plugin

```php
// Shortcode használata
[epub_translator url="http://localhost"]

// PHP kódban
echo do_shortcode('[epub_translator]');

// REST API
GET /wp-json/epub-translator/v1/books
```

🧩 Chrome Bővítmény

```
1. Chrome → bővítmények → Fejlesztői mód
2. "Csomagolatlan bővítmény betöltése"
3. Válaszd: integrations/chrome/ mappát
4. Használat: jobb klikk EPUB linkre → Fordítás
```

---

🏗️ Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│                     Felhasználói Böngésző                      │
│                    http://localhost:80                        │
│                    🌙 Dark Mode | 🌍 i18n                     │
│                    ⌨️ Shortcuts | 📊 Charts                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                      Nginx (80/443)                          │
│              Reverse Proxy + Statikus Fájlok                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                  Flask Backend (5000)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐    │
│  │ Felhasználó  │ │ Dashboard    │ │ Integrációk       │    │
│  │ Beállítások  │ │ 2.0          │ │ - Calibre         │    │
│  ├──────────────┤ ├──────────────┤ │ - Kindle          │    │
│  │ Dark Mode    │ │ Chart.js     │ │ - WordPress       │    │
│  │ Toggle       │ │ Grafikonok   │ │ - Chrome          │    │
│  ├──────────────┤ ├──────────────┤ ├──────────────────┤    │
│  │ Nyelv Váltás │ │ Statisztikák │ │ Auto-Update       │    │
│  │ (i18n)       │ │              │ │ Manager           │    │
│  └──────────────┘ └──────────────┘ └──────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼──────┐   ┌────────▼────────┐   ┌─────▼──────┐
│  PostgreSQL  │   │     Ollama       │   │   Redis    │
│  + Users     │   │  DeepSeek AI    │   │   Cache    │
│  + Settings  │   │  Modellek       │   │            │
└──────────────┘   └─────────────────┘   └────────────┘
```

---

⚙️ Konfiguráció

.env Fájl (v9.1)

```env
# Verzió
VERSION=9.1.0
CODENAME="Enhanced Studio"
RELEASE_DATE=2025-03-15

# Admin
ADMIN_EMAIL=admin@epub-translator.local
ADMIN_PASSWORD=your-secure-password

# Felhasználói beállítások
ENABLE_REGISTRATION=true
DEFAULT_TOKENS=5
DEFAULT_LANGUAGE=hu

# Megjelenés
ENABLE_DARK_MODE=true
ENABLE_SHORTCUTS=true
ENABLE_I18N=true

# AI Modell
SELECTED_MODEL=deepseek-r1:8b
MAX_WORKERS=3

# Integrációk
ENABLE_CALIBRE=true
ENABLE_KINDLE=true
ENABLE_WP_PLUGIN=true
ENABLE_CHROME_EXT=true

# Auto-Update
ENABLE_AUTO_UPDATE=true
GITHUB_REPO=https://github.com/sorosg/Epub-translate.git
GITHUB_TOKEN=ghp_xxxxxxxxxxxx

# SMTP
SMTP_MODE=local
SMTP_HOST=mailhog
SMTP_PORT=1025
```

Felhasználói Beállítások API

```bash
# Beállítások lekérése
GET /api/settings

# Beállítások módosítása
PUT /api/settings
{
    "dark_mode": true,
    "language": "en",
    "shortcuts_enabled": true
}
```

---

🔌 API Dokumentáció

Új v9.1 Végpontok

Végpont Módszer Leírás
/api/settings GET/PUT Felhasználói beállítások
/api/stats/dashboard GET Dashboard statisztikák
/api/i18n/languages GET Elérhető nyelvek
/api/i18n/switch POST Nyelv váltás
/api/integrations/calibre/send POST Küldés Calibre-ba
/api/integrations/kindle/send POST Küldés Kindle-re

Dashboard API

```bash
curl http://localhost/api/stats/dashboard \
  -H "Cookie: session=..."

# Válasz:
{
    "total_translations": 25,
    "completed": 20,
    "avg_quality": 85,
    "monthly": {
        "2025-01": 5,
        "2025-02": 8,
        "2025-03": 12
    },
    "tokens_left": 3
}
```

---

🔧 Karbantartás

Rendszeres Feladatok

```bash
# Státusz ellenőrzése
./scripts/status.sh

# Biztonsági mentés
./scripts/backup.sh

# Frissítés
./scripts/update.sh

# Logok
docker compose logs -f backend
```

Dark Mode Testreszabása

```css
/* Saját dark mode színek */
:root {
    --bg-primary: #1a1a2e;    /* Sötét háttér */
    --card-bg: #1e1e3a;       /* Kártya háttér */
    --text-primary: #e0e0e0;  /* Szöveg szín */
}
```

Nyelvi Fájlok Frissítése

```bash
# Új fordítások fordítása
pybabel compile -d backend/translations

# Fordítások frissítése a kódból
pybabel extract -F babel.cfg -o messages.pot .
pybabel update -i messages.pot -d backend/translations
```

---

🔍 Hibaelhárítás

Dark Mode Problémák

```bash
# Dark mode nem működik?
# Ellenőrizd a localStorage-t:
localStorage.getItem('theme')

# Töröld a cache-t:
localStorage.removeItem('theme')
location.reload()
```

Nyelvi Problémák

```bash
# Fordítások újratöltése
docker exec -it epub-backend pybabel compile -d translations

# Nyelv visszaállítása
curl -X PUT http://localhost/api/settings \
  -d '{"language": "hu"}'
```

Integrációs Hibák

```bash
# Calibre plugin
python3 -c "from calibre_plugin import EPUBTranslatorPlugin; print('OK')"

# Kindle send teszt
python3 -c "from kindle_send import KindleSender; print('OK')"
```

---

❓ GYIK

Dark Mode

K: Hogyan kapcsolhatom be a dark mode-ot?
V: Kattints a 🌙 gombra, használd a Ctrl+Shift+D billentyűt, vagy állítsd be a felhasználói beállításokban.

K: Megjegyzi a rendszer a beállításomat?
V: Igen! A beállítás tárolódik a localStorage-ban és a szerveren is.

Nyelvek

K: Hogyan válthatok nyelvet?
V: A felhasználói beállításokban válaszd ki a kívánt nyelvet.

K: Hozzáadhatok új nyelvet?
V: Igen! Másold le valamelyik meglévő fordítási fájlt és fordítsd le.

Integrációk

K: Hogyan használhatom a Calibre plugin-t?
V: Másold a calibre_plugin.py fájlt a Calibre plugins mappájába.

K: Működik a Kindle send Gmail nélkül?
V: Igen, bármilyen SMTP szerver használható.

---

📊 Verzió Történet

v9.1.0 (2025-03-15) - "Enhanced Studio"

· 🆕 Dark Mode támogatás
· 🆕 Billentyűparancsok (8 gyorsbillentyű)
· 🆕 Dashboard 2.0 (Chart.js grafikonok)
· 🆕 Többnyelvű felület (5 nyelv)
· 🆕 Calibre integráció
· 🆕 Kindle Send támogatás
· 🆕 WordPress plugin
· 🆕 Chrome bővítmény
· 🎨 Továbbfejlesztett felhasználói élmény

v9.0.0 (2025-01-15) - "User Portal"

· Felhasználói regisztráció
· Belső email rendszer
· Kezdő tokenek

v8.0.0 (2024-12-01) - "Library Manager"

· Drag & Drop könyvtárfeltöltés
· MailHog integráció

v7.0.0 (2024-09-15) - "Self-Evolving Translator"

· GitHub Auto-Update
· Öntanuló fordítási memória
· Valós idejű kollaboráció

v6.0.0 (2024-06-15)

· Hibrid fordítási stratégia
· Kollaboratív fordítás

v5.0.0 (2024-01-15)

· Könyv adatbázis
· AI műfaj felismerés

v4.0.0 (2024-01-01)

· Hibrid SMTP
· Vírusellenőrzés

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
· Chart.js - Interaktív grafikonok
· Flask-Babel - Többnyelvűség
· EbookLib - EPUB kezelés
· MailHog - Helyi email szerver

---

📞 Támogatás

· 📧 Email: sorosgergo@gmail.com
· 🌐 GitHub: https://github.com/sorosg/Epub-translate
· 📚 Dokumentáció: https://github.com/sorosg/Epub-translate/wiki

---

Készült ❤️-vel Magyarországon

Utolsó frissítés: 2026. július 2.

```
```