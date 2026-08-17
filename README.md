# EPUB Fordító Rendszer v3.0

EPUB könyvek **angolról magyarra** fordítása, öntanuló módon.

![Version](https://img.shields.io/badge/version-3.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-brightgreen)

---

## Mi ez?

Egy alkalmazás, ami EPUB könyveket fordít magyarra. A minőséget folyamatosan javítja: a korábban lefordított könyvekből **fordítási memóriát**, **glosszáriumot** és **stílusmintát** épít.

## Két futási mód

| Mód | Kinek | Motor |
|-----|-------|-------|
| **Asztali alkalmazás** (Windows / macOS) | a fő használati út, egyfelhasználós | DeepSeek Pro (alapból), helyi Ollama (opcionális, GPU) |
| **Docker szerver** (Linux) | haladó, többfelhasználós | ugyanaz a kettő |

## AI-motorok

A Beállításokban választhatsz:

- **☁️ DeepSeek Pro (ajánlott)** — gyors, jó minőség, alacsony költség (~100 Ft/könyv). Csak egy `sk-...` API kulcs kell.
- **🖥️ Helyi Ollama (opcionális)** — az adat a gépeden marad, offline is megy. **GPU kell hozzá** (a modell a VRAM-hoz igazodik); CPU-n hetekig tart, ezért nem ajánlott.

## Funkciók

- **Checkpoint / folytatás** — megszakadás után ott folytatja, ahol abbahagyta.
- **Fordítási memória** — a már lefordított mondatokat (pontos SHA256) újrahasználja.
- **Glosszárium** — automatikusan épülő angol→magyar kifejezések a következetességért.
- **Kontextus-könyvek** — a sorozatok korábbi részei terminológiai/stílus kontextust adnak.
- **Tegezés / magázás** — a Beállításokban választható.
- **Olvasó** — fejezetszintű, felbontás-függő oldaltördeléssel, mobilbarát.
- **Email értesítés** — fordítás végén, a kész EPUB csatolásával (24 MB-ig; SMTP konfigurálható).

> A korábbi „kétmenetes fordítás" (AI + külön minőségellenőrző menet) **kikapcsolásra került**, mert a modell duplikálta a szöveget — a jelenlegi mnemets egyetlen, node-onkénti fordítás.

## Asztali alkalmazás (Windows / macOS)

Nem kell Docker, nem kell parancssor.

1. Töltsd le a telepítőt a **GitHub Actions → Build Desktop** futás **Artifacts** füléről (Windows: `.exe` / NSIS, macOS: `.dmg`).
2. Telepítsd és indítsd el.
3. A Beállításokban add meg a DeepSeek API kulcsodat (vagy csatlakoztasd az Ollama GPU-t).
4. Tölts fel egy EPUB-ot, indítsd a fordítást.

A desktop verzió **egyfelhasználós**: nincs bejelentkezés, a könyvtár a te saját gyűjteményed, és minden adat a gépeden (`~/.epub-translator`).

## Docker szerver (Linux)

Többfelhasználós, közös könyvtár, Linuxra.

```bash
git clone https://github.com/sorosg/Epub-translate.git
cd Epub-translate
bash install.sh
```

- Web: `http://localhost:8080`
- Admin: `admin@epub-translator.local` / `Abrakadabra`
- MailHog (email-teszt): `http://localhost:8025`

## Dokumentáció

- `USER_GUIDE.md` — felhasználói kézikönyv
- `CHANGELOG.md` — verziótörténet
- `docs/DEVELOPMENT_LOG.md` — fejlesztői napló
- `ROADMAP.md` — fejlesztési terv

## Fejlesztés

Egyetlen kódbázis a szerver (Docker) és a desktop verzióhoz.
- **Backend:** Python / Flask (`backend/` / `src/backend/`)
- **Frontend:** React 18 + Vite + TypeScript + Tailwind (`frontend/` / `src/frontend/`)
- **Desktop:** Electron + PyInstaller + SQLite (`desktop/`)
- Részletek és konvenciók: `DEV_CONTEXT.md`.

---

*Készült ❤️-vel Magyarországon – v3.0.0*