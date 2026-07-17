# EPUB Fordító Rendszer v11.0

## 🧠 "Smart Optimizer" - Intelligens Optimalizáló

![Version](https://img.shields.io/badge/version-11.0.60-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-ready-brightgreen)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04+-orange)

---

## 🎯 Rendszer Áttekintés

Az EPUB Fordító Rendszer egy **teljesen ingyenes, helyben futó, öntanuló** megoldás EPUB könyvek fordítására angolról magyarra. A DeepSeek R1 AI modelleket használja az Ollama platformon keresztül, amelyek a saját gépeden futnak – **nincs szükség API kulcsra, internetkapcsolatra (a modell letöltése után), vagy előfizetésre!**

### Tervezési alapelvek

1. **Minőség a sebesség felett** – a rendszer kétmenetes fordítást végez (AI fordítás + minőségellenőrzés), a pontosság érdekében akár napokig is dolgozhat egy könyvön
2. **GPU nélkül is működik** – a hardver követelmények a RAM-ot veszik alapul a modell kiválasztásához, erős videókártya nem szükséges
3. **Közös könyvtár** – a feltöltött könyvekből deduplikált adatbázis épül, ami kontextusként szolgál a fordításokhoz
4. **Öntanuló** – glosszárium, fordítási memória és stílusminták automatikusan épülnek

### 🌟 Legfontosabb Jellemzők

- ✅ **100% Ingyenes** – Nincs rejtett költség, előfizetés vagy API díj
- ✅ **Helyben Fut** – Minden adat a saját gépeden marad
- ✅ **Kétmenetes fordítás** – AI fordítás + minőségellenőrzés a jobb minőségért
- ✅ **Közös könyvtár** – Minden felhasználó látja az összes feltöltött könyvet (deduplikációval)
- ✅ **Interaktív review** – Lefordított fejezetek böngészése és inline szerkesztése
- ✅ **Email értesítések** – MailHog SMTP szerver a fordítás befejezésekor
- ✅ **Önfrissítő** – GitHub frissítések ellenőrzése és telepítése
- ✅ **Hardver alapú modell ajánlás** – RAM mérettől függően

---

## ⏱️ Fordítási Idő Becslések (CPU-only, GPU nélkül)

A rendszer **kétmenetes fordítást** végez (első menet: AI fordítás, második menet: minőségellenőrzés), ami megnöveli a feldolgozási időt, de jelentősen javítja a minőséget. A sebesség elsősorban a CPU teljesítményétől és a választott modelltől függ.

### Átlagos fordítási idők egy 80 000 szavas könyvre

| Modell | CPU (i3 8. gen, 4 mag) | CPU (i7/Ryzen 7, 8+ mag) | Minőség |
|--------|------------------------|--------------------------|---------|
| deepseek-r1:7b | 1–2 nap | 12–24 óra | ⭐⭐⭐ |
| deepseek-r1:8b | 1,5–3 nap | 18–36 óra | ⭐⭐⭐ |
| deepseek-r1:14b | **2,5–4 nap** | 1,5–2,5 nap | ⭐⭐⭐⭐ |
| deepseek-r1:32b | 5–10 nap | 3–6 nap | ⭐⭐⭐⭐⭐ |

### Miért ilyen hosszú?

- **CPU-only futtatás**: GPU nélkül a deepseek-r1:14b ~1–3 tokent generál másodpercenként
- **Kétmenetes**: minden szövegrészt kétszer dolgoz fel (fordítás + ellenőrzés), ~6 000–10 000 API hívás könyvenként
- **Node-onkénti fordítás**: a megbízhatóság érdekében minden text node egyesével kerül fordításra (nem batch-ben)
- Szövegrészenként 15–45 másodperc feldolgozási idő a szöveghossztól függően

### Gyorsító tényezők

- **TM cache (Translation Memory)**: a már lefordított mondatokat SHA256 hash alapján azonnal visszaadja – második könyvtől jelentős gyorsulás
- **Glosszárium**: automatikusan épülő angol→magyar szópárak, terminológiai következetesség
- **Minél több könyvet fordítasz, a cache annál hatékonyabb** – a rendszer tanul a korábbi fordításokból

### Hardver ajánlás referencia időkkel

| Processzor | RAM | Ajánlott modell | Várható idő (80K szó) |
|-----------|-----|----------------|----------------------|
| i3 8. gen (4 mag) | 16 GB | 8b | 1,5–3 nap |
| i3 8. gen (4 mag) | 40 GB | **14b** ★ | **2,5–4 nap** |
| i7/Ryzen 7 (8+ mag) | 32 GB | 14b | 1,5–2,5 nap |
| i7/Ryzen 7 (8+ mag) | 64 GB | 32b | 3–6 nap |

> **Megjegyzés**: Az időbecslések tájékoztató jellegűek és erősen függenek a könyv szövegsűrűségétől, a fejezetek számától és a CPU egyéb terheltségétől. A rendszer a **minőséget helyezi előtérbe a sebességgel szemben**.

---

## 💻 Rendszerkövetelmények

### Hardver

| Komponens | Minimum | Ajánlott | Optimális (14b) | Maximális (32b) |
|-----------|---------|----------|-----------------|-----------------|
| **RAM** | 16 GB | 32 GB | 32 GB | 64 GB |
| **CPU** | 4 mag, 2.5 GHz | 8+ mag, 3.0+ GHz | 8 mag | 16 mag |
| **Tárhely** | 50 GB | 100+ GB SSD | 100 GB SSD | 200 GB SSD |
| **GPU** | Nem szükséges | NVIDIA (opcionális) | - | - |

### Szoftver

- **Operációs Rendszer:** Ubuntu 22.04 LTS vagy újabb (64 bit)
- **Docker:** 24.0+
- **Docker Compose:** 2.20+

### Automatikus Modell Ajánlás (RAM alapú, GPU nélkül)

| RAM | Ajánlott Modell | Minőség | Sebesség |
|-----|----------------|---------|----------|
| 8 GB | `deepseek-r1:1.5b` | ⭐⭐ | ⚡⚡⚡⚡⚡ |
| 16 GB | `deepseek-r1:7b` | ⭐⭐⭐ | ⚡⚡⚡⚡ |
| 32 GB | `deepseek-r1:14b` ★ | ⭐⭐⭐⭐ | ⚡⚡⚡ |
| 40 GB | `deepseek-r1:32b` | ⭐⭐⭐⭐⭐ | ⚡⚡ |
| 64 GB | `deepseek-r1:32b` | ⭐⭐⭐⭐⭐ | ⚡⚡ |

---

## 🚀 Gyors Telepítés

### Egy paranccsal:

```bash
curl -sSL https://raw.githubusercontent.com/sorosg/Epub-translate/main/install.sh | bash
```

Vagy lépésről lépésre:

```bash
# 1. Töltsd le a telepítőt
wget https://raw.githubusercontent.com/sorosg/Epub-translate/main/install.sh

# 2. Tedd futtathatóvá
chmod +x install.sh

# 3. Indítsd el (a rendszer automatikusan felismeri a hardvert)
./install.sh
```

### Telepítés után

```bash
# Webes felület
http://localhost

# Email felület (MailHog)
http://localhost:8025

# Admin belépés
Email: admin@epub-translator.local
Jelszó: Abrakadabra (változtasd meg!)
```

---

## 🔄 Frissítés Meglévő Telepítésről

### Frissítés a Programból

1. Admin → Frissítés Kezelés
2. "Frissítések ellenőrzése"
3. "Telepítés"

### Frissítés Parancssorból

```bash
# Telepítő script
./install.sh
# Válaszd: 1) Frissítés

# VAGY gyorsfrissítő
./scripts/update.sh
```

---

## 🆕 Funkciók

### Fordítási funkciók
- **Kétmenetes fordítás**: AI fordítás + minőségellenőrzés és javítás
- **Glosszárium építés**: automatikus angol→magyar szópár kinyerés
- **Fordítási memória (TM cache)**: SHA256 alapú gyorsítótárazás
- **Hunspell helyesírás-ellenőrzés**: magyar nyelvi validáció
- **Stílusinstrukció**: referencia (minta) könyvekből
- **Terminológiai lista**: kiválasztott könyvtári könyvekből

### Könyvtár funkciók (v11.0.59)
- **Közös könyvtár**: minden felhasználó látja az összes feltöltött könyvet
- **Deduplikáció**: cím+szerző alapú ellenőrzés feltöltéskor
- **Felhasználónkénti kiválasztás**: mindenki saját maga jelölhet ki kontextus könyveket
- **Jogosultságkezelés**: szerkesztés/törlés csak a feltöltő vagy admin számára

### Felhasználói funkciók
- **Interaktív review felület**: lefordított fejezetek böngészése és inline szerkesztése
- **Email értesítések**: fordítás befejezésekor (MailHog)
- **Admin felület**: rendszerfigyelés, felhasználókezelés, modellváltás
- **Részletes progressz követés**: fejezet, szószám, node szintű visszajelzés

### Rendszer funkciók
- **Hardver alapú optimalizálás**: RAM, CPU detektálás, auto-konfiguráció
- **Önfrissítő**: GitHub API alapú verzióellenőrzés és frissítés
- **DNS konfiguráció** (v11.0.60): backend konténer külső DNS feloldása a frissítésellenőrzéshez

---

## 🏗️ Architektúra

```
Böngésző (http://localhost:80)
        │
        ▼
┌───────────────────┐
│  Nginx (80/443)   │  Reverse Proxy + Statikus fájlok
└───────┬───────────┘
        │
        ▼
┌───────────────────┐     ┌──────────────┐
│  Flask Backend    │────▶│  PostgreSQL   │
│  (Gunicorn :5000) │     │  (Adatbázis)  │
└───────┬───────────┘     └──────────────┘
        │
        │ HTTP API hívások
        ▼
┌───────────────────┐     ┌──────────────┐     ┌──────────────┐
│  Ollama (CPU)     │     │  Redis       │     │  MailHog     │
│  deepseek-r1:14b  │     │  (Cache)     │     │  (SMTP:1025) │
│  host.docker      │     │              │     │  (Web:8025)  │
│  .internal:11434  │     │              │     │              │
└───────────────────┘     └──────────────┘     └──────────────┘
```

Minden komponens Docker konténerben fut, a `translator-network` bridge hálózaton keresztül kommunikálnak.

---

## 🤖 Modell Konfigurációk

### deepseek-r1:14b (Ajánlott 32-40GB RAM-hoz) ★

```
Teljesítmény:
  Sebesség: 2,5–4 nap/könyv (i3 8. gen CPU-n)
  Minőség: ⭐⭐⭐⭐ (85-92%)
  RAM: 18-22 GB

Optimalizálás:
  memory_limit: 24G, max_workers: 3
  batch_size: 5, num_parallel: 2

Ajánlott:
  - Irodalmi művekhez, fontos fordításokhoz
  - 50 000 szó feletti könyvekhez
  - Jó egyensúly minőség és sebesség között
```

### deepseek-r1:32b (40-64GB RAM-hoz)

```
Teljesítmény:
  Sebesség: 5-10 nap/könyv (i3 8. gen CPU-n)
  Minőség: ⭐⭐⭐⭐⭐ (90-95%)
  RAM: 30-35 GB

Optimalizálás:
  memory_limit: 30G, max_workers: 1
  batch_size: 2, num_parallel: 1

Ajánlott:
  - Maximális minőséghez
  - Irodalmi remekművekhez
  - 40 GB+ RAM szükséges
```

### deepseek-r1:8b (16GB RAM-hoz)

```
Teljesítmény:
  Sebesség: 1,5-3 nap/könyv (i3 8. gen CPU-n)
  Minőség: ⭐⭐⭐ (80-85%)
  RAM: 12-14 GB

Optimalizálás:
  memory_limit: 16G, max_workers: 3
  batch_size: 5, num_parallel: 2

Ajánlott:
  - Mindennapi használatra, gyorsabb fordításokhoz
  - 16GB RAM-mal rendelkező gépekhez
```

---

## 🔧 Karbantartás

```bash
# Státusz ellenőrzése
./scripts/status.sh

# Biztonsági mentés
./scripts/backup.sh

# Frissítés
./scripts/update.sh

# Monitor napló
tail -f logs/resource_monitor.log
```

### Modell Karbantartás

```bash
# Telepített modellek listázása
docker exec -it epub-ollama ollama list

# Új modell letöltése
docker exec -it epub-ollama ollama pull deepseek-r1:14b

# Modell törlése (tárhely felszabadítás)
docker exec -it epub-ollama ollama rm deepseek-r1:1.5b
```

---

## 🔍 Hibaelhárítás

### Konténerek ellenőrzése

```bash
docker compose ps
docker compose logs backend
docker compose logs ollama
```

### DNS / Frissítés ellenőrzési hiba

```bash
# Ellenőrizd, hogy a backend konténer eléri-e az internetet:
docker exec epub-backend curl -s https://api.github.com | head -5

# Ha nem, a docker-compose.yml-ben ellenőrizd a dns: bejegyzést:
# dns:
#   - 1.1.1.1
#   - 8.8.8.8
```

---

## 📊 Verzió Történet

### v11.0.60 (2026-07-17)
- 🔧 **DNS javítás**: backend konténer külső DNS feloldása (Cloudflare 1.1.1.1, Google 8.8.8.8) a frissítésellenőrzéshez és OpenLibrary API-hoz
- 📖 **README.md frissítve**: fordítási idő becslések CPU-only hardverre

### v11.0.59 (2026-07-17)
- 📚 **Közös könyvtár**: minden felhasználó látja az összes feltöltött könyvet
- 🚫 **Deduplikáció**: cím+szerző alapú ellenőrzés feltöltéskor
- 👤 **UserBookPreference**: felhasználónkénti könyvbeállítások (kontextus kiválasztás)
- 🔐 **Jogosultságkezelés**: szerkesztés/törlés csak a feltöltő vagy admin számára

### v11.0.56 (2026-07-16)
- 📝 **Interaktív review felület**: lefordított fejezetek böngészése és inline szerkesztése
- 📧 **Email értesítések**: fordítás befejezésekor (MailHog)

### v11.0.55 (2026-07-16)
- 🖥️ **Hardver alapú modell ajánlás javítása**: 40 GB RAM-hoz 32b modell

### v11.0.54 (2026-07-16)
- 🔧 **Node-onkénti fordítás**: megbízhatóbb, mint a batch mód

### v11.0.51 (2026-07-16)
- ✅ **Kétmenetes fordítás**: első menet AI fordítás + második menet minőségellenőrzés

### v11.0.50 (2026-07-16)
- 📖 **Glosszárium építés**: automatikus angol→magyar szópár kinyerés
- 💾 **Fordítási memória**: TM cache a konzisztens fordításokhoz
- 🔤 **Hunspell**: magyar helyesírás-ellenőrzés
- 📊 **Részletes progressz követés**: fejezet, szószám, node szintű visszajelzés

### v11.0.27 (2026-07-16) - "Smart Optimizer"
- 🆕 Intelligens modell optimalizáló
- 🆕 Valós idejű erőforrás monitor
- 🆕 Smart modellváltás auto-optimize
- 🆕 Hardver alapú auto-konfiguráció

### Korábbi verziók
- v10.0.0: AI Asszisztens, OAuth/SSO, OCR, Hang, Gamification
- v9.1.0: Dark Mode, Dashboard 2.0, Többnyelvű felület
- v8.0.0: Drag & Drop könyvtárfeltöltés
- v7.0.0: GitHub Auto-Update, Öntanuló fordítási memória
- v1.0.0 - v6.0.0: Alaprendszer, Felhasználó kezelés, Párhuzamos fordítás

---

## 📞 Támogatás

- 📧 Email: sorosgergo@gmail.com
- 🌐 GitHub: https://github.com/sorosg/Epub-translate
- 🐛 Hibajelentés: https://github.com/sorosg/Epub-translate/issues

---

Készült ❤️-vel Magyarországon – v11.0.60