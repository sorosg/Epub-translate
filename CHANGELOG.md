# 📋 EPUB Fordító – Fejlesztési Napló (Changelog)

## v2.0.0 – 2026-08-12 (aktuális) – Teljes UI redesign + végleges telepíthető verzió

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

*Utolsó frissítés: 2026-08-12 · v2.0.0*
