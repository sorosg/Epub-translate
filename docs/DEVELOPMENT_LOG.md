# 📓 EPUB Fordító – Fejlesztési Napló

> A frontend UI-redesign projekt fejlesztése során az összes fontos lépés és döntés dokumentálása.

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