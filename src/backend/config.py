import os
from dotenv import load_dotenv
load_dotenv()

# --- Platformfüggetlen adatkönyvtár ---
# Dockerben az /app a bázis; natív (desktop) környezetben a felhasználói
# könyvtár (~/.epub-translator) alá kerül minden adat.
def _resolve_data_dir():
    env = os.environ.get('DATA_DIR')
    if env:
        return env.rstrip('/')
    # Docker: a backend forráskódja KÖZVETLENÜL /app alatt van
    # (a Dockerfile a backend tartalmát /app-ba másolja), tehát az /app/app.py
    # léte az egyértelmű jel.
    if os.path.exists('/app/app.py'):
        return '/app'
    import pathlib
    return str(pathlib.Path.home() / '.epub-translator')

DATA_DIR = _resolve_data_dir()

class Config:
    @staticmethod
    def gpu_available():
        """True, ha a hoston elérhető NVIDIA GPU (nvidia-smi fut és van VRAM).
        A desktop UI ezt használja: GPU nélkül a helyi (Ollama) fordítás
        hetekig tartana, ezért figyelmeztetést adunk."""
        import subprocess
        try:
            out = subprocess.run(
                ['nvidia-smi', '--query-gpu=memory.total', '--format=csv,noheader,nounits'],
                capture_output=True, text=True, timeout=3,
            )
            if out.returncode != 0:
                return False
            total = (out.stdout.strip().split('\n')[0] if out.stdout.strip() else '').strip()
            return total.isdigit() and int(total) > 0
        except Exception:
            return False

    # Desktop (egyfelhasználós) mód: ha az Electron sidecar ezt a flag-et
    # indítja, a backend automatikusan bejelentkezteti a helyi felhasználót
    # (nincs login UI). Docker/Postgres szerver módban alapból False.
    DESKTOP_MODE = os.environ.get('DESKTOP_MODE', 'n').lower() in ('true', '1', 'i')

    VERSION = os.environ.get('VERSION', '3.0.1')
    CODENAME = os.environ.get('CODENAME', 'Smart Optimizer')
    RELEASE_DATE = os.environ.get('RELEASE_DATE', '2026-08-12')
    SECRET_KEY = os.environ.get('SECRET_KEY', 'change-this')
    # --- Adatbázis kiválasztása (Postgres / SQLite) ---
    # Docker/Postgres esetén a DATABASE_URL a postgres://... URI-t adja.
    # Önálló (desktop) telepítésnél DATABASE_URL nincs beállítva, ezért SQLite
    # fájlra váltunk (egyfelhasználós, függőségmentes).
    _DATABASE_URL = os.environ.get('DATABASE_URL')
    if _DATABASE_URL:
        SQLALCHEMY_DATABASE_URI = _DATABASE_URL
    else:
        _db_path = os.environ.get(
            'SQLITE_PATH',
            os.path.join(DATA_DIR, 'epub_translator.db'),
        )
        SQLALCHEMY_DATABASE_URI = f"sqlite:///{_db_path}"
    OLLAMA_HOST = os.environ.get('OLLAMA_HOST', 'http://ollama:11434')
    DEEPSEEK_API_URL = 'https://api.deepseek.com/v1/chat/completions'
    DEFAULT_MODEL = os.environ.get('SELECTED_MODEL', 'deepseek-r1:14b')
    RECOMMENDED_MODEL = os.environ.get('RECOMMENDED_MODEL', 'deepseek-r1:14b')
    MAX_WORKERS = int(os.environ.get('MAX_WORKERS', 3))
    # Elérhető távoli (felhős) modellek listája – DeepSeek Pro
    # Az árak USD / 1 millió token (becsült, a hivatalos DeepSeek árlista alapján).
    # Konfigurálhatók környezeti változóval is, hogy az árváltozások kézzel
    # frissíthetők legyenek kódmódosítás nélkül.
    import json as _json
    DEEPSEEK_PRICING = _json.loads(os.environ.get('DEEPSEEK_PRICING', _json.dumps({
        'deepseek-chat': {'input': 0.27, 'output': 1.10},
        'deepseek-reasoner': {'input': 0.55, 'output': 2.19},
    })))
    REMOTE_MODELS = [
        {
            'id': 'deepseek-chat',
            'name': 'DeepSeek Chat (V3)',
            'provider': 'deepseek',
            'description': 'Általános célú, gyors',
            'input_price_per_mtok': DEEPSEEK_PRICING.get('deepseek-chat', {}).get('input', 0.27),
            'output_price_per_mtok': DEEPSEEK_PRICING.get('deepseek-chat', {}).get('output', 1.10),
        },
        {
            'id': 'deepseek-reasoner',
            'name': 'DeepSeek Reasoner (R1)',
            'provider': 'deepseek',
            'description': 'Logikai feladatokhoz, lassabb de pontosabb',
            'input_price_per_mtok': DEEPSEEK_PRICING.get('deepseek-reasoner', {}).get('input', 0.55),
            'output_price_per_mtok': DEEPSEEK_PRICING.get('deepseek-reasoner', {}).get('output', 2.19),
        },
    ]
    BATCH_SIZE = int(os.environ.get('BATCH_SIZE', 5))
    ADMIN_EMAIL = os.environ.get('ADMIN_EMAIL', 'admin@epub-translator.local')
    ADMIN_PASSWORD = os.environ.get('ADMIN_PASSWORD', 'Abrakadabra')
    ENABLE_AUTO_OPTIMIZE = os.environ.get('ENABLE_AUTO_OPTIMIZE', 'i').lower() == 'i'
    ENABLE_RESOURCE_MONITOR = os.environ.get('ENABLE_RESOURCE_MONITOR', 'i').lower() == 'i'
    ENABLE_SMART_SWITCH = os.environ.get('ENABLE_SMART_SWITCH', 'i').lower() == 'i'
    ENABLE_AI_ASSISTANT = os.environ.get('ENABLE_AI_ASSISTANT', 'i').lower() == 'i'
    # Második menet (minőségellenőrző review). v2.5.2-től ALAPBÓL KIKAPCSOLVA,
    # mert a csonkolt bemenetből a modell duplikálta a szöveget. Visszaépítéshez
    # állítsd 'i'-re (vagy 'true'/'1'-re) ezt a környezeti változót.
    ENABLE_SECOND_PASS = os.environ.get('ENABLE_SECOND_PASS', 'n').lower() in ('true', '1', 'i')
    # A mappák Dockerben /app alatt vannak; natív telepítésnél a DATA_DIR
    # (alapból ~/.epub-translator) alatt (platformfüggetlen).
    UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER', os.path.join(DATA_DIR, 'uploads', 'books'))
    OUTPUT_FOLDER = os.environ.get('OUTPUT_FOLDER', os.path.join(DATA_DIR, 'output'))
    REFERENCE_FOLDER = os.environ.get('REFERENCE_FOLDER', os.path.join(DATA_DIR, 'uploads', 'reference'))
    LIBRARY_FOLDER = os.environ.get('LIBRARY_FOLDER', os.path.join(DATA_DIR, 'uploads', 'library'))
    LOG_DIR = os.environ.get('LOG_DIR', os.path.join(DATA_DIR, 'logs'))
    # --- Email (Flask-Mail) beállítások ---
    # SMTP_MODE: 'local' (MailHog teszt) vagy 'remote' (külső SMTP szerver)
    SMTP_MODE = os.environ.get('SMTP_MODE', 'local')
    MAIL_SERVER = os.environ.get('SMTP_HOST', 'mailhog')
    MAIL_PORT = int(os.environ.get('SMTP_PORT', 1025))
    MAIL_USE_TLS = os.environ.get('SMTP_USE_TLS', 'false').lower() in ('true', '1', 'i')
    MAIL_USE_SSL = os.environ.get('SMTP_USE_SSL', 'false').lower() in ('true', '1', 'i')
    MAIL_USERNAME = os.environ.get('SMTP_USER') or None
    MAIL_PASSWORD = os.environ.get('SMTP_PASSWORD') or None
    MAIL_DEFAULT_SENDER = os.environ.get('MAIL_DEFAULT_SENDER', 'epub-translator@localhost')
    # A csatolmány maximális mérete (byte) – ennél nagyobb EPUB-ot nem csatolunk.
    EMAIL_ATTACHMENT_MAX_BYTES = int(os.environ.get('EMAIL_ATTACHMENT_MAX_BYTES', 24 * 1024 * 1024))
    REDIS_URL = os.environ.get('REDIS_URL', 'redis://redis:6379/0')
    OPTIMAL_MEMORY_LIMIT = os.environ.get('OPTIMAL_MEMORY_LIMIT', '28G')
    OPTIMAL_REDIS = os.environ.get('OPTIMAL_REDIS', '768mb')
    OPTIMAL_PG_BUFFERS = os.environ.get('OPTIMAL_PG_BUFFERS', '768MB')