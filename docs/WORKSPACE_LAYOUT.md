# 🗂️ EPUB Fordító – Munkakönyvtárak rendje

Ez a dokumentum pontosan leírja, hogy **melyik mappa mire való**, hogy ne keveredjenek
össze a forráskód, a telepített példány és a GitHub tároló.

---

## A 3 különálló hely

| # | Elérési út | Szerep | Mikor használd |
|---|-----------|--------|----------------|
| 1 | `/mnt/c/Users/soros/Desktop/Epub-translate` | **FORRÁS-repo** (a GitHub tükre) | Ezt **szerkeszted**, innen commitolsz + pusholsz |
| 2 | `/home/sorosg/epub-translator` | **TELEPÍTETT példány** (futó rendszer) | Ezt **indítod / nézed / frissíted** – ide ne írj kódot |
| 3 | `github.com/sorosg/Epub-translate` | **GITHUB** | A `1`-es repo nyilvános mása (a `git push` ide küld) |

> ⚠️ **A legfontosabb szabály:** a kódot **csak az `1`-es mappában** szerkeszd.
> A `2`-es mappa a telepítő által **generált futtató példány** – ha ott javítasz,
> az a frissítéskor felülíródik és elveszik.

---

## 1. Forrás-repo – itt dolgozunk

```
/mnt/c/Users/soros/Desktop/Epub-translate/
├── src/                      ← a teljes forráskód
│   ├── backend/              ← Flask backend (app.py, config.py, models.py, templates/)
│   ├── frontend/             ← React SPA (src/, Dockerfile, nginx.conf, package.json)
│   ├── ollama/               ← Ollama konténer (Dockerfile + healthcheck)
│   └── docker-compose.yml    ← konténer definíciók (nginx/backend/postgres/ollama/...)
├── install.sh                ← telepítő/frissítő
├── docs/                     ← dokumentáció
├── README.md, CHANGELOG.md, VERSION.txt
└── _archiv/                  ← felesleges, archivált fájlok (nem a git tetején)
```

### Itt végezd ezeket
- Kód módosítása (backend + frontend)
- Dokumentáció frissítése
- `git add` + `git commit` + `git push origin main`

---

## 2. Telepített példány – fut, ne szerkeszd

```
/home/sorosg/epub-translator/
├── docker-compose.yml        ← az install.sh generálja
├── .env                      ← a telepítő hozza létre
├── backend/, frontend/       ← az install.sh másolja (futó kódról tükör)
├── logs/, book_database/, translation_memory/, ...  ← futás közbeni adatok
└── .install_config           ← a telepítő tárolja itt a verziót
```

> A `2`-es mappát az install.sh **`cp -a "$SRC_DIR"/* .`** paranccsal tölti meg.
> Ha ide is mástol a fejlesztői fájlokat (pl. `docs/`, `reset_admin_password.py`),
> az fölösleges duplikáció, ami összezavar.

### Itt végezd ezeket
- Frissítés: `bash install.sh` (a Desktop repóból futtasd, ne ide másolva)
- Státusz: `docker compose ps`
- Web: `http://localhost:8080`

---

## 3. GitHub – a push célpontja

```
git remote -v
# origin  git@github.com:sorosg/Epub-translate.git
```

A push innen történik: a Desktop repó `main` ága → GitHub `main` ága.

---

## 🧪 Hogyan tesztelj telepítést helyesen

### Friss telepítés tesztelése (ajánlott)
A telepítőt **a Desktop repóból** futtasd, mert ott van a friss forrás:

```bash
cd /mnt/c/Users/soros/Desktop/Epub-translate
./install.sh
```

A script a `$HOME/epub-translator`-ba telepít (a `2`-es mappába), és a repo `src/`-jéből másol.

### Frissítés tesztelése
```bash
cd /mnt/c/Users/soros/Desktop/Epub-translate
./install.sh
# Válaszd: 1) Frissítés
```

### Gyors fordulat, ha dolgozol
```bash
# Szerkesztés után a forrás-repóban:
cd /mnt/c/Users/soros/Desktop/Epub-translate
git add -A
git commit -m "leírás"
git push origin main

# Friss telepítés teszt:
cd /mnt/c/Users/soros/Desktop/Epub-translate
./install.sh
```

---

## 🧹 Amit a mappákból kitakarítottunk

- A `2`-es (`/home/sorosg/epub-translator`) mappából eltávolítottuk a fejlesztői duplikátumokat,
  mert azok a forrás-repóban (`1`) vannak.
- A macOS/Windows szinkron-maradványokat (`*:Zone.Identifier`, `*:com.apple.*`) eltávolítottuk.
- A felesleges egyszeri segédfájlokat a `_archiv/` mappába helyeztük.

---

## ❓ Gyakori hibák

| Hiba | Ok | Megoldás |
|------|----|----------|
| `Telepített verzió: 1.3.5 = Új verzió: 1.3.5` | A telepített `.install_config` és a script verziója megegyezett (elavult) | Frissítsd az install.sh verziószámát a Desktop repóban, majd futtasd onnan |
| Blank page a weben | `/api/profile` 302 JSON helyett | Javítva: a backend most JSON 401-et ad (v2.0.2) |
| A `2`-es mappa kódja eltér a `1`-estől | A `2`-es mappába is szerkesztettél | Csak a `1`-esben dolgozz, majd `./install.sh` frissíti a `2`-est |

---

*Utolsó frissítés: 2026-08-13*