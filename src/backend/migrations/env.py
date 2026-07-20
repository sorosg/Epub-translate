"""Alembic migrációs környezet – EPUB Translator.
Az alkalmazás Config osztályából olvassa az adatbázis URL-t,
a models.py-ban definiált SQLAlchemy modellek metaadatát használja.
"""
from logging.config import fileConfig
from alembic import context

# --- Alkalmazás importok ---
# sys.path beállítása, hogy a backend könyvtárból tudjunk modulokat importálni
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from config import Config
from models import db

# Alembic Config objektum
alembic_config = context.config

# Logging
if alembic_config.config_file_name is not None:
    fileConfig(alembic_config.config_file_name)

# Metaadat a modellekből (minden tábla figyelése)
target_metadata = db.metadata

# Egyéb konfigurációk
def get_url():
    """Adatbázis URL a Config osztályból vagy környezeti változóból."""
    # Docker környezetben a DATABASE_URL környezeti változóból
    db_url = Config.SQLALCHEMY_DATABASE_URI
    if not db_url:
        db_url = os.environ.get(
            'DATABASE_URL',
            'postgresql://epub_user:epub_password@postgres:5432/epub_translator'
        )
    return db_url

def run_migrations_offline() -> None:
    """Offline migráció – SQL script generálása."""
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()

def run_migrations_online() -> None:
    """Online migráció – közvetlen adatbázis kapcsolattal."""
    from sqlalchemy import create_engine

    url = get_url()
    connectable = create_engine(url, pool_pre_ping=True)

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()