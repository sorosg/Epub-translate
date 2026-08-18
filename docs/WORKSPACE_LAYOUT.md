# 🗂️ EPUB Fordító – Munkakönyvtárak rendje

Ez a dokumentum pontosan leírja, hogy **melyik mappa mire való**, hogy ne keveredjenek
össze a forráskód, a Docker-példány és a GitHub tároló.

---

## A 3 fontos hely (aktuális, v3.0.1)

| # | Elérési út | Szerep | Mit csinálsz itt |
|---|-----------|--------|------------------|
| 1 | `/home/sorosg/epub-translator` | **KANONIKUS forrás** (WSL) | Itt **szerkeszted** a kódot, itt buildelsz/tesztelsz |
| 2 | `/mnt/c/Users/soros/Desktop/Epub-translate` | **GIT-push tükör** (Windows) | Ide **szinkronizálsz**, innen commit + tag + push |
| 3 | `github.com/sorosg/Epub-translate` | **GITHUB** | A `2`-es repo nyilvános mása (`git push` ide küld) |

> ⚠️ **A legfontosabb szabály:** a kódot **csak a WSL-ben (`/home/sorosg/epub-translator`)**
> szerkeszd. A Desktop mappa **csak tükör** — oda szinkronizálunk, és onnan pusholunk,
> de kézzel ne ott javíts kódot.

---

## 1. WSL – kanonikus forrás (itt dolgozunk)

```
/home/sorosg/epub-translator/
├── backend/          # Flask (app.py, config.py, models.py, requirements*, templates)
├── frontend/         # React SPA (src/, package.json, Dockerfile, nginx.conf)
├── desktop/          # Electron + PyInstaller + SQLite (asztali csomag)
├── .github/workflows/# CI (ci.yml + desktop-build.yml)
├── docs/             # dokumentáció (napló, terv, elrendezés)
├── *.md, install.sh, VERSION.txt, .env
```

- **Ez a Docker build-forrás** és a desktop build forrása is.
- Itt futtatod: `docker compose build` / `up`, `py_compile`, `npm build`.

## 2. Windows Desktop – git-push tükör

```
/mnt/c/Users/soros/Desktop/Epub-translate/
├── src/backend/      # ← a WSL backend/ szinkronizált mása
├── src/frontend/     # ← a WSL frontend/ szinkronizált mása
├── desktop/          # ← a WSL desktop/ szinkronizált mása
├── .github/          # ← a WSL .github/ szinkronizált mása
└── *.md, VERSION.txt, install.sh
```

- A git remote itt **SSH** (`git@github.com:sorosg/Epub-translate.git`, branch `main`).
- Innen commitolsz + pusholsz, és a `v*` tag push indítja a CI desktop-buildet.

## 3. Szinkron irány (mindig WSL → Desktop)

```bash
S=/home/sorosg/epub-translator
T=/mnt/c/Users/soros/Desktop/Epub-translate
rsync -a "$S/backend/" "$T/src/backend/"
rsync -a "$S/frontend/src/" "$T/src/frontend/src/"
rsync -a "$S/desktop/" "$T/desktop/"
rsync -a "$S/.github/" "$T/.github/"
rsync -a "$S"/*.md "$S/install.sh" "$S/VERSION.txt" "$T/"
```

> A `.env` **soha** nem kerül a Desktop repóba (a `.gitignore` kizárja).

---

*Utolsó frissítés: 2026-08-17 · v3.0.1*