# 🗺️ EPUB Fordító – Fejlesztési Útiterv (Roadmap)

**Verzió:** 11.0.50 – "Smart Optimizer"  
**Utolsó frissítés:** 2026-07-17

---

## ✅ Már megvalósított fejlesztések (v11.0.34 – 11.0.48)

### Fordítási minőség
- [x] **HTML struktúra megőrzése** (v11.0.34) – text node batch fordítás, HTML elemek megtartása
- [x] **Fejlett prompt kontextus** (v11.0.35) – stílusinstrukció mintakönyvekből, terminológiai lista könyvtári könyvekből, sliding window
- [x] **Ollama paraméterek finomhangolása** (v11.0.44) – `temperature=0.2`, `num_predict=2048`, `repeat_penalty=1.1`, `top_p=0.9`
- [x] **Few-shot fordítási példák** (v11.0.44) – 2 angol→magyar példa a promptban
- [x] **Placeholder-alapú biztonságos text node csere** (v11.0.36)
- [x] **Timeout végtelenre állítása CPU-only deepseek-hez** (v11.0.47)

### Felhasználhatóság
- [x] **Modern UI/UX** – Bootstrap 5.3 + Icons, sötét téma, toast értesítések, stat kártyák, fade animációk
- [x] **Admin log oldal** (v11.0.34) – szintaxis kiemelés, auto-frissítés, vágólap másolás
- [x] **Kijelölt könyvek visszajelzése** (v11.0.43) – badge a dashboardon
- [x] **Részletes hibakezelés és logolás** (v11.0.34) – `/app/logs/app.log` + `translation.log`
- [x] **Flask-Limiter optimalizálás** (v11.0.46) – 2000 req/óra, dashboard 30mp frissítés

---

## 🔴 Rövid távú fejlesztések (következő verziók) – Magas prioritás

### 1. Automatikus glosszárium építés ✅ (v11.0.50)
**Státusz:** KÉSZ
- `GlossaryEntry` modell a `models.py`-ban (angol→magyar szópárok)
- Automatikus szópár kinyerés a fordítás során (forrásszöveg > 3 karakter)
- Glosszárium betöltés a fordítás előtt (`glossary_terms` dict)
- Meglévő bejegyzések `source_count` frissítése
- **Minőségjavulás:** ⭐⭐⭐⭐ (terminológiai következetesség)

### 2. Kétmenetes fordítás (hibrid modell) ✅ (v11.0.51)
**Státusz:** KÉSZ
- **Első menet:** AI fordítás a jelenlegi `translate_epub()`-bal (struktúra-megőrző mód, fejlett prompt)
- **Második menet:** Minőségellenőrzés és javítás – a modell megkapja az eredeti angol szöveget (referencia) és a lefordított magyar szöveget, ellenőrzi a nyelvtant, stílust, terminológiát
- Eredeti szövegek elmentése az első menet előtt (`original_texts` lista)
- `current_stage` követés: `first_pass` → `second_pass` → `post_processing` → `completed`
- Minőségi pontszám számítás a javítások aránya alapján (75-99 pont)
- `first_pass_model` és `second_pass_model` mezők tárolása
- **Minőségjavulás:** ⭐⭐⭐⭐⭐ (két menetes ellenőrzés és javítás)

### 3. Magyar nyelvi utófeldolgozás ✅ (v11.0.50)
**Státusz:** KÉSZ
- `hunspell hunspell-hu` telepítve a Dockerfile-ban
- `hunspell==0.5.5` hozzáadva a requirements.txt-hez
- Hunspell inicializálás a `translate_epub` elején
- Helyesírás-ellenőrzés a lefordított szövegen (naplózás, automatikus javítás nélkül)
- **Minőségjavulás:** ⭐⭐⭐ (helyesírási hibák kiszűrése)

### 4. Fordítási memória (Translation Memory) ✅ (v11.0.50)
**Státusz:** KÉSZ
- `TranslationMemory` modell a `models.py`-ban (SHA256 hash + szöveg)
- `search_tm()` segédfüggvény a pontos egyezés kereséséhez
- Automatikus TM mentés minden sikeres fordítás után
- `usage_count` és `last_used` követés
- **Minőségjavulás:** ⭐⭐⭐ (konzisztencia + sebesség)

### 5. Részletes fordítási progressz követés ✅ (v11.0.50)
**Státusz:** KÉSZ
- `Translation` modell bővítve: `current_stage`, `current_chapter`, `total_chapters`, `words_processed`, `total_words`, `nodes_translated`, `nodes_failed`
- Valós idejű progressz frissítés minden batch fordítás után
- Becsült szószám számítás az első 5 dokumentum alapján
- Részletes státusz API (`/api/status/<id>`) bővítve az új mezőkkel
- **Használhatóság:** ⭐⭐⭐⭐ (pontos visszajelzés)

---

## 🟡 Középtávú fejlesztések – Közepes prioritás

### 6. Interaktív fordítás-javítási felület
**Cél:** A felhasználó manuálisan javíthassa a lefordított szöveget.
- Webes felület a lefordított könyv böngészésére
- Inline szerkesztés (click-to-edit)
- Változtatások mentése a glosszáriumba
- **Használhatóság:** ⭐⭐⭐⭐⭐ (emberi korrektúra lehetősége)

### 7. Értesítések a fordítás befejezésekor
**Cél:** A felhasználó értesítést kapjon, amikor a fordítás elkészült.
- Email értesítés (Flask-Mail, már részben implementálva)
- Webhook (Discord, Slack)
- Böngésző Notification API
- Hangjelzés a webes felületen

### 8. Kontextus-érzékeny fordítás (szélesebb sliding window)
**Cél:** A jelenlegi sliding window (előző fejezet 300 karakter) bővítése.
- Előző fejezet teljes első bekezdése (500-800 karakter)
- Következő fejezet első bekezdése (előretekintő kontextus)
- Ez segít a narratív folytonosság fenntartásában
- **Minőségjavulás:** ⭐⭐⭐ (jobb kontextus = jobb fordítás)

### 9. Drag & drop a dashboardra
**Cél:** EPUB fájlok közvetlen behúzása a böngészőbe.
- JavaScript DragEvent kezelés
- Vizuális visszajelzés (drop zone kiemelés)
- Több fájl egyidejű feltöltése

### 10. Sötét/világos téma váltó
**Cél:** A felhasználó válthasson a sötét és világos téma között.
- CSS változók dinamikus cseréje
- Felhasználói preferencia mentése az adatbázisba
- Bootstrap 5.3 `data-bs-theme` attribútum használata

---

## 🟢 Hosszú távú fejlesztések – Alacsony prioritás

### 11. Gépi tanulás alapú minőségbecslés
**Cél:** Automatikus minőségi pontszám a fordításra (BLEU, szószám-arány, passzív szerkezetek).
- BLEU score számítás (ha van referencia fordítás)
- Szószám-arány ellenőrzése (a magyar fordítás általában hosszabb)
- Túl sok passzív szerkezet detektálása
- **Minőségjavulás:** ⭐⭐ (objektív minőségi metrika)

### 12. Többnyelvű felület bővítése
**Cél:** A felület több nyelven is elérhető legyen.
- Flask-Babel meglévő integráció kihasználása
- Angol, német, francia fordítások a UI-hoz
- Nyelv-választó a bejelentkezési oldalon

### 13. Közösségi glosszárium megosztás
**Cél:** A felhasználók megoszthassák egymással a glosszáriumaikat.
- Export/import funkció (JSON, CSV)
- Könyv-specifikus glosszáriumok (pl. Harry Potter univerzum terminusok)
- Opcionális közösségi adatbázis

### 14. Stílus-transzfer (formális ↔ informális)
**Cél:** A fordítás stílusának testreszabása.
- Formális (hivatalos) vs. informális (baráti) stílus választása
- Tegezés/magázás konzisztens kezelése
- Prompt szintű vezérlés: "Fordítsd le magyarra INFORMÁLIS stílusban..."

### 15. Fejezetek párhuzamos fordítása
**Cél:** Több fejezet egyidejű fordítása külön szálakon.
- Thread pool a fejezetek párhuzamos feldolgozásához
- Ollama num_parallel kihasználása
- Összességében gyorsabb fordítás (bár a felhasználónak az idő nem számít)

---

## 📊 Prioritási mátrix

| Fejlesztés | Minőségjavulás | Használhatóság | Implementációs idő | Priorítás |
|-----------|---------------|----------------|-------------------|-----------|
| Glosszárium építés | ⭐⭐⭐⭐ | ⭐⭐ | 2-3 óra | 🔴 |
| Kétmenetes fordítás | ⭐⭐⭐⭐⭐ | ⭐ | 3-4 óra | 🔴 |
| Magyar utófeldolgozás | ⭐⭐⭐ | ⭐⭐ | 1-2 óra | 🔴 |
| Fordítási memória | ⭐⭐⭐ | ⭐⭐ | 2-3 óra | 🔴 |
| Progressz követés | ⭐ | ⭐⭐⭐⭐ | 2-3 óra | 🔴 |
| Interaktív javítás | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 5-8 óra | 🟡 |
| Értesítések | ⭐ | ⭐⭐⭐⭐ | 1 óra | 🟡 |
| Szélesebb sliding window | ⭐⭐⭐ | ⭐ | 0.5 óra | 🟡 |
| Drag & drop | ⭐ | ⭐⭐⭐ | 1 óra | 🟡 |
| Téma váltó | ⭐ | ⭐⭐⭐ | 1 óra | 🟡 |
| Minőségbecslés | ⭐⭐ | ⭐⭐ | 3-4 óra | 🟢 |
| Többnyelvű UI | ⭐ | ⭐⭐⭐ | 2-3 óra | 🟢 |
| Közösségi glosszárium | ⭐⭐ | ⭐⭐⭐ | 2-3 óra | 🟢 |
| Stílus-transzfer | ⭐⭐⭐⭐ | ⭐⭐ | 1-2 óra | 🟢 |
| Párhuzamos fejezetek | ⭐ | ⭐⭐ | 3-4 óra | 🟢 |

---

## 🎯 Ajánlott következő lépések

A fordítási minőség javítására fókuszálva (az időfaktor nem számít):

1. **Kétmenetes fordítás** – a legnagyobb minőségjavulás (⭐⭐⭐⭐⭐)
2. **Automatikus glosszárium építés** – terminológiai következetesség (⭐⭐⭐⭐)
3. **Stílus-transzfer** – formális/informális vezérlés (⭐⭐⭐⭐)
4. **Magyar utófeldolgozás** – helyesírás-ellenőrzés (⭐⭐⭐)
5. **Szélesebb sliding window** – 0.5 óra alatt megvan (⭐⭐⭐)

---

*Ez a dokumentum folyamatosan frissül az új verziókkal. A kész fejlesztések a [README.md](README.md) Verzió Történet szekciójában is megtalálhatók.*