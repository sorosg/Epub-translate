from flask_sqlalchemy import SQLAlchemy
from flask_login import UserMixin
from datetime import datetime
import json
db = SQLAlchemy()

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255))
    first_name = db.Column(db.String(80))
    last_name = db.Column(db.String(80))
    internal_email = db.Column(db.String(120), unique=True)
    tokens = db.Column(db.Integer, default=5)
    is_admin = db.Column(db.Boolean, default=False)
    language = db.Column(db.String(5), default='hu')
    dark_mode = db.Column(db.Boolean, default=True)
    points = db.Column(db.Integer, default=0)
    level = db.Column(db.Integer, default=1)
    address = db.Column(db.String(255))
    birth_date = db.Column(db.String(20))
    tax_id = db.Column(db.String(50))
    phone = db.Column(db.String(30))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Translation(db.Model):
    __tablename__ = 'translations'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    original_filename = db.Column(db.String(255))
    output_filename = db.Column(db.String(255))
    status = db.Column(db.String(50), default='pending')
    progress = db.Column(db.Integer, default=0)
    model_used = db.Column(db.String(100))
    quality_score = db.Column(db.Integer)
    # Részletes progressz követés mezők
    current_stage = db.Column(db.String(30), default='pending')  # pending, first_pass, second_pass, post_processing, completed
    current_chapter = db.Column(db.Integer, default=0)  # aktuális fejezet index
    total_chapters = db.Column(db.Integer, default=0)  # összes fejezet
    words_processed = db.Column(db.Integer, default=0)  # feldolgozott szavak
    total_words = db.Column(db.Integer, default=0)  # összes szó a könyvben
    nodes_translated = db.Column(db.Integer, default=0)  # lefordított text node-ok
    nodes_failed = db.Column(db.Integer, default=0)  # sikertelen node-ok
    # Kétmenetes fordítás mezők
    first_pass_model = db.Column(db.String(100))  # első menet modellje (pl. 7b)
    second_pass_model = db.Column(db.String(100))  # második menet modellje (pl. 14b)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# ---- 1. GLOSSZÁRIUM (automatikus terminológia építés) ----
class GlossaryEntry(db.Model):
    """Fordítási glosszárium bejegyzés – angol→magyar szópárok tárolása.
    Automatikusan épül a lefordított könyvekből, és a későbbi fordításoknál
    terminológiai következetességet biztosít."""
    __tablename__ = 'glossary_entries'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    source_term = db.Column(db.String(500), nullable=False)  # angol szó/kifejezés
    target_term = db.Column(db.String(500), nullable=False)  # magyar fordítás
    language_pair = db.Column(db.String(10), default='en-hu')  # nyelvpár
    category = db.Column(db.String(50), default='general')  # kategória: character, place, term, general
    source_count = db.Column(db.Integer, default=1)  # hányszor fordult elő
    confidence = db.Column(db.Float, default=1.0)  # megbízhatóság (1.0 = biztos)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# ---- 4. FORDÍTÁSI MEMÓRIA (Translation Memory cache) ----
class TranslationMemory(db.Model):
    """Fordítási memória – lefordított mondatok cache-elése a gyorsabb és 
    konzisztensebb újrafordításhoz. Fuzzy matching alapján keresi a hasonló 
    mondatokat (75%+ hasonlóság)."""
    __tablename__ = 'translation_memory'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    source_text = db.Column(db.Text, nullable=False)  # eredeti angol szöveg
    translated_text = db.Column(db.Text, nullable=False)  # magyar fordítás
    source_hash = db.Column(db.String(64), unique=True)  # SHA256 a gyors kereséshez
    language_pair = db.Column(db.String(10), default='en-hu')
    usage_count = db.Column(db.Integer, default=1)  # hányszor használták
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_used = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class SystemSettings(db.Model):
    __tablename__ = 'system_settings'
    id = db.Column(db.Integer, primary_key=True)
    key = db.Column(db.String(100), unique=True)
    value = db.Column(db.Text)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class OptimizationLog(db.Model):
    __tablename__ = 'optimization_logs'
    id = db.Column(db.Integer, primary_key=True)
    model = db.Column(db.String(100))
    action = db.Column(db.String(50))
    details = db.Column(db.Text)
    performance_before = db.Column(db.Text)
    performance_after = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Book(db.Model):
    __tablename__ = 'books'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    filename = db.Column(db.String(255), nullable=False)
    file_path = db.Column(db.String(500))
    title = db.Column(db.String(500))
    author = db.Column(db.String(255))
    language = db.Column(db.String(10), default='en')
    genre = db.Column(db.String(100))
    series = db.Column(db.String(255))
    series_number = db.Column(db.Integer)
    uploaded_at = db.Column(db.DateTime, default=datetime.utcnow)
    # Kapcsolat a feltöltő felhasználóhoz
    uploader = db.relationship('User', backref='uploaded_books')

class UserBookPreference(db.Model):
    """Felhasználónkénti könyvbeállítások (pl. kiválasztás fordításhoz)."""
    __tablename__ = 'user_book_preferences'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    book_id = db.Column(db.Integer, db.ForeignKey('books.id'), nullable=False)
    is_selected = db.Column(db.Boolean, default=False)
    notes = db.Column(db.Text)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    __table_args__ = (db.UniqueConstraint('user_id', 'book_id', name='uq_user_book'),)

class ReferenceBook(db.Model):
    __tablename__ = 'reference_books'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    filename = db.Column(db.String(255))
    title = db.Column(db.String(255))
    language = db.Column(db.String(10), default='hu')
    file_path = db.Column(db.String(500))
    extracted_text = db.Column(db.Text)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)