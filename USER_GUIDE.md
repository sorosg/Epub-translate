> Az alábbi lépések mindkét esetben ugyanúgy működnek, kivéve ahol külön jelöljük.

---

## 1. Bejelentkezés

- **Asztali alkalmazás:** nincs bejelentkezés – a program automatikusan a helyi fiókodat használja.
- **Docker szerver:** a bal oldali sidebaron „Bejelentkezés", admin: `admin@epub-translator.local` / `Abrakadabra` (definiált admin), vagy a regisztrált fiókod.

---

## 2. Első lépések

1. Nyisd meg a **Beállítások** fület.
2. Válaszd ki a **fordító motort**:
   - **☁️ DeepSeek Pro** (ajánlott): add meg az `sk-...` API kulcsodat, és válaszd a modellt (Chat vagy Reasoner).
   - **🖥️ Helyi (Ollama)**: GPU-val ajánlott. A modellt a rendszer a GPU-hoz (VRAM) szabja. **GPU nélkül ne válaszd** – CPU-n hetekig tart.
3. Válaszd a **megszólítást** (tegezés/magázás).
4. Mentsd a beállításokat.

> ⚠️ **Fontos:** a DeepSeek kulcsot a rendszer **maszkolva** mutatja (`***XXXX`). A mentés csak a **valódi `sk-...`** kulcsot fogadja el, a maszkolt érték **nem íródik vissza**.

---

## 3. Fordítás indítása

1. A **Dashboard** (Vezérlőpult) fülön húzd vagy válaszd ki az EPUB fájlt.
2. Válaszd ki az **AI motort** és a **modellt**.
3. (Opcionális) Jelölj be **kontextus-könyveket** a könyvtárból – sorozatoknál ez javítja a terminológia/nevek konzisztenciáját.
4. Indítsd a fordítást.

A fordítás során látod a progresszt (százalék + fejezetszám). Ha szeretnéd, a **„Leállítás"** gombbal megszakíthatod, a **„Folytatás"** gombbal pedig ott folytatódik, ahol abbahagyta. Email értesítést is kapsz a végén (a kész EPUB csatolva, ha 24 MB alatt van).

---

## 4. Könyvtár

A **Könyvtár** fülön tárolod a könyveidet:

- **Több EPUB feltöltése egyszerre** – kiválaszthatod akár az összes könyvet, a rendszer egyesével dolgozza fel.
- **Metaadatok** – cím, szerző, nyelv, műfaj, sorozat. Hiányzó adatokat a rendszer **OpenLibrary-ből** pótolja.
- **Keresés/szűrés** – cím, szerző, műfaj szerint.
- **Szerkesztés/törlés** – a saját fiókod (vagy admin) kezelheti.
- A könyvek **kontextusként** is használhatók a fordításnál (csillag ikon).

### Desktop vs. Docker
- **Asztali:** a könyvtár a **saját gyűjteményed**.
- **Docker szerver:** a könyvtár **közös**, és a kész fordítások admin-jóváhagyás után kerülnek bele (lásd 7. pont).

---

## 5. Olvasó

A könyvtárban egy könyvre kattintva megnyílik az **olvasó**:

- **Oldaltördelés** – a fejezetek a képernyő/felbontás szerint tördelődnek; az „Előző/Következő oldal" gombokkal lapozol.
- **Tartalom (TOC)** – a jobb felső listában ugorhatsz fejezetek között.
- **Könyvjelző** – csillag ikonnal mentheted a pozíciódat.

---

## 6. Beállítások

| Opció | Leírás |
|-------|--------|
| **AI motor** | DeepSeek Pro vagy Helyi (Ollama) |
| **API kulcs** | DeepSeek `sk-...` kulcs |
| **Modell** | Chat (V3) / Reasoner (R1), vagy helyi modell |
| **Megszólítás** | Tegezés / Magázás |
| **Profil** | név, email, jelszó |

---

## 7. Adatmentés / visszaállítás (export/import)

A **Beállítások** oldal alján két gomb segíti a biztonsági mentést:

- **⬇️ Adatok exportálása** – a teljes adatot (DeepSeek kulcs, beállítások,
  könyvtár, fordítások, glosszárium, TM) egyetlen `epub-translator-backup-….zip`
  fájlba menti le.
- **⬆️ Adatok importálása** – egy korábban exportált ZIP visszatöltése.
  Az import előtt a rendszer automatikus biztonsági mentést készít, és az
  app újraindítása javasolt utána.

> Nagyszerű újratelepítés vagy új gép előtt: exportálj, telepítsd újra az appot,
> majd importáld vissza – minden megmarad.

## 8. Admin (csak Docker szerver módban)

Az admin fülön (admin joggal):

- **Felhasználók** – létrehozás, szerkesztés, törlés.
- **Könyvtár jóváhagyás** – a befejezett fordítások itt várakoznak; az admin olvassa, majd **jóváhagyja** (a közös könyvtárba kerül) vagy **elutasítja**.
- **Logok** – Fordítási log (élő, fejezetszámos előrehaladás) és Alkalmazás log.
- **Rendszer** – CPU/RAM/lemez monitor.

---

## 9. Gyakori kérdések (GYIK)

**A fordításom elakadt / nem halad?**
Nézd a Dashboard progresszét és a fejezetszámot. Ha „Megszakítva (folytatható)", nyomj **Folytatás**-t. Ami feldolgozva lett, nem veszik el (checkpoint).

**Miért maradt benne angol szöveg?**
Valószínűleg érvénytelen API-kulcs (lásd 2. pont – maszkolt kulcs hiba). Add meg újra a valódi `sk-...` kulcsot.

**Mekkora a költség?**
DeepSeek Pro-val egy könyv kb. 100 Ft (~0.3 USD); a helyi Ollama ingyenes, de GPU-t igényel.

**Eltűnt a bejelentkezésem?**
Asztali módban nincs bejelentkezés. Docker módban ellenőrizd az emailt/jelszót; admin: `admin@epub-translator.local` / `Abrakadabra`.

---

*Készült ❤️-vel Magyarországon – v3.0.1*
