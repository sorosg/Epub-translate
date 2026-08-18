# 🖥️ EPUB Fordító – Asztali (desktop) csomag

**Verzió:** v3.0.1 · **Utolsó frissítés:** 2026-08-17

## Architektúra
- **Electron** az ablak; a buildelt React SPA-t a `desktop/backend_entry.py` Flask
  sidecar szolgálja ki (egy porton az API-val együtt).
- A sidecar `DESKTOP_MODE=1`-gyel indítja a közös backendet → **SQLite** adatok +
  automatikus helyi felhasználó (nincs bejelentkezés).
- Csomagolás: **electron-builder** (app) + **PyInstaller** (backend sidecar).
- A közös `backend/app.py` és `frontend/` **változatlan** — ez a réteg csak vékony
  csomagolás, nem fork.

## Telepítő (a CI gyártja le)
A `.github/workflows/desktop-build.yml` egy `v*` tag push-ra fut:
- Windows: `.exe` (NSIS)
- macOS: `.dmg` (a notarization Apple-fejlesztői fiókot igényel)

Az eredmény az **Actions → Build Desktop → Artifacts** fülről tölthető le.

## Fejlesztői build (manuálisan)
```bash
# 1) frontend build
cd src/frontend && npm ci && npm run build

# 2) backend PyInstaller bináris
cd ../backend && pip install -r requirements-desktop.txt pyinstaller
pyinstaller --onefile --name backend --paths . --hidden-import app \
  --hidden-import config --hidden-import models \
  --distpath ../../desktop/pybackend ../../desktop/backend_entry.py

# 3) Electron telepítő
cd ../../desktop && npm install && npx electron-builder --win --publish never
```

## Jelenlegi állapot (v3.0.1)
- ✅ Platformfüggetlen backend: `DATA_DIR` (~/.epub-translator), SQLite fallback,
  `DESKTOP_MODE` automatikus bejelentkezés, GPU-detektálás (`gpu_available`).
- ✅ Desktop scaffold: `backend_entry.py` (SPA+API egy porton), `main.js`,
  `package.json`, CI (`desktop-build.yml`).
- ✅ Export/import adatmentés a Beállításokban (a teljes `DATA_DIR` ZIP-ben).
- ✅ E2E teszt: DESKTOP_MODE=1 + SQLite + SPA → `/health` 200, `/api/profile`
  auto-login `desktop@local`.
- ⬜ Hátralévő: macOS notarization (Apple-fejlesztői fiók); a Windows `.exe`
  telepítőt a CI már legyártja.

## 📤 Push (a Desktop repó a git-forrás)
A Desktop másolat a push-forrás (SSH `git@github.com:sorosg/Epub-translate.git`,
branch `main`). Folyamat: WSL → Desktop szinkron → `git add/commit` → (kódváltozás
esetén) `git tag vX.Y.Z` + `git push origin main vX.Y.Z`.