# 🖥️ EPUB Fordító – Asztali (desktop) csomag

## Architektúra
- **Electron** az ablak; a buildelt React SPA-t (frontend/dist) szolgálja ki.
- **Flask sidecar** (desktop/backend_entry.py) indítja a közös backendet
  `DESKTOP_MODE=1`-gyel → SQLite adatok + automatikus helyi felhasználó.
- Csomagolás: **electron-builder** (app) + **PyInstaller** (backend sidecar).
- A közös `backend/app.py` és `frontend/` VÁLTOZATLAN; csak ez a desktop-réteg plusz.

## Indítás fejlesztői módban
1. `cd frontend && npm ci && npm run build`  (legyártja a dist-et)
2. `cd ../desktop && npm ci && npm start`

## Telepítő build (a CI is ezt csinálja)
- Windows: `npm run dist:win`
- macOS:   `npm run dist:mac`
A macOs .dmg-hez Apple fejlesztői fiók + notarization ajánlott (különben
„nem azonosított fejlesztő" figyelmeztetés).

## Jelenlegi állapot (2026-08-16, v2.6.8)
- ✅ Backend alap platformfüggetlen: DATA_DIR (~/.epub-translator), SQLite fallback,
     _ensure_column, DESKTOP_MODE automatikus bejelentkezés, _trans_log.
- ✅ Desktop scaffold + E2E teszt: backend_entry.py (SPA+API egy porton), main.js, package.json, CI.
  Az E2E teszt (DESKTOP_MODE=1 + SQLite + buildelt SPA) SIKERES: /health 200,
  /api/profile auto-login 'desktop@local'.
- ⬜ Hátralévő: PyInstaller + electron-builder éles futtatás/tesztelés,
     AI-motor irányelvek UI-ba (GPU-kapcsoló + VRAM-modell + figyelmeztetés),
     macOS notarization.
