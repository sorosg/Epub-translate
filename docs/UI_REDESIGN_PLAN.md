# 🎨 UI Redesign Terv — React 18 SPA

> **Státusz:** Jóváhagyva (2026-08-12)
> **Cél:** A teljes webes felület modernizálása React 18 SPA keretrendszerrel.
> **Verzió:** v2.2.0 (megvalósult)

---

## 1. Háttér és motiváció

A jelenlegi frontend 12 darab Jinja2 HTML template-ből áll, amelyekben az inline JavaScript és CSS kód erősen összefonódik a backend logikával. Ez:

- nehezen karbantartható (duplikált kód, pl. a modellválasztás a dashboardon ÉS az adminban is megtalálható),
- nem igazán mobilbarát,
- nem ad egységes visszajelzést a felhasználónak (csak részleges toast/loading),
- nehezen bővíthető új funkciókkal.

**Megoldás:** A frontend teljes újraírása React 18 + Vite + TypeScript stackkel, a backendet pedig JSON API-ként használva.

---

## 2. Technológiai stack

| Réteg | Technológia | Indok |
|-------|-------------|-------|
| Keretrendszer | React 18 | komponens-alapú, széles ökoszisztéma |
| Build | Vite 5 | gyors fejlesztés (HMR), optimalizált production build |
| Nyelv | TypeScript 5 | típusbiztonság, karbantarthatóság |
| Routing | React Router 6 | kliensoldali navigáció |
| Állapotkezelés | Zustand 4 | egyszerű, kevés boilerplate |
| Adatlekérés | TanStack Query 5 | cache, polling, retry, betöltés/hiba kezelés |
| Stílus | Tailwind CSS 3 | modern, konzisztens design (sötét téma) |
| Ikonok | Lucide React | könnyű, egységes ikonkészlet |
| i18n | i18next + react-i18next | többnyelvű felület (hu/en) |

---

## 3. Design alapelvek

1. **Egy helyen az összetartozó dolgok** — pl. a modellválasztás csak a Beállításoknál
2. **Progressive disclosure** — a haladó/ritkán használt funkciók lenyítható accordion mögött
3. **Egységes visszajelzés** — minden művelet toast-ot ad, a hosszú folyamatok loading overlay-t
4. **Mobil-first** — 44px érintési célterület, alsó navigáció, FAB
5. **Sötét téma (fix)** — nincs sötét/világos váltó, egységes modern sötét paletta

---

## 4. App Shell architektúra

```
┌──────────────────────────────────────────────┐
│ TOPBAR: ☰ logo · 🔍 · 🌐hu/en · 🔔 · 👤      │
├──────────┬───────────────────────────────────┤
│ SIDEBAR  │  TARTALOM (React Router <Outlet/>)│
│ össze-   │                                     │
│ csukható │                                     │
├──────────┴───────────────────────────────────┤
│ ALSÓ SÁV (mobil): műveletek, FAB             │
└──────────────────────────────────────────────┘
```

---

## 5. Oldalak / főbb nézetek

| Oldal | Útvonal | Leírás |
|-------|---------|--------|
| Bejelentkezés | `/login` | session alapú auth |
| Vezérlőpult | `/` | áttekintő: aktív fordítások + gyors feltöltés + stat mini-kártyák |
| Könyvtár | `/library` | könyvek böngészése, szűrés, batch feltöltés, szerkesztés |
| Olvasó | `/reader/:id` | EPUB olvasás, TOC, könyvjelző |
| Átnézés | `/review/:id` | lefordított fejezetek szerkesztése |
| Beállítások | `/settings` | modell, paraméterek, profil, értesítések, nyelv |
| Olvasási előzmény | `/history` | legutóbb olvasott könyvek |
| Statisztika | `/stats` | fordítási statisztika |
| Admin | `/admin/*` | felhasználók, logok, frissítés, rendszer |

---

## 6. Backend kapcsolat

A Flask backend továbbra is a hitelesítést (session cookie) és az üzleti logikát szolgáltatja. A frontend az alábbi JSON végpontokat használja:

**Meglévő (használható):**
- `POST /login`, `GET /logout`
- `POST /upload`, `GET /api/status/:id`, `GET /api/translations/events`
- `GET /download/:id`, `POST /delete/:id`
- `GET /api/library/list`, `POST /api/library/upload`, `POST /api/library/edit/:id`, `POST /api/library/delete/:id`, `POST /api/library/toggle/:id`, `POST /api/library/batch-upload`, `POST /api/library/recommend`, `POST /api/library/fetch-metadata`, `POST /api/library/extract-metadata`
- `GET /api/reader/:id/chapters`, `GET /api/reader/:id/chapter/:idx`, `GET/POST /api/reader/:id/bookmark`
- `GET /api/models/list`, `POST /api/models/switch`, `POST /api/models/pull`
- `POST /api/user/settings`, `GET /api/notifications`
- `GET /api/system/monitor`, `GET /api/system/containers`
- `GET /api/review/save/:id`

**Új (a SPA-hoz és a bővítésekhez):**
- `GET /api/profile` — profil adat (a `GET /profile` HTML helyett)
- `GET /api/review/:id` — fejezetek JSON-ban (a `GET /review/:id` HTML helyett)
- `GET /api/admin/users` — felhasználó lista JSON-ban
- `GET /api/admin/logs` — log tartalom JSON-ban
- `GET /api/history`, `POST /api/history` — olvasási előzmény
- `GET /api/stats/summary` — statisztika
- `GET /api/library/:id/toc` — címtáblázat
- `GET /api/user/settings` — beállítások betöltése

---

## 7. Új adatbázis modell: ReadingHistory

```
ReadingHistory:
  id: Integer (PK)
  user_id: Integer (FK → users.id)
  book_id: Integer (FK → books.id)
  chapter_index: Integer
  scroll_position: Integer
  last_read_at: DateTime
```

Cél: a felhasználó olvasási pozíciójának és előzményeinek követése.

---

## 8. Megvalósítási fázisok

| Fázis | Tartalom |
|-------|----------|
| 0. Alapozás | Vite + React + TS + Tailwind scaffold, App Shell, routing, API client, login |
| 1. Fordítás | Dashboard, feltöltés, progress, ModelSelector |
| 2. Könyvtár | Library oldal, batch, szerkesztés, dedup |
| 3. Olvasó + előzmény | Reader, TOC, bookmark, ReadingHistory |
| 4. Beállítások | modell + paraméterek + profil egy helyen |
| 5. Statisztika + Review | Stats, Review |
| 6. Admin | felhasználók, logok, frissítés |
| 7. i18n + polish | nyelvváltás, toast/loading, mobil teszt |

---

## 9. Dokumentáció és követhetőség

Minden fázishoz és fontos komponenshez `.md` dokumentáció készül a `docs/` mappában:

- `UI_REDESIGN_PLAN.md` — ez a terv
- `ARCHITECTURE.md` — az új architektúra
- `DEVELOPMENT_LOG.md` — fázisonkénti haladás
- `frontend/README.md` — frontend fejlesztői útmutató

---

*Készült: 2026-08-12 · v2.0.0 terv*