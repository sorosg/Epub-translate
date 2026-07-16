```markdown
# EPUB Fordító Rendszer v11.0

## 🧠 "Smart Optimizer" - Intelligens Optimalizáló

![Version](https://img.shields.io/badge/version-11.0.6-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/docker-ready-brightgreen)
![Platform](https://img.shields.io/badge/platform-Ubuntu%2022.04+-orange)
![PWA](https://img.shields.io/badge/PWA-ready-purple)
![Update](https://img.shields.io/badge/auto--update-ready-success)
![AI](https://img.shields.io/badge/AI-powered-orange)
![Optimized](https://img.shields.io/badge/auto--optimized-brightgreen)
![Monitor](https://img.shields.io/badge/resource-monitor-blue)

---

## 🎯 Rendszer Áttekintés

Az EPUB Fordító Rendszer egy **teljesen ingyenes, helyben futó, öntanuló** megoldás EPUB könyvek fordítására. A DeepSeek AI modelleket használja, amelyek a saját gépeden futnak - **nincs szükség API kulcsra, internetkapcsolatra (a modell letöltése után), vagy előfizetésre!**

### 🌟 Legfontosabb Jellemzők

- ✅ **100% Ingyenes** - Nincs rejtett költség, előfizetés vagy API díj
- ✅ **Helyben Fut** - Minden adat a saját gépeden marad
- ✅ **Offline Működés** - Internet csak a modell első letöltéséhez kell
- ✅ **Öntanuló** - A fordítási memória és kontextus tanulás folyamatosan javul
- ✅ **Önfrissítő** - Automatikus GitHub frissítések, egykattintásos frissítés
- ✅ **Intelligens Optimalizáló** - Automatikusan hangolja a rendszert a kiválasztott modellhez
- ✅ **Erőforrás Monitor** - Valós idejű CPU, RAM, lemez figyelés
- ✅ **Smart Modellváltás** - Hardver alapú modell ajánlás
- ✅ **AI Asszisztens** - Valós idejű fordítási segítség
- ✅ **OAuth/SSO** - Google, GitHub, Microsoft bejelentkezés
- ✅ **OCR + Hang** - Képfordítás és beszédfelismerés
- ✅ **Gamification** - Achievement-ek, pontok, szintek, ranglisták

---

## 📋 Tartalomjegyzék

1. [Rendszerkövetelmények](#-rendszerkövetelmények)
2. [Gyors Telepítés](#-gyors-telepítés)
3. [Frissítés Meglévő Telepítésről](#-frissítés-meglévő-telepítésről)
4. [Újdonságok a v11.0-ban](#-újdonságok-a-v110-ban)
5. [Intelligens Optimalizáló](#-intelligens-optimalizáló)
6. [Erőforrás Monitor](#-erőforrás-monitor)
7. [Smart Modellváltás](#-smart-modellváltás)
8. [Modell Konfigurációk](#-modell-konfigurációk)
9. [Architektúra](#-architektúra)
10. [Konfiguráció](#-konfiguráció)
11. [API Dokumentáció](#-api-dokumentáció)
12. [Karbantartás](#-karbantartás)
13. [Hibaelhárítás](#-hibaelhárítás)
14. [GYIK](#-gyik)
15. [Verzió Történet](#-verzió-történet)

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

### Automatikus Modell Ajánlás

| RAM | Ajánlott Modell | Minőség | Sebesség |
|-----|----------------|---------|----------|
| 8 GB | `deepseek-r1:1.5b` | ⭐⭐ | ⚡⚡⚡⚡⚡ |
| 16 GB | `deepseek-r1:7b` | ⭐⭐⭐ | ⚡⚡⚡⚡ |
| 32 GB | `deepseek-r1:14b` ★ | ⭐⭐⭐⭐ | ⚡⚡⚡ |
| 64 GB | `deepseek-r1:32b` | ⭐⭐⭐⭐⭐ | ⚡⚡ |
| 128 GB+ | `deepseek-r1:70b` | ⭐⭐⭐⭐⭐ | ⚡ |

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

Telepítési Opciók

Opció Leírás Használat
Friss telepítés Új rendszer telepítése Alapértelmezett
Frissítés Meglévő verzió frissítése 1-es választás
Csak optimalizálás Meglévő rendszer hangolása 3-as választás

Telepítés Után

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

🔄 Frissítés Meglévő Telepítésről

Frissítés a Programból

```
1. Admin → Frissítés Kezelés
2. "Frissítések ellenőrzése"
3. "Telepítés"
```

Frissítés Parancssorból

```bash
# 1. Telepítő script
./install.sh
# Válaszd: 1) Frissítés

# 2. Gyorsfrissítő
./scripts/update.sh

# 3. Csak optimalizálás (ha csak hangolni szeretnél)
./install.sh
# Válaszd: 3) Csak optimalizálás
```

---

🆕 Újdonságok a v11.0-ban

🧠 Intelligens Optimalizáló

· Automatikus paraméter hangolás modellváltáskor
· Memória, CPU, Redis, PostgreSQL automatikus konfigurálása
· 6 előre definiált modell profil
· Optimalizálási napló a változások követéséhez

📊 Erőforrás Monitor

· Valós idejű CPU, RAM, lemez, swap figyelés
· Hálózati forgalom monitorozása
· API végpont a rendszer állapotához (/api/system/monitor)
· Health check részletes rendszer információkkal

🔄 Smart Modellváltás

· Hardver alapú automatikus modell ajánlás
· Egy kattintásos modellváltás optimalizálással
· Nem használt modellek opcionális eltávolítása
· Modell-specifikus erőforrás allokáció

⚡ Automatikus Hardver Felismerés

· Telepítéskor automatikusan észleli a rendszer erőforrásait
· Optimális beállításokat javasol
· Teljesítmény profil generálása
· Folyamatos monitorozás és újrahangolás

---

🧠 Intelligens Optimalizáló

Hogyan Működik?

```
1. Modell kiválasztása (vagy automatikus ajánlás)
2. Optimalizáló elemzi a modell igényeit
3. Automatikusan beállítja:
   ├── Ollama memória limit
   ├── Párhuzamos szálak száma
   ├── Batch méret
   ├── Redis cache méret
   ├── PostgreSQL bufferek
   └── Docker erőforrás limitek
4. Újraindítja a szolgáltatásokat
5. Ellenőrzi a beállításokat
```

Optimalizálási Profilok

Modell RAM Limit Szálak Batch Redis PostgreSQL
1.5b 4G 4 8 128MB 128MB
7b 12G 3 6 256MB 256MB
8b 16G 3 5 512MB 512MB
14b 24G 3 5 512MB 512MB
32b 30G 1 2 256MB 256MB
70b 60G 1 1 128MB 128MB

API Használat

```bash
# Modell váltás optimalizálással
curl -X POST http://localhost/api/models/switch \
  -H "Content-Type: application/json" \
  -d '{"model": "deepseek-r1:14b", "auto_optimize": true}'

# Válasz:
{
    "success": true,
    "message": "Modell átváltva: deepseek-r1:14b",
    "optimization": {
        "model": "deepseek-r1:14b",
        "config": {
            "max_workers": 3,
            "batch_size": 5,
            "memory_limit": "24G",
            ...
        },
        "steps": [
            {"step": "env", "success": true},
            {"step": "redis", "success": true},
            ...
        ]
    }
}
```

---

📊 Erőforrás Monitor

Valós Idejű Monitorozás

```bash
# Rendszer állapot lekérése
curl http://localhost/api/system/monitor

# Válasz:
{
    "cpu": {
        "percent": 45.2,
        "cores": 8,
        "frequency": 3200
    },
    "memory": {
        "total_gb": 32.0,
        "used_gb": 22.5,
        "available_gb": 9.5,
        "percent": 70.3
    },
    "disk": {
        "total_gb": 500.0,
        "free_gb": 350.0,
        "percent": 30.0
    },
    "swap": {
        "total_gb": 8.0,
        "used_gb": 0.5,
        "percent": 6.25
    },
    "network": {
        "bytes_sent": 125000000,
        "bytes_recv": 98000000
    }
}
```

Health Check (Részletes)

```bash
curl http://localhost/health

# Válasz:
{
    "status": "healthy",
    "version": "11.0.6",
    "codename": "Smart Optimizer",
    "release_date": "2026-07-16",
    "model": "deepseek-r1:14b",
    "memory": "70.3%",
    "cpu": "45.2%"
}
```

Automatikus Monitorozás

A rendszer 30 percenként automatikusan naplózza az erőforrásokat:

```bash
# Monitor log megtekintése
tail -f logs/resource_monitor.log

# Kimenet:
# 2026-07-16 14:30: CPU:45.2% RAM:22.5G/32.0G Disk:30%
# 2026-07-16 15:00: CPU:52.1% RAM:24.1G/32.0G Disk:30%
```

---

🔄 Smart Modellváltás

Automatikus Modell Ajánlás

```bash
# Rendszer alapján ajánlott modell
curl http://localhost/api/models/recommend

# Válasz:
{
    "recommended": "deepseek-r1:14b",
    "current": "deepseek-r1:8b",
    "should_switch": true,
    "system_info": {
        "total_ram_gb": 32.0,
        "free_ram_gb": 12.5
    }
}
```

Modellváltás Folyamata

```
1. Felhasználó kiválasztja az új modellt
   VAGY
   A rendszer ajánl egyet

2. Optimalizáló ellenőrzi az erőforrásokat
   ├── Van-e elég RAM?
   ├── Van-e elég lemez?
   └── Milyen a CPU terheltség?

3. Automatikus beállítások alkalmazása
   ├── Memória limitek
   ├── Szálak száma
   ├── Cache méretek
   └── Adatbázis hangolás

4. Modell letöltése (ha szükséges)
5. Szolgáltatások újraindítása
6. Működés ellenőrzése
```

---

🤖 Modell Konfigurációk

Részletes Modell Profilok

deepseek-r1:14b (Ajánlott 32GB RAM-hoz)

```yaml
Teljesítmény:
  Sebesség: ⚡⚡⚡ (3-4 óra/könyv)
  Minőség: ⭐⭐⭐⭐ (85-92%)
  RAM: 18-22 GB
  
Optimalizálás:
  max_workers: 3
  batch_size: 5
  memory_limit: 24G
  num_parallel: 2
  redis_maxmemory: 512mb
  pg_buffers: 512MB
  
Ajánlott:
  - Irodalmi művekhez
  - Fontos fordításokhoz
  - 50 000 szó feletti könyvekhez
```

deepseek-r1:32b (64GB RAM-hoz)

```yaml
Teljesítmény:
  Sebesség: ⚡⚡ (8-12 óra/könyv)
  Minőség: ⭐⭐⭐⭐⭐ (90-95%)
  RAM: 30-35 GB
  
Optimalizálás:
  max_workers: 1
  batch_size: 2
  memory_limit: 30G
  num_parallel: 1
  redis_maxmemory: 256mb
  pg_buffers: 256MB
  
Ajánlott:
  - Maximális minőséghez
  - Irodalmi remekművekhez
  - Kisebb könyvekhez (50 000 szó alatt)
```

deepseek-r1:8b (16GB RAM-hoz)

```yaml
Teljesítmény:
  Sebesség: ⚡⚡⚡⚡ (2-3 óra/könyv)
  Minőség: ⭐⭐⭐ (80-85%)
  RAM: 12-14 GB
  
Optimalizálás:
  max_workers: 3
  batch_size: 5
  memory_limit: 16G
  num_parallel: 2
  redis_maxmemory: 512mb
  pg_buffers: 512MB
  
Ajánlott:
  - Mindennapi használatra
  - Gyors fordításokhoz
  - 16GB RAM-mal rendelkező gépekhez
```

---

🏗️ Architektúra

```
┌─────────────────────────────────────────────────────────────┐
│                     Felhasználói Böngésző                      │
│                    http://localhost:80                        │
│                    📊 Monitor | 🧠 Optimize                   │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                      Nginx (80/443)                          │
│              Reverse Proxy + Statikus Fájlok                 │
│              Health Check: /health                           │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│                  Flask Backend (5000)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐    │
│  │ Smart        │ │ Resource     │ │ Model            │    │
│  │ Optimizer    │ │ Monitor      │ │ Manager          │    │
│  │ (Auto-tune)  │ │ (Real-time)  │ │ (Switch+Optimize)│    │
│  ├──────────────┤ ├──────────────┤ ├──────────────────┤    │
│  │ Performance  │ │ System       │ │ AI Assistant     │    │
│  │ Profiles     │ │ Health       │ │ + OCR + Voice    │    │
│  └──────────────┘ └──────────────┘ └──────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼──────┐   ┌────────▼────────┐   ┌─────▼──────┐
│  PostgreSQL  │   │     Ollama       │   │   Redis    │
│  (Auto-tuned │   │  DeepSeek AI    │   │ (Auto-tuned│
│   buffers)   │   │  (Auto-memory)  │   │  maxmemory)│
└──────────────┘   └─────────────────┘   └────────────┘
```

---

⚙️ Konfiguráció

.env Fájl (v11.0)

```env
# Verzió
VERSION=11.0.6
CODENAME="Smart Optimizer"
RELEASE_DATE=2026-07-16

# Admin
ADMIN_EMAIL=admin@epub-translator.local
ADMIN_PASSWORD=your-secure-password

# AI Modell (automatikusan ajánlva)
SELECTED_MODEL=deepseek-r1:14b
RECOMMENDED_MODEL=deepseek-r1:14b

# Optimalizálás
ENABLE_AUTO_OPTIMIZE=true       # Automatikus optimalizálás modellváltáskor
ENABLE_RESOURCE_MONITOR=true    # Erőforrás figyelés
ENABLE_SMART_SWITCH=true        # Intelligens modell ajánlás

# Teljesítmény (automatikusan hangolva)
MAX_WORKERS=3
BATCH_SIZE=5
OPTIMAL_MEMORY_LIMIT=24G
OPTIMAL_REDIS=512mb
OPTIMAL_PG_BUFFERS=512MB

# Funkciók
ENABLE_AI_ASSISTANT=true
ENABLE_OAUTH=true
ENABLE_OCR=true
ENABLE_VOICE_INPUT=true
ENABLE_GAMIFICATION=true
ENABLE_COMMUNITY=true
ENABLE_FINE_TUNING=true
ENABLE_AUTO_COMPLETE=true

# Auto-Update
ENABLE_AUTO_UPDATE=true
GITHUB_REPO=https://github.com/sorosg/Epub-translate.git
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

---

🔌 API Dokumentáció

Új v11.0 Végpontok

Végpont Módszer Leírás
/api/models/switch POST Modell váltás optimalizálással
/api/models/recommend GET Hardver alapú modell ajánlás
/api/models/optimization-status GET Optimalizálási állapot
/api/models/optimize POST Jelenlegi modell optimalizálása
/api/system/monitor GET Rendszer erőforrások
/api/system/health GET Részletes health check

Modellváltás Optimalizálással

```bash
curl -X POST http://localhost/api/models/switch \
  -H "Content-Type: application/json" \
  -H "Cookie: session=..." \
  -d '{
    "model": "deepseek-r1:14b",
    "auto_optimize": true,
    "cleanup_unused": false
  }'
```

Rendszer Monitor

```bash
curl http://localhost/api/system/monitor \
  -H "Cookie: session=..."
```

Modell Ajánlás

```bash
curl http://localhost/api/models/recommend \
  -H "Cookie: session=..."
```

---

🔧 Karbantartás

Rendszeres Feladatok

```bash
# Státusz (részletes erőforrás információkkal)
./scripts/status.sh

# Biztonsági mentés
./scripts/backup.sh

# Frissítés
./scripts/update.sh

# Optimalizálás ellenőrzése
./scripts/optimize.sh

# Erőforrás monitor napló
tail -f logs/resource_monitor.log
```

Optimalizálás Kézi Indítása

```bash
# Csak optimalizálás (nem frissít)
./install.sh
# Válaszd: 3) Csak optimalizálás

# VAGY API-n keresztül
curl -X POST http://localhost/api/models/optimize
```

Modell Karbantartás

```bash
# Telepített modellek listázása
docker exec -it epub-ollama ollama list

# Modell törlése (tárhely felszabadítás)
docker exec -it epub-ollama ollama rm deepseek-r1:1.5b

# Új modell letöltése
docker exec -it epub-ollama ollama pull deepseek-r1:14b
```

---

🔍 Hibaelhárítás

Optimalizálási Problémák

```bash
# Optimalizálás állapotának ellenőrzése
curl http://localhost/api/models/optimization-status

# Kézi optimalizálás
curl -X POST http://localhost/api/models/optimize

# Optimalizálási napló megtekintése
docker exec -it epub-backend python3 -c "
from models import OptimizationLog
for log in OptimizationLog.query.order_by(OptimizationLog.created_at.desc()).limit(5):
    print(f'{log.created_at}: {log.model} - {log.action}')
"
```

Memória Problémák

```bash
# Rendszer monitor ellenőrzése
curl http://localhost/api/system/monitor

# Ha kevés a memória, válts kisebb modellre:
curl -X POST http://localhost/api/models/switch \
  -d '{"model": "deepseek-r1:8b", "auto_optimize": true}'
```

Modellváltási Hibák

```bash
# Ellenőrizd, hogy a modell telepítve van-e
docker exec -it epub-ollama ollama list

# Ha nincs, töltsd le
docker exec -it epub-ollama ollama pull deepseek-r1:14b

# Próbáld újra a váltást
curl -X POST http://localhost/api/models/switch \
  -d '{"model": "deepseek-r1:14b", "auto_optimize": true}'
```

---

❓ GYIK

Optimalizálás

K: Az optimalizálás automatikus?
V: Igen! Modellváltáskor automatikusan megtörténik, de kézzel is indítható.

K: Testreszabhatom az optimalizálási beállításokat?
V: Igen, a .env fájlban felülírhatod az automatikus értékeket.

K: Milyen gyakran érdemes optimalizálni?
V: Modellváltáskor automatikus, egyébként havonta egyszer ajánlott.

Modellváltás

K: Válthatok modellek között fordítás közben?
V: Nem, a váltáshoz a fordításnak be kell fejeződnie.

K: Elvesznek a beállításaim modellváltáskor?
V: Nem, a rendszer minden modellhez elmenti az optimális beállításokat.

Erőforrás Monitor

K: Terheli a rendszert a monitorozás?
V: Minimális, kevesebb mint 1% CPU használat.

K: Hol találom a monitor naplókat?
V: logs/resource_monitor.log fájlban.

---

📊 Verzió Történet

v11.0.6 (2026-07-16) - "Smart Optimizer"

· 🆕 Intelligens modell optimalizáló
· 🆕 Valós idejű erőforrás monitor
· 🆕 Smart modellváltás auto-optimize
· 🆕 Hardver alapú auto-konfiguráció
· 🆕 Teljesítmény profilok
· 🆕 Optimalizálási napló
· 🆕 Részletes health check

v10.0.0 (2025-06-20) - "AI Studio"

· AI Asszisztens, OAuth/SSO, OCR, Hang, Gamification, Közösség, Fine-tuning, Auto-Complete

v9.1.0 (2025-03-15) - "Enhanced Studio"

· Dark Mode, Billentyűparancsok, Dashboard 2.0, Többnyelvű, Integrációk

v9.0.0 (2025-01-15) - "User Portal"

· Felhasználói regisztráció, Belső email

v8.0.0 (2024-12-01) - "Library Manager"

· Drag & Drop könyvtárfeltöltés

v7.0.0 (2024-09-15) - "Self-Evolving Translator"

· GitHub Auto-Update, Öntanuló fordítási memória

v1.0.0 - v6.0.0

· Alaprendszer, Felhasználó kezelés, Párhuzamos fordítás, Hibrid SMTP, Könyv adatbázis, Kollaboráció

---

🤝 Közreműködés

```bash
git clone https://github.com/sorosg/Epub-translate.git
cd Epub-translate
docker compose up -d
```

· Hibajelentés: https://github.com/sorosg/Epub-translate/issues
· Feature Request: https://github.com/sorosg/Epub-translate/discussions

---

📄 Licensz

MIT License

---

🙏 Köszönetnyilvánítás

· DeepSeek - Nyílt forráskódú AI modellek
· Ollama - Modell futtatás
· Flask - Web keretrendszer
· psutil - Rendszer monitorozás
· Tesseract OCR - Szövegfelismerés
· SpeechRecognition - Beszédfelismerés
· Chart.js - Grafikonok
· EbookLib - EPUB kezelés

---

📞 Támogatás

· 📧 Email: sorosgergo@gmail.com
· 🌐 GitHub: https://github.com/sorosg/Epub-translate
· 📚 Dokumentáció: https://github.com/sorosg/Epub-translate/wiki

---

Készült ❤️-vel Magyarországon


```
```