from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, send_file, send_from_directory
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_babel import Babel, gettext as _
from flasgger import Swagger
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, SystemSettings, OptimizationLog, ReferenceBook, Book, GlossaryEntry, TranslationMemory, UserBookPreference, ReaderBookmark, ReadingHistory
from datetime import datetime
from functools import wraps
from packaging import version as pkg_version
import os, json, psutil, requests, threading, uuid, shutil, logging

app = Flask(__name__)
app.config.from_object(Config)
app.config['SWAGGER'] = {
    'title': 'EPUB Translator API',
    'uiversion': 3,
    'version': Config.VERSION,
    'description': 'Docker-alapú EPUB fordító rendszer Ollama AI-val. Fordítás, könyvtárkezelés, admin funkciók.',
    'specs': [{
        'endpoint': 'apispec',
        'route': '/api/apispec.json',
    }],
    'swagger_ui': True, 
    'specs_route': '/api/docs/'
}
swagger = Swagger(app, template={
    'swagger': '2.0',
    'info': {
        'title': 'EPUB Translator API',
        'version': Config.VERSION,
        'description': 'Docker-alapú EPUB fordító rendszer API dokumentációja'
    },
    'basePath': '/',
    'schemes': ['http', 'https'],
    'tags': [
        {'name': 'Auth', 'description': 'Autentikáció és session kezelés'},
        {'name': 'Translation', 'description': 'Fordítás kezelése (feltöltés, státusz, letöltés)'},
        {'name': 'Library', 'description': 'Közös könyvtár kezelése'},
        {'name': 'Review', 'description': 'Fordítás átnézés és szerkesztés'},
        {'name': 'Admin', 'description': 'Adminisztrációs funkciók'},
        {'name': 'System', 'description': 'Rendszer monitorozás és frissítés'}
    ]
})
# A mappák a Config-ból jönnek (platformfüggetlen): Dockerben /app alatt,
# natív (desktop) környezetben ~/.epub-translator alatt.
app.config['UPLOAD_FOLDER'] = Config.UPLOAD_FOLDER
app.config['REFERENCE_FOLDER'] = Config.REFERENCE_FOLDER
app.config['OUTPUT_FOLDER'] = Config.OUTPUT_FOLDER
app.config['LIBRARY_FOLDER'] = Config.LIBRARY_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 200 * 1024 * 1024
db.init_app(app)

# --- LOGOLÁS BEÁLLÍTÁSA ---
import sys
LOG_DIR = Config.LOG_DIR
os.makedirs(LOG_DIR, exist_ok=True)

# Közös formatter
log_formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')

# Alkalmazás log (összes request, hiba) – fájlba + stdout-ra (Docker logs)
app_logger = logging.getLogger('epub_translator')
app_logger.setLevel(logging.INFO)
# Fájl handler
fh_app = logging.FileHandler(os.path.join(LOG_DIR, 'app.log'), encoding='utf-8')
fh_app.setLevel(logging.INFO)
fh_app.setFormatter(log_formatter)
app_logger.addHandler(fh_app)
# Stdout handler – azonnali visszajelzés a docker logs-ban
sh_app = logging.StreamHandler(sys.stdout)
sh_app.setLevel(logging.INFO)
sh_app.setFormatter(log_formatter)
app_logger.addHandler(sh_app)

# Fordítási log – translation.log + stdout (Docker logs)
translation_logger = logging.getLogger('epub_translator.translation')
translation_logger.setLevel(logging.DEBUG)
# Fájl handler
fh_trans = logging.FileHandler(os.path.join(LOG_DIR, 'translation.log'), encoding='utf-8')
fh_trans.setLevel(logging.DEBUG)
fh_trans.setFormatter(log_formatter)
translation_logger.addHandler(fh_trans)
# Stdout handler – azonnali visszajelzés (docker logs epub-backend)
sh_trans = logging.StreamHandler(sys.stdout)
sh_trans.setLevel(logging.DEBUG)
sh_trans.setFormatter(log_formatter)
translation_logger.addHandler(sh_trans)
translation_logger.propagate = False  # a fordítási log NE menjen duplán az app.log-ba

def _trans_log(msg, level='INFO'):
    """Megbízható fordítási naplózás: KÖZVETLENÜL a translation.log fájlba és a
    stdout-ra ír, flush-sel. A logging modul handlerjei gunicorn worker +
    háttérszál környezetben nem mindig írnak ki időben, ezért a fordítási szál
    ezt a direkt írást használja (a fájl írhatósága ellenőrizve, a fordítás
    fut, de a logger néma maradt).
    """
    ts = datetime.utcnow().isoformat()
    ln = f"{ts} [{level.upper()}] {msg}"
    try:
        with open(os.path.join(LOG_DIR, 'translation.log'), 'a', encoding='utf-8') as _f:
            _f.write(ln + "\n")
    except Exception:
        pass
    try:
        print(ln, flush=True)
    except Exception:
        pass


# Flask built-in logger
app.logger.handlers.clear()
app.logger.addHandler(fh_app)

app_logger.info(f"=== EPUB Translator v{Config.VERSION} indítása ===")

def get_locale():
    return 'hu'

babel = Babel(app, locale_selector=get_locale)

# Context processor: minden template számára elérhető config
@app.context_processor
def inject_config():
    return {'config': Config}

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(app.config['REFERENCE_FOLDER'], exist_ok=True)
os.makedirs(app.config['OUTPUT_FOLDER'], exist_ok=True)
os.makedirs(app.config['LIBRARY_FOLDER'], exist_ok=True)

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# Desktop (egyfelhasználós) mód: automatikus bejelentkezés.
# Ha az Electron sidecar DESKTOP_MODE=1 flag-gel indítja a backendet, nincs
# login oldal; minden kérés előtt gondoskodunk arról, hogy a helyi felhasználó
# be legyen jelentkezve. (Docker/Postgres szerver módban a Config.DESKTOP_MODE
# False, így ez a hook no-op.)
@app.before_request
def _desktop_auto_login():
    if not Config.DESKTOP_MODE:
        return None
    if current_user.is_authenticated:
        return None
    user = User.query.filter_by(email='desktop@local').first()
    if not user:
        user = User(
            username='desktop',
            email='desktop@local',
            password_hash='!',  # nem használt (nincs login)
            first_name='Helyi',
            last_name='Felhasználó',
            is_admin=True,
            tokens=999999,
            preferred_model_source='remote',
        )
        db.session.add(user)
        db.session.commit()
    login_user(user)
    return None

limiter = Limiter(app=app, key_func=get_remote_address, default_limits=["5000 per day", "2000 per hour"])

# A React SPA-hitelesítéshez: amikor egy /api/ végpont login_required miatt
# 401-el térne vissza, JSON választ adjunk a HTML-es 302 redirect helyett.
# Ellenkező esetben a frontend authStore.fetchUser() HTML-t kapna, és az SPA
# betöltése "blank page"-nél állna meg.
@login_manager.unauthorized_handler
def api_unauthorized():
    if request.path.startswith('/api/'):
        return jsonify({'error': 'Nincs bejelentkezve', 'authenticated': False}), 401
    return redirect(url_for('login', next=request.url))

ALLOWED_EXTENSIONS = {'epub'}

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def admin_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not current_user.is_authenticated or not current_user.is_admin:
            flash(_('Admin jogosultság szükséges!'), 'error')
            return redirect(url_for('dashboard'))
        return f(*args, **kwargs)
    return decorated

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/health')
def health():
    return jsonify({
        'status':'healthy',
        'version':app.config['VERSION'],
        'model':app.config['DEFAULT_MODEL'],
        'desktop_mode': Config.DESKTOP_MODE,
        'gpu_available': Config.gpu_available(),
    })

@app.route('/')
def index():
    return redirect(url_for('dashboard') if current_user.is_authenticated else url_for('login'))

import traceback as _traceback

@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('admin') if current_user.is_admin else url_for('dashboard'))
    if request.method == 'POST':
        try:
            email = request.form.get('email','').strip()
            password = request.form.get('password','')
            user = User.query.filter_by(email=email).first()
            if user and user.password_hash and check_password_hash(user.password_hash, password):
                login_user(user)
                return redirect(url_for('admin') if user.is_admin else url_for('dashboard'))
            flash(_('Hibás email vagy jelszó!'),'error')
        except Exception as e:
            app.logger.error(f"Login error: {_traceback.format_exc()}")
            flash(_(f'Bejelentkezési hiba: {str(e)[:100]}'),'error')
    return render_template('login.html')

@app.errorhandler(500)
def internal_server_error(e):
    app.logger.error(f"500 error: {_traceback.format_exc()}")
    return f"<h2>500 Internal Server Error</h2><pre>{_traceback.format_exc()}</pre>", 500

@app.route('/api/login', methods=['POST'])
def api_login():
    """JSON alapú bejelentkezés a React SPA számára.
    Sikeres belépéskor a felhasználó adatait adja vissza JSON-ban,
    hibás adatnál 401-es hibát JSONban."""
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip()
    password = data.get('password') or ''
    user = User.query.filter_by(email=email).first()
    if user and user.password_hash and check_password_hash(user.password_hash, password):
        login_user(user)
        return jsonify({
            'success': True,
            'user': {
                'id': user.id,
                'email': user.email,
                'first_name': user.first_name or '',
                'last_name': user.last_name or '',
                'tokens': user.tokens,
                'is_admin': user.is_admin,
                'preferred_model_source': user.preferred_model_source or 'local',
                'preferred_model': user.preferred_model or '',
            }
        })
    return jsonify({'success': False, 'error': 'Hibás email vagy jelszó'}), 401

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    translations = Translation.query.filter_by(user_id=current_user.id).order_by(Translation.created_at.desc()).all()
    ref_books = ReferenceBook.query.filter_by(user_id=current_user.id).order_by(ReferenceBook.created_at.desc()).all()
    # Közös könyvtárból: saját könyvek + kiválasztottak
    my_books = Book.query.filter_by(user_id=current_user.id).order_by(Book.uploaded_at.desc()).all()
    # Felhasználó által kiválasztott könyvek (UserBookPreference)
    selected_prefs = UserBookPreference.query.filter_by(user_id=current_user.id, is_selected=True).all()
    selected_book_ids = [p.book_id for p in selected_prefs]
    selected_books = Book.query.filter(Book.id.in_(selected_book_ids)).all() if selected_book_ids else []
    # Összefésült lista (saját + kiválasztott), duplikáció nélkül
    all_book_ids = set()
    books = []
    for b in my_books + selected_books:
        if b.id not in all_book_ids:
            all_book_ids.add(b.id)
            books.append(b)
    # Preferenciák dict
    prefs = {p.book_id: p for p in UserBookPreference.query.filter_by(user_id=current_user.id).all()}
    return render_template('dashboard.html', user=current_user, translations=translations, ref_books=ref_books, books=books, book_prefs=prefs, Config=Config)

@app.route('/upload', methods=['POST'])
@login_required
def upload_epub():
    if 'file' not in request.files:
        flash(_('Nincs fájl kiválasztva!'),'error')
        return redirect(url_for('dashboard'))
    file = request.files['file']
    if file.filename == '' or not allowed_file(file.filename):
        flash(_('Csak EPUB fájlok tölthetők fel!'),'error')
        return redirect(url_for('dashboard'))
    if current_user.tokens <= 0:
        flash(_('Nincs elég tokened a fordításhoz!'),'error')
        return redirect(url_for('dashboard'))
    filename = f"{uuid.uuid4().hex}_{secure_filename(file.filename)}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)
    
    # Modell forrás mentése (local/remote) a felhasználó preferenciája alapján
    model_source = request.form.get('model_source', 'local')
    model_used = app.config['DEFAULT_MODEL']
    if model_source == 'remote' and current_user.deepseek_api_key:
        # A felhasználó által kiválasztott remote modell (deepseek-chat vagy deepseek-reasoner)
        selected_remote = request.form.get('selected_model', '') or current_user.preferred_model or 'deepseek-chat'
        model_used = selected_remote if selected_remote in ('deepseek-chat', 'deepseek-reasoner') else 'deepseek-chat'
    
    translation = Translation(user_id=current_user.id, original_filename=file.filename, output_filename=None, status='pending', progress=0, model_used=model_used)
    db.session.add(translation)
    # Modell forrás elmentése a Translation objektumba (a model_used mezőbe kódolva)
    translation.first_pass_model = model_source  # ideiglenesen itt tároljuk a source-t
    
    current_user.tokens -= 1
    # A kiválasztott könyvtári könyveket hozzárendeljük a fordításhoz
    # 1. A dashboard-ból érkező reference_ids[] (könyvajánló alapján)
    # 2. A korábban kiválasztott UserBookPreference bejegyzések
    reference_ids = request.form.getlist('reference_ids[]')
    all_selected_books = []
    
    if reference_ids:
        # A dashboard-ból érkező referencia könyvek
        ref_books = Book.query.filter(Book.id.in_([int(rid) for rid in reference_ids if rid.isdigit()])).all()
        all_selected_books.extend(ref_books)
        # UserBookPreference bejegyzések létrehozása/frissítése a kiválasztott könyvekhez
        for rb in ref_books:
            pref = UserBookPreference.query.filter_by(user_id=current_user.id, book_id=rb.id).first()
            if pref:
                pref.is_selected = True
            else:
                pref = UserBookPreference(user_id=current_user.id, book_id=rb.id, is_selected=True)
                db.session.add(pref)
        app_logger.info(f"Fordítás #{translation.id}: {len(ref_books)} referencia könyv a dashboard ajánlóból")
    
    # Korábban kiválasztott könyvek (UserBookPreference) hozzáadása
    selected_prefs = UserBookPreference.query.filter_by(user_id=current_user.id, is_selected=True).all()
    for p in selected_prefs:
        book = Book.query.get(p.book_id)
        if book and book not in all_selected_books:
            all_selected_books.append(book)
    
    # Kiválasztás törlése
    for p in selected_prefs:
        p.is_selected = False
    db.session.commit()
    thread = threading.Thread(target=translate_epub, args=(app, translation.id, filepath, [b.file_path for b in all_selected_books], model_source))
    thread.daemon = True
    thread.start()
    app_logger.info(f"📤 Feltöltés: {file.filename} -> Fordítás #{translation.id} ({model_used})")
    flash(_('Fájl feltöltve, fordítás folyamatban...'),'success')
    return redirect(url_for('dashboard'))

@app.route('/api/status/<int:translation_id>')
@login_required
def translation_status(translation_id):
    """Fordítás állapotának lekérdezése.
    ---
    tags:
      - Translation
    parameters:
      - name: translation_id
        in: path
        type: integer
        required: true
        description: A fordítás azonosítója
    responses:
      200:
        description: A fordítás részletes állapota
        schema:
          type: object
          properties:
            id:
              type: integer
            status:
              type: string
              enum: [pending, processing, completed, failed]
            progress:
              type: integer
            current_stage:
              type: string
            current_chapter:
              type: integer
            total_chapters:
              type: integer
            words_processed:
              type: integer
            total_words:
              type: integer
            quality_score:
              type: integer
      403:
        description: Nincs jogosultság
    """
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error':'Nincs jogosultságod'}), 403
    # Eltelt idő és becsült hátralévő idő számítása
    elapsed_seconds = 0
    estimated_seconds = 0
    if t.created_at and t.status == 'processing' and t.progress > 0:
        elapsed_seconds = int((datetime.utcnow() - t.created_at).total_seconds())
        if t.progress > 0:
            estimated_seconds = int(elapsed_seconds * (100 - t.progress) / t.progress)
    
    return jsonify({
        'id':t.id,
        'status':t.status,
        'progress':t.progress,
        'original_filename':t.original_filename,
        # Részletes progressz mezők (5. fejlesztés)
        'current_stage': t.current_stage,
        'current_chapter': t.current_chapter,
        'total_chapters': t.total_chapters,
        'words_processed': t.words_processed,
        'total_words': t.total_words,
        'nodes_translated': t.nodes_translated,
        'nodes_failed': t.nodes_failed,
        'first_pass_model': t.first_pass_model,
        'second_pass_model': t.second_pass_model,
        'output_filename': t.output_filename,
        'model_used': t.model_used,
        'quality_score': t.quality_score,
        'created_at': to_budapest(t.created_at) if t.created_at else None,
        # Becsült idő mezők
        'elapsed_seconds': elapsed_seconds,
        'estimated_seconds': estimated_seconds,
        # Token/költség napló
        'input_tokens_used': t.input_tokens_used,
        'output_tokens_used': t.output_tokens_used,
        'cost_usd': t.cost_usd
    })

@app.route('/api/model/status')
@login_required
@admin_required
def model_status():
    try:
        resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/ps", timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            models = data.get('models',[])
            result = [{'name':m.get('name',''),'size_gb':round(m.get('size',0)/(1024**3),2)} for m in models]
            return jsonify({'models':result})
        return jsonify({'error':'Nem érhető el az Ollama'}), resp.status_code
    except Exception as e:
        return jsonify({'error':str(e)[:100]}), 500

@app.route('/api/translations', methods=['GET'])
@login_required
def api_translations():
    """A felhasználó összes fordításának lekérése (a React Dashboard listához)."""
    translations = Translation.query.filter_by(user_id=current_user.id)\
        .order_by(Translation.created_at.desc()).all()
    return jsonify({'translations': [{
        'id': t.id,
        'status': t.status,
        'progress': t.progress,
        'original_filename': t.original_filename,
        'current_stage': t.current_stage,
        'current_chapter': t.current_chapter,
        'total_chapters': t.total_chapters,
        'words_processed': t.words_processed,
        'total_words': t.total_words,
        'model_used': t.model_used,
        'quality_score': t.quality_score,
        'created_at': to_budapest(t.created_at) if t.created_at else None,
        'input_tokens_used': t.input_tokens_used,
        'output_tokens_used': t.output_tokens_used,
        'cost_usd': t.cost_usd,
    } for t in translations]})

@app.route('/api/translations/events')
@login_required
def translation_events():
    """Fordítási események – a dashboard polling-olja.
    Visszaadja az utolsó 5 eseményt (státuszváltozás, befejezés, hiba).
    """
    translations = Translation.query.filter_by(user_id=current_user.id)\
        .order_by(Translation.created_at.desc()).limit(5).all()
    events = []
    for t in translations:
        if t.status == 'completed':
            events.append({
                'id': t.id, 'type': 'success', 
                'message': f'✅ {t.original_filename} – Fordítás kész! (minőség: {t.quality_score}/100)',
                'time': to_budapest(t.created_at) if t.created_at else ''
            })
        elif t.status == 'processing':
            events.append({
                'id': t.id, 'type': 'info',
                'message': f'⏳ {t.original_filename} – Fordítás folyamatban ({t.progress}%)...',
                'time': to_budapest(t.created_at) if t.created_at else ''
            })
        elif t.status == 'failed':
            events.append({
                'id': t.id, 'type': 'error',
                'message': f'❌ {t.original_filename} – Fordítás sikertelen',
                'time': to_budapest(t.created_at) if t.created_at else ''
            })
    return jsonify({'events': events})

@app.route('/download/<int:translation_id>')
@login_required
def download_translation(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        flash(_('Nincs jogosultságod'),'error'); return redirect(url_for('dashboard'))
    if t.status != 'completed' or not t.output_filename:
        flash(_('A fordítás még nem készült el'),'error'); return redirect(url_for('dashboard'))
    output_path = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
    if not os.path.exists(output_path):
        flash(_('A fájl nem található'),'error'); return redirect(url_for('dashboard'))
    return send_file(output_path, as_attachment=True, download_name=f"forditott_{t.original_filename}")

@app.route('/delete/<int:translation_id>', methods=['POST'])
@login_required
def delete_translation(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        flash(_('Nincs jogosultságod'),'error'); return redirect(url_for('dashboard'))
    if t.output_filename:
        out = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
        if os.path.exists(out): os.remove(out)
    db.session.delete(t); db.session.commit()
    flash(_('Fordítás törölve'),'success')
    return redirect(url_for('dashboard'))

# ---- REVIEW OLDAL (6. fejlesztés: Interaktív fordítás-javítási felület) ----
@app.route('/review/<int:translation_id>')
@login_required
def review_translation(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        flash(_('Nincs jogosultságod'),'error'); return redirect(url_for('dashboard'))
    if t.status != 'completed':
        flash(_('Csak befejezett fordításokat lehet átnézni'),'error'); return redirect(url_for('dashboard'))
    
    # EPUB szöveg kiolvasása
    from ebooklib import epub as epub_lib
    from bs4 import BeautifulSoup
    chapters = []
    try:
        output_path = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
        if os.path.exists(output_path):
            book = epub_lib.read_epub(output_path)
            items = list(book.get_items_of_type(9))
            for idx, item in enumerate(items):
                soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                text = soup.get_text().strip()
                if text and len(text) > 30:
                    chapters.append({
                        'index': idx,
                        'text': text,
                        'length': len(text)
                    })
    except Exception as e:
        flash(_(f'Nem sikerült beolvasni a fordítást: {str(e)[:100]}'),'error')
    
    return render_template('review.html', translation=t, chapters=chapters)

@app.route('/api/review/save/<int:translation_id>', methods=['POST'])
@login_required
def review_save(translation_id):
    """Egy fejezet szerkesztett szövegének mentése az EPUB-ba"""
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error':'Nincs jogosultságod'}), 403
    
    data = request.get_json()
    chapter_idx = data.get('chapter_index')
    edited_text = data.get('text', '').strip()
    
    if chapter_idx is None or not edited_text:
        return jsonify({'error':'Hiányzó adatok'}), 400
    
    try:
        from ebooklib import epub as epub_lib
        from bs4 import BeautifulSoup, NavigableString
        output_path = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
        if not os.path.exists(output_path):
            return jsonify({'error':'A fájl nem található'}), 404
        
        book = epub_lib.read_epub(output_path)
        items = list(book.get_items_of_type(9))
        
        if chapter_idx >= len(items):
            return jsonify({'error':'Érvénytelen fejezet index'}), 400
        
        item = items[chapter_idx]
        soup = BeautifulSoup(item.get_body_content(), 'html.parser')
        
        # A szerkesztett szöveg visszaírása az első text node-ba,
        # a többit töröljük (hasonlóan a második menethez)
        text_nodes = [n for n in soup.descendants if isinstance(n, NavigableString) and n.strip()]
        if text_nodes:
            for i, node in enumerate(text_nodes):
                if i == 0:
                    node.replace_with(edited_text)
                else:
                    node.replace_with('')
        else:
            # Ha nincs text node, cseréljük ki a teljes tartalmat
            soup.clear()
            soup.append(BeautifulSoup(f"<p>{edited_text}</p>", 'html.parser'))
        
        item.set_content(str(soup).encode('utf-8'))
        epub_lib.write_epub(output_path, book)
        
        app_logger.info(f"Review mentés: translation #{translation_id}, chapter {chapter_idx} (user: {current_user.email})")
        return jsonify({'success':True, 'message':f'Fejezet {chapter_idx+1} mentve'})
    except Exception as e:
        app_logger.error(f"Review mentési hiba: {_traceback.format_exc()}")
        return jsonify({'error': str(e)[:200]}), 500

# ---- KÖNYVTÁR ----
@app.route('/library')
@login_required
def library():
    return render_template('library.html')

def openlibrary_enrich(title, author):
    """OpenLibrary keresés cím+szerző alapján; visszaadja a pótolható mezőket
    (title, author, genre). Hálózati hiba/hiány esetén üres dict-et ad."""
    import requests as _req
    from urllib.parse import quote as _quote
    q = ' '.join(x for x in [title, author] if x).strip()
    if not q:
        return {}
    try:
        resp = _req.get(
            f'https://openlibrary.org/search.json?q={_quote(q)}&limit=3',
            timeout=8
        )
        if resp.status_code != 200:
            return {}
        docs = resp.json().get('docs', [])
        if not docs:
            return {}
        d = docs[0]
        result = {}
        if d.get('title'):
            result['title'] = str(d['title'])[:500]
        if d.get('author_name'):
            result['author'] = ', '.join([str(a) for a in d['author_name']])[:255]
        subjects = d.get('subject', [])
        if subjects:
            result['genre'] = ', '.join([str(g) for g in subjects[:3]])[:300]
        return result
    except Exception:
        return {}


@app.route('/api/library/upload', methods=['POST'])
@login_required
def library_upload():
    if 'file' not in request.files:
        return jsonify({'error':'Nincs fájl'}), 400
    file = request.files['file']
    if not file.filename or not allowed_file(file.filename):
        return jsonify({'error':'Csak EPUB fájl tölthető fel'}), 400
    
    title = request.form.get('title','') or file.filename.rsplit('.',1)[0]
    author = request.form.get('author','')
    genre = request.form.get('genre','')
    series = request.form.get('series','')

    # Hiányzó metaadatok automatikus pótlása OpenLibrary-ből (cím/szerző/műfaj)
    if (not genre or not author) and title:
        try:
            enriched = openlibrary_enrich(title, author)
            if not author and enriched.get('author'):
                author = enriched['author']
            if not title and enriched.get('title'):
                title = enriched['title']
            if not genre and enriched.get('genre'):
                genre = enriched['genre']
        except Exception:
            pass

    # Deduplikáció ellenőrzés: cím + szerző alapján
    if title and author:
        existing = Book.query.filter(
            db.func.lower(Book.title) == title.lower().strip(),
            db.func.lower(Book.author) == author.lower().strip()
        ).first()
        if existing:
            return jsonify({
                'error': f'Ez a könyv már szerepel a könyvtárban! Feltöltő: {existing.uploader.username if existing.uploader else "ismeretlen"}',
                'duplicate': True,
                'existing_id': existing.id,
                'existing_title': existing.title,
                'existing_author': existing.author
            }), 409
    
    filename = f"lib_{uuid.uuid4().hex}_{secure_filename(file.filename)}"
    filepath = os.path.join(app.config['LIBRARY_FOLDER'], filename)
    file.save(filepath)
    book = Book(
        user_id=current_user.id, filename=file.filename, file_path=filepath,
        title=title, author=author,
        language=request.form.get('language','en'),
        genre=genre, series=series,
        series_number=int(request.form.get('series_number',0)) if request.form.get('series_number','').isdigit() else None
    )
    db.session.add(book); db.session.commit()
    return jsonify({'success':True,'id':book.id,'message':f'"{book.title}" feltöltve'})

@app.route('/api/library/list')
@login_required
def library_list():
    # Közös könyvtár: minden könyv látható mindenki számára
    books = Book.query.order_by(Book.uploaded_at.desc()).all()
    # Felhasználónkénti preferenciák betöltése
    prefs = {p.book_id: p for p in UserBookPreference.query.filter_by(user_id=current_user.id).all()}
    return jsonify({'books':[{ 
        'id':b.id,
        'title':b.title or '',
        'author':b.author or '',
        'language':b.language or '',
        'genre':b.genre or '',
        'series':b.series or '',
        'series_number':b.series_number,
        'is_selected': prefs[b.id].is_selected if b.id in prefs else False,
        'is_owner': b.user_id == current_user.id,
        'uploader_name': b.uploader.username if b.uploader else 'Ismeretlen',
        'uploaded_at':to_budapest(b.uploaded_at) if b.uploaded_at else '',
        'filename':b.filename
    } for b in books]})

@app.route('/api/library/edit/<int:book_id>', methods=['POST'])
@login_required
def library_edit(book_id):
    book = Book.query.get_or_404(book_id)
    # Szerkesztés: csak a feltöltő vagy admin jogosult
    if book.user_id != current_user.id and not current_user.is_admin:
        return jsonify({'error':'Nincs jogosultságod a szerkesztéshez'}), 403
    book.title = request.form.get('title', book.title)
    book.author = request.form.get('author', book.author)
    book.language = request.form.get('language', book.language)
    book.genre = request.form.get('genre', book.genre)
    book.series = request.form.get('series', book.series)
    sn = request.form.get('series_number','')
    book.series_number = int(sn) if sn.isdigit() else None
    db.session.commit()
    return jsonify({'success':True})

@app.route('/api/library/delete/<int:book_id>', methods=['POST'])
@login_required
def library_delete(book_id):
    book = Book.query.get_or_404(book_id)
    # Törlés: csak a feltöltő vagy admin jogosult
    if book.user_id != current_user.id and not current_user.is_admin:
        return jsonify({'error':'Nincs jogosultságod a törléshez'}), 403
    # Töröljük a hozzá tartozó felhasználói preferenciákat is
    UserBookPreference.query.filter_by(book_id=book_id).delete()
    if book.file_path and os.path.exists(book.file_path):
        os.remove(book.file_path)
    db.session.delete(book); db.session.commit()
    return jsonify({'success':True})

@app.route('/api/library/toggle/<int:book_id>', methods=['POST'])
@login_required
def library_toggle(book_id):
    """Könyv kiválasztása/visszavonása fordításhoz – felhasználónkénti preferencia."""
    book = Book.query.get_or_404(book_id)
    # Megnézzük, van-e már preferencia bejegyzés
    pref = UserBookPreference.query.filter_by(user_id=current_user.id, book_id=book_id).first()
    if pref:
        pref.is_selected = not pref.is_selected
    else:
        pref = UserBookPreference(user_id=current_user.id, book_id=book_id, is_selected=True)
        db.session.add(pref)
    db.session.commit()
    return jsonify({'success':True,'is_selected':pref.is_selected})

@app.route('/api/library/extract-metadata', methods=['POST'])
@login_required
def library_extract_metadata():
    """EPUB fájl belső metaadatainak kinyerése (cím, szerző, nyelv).
    ---
    tags:
      - Library
    consumes:
      - multipart/form-data
    parameters:
      - name: file
        in: formData
        type: file
        required: true
        description: A feltöltendő EPUB fájl
    responses:
      200:
        description: A kinyert metaadatok
    """
    # EPUB belső metaadat kinyerése (dc:title, dc:creator, dc:language)
    if 'file' not in request.files:
        return jsonify({'error': 'Nincs fájl'}), 400
    file = request.files['file']
    if not file.filename or not allowed_file(file.filename):
        return jsonify({'error': 'Csak EPUB fájl dolgozható fel'}), 400
    
    try:
        import tempfile
        from ebooklib import epub as epub_lib
        
        # EPUB tartalom beolvasása memóriából (ideiglenes fájlba mentés)
        with tempfile.NamedTemporaryFile(suffix='.epub', delete=False) as tmp:
            file.save(tmp.name)
            tmp_path = tmp.name
        
        try:
            book = epub_lib.read_epub(tmp_path)
            
            # Metaadatok kinyerése
            title = ''
            author = ''
            language = 'en'
            description = ''
            
            # dc:title
            titles = book.get_metadata('DC', 'title')
            if titles:
                title = titles[0][0] if isinstance(titles[0], tuple) else str(titles[0])
            
            # dc:creator
            creators = book.get_metadata('DC', 'creator')
            if creators:
                author = creators[0][0] if isinstance(creators[0], tuple) else str(creators[0])
            
            # dc:language
            langs = book.get_metadata('DC', 'language')
            if langs:
                lang_val = langs[0][0] if isinstance(langs[0], tuple) else str(langs[0])
                language = lang_val[:2].lower() if len(lang_val) >= 2 else 'en'
            
            # dc:description
            descs = book.get_metadata('DC', 'description')
            if descs:
                description = descs[0][0][:500] if isinstance(descs[0], tuple) else str(descs[0])[:500]
            
            # dc:subject (téma/műfaj) – több is lehet, vesszővel összefűzzük
            genre = ''
            subjects = book.get_metadata('DC', 'subject')
            if subjects:
                subject_list = []
                for s in subjects[:5]:  # max 5 téma
                    val = s[0] if isinstance(s, tuple) else str(s)
                    if val and len(val) > 1:
                        subject_list.append(val.strip())
                if subject_list:
                    genre = ', '.join(subject_list)
            
            # Kalibre sorozat metaadatok
            series = ''
            series_number = None
            calibre_series = book.get_metadata('OPF', 'calibre:series')
            if calibre_series:
                s_val = calibre_series[0][0] if isinstance(calibre_series[0], tuple) else str(calibre_series[0])
                if s_val and s_val.strip():
                    series = s_val.strip()
            
            # Sorozat szám
            calibre_series_idx = book.get_metadata('OPF', 'calibre:series_index')
            if calibre_series_idx:
                try:
                    idx_val = calibre_series_idx[0][0] if isinstance(calibre_series_idx[0], tuple) else str(calibre_series_idx[0])
                    # A Calibre float-ként tárolja (pl. 1.0), egészre kerekítjük
                    series_number = int(float(str(idx_val)))
                except (ValueError, TypeError):
                    pass
            
            # Kalibre cím (ha a dc:title üres)
            if not title:
                calibre_titles = book.get_metadata('OPF', 'calibre:title_sort')
                if calibre_titles:
                    title = calibre_titles[0][0] if isinstance(calibre_titles[0], tuple) else str(calibre_titles[0])

            # Sorozat kinyerése a címből/fájlnévből, ha a Calibre mező üres.
            # Gyakori minták: "The Lost Fleet: Relentless", "Title 03",
            # "Title #3", "Title - Book 3", "Title (Book 3)".
            if not series and title:
                import re as _re
                m = _re.match(r'^(.*?)[:\-–—]\s*(.*)$', title.strip())
                if m:
                    series = m.group(1).strip()
                    rest = m.group(2).strip()
                    # Ha a kettőspont utáni rész csak egy sorszám mintázat, akkor
                    # a "title" valójában sorozat + rész. Különben csak sorozatnevet
                    # jelölünk, sorszám nélkül.
                # Sorszám mintázatok a cím végén: " Title 3", " Title #3", "Book 3"
                num_m = _re.search(r'\s+(?:book\s+)?#?(\d+)\s*$', title.strip(), _re.IGNORECASE)
                if num_m and not series:
                    series = title.strip()[:num_m.start()].strip()
                    series_number = int(num_m.group(1))
            
            app_logger.info(f"EPUB metaadat kinyerve: '{title}' by '{author}' (lang: {language}, genre: {genre}, series: {series}#{series_number})")
            
            return jsonify({
                'success': True,
                'metadata': {
                    'title': title,
                    'author': author,
                    'language': language,
                    'description': description[:300] if description else '',
                    'genre': genre,
                    'series': series,
                    'series_number': series_number
                }
            })
        finally:
            os.unlink(tmp_path)  # takarítás
            
    except Exception as e:
        app_logger.warning(f"EPUB metaadat kinyerési hiba: {e}")
        return jsonify({
            'success': False,
            'error': f'Nem sikerült kinyerni a metaadatokat: {str(e)[:100]}',
            'metadata': {
                'title': file.filename.rsplit('.', 1)[0].replace('_', ' '),
                'author': '',
                'language': 'en',
                'description': '',
                'genre': '',
                'series': '',
                'series_number': None
            }
        })

@app.route('/api/library/batch-upload', methods=['POST'])
@login_required
def library_batch_upload():
    """Több könyv egyidejű feltöltése metaadatokkal.
    ---
    tags:
      - Library
    consumes:
      - application/json
    parameters:
      - name: body
        in: body
        required: true
        schema:
          type: object
          properties:
            books:
              type: array
              description: A feltöltendő könyvek listája metaadatokkal
    responses:
      200:
        description: Feltöltés eredménye (sikeres + kihagyott)
    """
    data = request.get_json()
    books_data = data.get('books', [])
    if not books_data:
        return jsonify({'error': 'Nincsenek könyvek a listában'}), 400
    
    results = {'uploaded': [], 'duplicates': [], 'errors': []}
    
    for book_info in books_data:
        title = (book_info.get('title') or '').strip()
        author = (book_info.get('author') or '').strip()
        filename = (book_info.get('filename') or '').strip()
        filepath = (book_info.get('filepath') or '').strip()
        
        if not title:
            results['errors'].append({'filename': filename, 'error': 'Hiányzó cím'})
            continue
        
        # Deduplikáció ellenőrzés
        existing = None
        if title and author:
            existing = Book.query.filter(
                db.func.lower(Book.title) == title.lower(),
                db.func.lower(Book.author) == author.lower()
            ).first()
        
        if existing:
            results['duplicates'].append({
                'title': title, 'author': author,
                'existing_id': existing.id,
                'uploader': existing.uploader.username if existing.uploader else 'ismeretlen'
            })
            # Ha van fájlunk és duplikátum, töröljük a felesleges fájlt
            if filepath and os.path.exists(filepath):
                try: os.remove(filepath)
                except: pass
            continue
        
        # Könyv létrehozása
        # Ha a fájl már fel van töltve (batch extract során mentve), használjuk azt
        # különben a filepath alapján másoljuk be
        if filepath and os.path.exists(filepath):
            # A fájl már a megfelelő helyen van (extract mentette)
            book = Book(
                user_id=current_user.id,
                filename=filename,
                file_path=filepath,
                title=title,
                author=author,
                language=book_info.get('language', 'en'),
                genre=book_info.get('genre', ''),
                series=book_info.get('series', ''),
                series_number=int(book_info.get('series_number', 0)) if str(book_info.get('series_number', '')).isdigit() else None
            )
            db.session.add(book)
            results['uploaded'].append({'title': title, 'author': author})
        else:
            results['errors'].append({'filename': filename, 'error': 'A fájl nem található a szerveren'})
    
    db.session.commit()
    
    summary = f"{len(results['uploaded'])} feltöltve"
    if results['duplicates']:
        summary += f", {len(results['duplicates'])} kihagyva (már létezik)"
    if results['errors']:
        summary += f", {len(results['errors'])} hiba"
    
    app_logger.info(f"Batch feltöltés: {summary} (user: {current_user.email})")
    return jsonify({'success': True, 'results': results, 'summary': summary})

@app.route('/api/library/recommend', methods=['POST'])
@login_required
def library_recommend():
    """Kapcsolódó könyvek ajánlása a könyvtárból a feltöltött könyv metaadatai alapján.
    Prioritási sorrend: 1) azonos sorozat, 2) azonos szerző, 3) hasonló műfaj.
    ---
    tags:
      - Library
    """
    data = request.get_json() or {}
    title = (data.get('title') or '').strip()
    author = (data.get('author') or '').strip()
    genre = (data.get('genre') or '').strip().lower()
    series = (data.get('series') or '').strip()
    
    if not title and not author:
        return jsonify({'recommendations': [], 'message': 'Nincs elég adat az ajánláshoz'})
    
    recommendations = []
    seen_ids = set()
    
    # 1. Azonos sorozat más részei (legrelevánsabb)
    if series:
        series_books = Book.query.filter(
            db.func.lower(Book.series) == series.lower()
        ).order_by(Book.series_number).limit(10).all()
        for b in series_books:
            if b.id not in seen_ids:
                recommendations.append({
                    'id': b.id, 'title': b.title or '', 'author': b.author or '',
                    'language': b.language or '', 'genre': b.genre or '',
                    'series': b.series or '', 'series_number': b.series_number,
                    'reason': 'series'
                })
                seen_ids.add(b.id)
    
    # 2. Azonos szerző más könyvei
    if author:
        author_books = Book.query.filter(
            db.func.lower(Book.author) == author.lower()
        ).order_by(Book.uploaded_at.desc()).limit(10).all()
        for b in author_books:
            if b.id not in seen_ids:
                recommendations.append({
                    'id': b.id, 'title': b.title or '', 'author': b.author or '',
                    'language': b.language or '', 'genre': b.genre or '',
                    'series': b.series or '', 'series_number': b.series_number,
                    'reason': 'author'
                })
                seen_ids.add(b.id)
    
    # 3. Hasonló műfajú könyvek
    if genre:
        genre_parts = [g.strip() for g in genre.split(',') if g.strip()]
        for g in genre_parts[:3]:  # max 3 műfaj
            genre_books = Book.query.filter(
                db.func.lower(Book.genre).contains(g.lower())
            ).order_by(Book.uploaded_at.desc()).limit(5).all()
            for b in genre_books:
                if b.id not in seen_ids:
                    recommendations.append({
                        'id': b.id, 'title': b.title or '', 'author': b.author or '',
                        'language': b.language or '', 'genre': b.genre or '',
                        'series': b.series or '', 'series_number': b.series_number,
                        'reason': 'genre'
                    })
                    seen_ids.add(b.id)
    
    # Limit: maximum 20 ajánlás
    recommendations = recommendations[:20]
    
    app_logger.info(f"Könyv ajánlás: '{title}' by '{author}' -> {len(recommendations)} találat")
    return jsonify({
        'recommendations': recommendations,
        'count': len(recommendations)
    })

@app.route('/api/library/enrich-missing', methods=['POST'])
@login_required
@admin_required
def library_enrich_missing():
    """Hiányos metaadatú könyvek (szerző/műfaj/cím) automatikus pótlása OpenLibrary-ből."""
    import time as _time
    books = Book.query.all()
    updated = 0
    for b in books:
        if not b.title:
            continue
        if b.author and b.genre:
            continue
        try:
            enriched = openlibrary_enrich(b.title, b.author)
            changed = False
            if not b.author and enriched.get('author'):
                b.author = enriched['author']
                changed = True
            if not b.title and enriched.get('title'):
                b.title = enriched['title']
                changed = True
            if not b.genre and enriched.get('genre'):
                b.genre = enriched['genre']
                changed = True
            if changed:
                updated += 1
            _time.sleep(0.2)  # OpenLibrary rate-limit védelem
        except Exception:
            pass
    db.session.commit()
    return jsonify({'success': True, 'updated': updated})


@app.route('/api/admin/pending-library', methods=['GET'])
@login_required
@admin_required
def admin_pending_library():
    """A könyvtárba jóváhagyásra váró (pending) lefordított könyvek listája."""
    pending = Translation.query.filter_by(library_status='pending')\
        .order_by(Translation.created_at.desc()).all()
    return jsonify({'pending': [{
        'id': t.id,
        'original_filename': t.original_filename,
        'output_filename': t.output_filename,
        'quality_score': t.quality_score,
        'model_used': t.model_used,
        'owner': t.user.email if t.user else '',
        'created_at': to_budapest(t.created_at) if t.created_at else None,
    } for t in pending]})

@app.route('/api/admin/library/approve/<int:translation_id>', methods=['POST'])
@login_required
@admin_required
def admin_library_approve(translation_id):
    """Várakozó fordítás jóváhagyása → a lefordított EPUB a közös könyvtárba kerül."""
    t = Translation.query.get_or_404(translation_id)
    if t.library_status != 'pending':
        return jsonify({'error': 'Ez a fordítás nincs jóváhagyásra váró állapotban'}), 400

    output_path = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename) if t.output_filename else None
    if not output_path or not os.path.exists(output_path):
        return jsonify({'error': 'A lefordított fájl nem található'}), 404

    # Az eredeti EPUB-ból próbáljuk meg cím/szerző meghatározását, OpenLibrary fallback-kel
    from ebooklib import epub as epub_lib
    from bs4 import BeautifulSoup
    title = t.original_filename.rsplit('.', 1)[0]
    author = ''
    genre = ''
    try:
        ob = epub_lib.read_epub(output_path)
        ttl = ob.get_metadata('DC', 'title')
        cr = ob.get_metadata('DC', 'creator')
        if ttl:
            title = ttl[0][0] if isinstance(ttl[0], tuple) else str(ttl[0])
        if cr:
            author = cr[0][0] if isinstance(cr[0], tuple) else str(cr[0])
        subj = ob.get_metadata('DC', 'subject')
        if subj:
            genre = ', '.join([str((s[0] if isinstance(s, tuple) else s)).strip() for s in subj[:3]])
    except Exception:
        pass

    # OpenLibrary pótlás a hiányzó mezőkre
    if (not author or not genre) and title:
        try:
            enriched = openlibrary_enrich(title, author)
            if not author and enriched.get('author'):
                author = enriched['author']
            if not genre and enriched.get('genre'):
                genre = enriched['genre']
        except Exception:
            pass

    # Dedup ellenőrzés
    existing = Book.query.filter(
        db.func.lower(Book.title) == title.lower().strip(),
        db.func.lower(Book.author) == author.lower().strip()
    ).first() if author else None
    if existing:
        t.library_status = 'approved'  # már van ilyen, a fordítás „jóváhagyva" de nem duplikálunk
        db.session.commit()
        return jsonify({'success': True, 'duplicate': True, 'book_id': existing.id,
                        'message': 'Már létezik ilyen könyv a könyvtárban, a fordítás jóváhagyva'})

    # A lefordított EPUB másolása a könyvtár mappába
    lib_name = f"lib_{uuid.uuid4().hex}_{t.output_filename}"
    lib_path = os.path.join(app.config['LIBRARY_FOLDER'], lib_name)
    shutil.copy2(output_path, lib_path)

    book = Book(
        user_id=t.user_id,   # a fordító felhasználó a tulajdonos
        filename=t.original_filename,
        file_path=lib_path,
        title=title,
        author=author,
        language='hu',
        genre=genre,
        series='',
        series_number=None,
    )
    db.session.add(book)
    t.library_status = 'approved'
    db.session.commit()
    app_logger.info(f"Fordítás #{translation_id} jóváhagyva és a könyvtárba került (book #{book.id})")
    return jsonify({'success': True, 'book_id': book.id, 'message': 'Könyv a könyvtárba került'})

@app.route('/api/admin/library/reject/<int:translation_id>', methods=['POST'])
@login_required
@admin_required
def admin_library_reject(translation_id):
    """Várakozó fordítás elutasítása (nem kerül a könyvtárba, letölthető marad)."""
    t = Translation.query.get_or_404(translation_id)
    if t.library_status != 'pending':
        return jsonify({'error': 'Ez a fordítás nincs jóváhagyásra váró állapotban'}), 400
    t.library_status = 'rejected'
    db.session.commit()
    return jsonify({'success': True, 'message': 'Fordítás elutasítva (letölthető marad)'})

@app.route('/api/library/fetch-metadata', methods=['POST'])
@login_required
def library_fetch_metadata():
    data = request.get_json()
    query = data.get('query','').strip()
    if len(query) < 3:
        return jsonify({'error':'Túl rövid keresési kifejezés'}), 400
    try:
        resp = requests.get(f'https://openlibrary.org/search.json?q={requests.utils.quote(query)}&limit=3', timeout=10)
        if resp.status_code == 200:
            docs = resp.json().get('docs',[])
            results = []
            for doc in docs:
                results.append({
                    'title': doc.get('title',''),
                    'author': ', '.join(doc.get('author_name',[])) if doc.get('author_name') else '',
                    'language': ', '.join(doc.get('language',[])) if doc.get('language') else '',
                    'first_publish': doc.get('first_publish_year',''),
                    'subjects': doc.get('subject',[])[:5] if doc.get('subject') else []
                })
            return jsonify({'results':results})
        return jsonify({'error':'OpenLibrary API hiba'}), resp.status_code
    except Exception as e:
        return jsonify({'error':str(e)[:100]}), 500

# ---- REFERENCE ----
@app.route('/reference/upload', methods=['POST'])
@login_required
def upload_reference():
    if 'file' not in request.files:
        flash(_('Nincs fájl kiválasztva!'),'error'); return redirect(url_for('dashboard'))
    file = request.files['file']
    if file.filename == '' or not allowed_file(file.filename):
        flash(_('Csak EPUB fájlok tölthetők fel!'),'error'); return redirect(url_for('dashboard'))
    title = request.form.get('title', file.filename.rsplit('.',1)[0])
    filename = f"ref_{uuid.uuid4().hex}_{secure_filename(file.filename)}"
    filepath = os.path.join(app.config['REFERENCE_FOLDER'], filename)
    file.save(filepath)
    ref = ReferenceBook(user_id=current_user.id, filename=file.filename, title=title, language=request.form.get('language','hu'), file_path=filepath)
    db.session.add(ref); db.session.commit()
    flash(_('Mintakönyv feltöltve!'),'success')
    return redirect(url_for('dashboard'))

@app.route('/reference/delete/<int:ref_id>', methods=['POST'])
@login_required
def delete_reference(ref_id):
    ref = ReferenceBook.query.get_or_404(ref_id)
    if ref.user_id != current_user.id:
        flash(_('Nincs jogosultságod'),'error'); return redirect(url_for('dashboard'))
    if ref.file_path and os.path.exists(ref.file_path):
        os.remove(ref.file_path)
    db.session.delete(ref); db.session.commit()
    flash(_('Mintakönyv törölve'),'success')
    return redirect(url_for('dashboard'))

# ---- ADMIN ----
@app.route('/admin')
@login_required
@admin_required
def admin():
    sys_info = {
        'cpu_percent': psutil.cpu_percent(), 'memory_percent': psutil.virtual_memory().percent,
        'memory_used_gb': round(psutil.virtual_memory().used/(1024**3),2),
        'memory_total_gb': round(psutil.virtual_memory().total/(1024**3),2),
        'disk_percent': psutil.disk_usage('/').percent, 'disk_free_gb': round(psutil.disk_usage('/').free/(1024**3),2)
    }
    return render_template('admin.html', sys_info=sys_info, current_model=app.config['DEFAULT_MODEL'],
                          translations_count=Translation.query.count(), users_count=User.query.count())

@app.route('/api/models/pull', methods=['POST'])
@login_required
@admin_required
def api_models_pull():
    data = request.get_json()
    model_name = data.get('model','').strip()
    if not model_name:
        return jsonify({'error':'Modell név szükséges'}), 400
    def pull_in_background(app_ref, model):
        with app_ref.app_context():
            try:
                requests.post(f"{app_ref.config['OLLAMA_HOST']}/api/pull", json={'name':model,'stream':False}, timeout=7200)
            except Exception as e:
                app_ref.logger.error(f"Model pull failed: {e}")
    thread = threading.Thread(target=pull_in_background, args=(app, model_name))
    thread.daemon = True; thread.start()
    return jsonify({'success':True,'message':f'Modell letöltés elindítva: {model_name}'})

@app.route('/profile', methods=['GET', 'POST'])
@login_required
def profile():
    """Felhasználó saját profiljának megtekintése és szerkesztése.
    A felhasználó módosíthatja a személyes adatait, API kulcsát és jelszavát.
    Tokeneket csak az admin módosíthat (admin/users oldalon)."""
    if request.method == 'POST':
        # Személyes adatok frissítése
        current_user.first_name = request.form.get('first_name', '').strip()
        current_user.last_name = request.form.get('last_name', '').strip()
        current_user.email = request.form.get('email', '').strip()
        current_user.phone = request.form.get('phone', '').strip()
        current_user.address = request.form.get('address', '').strip()
        current_user.birth_date = request.form.get('birth_date', '').strip()
        current_user.tax_id = request.form.get('tax_id', '').strip()
        
        # API kulcs frissítése (ha nem a *** érték jön, akkor új kulcs)
        api_key = request.form.get('deepseek_api_key', '').strip()
        if api_key and not api_key.startswith('***'):
            current_user.deepseek_api_key = api_key
        
        # Jelszó frissítése (ha meg van adva és egyezik)
        password = request.form.get('password', '').strip()
        password_confirm = request.form.get('password_confirm', '').strip()
        if password:
            if password != password_confirm:
                flash(_('A jelszavak nem egyeznek!'), 'error')
                translations_count = Translation.query.filter_by(user_id=current_user.id).count()
                return render_template('profile.html', user=current_user, translations_count=translations_count)
            current_user.password_hash = generate_password_hash(password)
            flash(_('Jelszó sikeresen megváltoztatva!'), 'success')
        
        db.session.commit()
        flash(_('Profil adatok mentve!'), 'success')
        return redirect(url_for('profile'))
    
    translations_count = Translation.query.filter_by(user_id=current_user.id).count()
    return render_template('profile.html', user=current_user, translations_count=translations_count)

@app.route('/api/user/settings', methods=['POST'])
@login_required
def user_settings():
    """Felhasználói beállítások mentése (API kulcs, preferált modell, téma)"""
    data = request.get_json() or {}
    
    # DeepSeek API kulcs mentése.
    # FONTOS: a beállítások oldal a kulcsot MASZKOLVA (*** + utolsó 4 karakter)
    # küldheti vissza; ezt NEM szabad elmenteni, mert felülírná a valódi kulcsot
    # (ez okozta, hogy a fordítás angolul maradt – érvénytelen kulccsal hívtunk).
    if 'deepseek_api_key' in data:
        new_key = (data['deepseek_api_key'] or '').strip()
        if new_key and not new_key.startswith('***'):
            current_user.deepseek_api_key = new_key
    
    # Preferált modell forrás (local/remote)
    if 'preferred_model_source' in data:
        current_user.preferred_model_source = data['preferred_model_source']
    
    # Preferált modell név
    if 'preferred_model' in data:
        current_user.preferred_model = data['preferred_model']
    
    # Sötét/világos téma preferencia (10. fejlesztés)
    if 'dark_mode' in data:
        current_user.dark_mode = bool(data['dark_mode'])
    
    # Tegezés/magázás preferencia (v2.5.0+)
    if 'formality' in data:
        current_user.formality = data['formality'] if data['formality'] in ('informal', 'formal') else 'informal'
    
    db.session.commit()
    
    return jsonify({
        'success': True,
        'deepseek_api_key': ('***' + current_user.deepseek_api_key[-4:]) if current_user.deepseek_api_key else '',
        'preferred_model_source': current_user.preferred_model_source,
        'preferred_model': current_user.preferred_model,
        'dark_mode': current_user.dark_mode,
        'formality': current_user.formality
    })

@app.route('/api/models/list')
@login_required
def api_models_list():
    """Modell lista – helyi (Ollama) + távoli (DeepSeek Pro) modellek egyesített listája."""
    models = []; error = None
    
    # Helyi modellek lekérése az Ollama-tól
    for attempt in range(1,4):
        try:
            resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/tags", timeout=5)
            if resp.status_code == 200:
                models = resp.json().get('models',[]); break
        except Exception as e:
            if attempt == 3: error = str(e)[:100]
            else: import time; time.sleep(2)
    
    # Távoli (DeepSeek Pro) modellek hozzáadása, ha van API kulcs
    remote_available = bool(current_user.deepseek_api_key)
    remote_models = []
    if remote_available:
        remote_models = Config.REMOTE_MODELS
    
    return jsonify({
        'models': models,
        'remote_models': remote_models,
        'remote_available': remote_available,
        'current_model': app.config['DEFAULT_MODEL'],
        'error': error
    })

@app.route('/api/estimate', methods=['POST'])
@login_required
def api_estimate():
    """Előzetes fordítási becslés a feltöltött EPUB alapján.
    A választott modell alapján visszaadja a szószámot, a becsült token-
    mennyiséget, a becsült időt (helyi modellnél) és a becsült költséget
    (DeepSeek Pro-nál, USD-ben).

    ---
    tags:
      - Translation
    consumes:
      - multipart/form-data
    parameters:
      - name: file
        in: formData
        type: file
        required: true
        description: A feltöltendő EPUB fájl
      - name: model_source
        in: formData
        type: string
        required: true
        enum: [local, remote]
        description: Modell forrás (helyi Ollama vagy DeepSeek Pro)
      - name: selected_model
        in: formData
        type: string
        required: false
        description: A kiválasztott modell azonosítója
    """
    if 'file' not in request.files:
        return jsonify({'error': 'Nincs fájl'}), 400
    file = request.files['file']
    model_source = request.form.get('model_source', 'local')
    selected_model = request.form.get('selected_model', '').strip()

    # 1. EPUB szöveg kinyerése és szószám számítás
    total_words = 0
    try:
        import tempfile
        from ebooklib import epub as epub_lib
        from bs4 import BeautifulSoup
        import re as _re

        with tempfile.NamedTemporaryFile(suffix='.epub', delete=False) as tmp:
            file.save(tmp.name)
            tmp_path = tmp.name
        try:
            book = epub_lib.read_epub(tmp_path)
            items = list(book.get_items_of_type(9))
            for it in items:
                try:
                    text = BeautifulSoup(it.get_body_content(), 'html.parser').get_text()
                    total_words += len(text.split())
                except Exception:
                    pass
        finally:
            os.unlink(tmp_path)
    except Exception as e:
        app_logger.warning(f"Becslési hiba (EPUB olvasás): {e}")
        return jsonify({'error': f'Nem sikerült beolvasni az EPUB-ot: {str(e)[:100]}'}), 400

    # 2. Token becslés (angol szövegre ~1.3 token/szó, magyarra ~1.5)
    #    A fordítás két menetes: input ≈ forrás tokenek, output ≈ cél tokenek.
    input_tokens = int(total_words * 1.3)
    output_tokens = int(total_words * 1.5)

    # 3. Idő becslés (szavak/perc átlagos sebességgel)
    #    Helyi Ollama: ~300 szó/perc, DeepSeek: ~900 szó/perc (becslés).
    words_per_minute = 900 if model_source == 'remote' else 300
    estimated_minutes = total_words / max(words_per_minute, 1)

    # 4. Költség becslés (csak DeepSeek Pro-nál)
    cost_usd = 0.0
    currency = 'USD'
    if model_source == 'remote':
        pricing = {}
        for m in Config.REMOTE_MODELS:
            if m.get('id') == selected_model:
                pricing = m
                break
        in_price = pricing.get('input_price_per_mtok', 0.27)
        out_price = pricing.get('output_price_per_mtok', 1.10)
        cost_usd = (input_tokens / 1_000_000) * in_price + (output_tokens / 1_000_000) * out_price

    return jsonify({
        'total_words': total_words,
        'input_tokens': input_tokens,
        'output_tokens': output_tokens,
        'estimated_minutes': round(estimated_minutes, 1),
        'cost': round(cost_usd, 4),
        'currency': currency,
        'model_source': model_source,
        'selected_model': selected_model,
    })

@app.route('/admin/users')
@login_required
@admin_required
def admin_users():
    users = User.query.order_by(User.created_at.desc()).all()
    return render_template('users.html', users=users)

@app.route('/admin/users/add', methods=['GET','POST'])
@login_required
@admin_required
def admin_users_add():
    if request.method == 'POST':
        email = request.form.get('email','').strip()
        password = request.form.get('password','').strip()
        tokens = request.form.get('tokens','5').strip()
        if not email or not password:
            flash(_('Az email és a jelszó kötelező!'),'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=False)
        if User.query.filter_by(email=email).first():
            flash(_('Ez az email cím már használatban van!'),'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=False)
        user = User(username=email.split('@')[0], email=email, password_hash=generate_password_hash(password),
                     first_name=request.form.get('first_name','').strip(), last_name=request.form.get('last_name','').strip(),
                     address=request.form.get('address','').strip(), birth_date=request.form.get('birth_date','').strip(),
                     tax_id=request.form.get('tax_id','').strip(), phone=request.form.get('phone','').strip(),
                     tokens=int(tokens) if tokens.isdigit() else 5, is_admin=request.form.get('is_admin')=='1')
        db.session.add(user); db.session.commit()
        flash(_('Felhasználó létrehozva!'),'success')
        return redirect(url_for('admin_users'))
    return render_template('users_form.html', user_data={}, edit_mode=False)

@app.route('/admin/users/edit/<int:user_id>', methods=['GET','POST'])
@login_required
@admin_required
def admin_users_edit(user_id):
    user = User.query.get_or_404(user_id)
    if request.method == 'POST':
        email = request.form.get('email','').strip()
        password = request.form.get('password','').strip()
        tokens = request.form.get('tokens', str(user.tokens)).strip()
        existing = User.query.filter_by(email=email).first()
        if existing and existing.id != user.id:
            flash(_('Ez az email cím már használatban van!'),'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=True, user=user)
        user.email = email; user.first_name = request.form.get('first_name','').strip()
        user.last_name = request.form.get('last_name','').strip(); user.address = request.form.get('address','').strip()
        user.birth_date = request.form.get('birth_date','').strip(); user.tax_id = request.form.get('tax_id','').strip()
        user.phone = request.form.get('phone','').strip(); user.tokens = int(tokens) if tokens.isdigit() else user.tokens
        user.is_admin = request.form.get('is_admin')=='1'
        if password: user.password_hash = generate_password_hash(password)
        db.session.commit()
        flash(_('Felhasználó módosítva!'),'success')
        return redirect(url_for('admin_users'))
    return render_template('users_form.html', user_data={}, edit_mode=True, user=user)

@app.route('/admin/users/delete/<int:user_id>', methods=['POST'])
@login_required
@admin_required
def admin_users_delete(user_id):
    if user_id == current_user.id:
        flash(_('Saját magadat nem törölheted!'),'error'); return redirect(url_for('admin_users'))
    user = User.query.get_or_404(user_id)
    Translation.query.filter_by(user_id=user.id).delete()
    db.session.delete(user); db.session.commit()
    flash(_('Felhasználó törölve!'),'success')
    return redirect(url_for('admin_users'))

@app.route('/api/models/switch', methods=['POST'])
@login_required
@admin_required
def switch_model():
    """Modell váltás – ellenőrzi az elérhetőséget, perzisztál az .env fájlba."""
    data = request.get_json()
    model_name = data.get('model')
    if not model_name: return jsonify({'error':'Modell név szükséges'}), 400
    
    # 1. Ellenőrizzük, hogy a modell elérhető-e az Ollama-ban
    model_available = False
    try:
        resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/tags", timeout=10)
        if resp.status_code == 200:
            models = resp.json().get('models', [])
            model_available = any(m.get('name', '') == model_name for m in models)
    except Exception:
        pass
    
    if not model_available:
        # Modell nincs letöltve – pull indítása háttérben
        def pull_model(app_ref, model):
            with app_ref.app_context():
                try:
                    requests.post(f"{app_ref.config['OLLAMA_HOST']}/api/pull", 
                                 json={'name': model, 'stream': False}, timeout=7200)
                except Exception as e:
                    app_ref.logger.error(f"Modell letöltési hiba: {e}")
        thread = threading.Thread(target=pull_model, args=(app, model_name))
        thread.daemon = True; thread.start()
        
        log = OptimizationLog(model=model_name, action='pull_started', 
                             details=json.dumps({'switched_by': current_user.email}), 
                             created_at=datetime.utcnow())
        db.session.add(log); db.session.commit()
        
        return jsonify({
            'success': True, 
            'status': 'downloading',
            'message': f'A(z) {model_name} modell letöltése elindult. Ez akár 30-60 percig is eltarthat. A letöltés után a modell automatikusan elérhető lesz.'
        })
    
    # 2. Modell elérhető – váltás és perzisztálás
    app.config['DEFAULT_MODEL'] = model_name
    
    # .env fájl frissítése (ha elérhető)
    try:
        env_path = '/app/../.env'
        import shutil
        if os.path.exists(env_path):
            with open(env_path, 'r') as f:
                env_content = f.read()
            import re as _re
            env_content = _re.sub(r'^SELECTED_MODEL=.*$', f'SELECTED_MODEL={model_name}', env_content, flags=_re.MULTILINE)
            with open(env_path, 'w') as f:
                f.write(env_content)
            app_logger.info(f"Modell perzisztálva .env-ben: {model_name} (user: {current_user.email})")
    except Exception as e:
        app_logger.warning(f".env frissítés nem sikerült: {e}")
    
    log = OptimizationLog(model=model_name, action='switch', 
                         details=json.dumps({'switched_by': current_user.email}), 
                         created_at=datetime.utcnow())
    db.session.add(log); db.session.commit()
    
    return jsonify({
        'success': True, 
        'status': 'switched',
        'message': f'Modell átváltva: {model_name} (perzisztens – konténer újraindítás után is megmarad)'
    })

@app.route('/admin/update')
@login_required
@admin_required
def admin_update():
    return render_template('update.html', current_version=app.config['VERSION'])

@app.route('/api/update/check')
@login_required
@admin_required
def api_update_check():
    for attempt in range(1,4):
        try:
            resp = requests.get('https://api.github.com/repos/sorosg/Epub-translate/releases/latest',
                               headers={'Accept':'application/vnd.github.v3+json'}, timeout=30, verify=True)
            if resp.status_code == 200:
                data = resp.json()
                remote_version = data.get('tag_name','').lstrip('v')
                has_update = remote_version > app.config['VERSION']
                return jsonify({'remote_version':remote_version or 'ismeretlen','current':app.config['VERSION'],'has_update':has_update,'release_url':data.get('html_url',''),'release_notes':(data.get('body','') or '')[:500]})
            return jsonify({'error':f'GitHub API hiba: {resp.status_code}'}), resp.status_code
        except requests.exceptions.SSLError:
            try:
                import urllib3; urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
                resp = requests.get('https://api.github.com/repos/sorosg/Epub-translate/releases/latest',
                                   headers={'Accept':'application/vnd.github.v3+json'}, timeout=30, verify=False)
                if resp.status_code == 200:
                    data = resp.json()
                    remote_version = data.get('tag_name','').lstrip('v')
                    has_update = remote_version > app.config['VERSION']
                    return jsonify({'remote_version':remote_version or 'ismeretlen','current':app.config['VERSION'],'has_update':has_update,'release_url':data.get('html_url',''),'release_notes':(data.get('body','') or '')[:500]})
            except: pass
            if attempt == 3: return jsonify({'error':'SSL tanúsítvány hiba','current':app.config['VERSION'],'has_update':False})
        except Exception as e:
            if attempt == 3: return jsonify({'error':f'Nem sikerült ellenőrizni a frissítéseket: {str(e)[:100]}','current':app.config['VERSION'],'has_update':False})
            import time; time.sleep(3)

@app.route('/api/update/run', methods=['POST'])
@login_required
@admin_required
def api_update_run():
    import subprocess
    try:
        result = subprocess.run(['bash','/app/../scripts/update.sh'], capture_output=True, text=True, timeout=600)
        log = OptimizationLog(model='system', action='update', details=json.dumps({'output':result.stdout[-500:],'returncode':result.returncode}), created_at=datetime.utcnow())
        db.session.add(log); db.session.commit()
        return jsonify({'success':result.returncode==0,'output':result.stdout[-500:]})
    except Exception as e:
        return jsonify({'success':False,'error':str(e)[:200]}), 500

# ==== EPUB OLVASÓ ====
@app.route('/reader/<int:book_id>')
@login_required
def book_reader(book_id):
    """EPUB olvasó oldal a könyvtár könyveihez"""
    book = Book.query.get_or_404(book_id)
    return render_template('reader.html', book=book)

@app.route('/api/reader/<int:book_id>/chapters')
@login_required
def api_reader_chapters(book_id):
    """EPUB fejezeteinek listázása (cím + hossz)"""
    book = Book.query.get_or_404(book_id)
    if not book.file_path or not os.path.exists(book.file_path):
        return jsonify({'error': 'A fájl nem található', 'chapters': []})
    try:
        from ebooklib import epub as epub_lib
        from bs4 import BeautifulSoup
        bk = epub_lib.read_epub(book.file_path)
        chapters = []
        items = list(bk.get_items_of_type(9))
        for idx, item in enumerate(items):
            soup = BeautifulSoup(item.get_body_content(), 'html.parser')
            text = soup.get_text().strip()
            if text and len(text) > 50:
                # Fejezet cím keresése (h1, h2, h3)
                title_tag = soup.find(['h1', 'h2', 'h3'])
                title = title_tag.get_text().strip() if title_tag else f'Fejezet {idx+1}'
                chapters.append({
                    'index': idx,
                    'title': title[:80],
                    'length': len(text),
                    'preview': text[:200] + ('...' if len(text) > 200 else '')
                })
        return jsonify({'chapters': chapters, 'title': book.title or book.filename, 'author': book.author or ''})
    except Exception as e:
        return jsonify({'error': str(e)[:200], 'chapters': []})

@app.route('/api/reader/<int:book_id>/bookmark', methods=['GET', 'POST'])
@login_required
def api_reader_bookmark(book_id):
    """Könyvjelző mentése/betöltése – felhasználónként egy könyvjelző könyvenként"""
    book = Book.query.get_or_404(book_id)
    
    if request.method == 'GET':
        # Könyvjelző betöltése
        bm = ReaderBookmark.query.filter_by(user_id=current_user.id, book_id=book_id).first()
        if bm:
            return jsonify({
                'bookmark': {
                    'chapter_index': bm.chapter_index,
                    'scroll_position': bm.scroll_position,
                    'updated_at': to_budapest(bm.updated_at) if bm.updated_at else None
                }
            })
        return jsonify({'bookmark': None})
    
    # POST: Könyvjelző mentése
    data = request.get_json() or {}
    chapter_index = data.get('chapter_index', 0)
    scroll_position = data.get('scroll_position', 0)
    
    bm = ReaderBookmark.query.filter_by(user_id=current_user.id, book_id=book_id).first()
    if bm:
        bm.chapter_index = chapter_index
        bm.scroll_position = scroll_position
        bm.updated_at = datetime.utcnow()
    else:
        bm = ReaderBookmark(
            user_id=current_user.id,
            book_id=book_id,
            chapter_index=chapter_index,
            scroll_position=scroll_position
        )
        db.session.add(bm)
    db.session.commit()
    
    return jsonify({'success': True, 'message': 'Könyvjelző mentve'})

@app.route('/api/reader/<int:book_id>/chapter/<int:idx>')
@login_required
def api_reader_chapter(book_id, idx):
    """Egy fejezet teljes szövegének lekérése"""
    book = Book.query.get_or_404(book_id)
    if not book.file_path or not os.path.exists(book.file_path):
        return jsonify({'error': 'A fájl nem található', 'text': ''})
    try:
        from ebooklib import epub as epub_lib
        from bs4 import BeautifulSoup
        bk = epub_lib.read_epub(book.file_path)
        items = list(bk.get_items_of_type(9))
        if idx < 0 or idx >= len(items):
            return jsonify({'error': 'Érvénytelen fejezet index', 'text': ''})
        item = items[idx]
        body_html = item.get_body_content().decode('utf-8', errors='replace') if isinstance(item.get_body_content(), bytes) else str(item.get_body_content())
        soup = BeautifulSoup(body_html, 'html.parser')
        # Fejezet cím kinyerése
        title_tag = soup.find(['h1', 'h2', 'h3'])
        title = title_tag.get_text().strip() if title_tag else f'Fejezet {idx+1}'
        # Tisztított HTML (script, style eltávolítása)
        for tag in soup(['script', 'style', 'meta', 'link']):
            tag.decompose()
        text = soup.get_text().strip()
        return jsonify({
            'title': title,
            'text': text,
            'html': str(soup),  # HTML struktúra megtartása
            'index': idx,
            'length': len(text),
            'total': len(items)
        })
    except Exception as e:
        return jsonify({'error': str(e)[:200], 'text': ''})

@app.route('/api/notifications')
@login_required
def api_notifications():
    """Legutóbbi fordítási események a felhasználónak (értesítési központ)"""
    translations = Translation.query.filter_by(user_id=current_user.id)\
        .order_by(Translation.created_at.desc()).limit(10).all()
    events = []
    for t in translations:
        status_icon = {'pending':'⏳','processing':'🔄','completed':'✅','failed':'❌'}.get(t.status,'📋')
        events.append({
            'id':t.id,
            'type':t.status,
            'icon':status_icon,
            'message':f'{status_icon} {t.original_filename} – {"Fordítás kész!" if t.status=="completed" else "Folyamatban..." if t.status=="processing" else "Várakozik..." if t.status=="pending" else "Hiba történt"}',
            'time':to_budapest(t.created_at) if t.created_at else '',
            'progress':t.progress,
            'quality_score':t.quality_score
        })
    return jsonify({'events':events})

@app.route('/api/system/containers')
@login_required
@admin_required
def api_system_containers():
    """Docker konténerek állapotának lekérése (docker compose ps alapján)"""
    import subprocess
    try:
        result = subprocess.run(
            ['docker', 'compose', '-f', '/app/../docker-compose.yml', 'ps', '--format', 'json'],
            capture_output=True, text=True, timeout=10, cwd='/app/..'
        )
        if result.returncode != 0:
            # Fallback: sima docker ps
            result2 = subprocess.run(
                ['docker', 'ps', '--format', '{{json .}}', '--filter', 'name=epub-'],
                capture_output=True, text=True, timeout=10
            )
            containers = []
            for line in result2.stdout.strip().split('\n'):
                if line.strip():
                    try:
                        containers.append(json.loads(line))
                    except:
                        pass
            return jsonify({'containers': containers, 'source': 'docker ps'})
        
        containers = []
        for line in result.stdout.strip().split('\n'):
            if line.strip():
                try:
                    containers.append(json.loads(line))
                except:
                    pass
        return jsonify({'containers': containers, 'source': 'compose ps'})
    except Exception as e:
        return jsonify({'error': str(e)[:200], 'containers': []})

@app.route('/api/system/monitor')
@login_required
@admin_required
def system_monitor():
    return jsonify({'cpu':{'percent':psutil.cpu_percent(),'cores':psutil.cpu_count()},'memory':{'total_gb':round(psutil.virtual_memory().total/(1024**3),2),'used_gb':round(psutil.virtual_memory().used/(1024**3),2),'percent':psutil.virtual_memory().percent},'disk':{'total_gb':round(psutil.disk_usage('/').total/(1024**3),2),'free_gb':round(psutil.disk_usage('/').free/(1024**3),2),'percent':psutil.disk_usage('/').percent},'uptime':to_budapest(datetime.utcnow())})

# ---- ADMIN LOGOK ----
@app.route('/admin/logs')
@login_required
@admin_required
def admin_logs():
    log_type = request.args.get('type', 'translation')
    lines = request.args.get('lines', 200, type=int)
    lines = min(max(lines, 10), 5000)  # limit 10-5000 sor között
    
    log_file_map = {
        'translation': os.path.join(LOG_DIR, 'translation.log'),
        'app': os.path.join(LOG_DIR, 'app.log'),
    }
    
    log_file = log_file_map.get(log_type, log_file_map['translation'])
    log_content = ''
    file_exists = os.path.exists(log_file)
    file_size = os.path.getsize(log_file) if file_exists else 0
    
    if file_exists and file_size > 0:
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                all_lines = f.readlines()
                log_content = ''.join(all_lines[-lines:])
        except Exception as e:
            log_content = f"[HIBA] Nem sikerült beolvasni a log fájlt: {e}"
    else:
        log_content = '(A log fájl még üres vagy nem létezik.)'
    
    # Elérhető log fájlok listája
    available_logs = []
    for name, path in log_file_map.items():
        size_mb = round(os.path.getsize(path) / (1024 * 1024), 2) if os.path.exists(path) else 0
        available_logs.append({
            'name': name,
            'label': 'Fordítási log' if name == 'translation' else 'Alkalmazás log',
            'size_mb': size_mb,
            'exists': os.path.exists(path)
        })
    
    return render_template('logs.html', log_content=log_content, log_type=log_type, 
                          lines=lines, file_size=file_size, available_logs=available_logs)

@app.route('/admin/logs/clear', methods=['POST'])
@login_required
@admin_required
def admin_logs_clear():
    """Log fájlok törlése (törli a fájlt, majd újra létrehozza üresen)"""
    log_type = request.form.get('type', 'translation')
    log_file_map = {
        'translation': os.path.join(LOG_DIR, 'translation.log'),
        'app': os.path.join(LOG_DIR, 'app.log'),
    }
    log_file = log_file_map.get(log_type)
    if not log_file:
        return jsonify({'error': 'Ismeretlen log típus'}), 400
    
    try:
        if os.path.exists(log_file):
            # Töröljük a fájlt, majd újra létrehozzuk üresen
            os.remove(log_file)
            with open(log_file, 'w', encoding='utf-8') as f:
                f.write('')
            app_logger.info(f"Log fájl törölve: {log_file} (admin: {current_user.email})")
            return jsonify({'success': True, 'message': f'Log fájl törölve: {os.path.basename(log_file)}'})
        else:
            return jsonify({'success': False, 'message': 'A log fájl nem létezik'})
    except Exception as e:
        return jsonify({'error': str(e)[:200]}), 500

# ==== ÚJ JSON VÉGPONTOK (UI-redesign React SPA-hoz) ====

@app.route('/api/profile', methods=['GET'])
@login_required
def api_profile():
    """A bejelentkezett felhasználó profiljának lekérése JSON formátumban.
    A React SPA authStore-ja ezt hívja a session ellenőrzéséhez."""
    translations_count = Translation.query.filter_by(user_id=current_user.id).count()
    return jsonify({
        'id': current_user.id,
        'email': current_user.email,
        'first_name': current_user.first_name or '',
        'last_name': current_user.last_name or '',
        'tokens': current_user.tokens,
        'points': current_user.points,
        'level': current_user.level,
        'is_admin': current_user.is_admin,
        'language': current_user.language or 'hu',
        'preferred_model_source': current_user.preferred_model_source or 'local',
        'preferred_model': current_user.preferred_model or '',
        'deepseek_api_key': ('***' + current_user.deepseek_api_key[-4:]) if current_user.deepseek_api_key else '',
        'translations_count': translations_count,
    })

@app.route('/api/user/settings', methods=['GET'])
@login_required
def api_get_user_settings():
    """A felhasználó beállításainak lekérése (a React Beállítások oldalhoz)."""
    return jsonify({
        'success': True,
        'deepseek_api_key': ('***' + current_user.deepseek_api_key[-4:]) if current_user.deepseek_api_key else '',
        'preferred_model_source': current_user.preferred_model_source or 'local',
        'preferred_model': current_user.preferred_model or '',
        'dark_mode': current_user.dark_mode,
        'formality': current_user.formality or 'informal',
    })

@app.route('/api/library/<int:book_id>/toc')
@login_required
def api_library_toc(book_id):
    """Egy könyv címtáblázatának (TOC) lekérése – csak a fejezet címek és indexek."""
    book = Book.query.get_or_404(book_id)
    if not book.file_path or not os.path.exists(book.file_path):
        return jsonify({'error': 'A fájl nem található', 'chapters': []})
    try:
        from ebooklib import epub as epub_lib
        from bs4 import BeautifulSoup
        bk = epub_lib.read_epub(book.file_path)
        chapters = []
        items = list(bk.get_items_of_type(9))
        for idx, item in enumerate(items):
            soup = BeautifulSoup(item.get_body_content(), 'html.parser')
            text = soup.get_text().strip()
            if text and len(text) > 50:
                title_tag = soup.find(['h1', 'h2', 'h3'])
                title = title_tag.get_text().strip() if title_tag else f'Fejezet {idx+1}'
                chapters.append({'index': idx, 'title': title[:80]})
        return jsonify({'chapters': chapters, 'title': book.title or book.filename})
    except Exception as e:
        return jsonify({'error': str(e)[:200], 'chapters': []})

@app.route('/api/review/<int:translation_id>')
@login_required
def api_review(translation_id):
    """A lefordított fejezetek lekérése JSON-ban (a React Review oldalhoz)."""
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error': 'Nincs jogosultságod'}), 403
    if t.status != 'completed':
        return jsonify({'error': 'Csak befejezett fordításokat lehet átnézni'}), 400
    
    from ebooklib import epub as epub_lib
    from bs4 import BeautifulSoup
    chapters = []
    try:
        output_path = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
        if os.path.exists(output_path):
            book = epub_lib.read_epub(output_path)
            items = list(book.get_items_of_type(9))
            for idx, item in enumerate(items):
                soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                text = soup.get_text().strip()
                if text and len(text) > 30:
                    chapters.append({'index': idx, 'text': text, 'length': len(text)})
    except Exception as e:
        return jsonify({'error': f'Nem sikerült beolvasni: {str(e)[:100]}', 'chapters': []})
    
    return jsonify({
        'translation': {
            'id': t.id,
            'original_filename': t.original_filename,
            'quality_score': t.quality_score,
            'model_used': t.model_used,
        },
        'chapters': chapters,
    })

@app.route('/api/history', methods=['GET'])
@login_required
def api_history():
    """A felhasználó olvasási előzményeinek lekérése (a React History oldalhoz)."""
    entries = ReadingHistory.query.filter_by(user_id=current_user.id)\
        .order_by(ReadingHistory.last_read_at.desc()).all()
    return jsonify({'history': [{
        'id': e.id,
        'book_id': e.book_id,
        'book_title': e.book.title if e.book else '',
        'book_author': e.book.author if e.book else '',
        'chapter_index': e.chapter_index,
        'scroll_position': e.scroll_position,
        'last_read_at': to_budapest(e.last_read_at) if e.last_read_at else None,
    } for e in entries]})

@app.route('/api/history', methods=['POST'])
@login_required
def api_history_save():
    """Olvasási pozíció mentése az előzményekbe (könyv és fejezet megnyitásakor)."""
    data = request.get_json() or {}
    book_id = data.get('book_id')
    chapter_index = data.get('chapter_index', 0)
    scroll_position = data.get('scroll_position', 0)
    if not book_id:
        return jsonify({'error': 'Hiányzó book_id'}), 400
    
    # Meglévő bejegyzés frissítése, vagy új létrehozása
    entry = ReadingHistory.query.filter_by(user_id=current_user.id, book_id=book_id).first()
    if entry:
        entry.chapter_index = chapter_index
        entry.scroll_position = scroll_position
        entry.last_read_at = datetime.utcnow()
    else:
        entry = ReadingHistory(
            user_id=current_user.id,
            book_id=book_id,
            chapter_index=chapter_index,
            scroll_position=scroll_position,
        )
        db.session.add(entry)
    db.session.commit()
    return jsonify({'success': True})

@app.route('/api/stats/summary')
@login_required
def api_stats_summary():
    """Fordítási statisztika összefoglaló a React Stats oldalhoz."""
    translations = Translation.query.filter_by(user_id=current_user.id).all()
    total_translations = len(translations)
    completed = [t for t in translations if t.status == 'completed']
    completed_translations = len(completed)
    total_words = sum(t.total_words or 0 for t in translations)
    active_translations = sum(1 for t in translations if t.status == 'processing')
    quality_scores = [t.quality_score for t in completed if t.quality_score is not None]
    average_quality = round(sum(quality_scores) / len(quality_scores), 1) if quality_scores else None
    
    return jsonify({
        'total_translations': total_translations,
        'completed_translations': completed_translations,
        'total_words': total_words,
        'average_quality': average_quality,
        'active_translations': active_translations,
    })

@app.route('/api/admin/users')
@login_required
@admin_required
def api_admin_users():
    """Felhasználók listájának lekérése JSON-ban (a React Admin oldalhoz)."""
    users = User.query.order_by(User.created_at.desc()).all()
    return jsonify({'users': [{
        'id': u.id,
        'email': u.email,
        'first_name': u.first_name or '',
        'last_name': u.last_name or '',
        'tokens': u.tokens,
        'is_admin': u.is_admin,
        'created_at': to_budapest(u.created_at) if u.created_at else None,
    } for u in users]})


@app.route('/api/admin/users', methods=['POST'])
@login_required
@admin_required
def api_admin_users_create():
    """Új felhasználó létrehozása (JSON) – admin jogosultsággal."""
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip()
    password = data.get('password') or ''
    first_name = (data.get('first_name') or '').strip()
    last_name = (data.get('last_name') or '').strip()
    tokens = data.get('tokens', 5)
    is_admin = bool(data.get('is_admin', False))

    if not email or not password:
        return jsonify({'error': 'Az email és a jelszó kötelező'}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({'error': 'Ez az email cím már használatban van'}), 409

    try:
        tokens_int = int(tokens) if str(tokens).isdigit() else 5
    except (TypeError, ValueError):
        tokens_int = 5

    user = User(
        username=email.split('@')[0],
        email=email,
        password_hash=generate_password_hash(password),
        first_name=first_name,
        last_name=last_name,
        tokens=tokens_int,
        is_admin=is_admin,
    )
    db.session.add(user)
    db.session.commit()
    return jsonify({'success': True, 'id': user.id, 'message': 'Felhasználó létrehozva'})


@app.route('/api/admin/users/<int:user_id>', methods=['PUT'])
@login_required
@admin_required
def api_admin_users_update(user_id):
    """Felhasználó szerkesztése (JSON) – admin jogosultsággal."""
    user = User.query.get_or_404(user_id)
    data = request.get_json(silent=True) or {}

    if 'email' in data:
        new_email = (data['email'] or '').strip()
        if new_email:
            existing = User.query.filter_by(email=new_email).first()
            if existing and existing.id != user.id:
                return jsonify({'error': 'Ez az email cím már használatban van'}), 409
            user.email = new_email

    if 'first_name' in data:
        user.first_name = (data['first_name'] or '').strip()
    if 'last_name' in data:
        user.last_name = (data['last_name'] or '').strip()
    if 'tokens' in data:
        try:
            user.tokens = int(data['tokens']) if str(data['tokens']).isdigit() else user.tokens
        except (TypeError, ValueError):
            pass
    if 'is_admin' in data:
        user.is_admin = bool(data['is_admin'])
    if data.get('password'):
        user.password_hash = generate_password_hash(data['password'])

    db.session.commit()
    return jsonify({'success': True, 'message': 'Felhasználó módosítva'})


@app.route('/api/admin/users/<int:user_id>', methods=['DELETE'])
@login_required
@admin_required
def api_admin_users_delete(user_id):
    """Felhasználó törlése (JSON) – admin jogosultsággal."""
    if user_id == current_user.id:
        return jsonify({'error': 'Saját magadat nem törölheted'}), 400
    user = User.query.get_or_404(user_id)
    Translation.query.filter_by(user_id=user.id).delete()
    db.session.delete(user)
    db.session.commit()
    return jsonify({'success': True, 'message': 'Felhasználó törölve'})


@app.route('/api/profile', methods=['POST'])
@login_required
def api_profile_update():
    """A felhasználó saját alapadatainak módosítása (név, jelszó, API kulcs)."""
    data = request.get_json(silent=True) or {}

    # Személyes adatok frissítése
    if 'first_name' in data:
        current_user.first_name = (data['first_name'] or '').strip()
    if 'last_name' in data:
        current_user.last_name = (data['last_name'] or '').strip()
    if 'email' in data and data['email']:
        new_email = data['email'].strip()
        existing = User.query.filter_by(email=new_email).first()
        if existing and existing.id != current_user.id:
            return jsonify({'error': 'Ez az email cím már használatban van'}), 409
        current_user.email = new_email

    # API kulcs módosítása (csak akkor, ha nem a maszkolt *** érték érkezik)
    if 'deepseek_api_key' in data and data['deepseek_api_key'] and not data['deepseek_api_key'].startswith('***'):
        current_user.deepseek_api_key = data['deepseek_api_key'].strip()

    # Jelszó módosítása
    if data.get('password'):
        current_user.password_hash = generate_password_hash(data['password'])

    db.session.commit()
    return jsonify({'success': True, 'message': 'Profil mentve'})


@app.route('/api/translations/<int:translation_id>/stop', methods=['POST'])
@login_required
def api_translation_stop(translation_id):
    """Fordítás leállításának kérése. A háttérszál a következő iterációnál
    észleli a stop_requested flag-et, és 'stopped' státusszal leáll."""
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error': 'Nincs jogosultságod'}), 403
    if t.status not in ('pending', 'processing'):
        return jsonify({'error': 'Csak folyamatban lévő fordítás állítható le'}), 400

    t.stop_requested = True
    db.session.commit()
    return jsonify({'success': True, 'message': 'Leállítási kérés rögzítve'})

@app.route('/api/translations/<int:translation_id>/resume', methods=['POST'])
@login_required
def api_translation_resume(translation_id):
    """Megszakadt (paused) fordítás folytatása a checkpoint alapján."""
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error': 'Nincs jogosultságod'}), 403
    if t.status != 'paused':
        return jsonify({'error': 'Csak megszakadt (paused) fordítás folytatható'}), 400

    # A checkpoint-ból ellenőrizzük a forrásfájlt
    src = None
    if t.checkpoint_data:
        try:
            cp = json.loads(t.checkpoint_data)
            src = cp.get('source_filepath')
        except Exception:
            src = None
    if not src or not os.path.exists(src):
        return jsonify({'error': 'A forrásfájl már nem elérhető, a folytatás nem lehetséges'}), 400

    t.stop_requested = False
    t.status = 'pending'
    db.session.commit()
    thread = threading.Thread(target=translate_epub, args=(app, t.id, src, None, (t.first_pass_model or 'local')))
    thread.daemon = True
    thread.start()
    return jsonify({'success': True, 'message': 'Fordítás folytatása elindítva'})

@app.route('/api/admin/logs')
@login_required
@admin_required
def api_admin_logs():
    """Log tartalmak lekérése JSON-ban (a React Admin Logs oldalhoz)."""
    log_type = request.args.get('type', 'translation')
    lines = request.args.get('lines', 200, type=int)
    lines = min(max(lines, 10), 5000)
    
    log_file_map = {
        'translation': os.path.join(LOG_DIR, 'translation.log'),
        'app': os.path.join(LOG_DIR, 'app.log'),
    }
    log_file = log_file_map.get(log_type, log_file_map['translation'])
    log_content = ''
    if os.path.exists(log_file):
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                log_content = ''.join(f.readlines()[-lines:])
        except Exception as e:
            log_content = f'[HIBA] {e}'
    
    available_logs = [
        {'name': name, 'label': 'Fordítási log' if name == 'translation' else 'Alkalmazás log',
         'size_mb': round(os.path.getsize(path) / (1024*1024), 2) if os.path.exists(path) else 0,
         'exists': os.path.exists(path)}
        for name, path in log_file_map.items()
    ]
    return jsonify({'log_content': log_content, 'log_type': log_type, 'available_logs': available_logs})

def to_budapest(dt):
    """Naiv UTC datetime objektumot budapesti idővé konvertál és ISO stringet ad vissza.
    A zoneinfo (DST-helyes) ha elérhető, különben fix UTC+2 (nyári) fallback."""
    if dt is None:
        return None
    import datetime as _dt
    try:
        from zoneinfo import ZoneInfo
        btz = ZoneInfo('Europe/Budapest')
    except Exception:
        btz = _dt.timezone(_dt.timedelta(hours=2))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=_dt.timezone.utc)
    return dt.astimezone(btz).isoformat()

def sanitize_text(s):
    """Eltávolítja a magányos Unicode surrogate-öket (félbevágott karaktereket),
    amelyek érvénytelen JSON-t eredményeznének az API szerver felé."""
    if not isinstance(s, str):
        return s
    try:
        s.encode('utf-8')
        return s
    except UnicodeEncodeError:
        return s.encode('utf-8', 'replace').decode('utf-8')

def protect_entities(text, entities):
    """Ismert entitások (tulajdonnevek, terminusok) védelme placeholder-ekkel,
    hogy a modell ne tudja őket félrefordítani / inkonzisztensen kezelni.

    Visszaadja a védett szöveget és a visszaállító map-et (placeholder -> entity)."""
    if not text or not entities:
        return text, {}
    import re
    # Egyedi, hosszabbak először (a részleges egyezések elkerülésére)
    unique = sorted({e.strip() for e in entities if e and e.strip()}, key=len, reverse=True)
    restore = {}
    protected = text
    idx = 0
    for ent in unique:
        if len(ent) < 2:
            continue
        ph = f"__ENT{idx}__"
        replaced = re.subn(re.escape(ent), ph, protected, flags=re.IGNORECASE)
        if replaced[1] > 0:
            protected = replaced[0]
            restore[ph] = ent
            idx += 1
    return protected, restore

def restore_entities(text, restore_map):
    """A placeholder-ek visszaállítása az eredeti entitás-szövegre."""
    if not text or not restore_map:
        return text
    for ph, ent in restore_map.items():
        text = text.replace(ph, ent)
    return text

# Átmeneti hibakódok, amiknél érdemes újrapróbálkozni exponenciális háttal.
RETRYABLE_STATUS = {429, 500, 502, 503, 504}

def request_with_retry(method, url, retries=3, **kwargs):
    """HTTP kérés újrapróbálkozással, exponenciális (1s, 2s, 4s) várakozással.

    - 429/5xx és kapcsolódási hibák esetén újrapróbálkozik;
    - 400-as (például a korábbi érvénytelen JSON / surrogate hiba) esetén NEM
      próbálkozik újra, mert az értelmetlen, hanem visszaadja a választ.
    """
    import time
    last_exc = None
    for attempt in range(retries):
        try:
            resp = requests.request(method, url, **kwargs)
            if resp.status_code in RETRYABLE_STATUS and attempt < retries - 1:
                time.sleep(2 ** attempt)  # 1s, 2s, 4s
                continue
            return resp
        except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
            last_exc = e
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
    if last_exc is not None:
        raise last_exc
    # Elméletileg ide nem jutunk, de biztonság kedvéért egy üres választ adunk.
    return requests.Response()

def translate_epub(app_ref, translation_id, filepath, context_files=None, model_source='local'):
    with app_ref.app_context():
        t = Translation.query.get(translation_id)
        if not t:
            _trans_log(f"Translation #{translation_id} nem található az adatbázisban")
            return
        user = User.query.get(t.user_id) if t.user_id else None
        user_info = f"{user.email} (ID:{user.id})" if user else "ismeretlen"
        _trans_log(f"=== Fordítás indítása === Fordítás ID:{translation_id}, Fájl: {t.original_filename}, Felhasználó: {user_info}, Modell: {app_ref.config['DEFAULT_MODEL']}")
        try:
            fh_trans.flush()
        except Exception:
            pass
        try:
            # === RÉSZLETES PROGRESSZ INICIALIZÁLÁSA (5. fejlesztés) ===
            t.status = 'processing'; t.progress = 5
            t.current_stage = 'first_pass'  # első menet: AI fordítás
            db.session.commit()
            _trans_log(f"[ID:{translation_id}] 📖 EPUB olvasása: {t.original_filename}")
            from ebooklib import epub as epub_lib
            from bs4 import BeautifulSoup, NavigableString, Tag
            import hashlib, re
            book = epub_lib.read_epub(filepath)
            model = app_ref.config['DEFAULT_MODEL']
            ollama_host = app_ref.config['OLLAMA_HOST']
            deepseek_api_key = user.deepseek_api_key if user else ''
            use_deepseek = (model_source == 'remote' and deepseek_api_key)
            _trans_log(f"[ID:{translation_id}] 🔧 Modell forrás: {'DeepSeek Pro' if use_deepseek else 'Helyi Ollama'}, modell: {model}")
            
            if use_deepseek:
                # A felhasználó által kiválasztott remote modell használata
                # (lehet deepseek-chat vagy deepseek-reasoner)
                model = t.model_used if t.model_used in ('deepseek-chat', 'deepseek-reasoner') else 'deepseek-chat'
                _trans_log(f"[ID:{translation_id}] 🌐 DeepSeek Pro API: {model}")
            else:
                _trans_log(f"[ID:{translation_id}] 🖥️ Helyi Ollama modell: {model}")
            items = list(book.get_items_of_type(9))  # ITEM_DOCUMENT
            total = len(items)
            t.total_chapters = total  # összes fejezet/dokumentum
            
            # === EREDETI ANGOL SZÖVEGEK ELMENTÉSE (a második menethez) ===
            # Az első menet során az item-ek tartalma módosul (lefordított szövegre cserélődik),
            # ezért a második menet "ellenőrző" promptjához szükséges eredeti angol szövegeket
            # el kell mentenünk még a fordítás előtt.
            original_texts = []
            for it in items:
                try:
                    orig_soup = BeautifulSoup(it.get_body_content(), 'html.parser')
                    original_texts.append(orig_soup.get_text()[:2000].strip())
                except:
                    original_texts.append("")
            _trans_log(f"[ID:{translation_id}] Eredeti szövegek elmentve a második menethez ({total} dokumentum)")
            # Becsült szószám számítás (az első 5 dokumentum alapján extrapolálunk)
            total_words_est = 0
            for it in items[:min(5, total)]:
                try:
                    ws = BeautifulSoup(it.get_body_content(), 'html.parser').get_text()
                    total_words_est += len(ws.split())
                except: pass
            if total > 0:
                t.total_words = int(total_words_est * (total / min(5, total)))
            db.session.commit()
            _trans_log(f"[ID:{translation_id}] 📊 {total} szöveges elem, ~{t.total_words} szó, fordítás kezdése a(z) {model} modellel")

            # === CHECKPOINT VISSZAÁLLÍTÁS (v2.3.0+) ===
            # Ha van mentett állapot (pl. konténer-újraindítás után folytatjuk),
            # a már lefordított fejezetek tartalmát visszatöltjük.
            resume_from = 0
            if t.checkpoint_data:
                try:
                    import base64
                    cp = json.loads(t.checkpoint_data)
                    contents = cp.get('contents') or []
                    saved_texts = cp.get('original_texts') or []
                    if saved_texts and len(saved_texts) == len(original_texts):
                        original_texts = saved_texts
                    for i, b64 in enumerate(contents):
                        if i < total and b64:
                            try:
                                items[i].set_content(base64.b64decode(b64))
                            except Exception:
                                pass
                    resume_from = int(cp.get('chapter_index', 0)) + 1
                    _trans_log(f"[ID:{translation_id}] 🔁 Checkpoint visszaállítva: {resume_from}/{total} fejezettől folytatás")
                except Exception as cp_err:
                    _trans_log(f"[ID:{translation_id}] Checkpoint visszaállítása sikertelen: {cp_err}")

            # Checkpoint mentő helper: minden fejezet után elmenti a kész tartalmat.
            def save_checkpoint(last_idx):
                try:
                    import base64
                    contents = []
                    for i in range(last_idx + 1):
                        try:
                            contents.append(base64.b64encode(items[i].get_content()).decode('ascii'))
                        except Exception:
                            contents.append(None)
                    cp = json.dumps({
                        'chapter_index': last_idx,
                        'contents': contents,
                        'original_texts': original_texts,
                        'source_filepath': filepath,
                    })
                    t.checkpoint_data = cp
                    t.last_checkpoint_at = datetime.utcnow()
                except Exception as cp_err:
                    _trans_log(f"[ID:{translation_id}] Checkpoint mentése sikertelen: {cp_err}")

            def stop_requested_fresh():
                """A stop_requested flag friss olvasása az adatbázisból, mert a
                /stop kérés egy másik munkamenetben commitolja azt."""
                try:
                    v = db.session.execute(
                        db.text("SELECT stop_requested FROM translations WHERE id = :id"),
                        {'id': translation_id}
                    ).scalar()
                    return bool(v)
                except Exception:
                    return False

            app_logger.info(f"🚀 Fordítás indult: #{translation_id} '{t.original_filename}' ({model}, {t.total_words} szó)")
            translated_count = 0; failed_items = 0; total_nodes_translated = 0
            
            # Szeparátor a text node-ok batch fordításához
            NODE_SEP = '\n---NEXT_TEXT_NODE---\n'
            
            # === GLOSSZÁRIUM BETÖLTÉSE (1. fejlesztés) ===
            glossary_terms = {}
            glossary_source_terms = []
            try:
                entries = GlossaryEntry.query.filter_by(user_id=t.user_id).order_by(GlossaryEntry.source_count.desc()).limit(100).all()
                for entry in entries:
                    glossary_terms[entry.source_term.lower()] = entry.target_term
                    glossary_source_terms.append(entry.source_term)
                if glossary_terms:
                    _trans_log(f"[ID:{translation_id}] Glosszárium betöltve: {len(glossary_terms)} bejegyzés")
            except Exception as ge:
                _trans_log(f"[ID:{translation_id}] Glosszárium nem elérhető: {ge}")
            
            # === FORDÍTÁSI MEMÓRIA ELŐKÉSZÍTÉSE (4. fejlesztés) ===
            # A TM-et menet közben használjuk – a search_translation_memory segédfüggvénnyel
            def search_tm(source_text, user_id):
                """Fordítási memória keresés – SHA256 hash alapján pontos egyezés."""
                try:
                    import hashlib
                    text_hash = hashlib.sha256(source_text.strip().encode()).hexdigest()
                    tm = TranslationMemory.query.filter_by(user_id=user_id, source_hash=text_hash).first()
                    if tm:
                        tm.usage_count += 1
                        tm.last_used = datetime.utcnow()
                        db.session.commit()
                        return tm.translated_text
                except:
                    pass
                return None

            def fuzzy_search_tm(source_text, user_id, threshold=0.8, max_candidates=200):
                """Hasonlóságalapú fordítási memória keresés difflib-bal.

                Előszűrés: csak a felhasználó bejegyzései, hosszarány-szűrés
                (0.6–1.6×) és last_used szerinti rendezés + limit, hogy nagy TM
                esetén se lassuljon le a keresés.
                """
                try:
                    import difflib
                    src = source_text.strip()
                    slen = len(src)
                    if slen < 10:
                        return None
                    candidates = (TranslationMemory.query
                                  .filter_by(user_id=user_id)
                                  .order_by(TranslationMemory.last_used.desc())
                                  .limit(max_candidates)
                                  .all())
                    best = None
                    best_ratio = threshold
                    for tm in candidates:
                        text = (tm.source_text or '').strip()
                        if not text:
                            continue
                        tlen = len(text)
                        # Hosszarány-szűrés a felesleges összehasonlítások elkerülésére
                        if slen > 0 and (tlen / slen > 1.6 or tlen / slen < 0.6):
                            continue
                        ratio = difflib.SequenceMatcher(None, src, text).ratio()
                        if ratio >= best_ratio:
                            best = tm
                            best_ratio = ratio
                    if best:
                        best.usage_count += 1
                        best.last_used = datetime.utcnow()
                        db.session.commit()
                        return best.translated_text
                except:
                    pass
                return None

            # Token-fogyasztás és költség napló gyűjtése
            tokens_in_total = 0
            tokens_out_total = 0
            cost_total = 0.0
            # DeepSeek árazás (USD / 1M token) a későbbi költségszámításhoz
            ds_pricing = {}
            for m in Config.REMOTE_MODELS:
                if m.get('id') == model:
                    ds_pricing = m
                    break
            
            # === HUNSPELL INICIALIZÁLÁS (3. fejlesztés) ===
            # CLI eszközként használjuk (subprocess), mivel a hunspell Python binding
            # nem fordul megbízhatóan a pip telepítés során
            hunspell_available = False
            try:
                import subprocess as _sp
                result = _sp.run(['hunspell', '-d', 'hu_HU', '--version'], 
                                capture_output=True, text=True, timeout=5)
                hunspell_available = result.returncode == 0
                if hunspell_available:
                    _trans_log(f"[ID:{translation_id}] Hunspell CLI magyar helyesírás-ellenőrző elérhető")
            except Exception as he:
                _trans_log(f"[ID:{translation_id}] Hunspell nem elérhető: {he}")
            
            # === FEJLETT PROMPT KONTEXTUS ELŐKÉSZÍTÉSE ===
            style_instruction = ""
            terminology_list = ""
            terminology_entities = set()
            
            # 1. Stílus-instrukció gyűjtése referencia (minta) könyvekből
            try:
                ref_books = ReferenceBook.query.filter_by(user_id=t.user_id).all()
                if ref_books:
                    style_samples = []
                    for rb in ref_books[:3]:  # maximum 3 referencia könyv
                        try:
                            r_book = epub_lib.read_epub(rb.file_path)
                            r_items = list(r_book.get_items_of_type(9))
                            if r_items:
                                r_soup = BeautifulSoup(r_items[0].get_body_content(), 'html.parser')
                                sample_text = r_soup.get_text()[:2000].strip()
                                if sample_text:
                                    style_samples.append(sample_text)
                        except Exception:
                            pass
                    if style_samples:
                        combined_sample = "\n".join(style_samples[:2])[:1500]
                        style_instruction = f"""Stílusinstrukció: A következő mintaszövegek alapján azonos stílusban, 
hasonló szókinccsel és mondatszerkezettel fordítsd a szövegeket magyarra.
Minták a kívánt stílushoz:
{combined_sample}
---
"""
                        _trans_log(f"[ID:{translation_id}] Stílusinstrukció betöltve ({len(style_samples)} referencia könyvből)")
            except Exception as style_err:
                _trans_log(f"[ID:{translation_id}] Stílusinstrukció nem elérhető: {style_err}")
            
            # 2. Terminológia gyűjtése könyvtári könyvekből (a felhasználó által kiválasztottak)
            try:
                # A fordítási űrlapról érkező kiválasztott könyvek (context_files) az elsődleges forrás.
                # Ha nincs kijelölés, a felhasználó saját 3 legutóbb feltöltött könyve a fallback.
                all_book_paths = []
                if context_files:
                    all_book_paths.extend(context_files)
                else:
                    fallback_books = Book.query.filter_by(user_id=t.user_id).order_by(Book.uploaded_at.desc()).limit(3).all()
                    fallback_paths = [b.file_path for b in fallback_books if b.file_path]
                    if fallback_paths:
                        _trans_log(f"[ID:{translation_id}] Nincs kijelölt kontextus-könyv, fallback: a felhasználó 3 legutóbbi könyve")
                    all_book_paths.extend(fallback_paths)
                all_book_paths = all_book_paths[:5]  # max 5 könyv

                if all_book_paths:
                    # Kulcsszavak kigyűjtése: tulajdonnevek, speciális kifejezések
                    import re
                    terms = set()
                    for bp in set(all_book_paths):
                        try:
                            if os.path.exists(bp):
                                lb_book = epub_lib.read_epub(bp)
                                lb_items = list(lb_book.get_items_of_type(9))[:10]
                                for lb_item in lb_items:
                                    lb_soup = BeautifulSoup(lb_item.get_body_content(), 'html.parser')
                                    lb_text = lb_soup.get_text()
                                    # Tulajdonnevek keresése (nagybetűs szavak, amik nem mondatkezdők)
                                    proper_nouns = re.findall(r'(?<![.\!?]\s)\b([A-Z][a-z]+(?:\s[A-Z][a-z]+)*)\b', lb_text)
                                    for pn in proper_nouns:
                                        if len(pn) > 3 and pn.lower() not in ('the', 'this', 'that', 'there', 'these', 'those', 'they', 'their', 'them', 'chapter', 'part', 'section', 'book', 'page'):
                                            terms.add(pn.strip())
                                    # Hosszabb speciális kifejezések (legalább 10 karakter)
                                    special_terms = re.findall(r'\b[A-Z][a-z]{3,}(?:\s[A-Z][a-z]{3,}){1,3}\b', lb_text)
                                    for st in special_terms[:5]:
                                        terms.add(st.strip())
                        except Exception:
                            pass
                    
                    if terms:
                        terminology_entities = terms
                        term_list = sorted(list(terms))[:30]
                        terminology_list = f"""Fontos terminológia és tulajdonnevek (ezeket NE fordítsd le, hagyd eredeti formában):
{', '.join(term_list)}

"""
                        _trans_log(f"[ID:{translation_id}] Terminológia betöltve: {len(term_list)} kifejezés")
            except Exception as term_err:
                _trans_log(f"[ID:{translation_id}] Terminológia gyűjtés nem sikerült: {term_err}")

            # === NER ENTITÁS-VÉDELEM (v2.4.0+) – KI VAN KAPCSOLVA (v2.5.6) ===
            # A regex-alapú „tulajdonnév" gyűjtés minden nagybetűvel kezdődő
            # KÖZNEVET is névnek nézett (Could, Another), és a modell ezeket
            # angolul hagyta. A glosszárium-védelem (megerősített terminusok)
            # TÖRETLENÜL megmarad; a nyers regex-védelem törölve.
            protected_entities = []

            # === TELEZÉS/MAGÁZÁS + REGISZTER UTASÍTÁS (v2.5.0+) ===
            formality = (user.formality if user and getattr(user, 'formality', None) else 'informal')
            if formality == 'formal':
                formality_hint = "Formasági utasítás: magázó stílusban fordíts (Ön, önt formák).\n"
            else:
                formality_hint = "Formasági utasítás: tegeződő stílusban fordíts.\n"

            for idx, item in enumerate(items):
                # A korábbi checkpoint-nál már kész fejezeteket átugorjuk
                if resume_from > 0 and idx < resume_from:
                    continue
                # Leállítási kérés ellenőrzése (a felhasználó a /stop végponttal kéri)
                if stop_requested_fresh():
                    _trans_log(f"[ID:{translation_id}] ⏹️ Leállítási kérés észlelve, fordítás megszakítva (elem {idx+1}/{total})")
                    save_checkpoint(idx - 1) if idx > 0 else None
                    t.status = 'paused'
                    t.current_stage = 'paused'
                    db.session.commit()
                    return
                try:
                    # Fejezet kezdete – azonnali visszajelzés (fejezetszám + log),
                    # hogy ne tűnjön a fordítás „beragadtnak" egy hosszú fejezet közben.
                    if idx >= resume_from:
                        t.current_chapter = idx + 1
                        t.nodes_translated = total_nodes_translated
                        db.session.commit()
                        _trans_log(f"[ID:{translation_id}] 📖 Fejezet {idx+1}/{total} feldolgozása…")
                        try:
                            fh_trans.flush()
                        except Exception:
                            pass
                    soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                    
                    # 1. szakasz: Gyűjtsük ki az összes lefordítandó NavigableString-et
                    # Kizárjuk: script, style, code, pre tartalmat, illetve csak whitespace-t
                    text_nodes = []
                    for node in soup.descendants:
                        if isinstance(node, NavigableString):
                            stripped = node.strip()
                            if not stripped:
                                continue
                            # Hagyjuk ki a nem fordítandó elemeket
                            if node.parent and node.parent.name in ('script', 'style', 'code', 'pre'):
                                continue
                            text_nodes.append((node, stripped))
                    
                    if not text_nodes:
                        _trans_log(f"[ID:{translation_id}] Elem {idx+1}/{total}: nincs lefordítandó szöveg, kihagyva")
                        continue
                    
                    _trans_log(f"[ID:{translation_id}] Elem {idx+1}/{total}: {len(text_nodes)} text node, fordítás batch-ben...")
                    
                    # 2. szakasz: Batch fordítás placeholder-alapú biztonságos cserével
                    source_texts = [tn[1] for tn in text_nodes]
                    combined_source = NODE_SEP.join(source_texts)
                    
                    # v2.6.12: a szomszédos fejezet kontextus KI VAN KAPCSOLVA.
                    # A korábbi sliding-window (előző 800 + következő 500 karakter)
                    # a node-onkénti promptBA tette a szomszédos fejezetet, amit a modell
                    # lefordítva visszamondott -> duplikáció és rossz helyen lévő részek.
                    surrounding_context = ""
                    
                    # === NODE-ONKÉNTI FORDÍTÁS (megbízhatóbb, mint a batch) ===
                    # Batch fordítás helyett minden text node-ot egyesével fordítunk,
                    # mert a deepseek-r1 nem használja megbízhatóan a NODE_SEP szeparátort.
                    # Ez több API hívást jelent, de a megbízhatóság garantált.
                    
                    # Few-shot fordítási példák a jobb minőségért – a modell ezek alapján tanulja a stílust
                    few_shot = """Fordítási példák (stílus és formátum referenciaként):

Angol: The quick brown fox jumps over the lazy dog.
Magyar: A gyors barna róka átugorja a lusta kutyát.

Angol: She walked through the garden, admiring the beautiful flowers that bloomed in the morning sun.
Magyar: Átsétált a kerten, gyönyörködve a gyönyörű virágokban, amelyek a reggeli napfényben nyíltak.

---
"""
                    import hashlib
                    nodes_translated_here = 0
                    placeholders = []
                    
                    for node_idx, (node, original) in enumerate(text_nodes):
                        # Leállítás friss ellenőrzése node-szinten is
                        if stop_requested_fresh():
                            _trans_log(f"[ID:{translation_id}] ⏹️ Leállítás node-szinten észlelve (elem {idx+1}/{total}, node {node_idx+1})")
                            save_checkpoint(idx - 1) if idx > 0 else None
                            t.status = 'paused'
                            t.current_stage = 'paused'
                            db.session.commit()
                            return
                        if len(original) < 5:
                            continue  # túl rövid szöveg, nem érdemes fordítani
                        
                        # Fordítási memória keresés: PONTOS egyezés (SHA256).
                        # A fuzzy matching KI van kapcsolva, mert a rövid, hasonló
                        # párbeszédeknél téves találatokat adott (Relentless eset).
                        cached = search_tm(original, t.user_id)
                        if cached:
                            ph = f"__CACHED_{hashlib.md5(f'{idx}_{node_idx}_{uuid.uuid4().hex[:6]}'.encode()).hexdigest()[:12]}__"
                            node.replace_with(ph)
                            placeholders.append((ph, cached, True))
                            nodes_translated_here += 1
                            total_nodes_translated += 1
                            _trans_log(f"[ID:{translation_id}] Elem {idx+1}/{total}, node {node_idx+1}/{len(text_nodes)}: TM cache találat (exact)")
                            continue
                        
                        # Ollama API hívás egyetlen text node fordítására
                        # Kontextus: few-shot + stílus + terminológia + előző fejezet + GLOSSZÁRIUM
                        # A glosszárium betöltve, használjuk explicit utasításként
                        glossary_hint = ""
                        if glossary_terms:
                            relevant = [f"{k} → {v}" for k, v in glossary_terms.items() if k in original.lower()]
                            if relevant:
                                glossary_hint = f"Glosszárium (használd ezeket a fordításokat): {', '.join(relevant[:5])}\n"
                        
                        # (NER entitás-védelem kikapcsolva – nincs placeholder-csere)

                        # Regiszter-besorolás: párbeszéd vs. narráció
                        register_hint = ""
                        if re.search(r'["“”\u201c\u201d]', original):
                            register_hint = "Ez párbeszéd. Közvetlen, élő magyar beszélt nyelvet használj.\n"

                        single_prompt = f"""{few_shot}{glossary_hint}{style_instruction}{formality_hint}{register_hint}Fordítsd le a következő angol szöveget magyarra.
Csak a fordítást add vissza, semmi mást!

{original[:800]}"""
                        single_prompt = sanitize_text(single_prompt)
                        
                        try:
                            if use_deepseek:
                                # DeepSeek Pro API hívás (Chat Completions formátum)
                                # DeepSeek API: deepseek-reasoner máshogy kezelendő (nem támogatja a temperature-t)
                                deepseek_payload = {
                                    'model': model,
                                    'messages': [{'role': 'user', 'content': single_prompt}],
                                    'max_tokens': 1024,
                                    'stream': False
                                }
                                if model == 'deepseek-chat':
                                    deepseek_payload['temperature'] = 0.2
                                # deepseek-reasoner nem támogatja a temperature paramétert
                                
                                resp = request_with_retry("POST", "https://api.deepseek.com/v1/chat/completions", json=deepseek_payload,
                                    headers={
                                        'Authorization': f'Bearer {deepseek_api_key}',
                                        'Content-Type': 'application/json'
                                    }, timeout=None)
                                if resp.status_code == 200:
                                    data = resp.json()
                                    translated = data['choices'][0]['message']['content'].strip()
                                    usage = data.get('usage') or {}
                                    tokens_in_total += usage.get('prompt_tokens', 0)
                                    tokens_out_total += usage.get('completion_tokens', 0)
                                else:
                                    _trans_log(f"[ID:{translation_id}] DeepSeek API hiba (HTTP {resp.status_code}): {resp.text[:200]}")
                                    translated = ''
                            else:
                                # Helyi Ollama API hívás
                                resp = request_with_retry("POST", f"{ollama_host}/api/generate", json={
                                    'model': model,
                                    'prompt': single_prompt,
                                    'stream': False,
                                    'options': {
                                        'num_predict': 1024,
                                        'temperature': 0.2,
                                        'repeat_penalty': 1.1,
                                        'top_p': 0.9
                                    }
                                }, timeout=None)
                                if resp.status_code == 200:
                                    data = resp.json()
                                    translated = data.get('response', '').strip()
                                    tokens_in_total += data.get('prompt_eval_count', 0)
                                    tokens_out_total += data.get('eval_count', 0)
                                else:
                                    _trans_log(f"[ID:{translation_id}] Ollama hiba (HTTP {resp.status_code}) node {node_idx+1}-nél")
                                    translated = ''
                            
                            if translated and translated != original:
                                # Placeholder-s csere
                                ph = f"__TNPLACEHOLDER_{hashlib.md5(f'{idx}_{node_idx}_{uuid.uuid4().hex[:6]}'.encode()).hexdigest()[:12]}__"
                                try:
                                    node.replace_with(ph)
                                    placeholders.append((ph, translated, False))
                                    nodes_translated_here += 1
                                    total_nodes_translated += 1
                                except:
                                    placeholders.append((ph, original, False))  # hiba esetén az eredeti
                            else:
                                # Üres vagy azonos válasz – az eredeti marad
                                ph = f"__TNPLACEHOLDER_{hashlib.md5(f'{idx}_{node_idx}_{uuid.uuid4().hex[:6]}'.encode()).hexdigest()[:12]}__"
                                try:
                                    node.replace_with(ph)
                                    placeholders.append((ph, original, False))
                                except:
                                    pass
                        except Exception as node_err:
                            _trans_log(f"[ID:{translation_id}] Node fordítási hiba: {node_err}")
                    
                    # Cseréljük a placeholder-eket a fordított szövegre
                    html_str = str(soup)
                    for ph, text, is_cached in placeholders:
                        html_str = html_str.replace(ph, text, 1)
                    
                    if nodes_translated_here > 0:
                        translated_count += 1
                    
                    # Részletes előrehaladás logolás minden 10. elemnél vagy az első 3-nál
                    if idx < 3 or (idx + 1) % 10 == 0:
                        pct = t.progress
                        _trans_log(f"[ID:{translation_id}] ⏳ Előrehaladás: {idx+1}/{total} elem ({pct}%), {total_nodes_translated} node lefordítva, {failed_items} hiba")
                    
                    _trans_log(f"[ID:{translation_id}] Elem {idx+1}: {nodes_translated_here}/{len(text_nodes)} node lefordítva (node-onkénti mód)")
                    
                    # === GLOSSZÁRIUM ÉPÍTÉS (1. fejlesztés) ===
                    try:
                        for node, original in text_nodes:
                            translated = None
                            for ph, txt, _ in placeholders:
                                if node.strip()[:20] in original[:20]:
                                    translated = txt
                                    break
                            if not translated or translated == original or len(original) < 3 or len(translated) < 3:
                                continue
                            source_lower = original.lower().strip()
                            target_lower = translated.lower().strip()
                            if source_lower != target_lower:
                                existing = GlossaryEntry.query.filter_by(
                                    user_id=t.user_id, 
                                    source_term=original[:200]
                                ).first()
                                if not existing:
                                    entry = GlossaryEntry(user_id=t.user_id, source_term=original[:200], target_term=translated[:200])
                                    db.session.add(entry)
                                else:
                                    existing.source_count += 1
                        db.session.commit()
                    except Exception:
                        db.session.rollback()
                    
                    # === FORDÍTÁSI MEMÓRIA MENTÉS (4. fejlesztés) ===
                    # === FORDÍTÁSI MEMÓRIA MENTÉS (4. fejlesztés) ===
                    try:
                        for node, original in text_nodes:
                            translated = None
                            for ph, txt, _ in placeholders:
                                if node.strip()[:20] in original[:20]:
                                    translated = txt
                                    break
                            if not translated or translated == original:
                                continue
                            import hashlib
                            tm_hash = hashlib.sha256(original.strip().encode()).hexdigest()
                            # A source_hash GLOBÁLISAN unique; ha már bármely
                            # felhasználó lefordította ezt a szöveget, ne szúrjuk
                            # be újra (korábban UniqueViolation miatt szállt el a szál).
                            exists = TranslationMemory.query.filter_by(source_hash=tm_hash).first()
                            if exists:
                                continue
                            db.session.add(TranslationMemory(
                                user_id=t.user_id,
                                source_text=original[:1000],
                                translated_text=translated[:1000],
                                source_hash=tm_hash,
                            ))
                        db.session.commit()
                    except Exception:
                        db.session.rollback()
                    
                    # === HUNSPELL HELYESÍRÁS ELLENŐRZÉS (3. fejlesztés) ===
                    if hunspell_available:
                        try:
                            for ph, translated, _ in placeholders:
                                if not translated or len(translated) < 5: continue
                                words = translated.split()
                                for word in words:
                                    clean_word = word.strip('.,;:!?()[]{}"\'').lower()
                                    if len(clean_word) > 2:
                                        result = _sp.run(['hunspell', '-d', 'hu_HU', '-a'], input=clean_word + '\n', capture_output=True, text=True, timeout=2)
                        except Exception: pass
                    
                    # === RÉSZLETES PROGRESSZ FRISSÍTÉS (5. fejlesztés) ===
                    t.current_chapter = idx + 1
                    t.nodes_translated = total_nodes_translated
                    t.nodes_failed = failed_items
                    words_here = sum(len(tn[1].split()) for tn in text_nodes if len(tn[1].split()) > 2)
                    t.words_processed = (t.words_processed or 0) + words_here
                    item.set_content(html_str.encode('utf-8'))
                    
                except requests.exceptions.ConnectionError as ce:
                    _trans_log(f"[ID:{translation_id}] Kapcsolódási hiba: {ce}")
                    raise
                except Exception as item_err:
                    _trans_log(f"[ID:{translation_id}] Elem feldolgozási hiba: {item_err}")
                    failed_items += 1
                
                t.progress = 5 + int(90 * (idx + 1) / total)
                db.session.commit()
                # Checkpoint mentés az aktuális fejezet után
                if idx >= resume_from:
                    save_checkpoint(idx)
                # A fordítási log fájl azonnali frissítése (fejezetszám láthatósága)
                try:
                    fh_trans.flush()
                except Exception:
                    pass
            
            _trans_log(f"[ID:{translation_id}] Első menet kész: {translated_count}/{total} dokumentum, {total_nodes_translated} szöveges csomópont lefordítva, {failed_items} hiba")
            
            # ═══════════════════════════════════════════════════════════════
            t.first_pass_model = model  # elmentjük, melyik modell futott az első menetben
            # === KÉTMENETES FORDÍTÁS – MÁSODIK MENET: MINŐSÉGELLENŐRZÉS ===
            # ═══════════════════════════════════════════════════════════════
            # v2.5.2-től ALAPBÓL KIKAPCSOLVA (ENABLE_SECOND_PASS='n'), mert a
            # csonkolt bemenetből (eredeti[:800] + fordítás[:1500]) a modell nem
            # tudta a teljes fejezetet reprodukálni, és duplikálta/többszörözte a
            # szöveget (pl. "TartalomjegyzékTartalomjegyzék", "A Berkley ..." 32x).
            # Visszaépítéshez: Config.ENABLE_SECOND_PASS = True (+ .env ENABLE_SECOND_PASS=i).
            review_count = 0; review_improvements = 0
            second_pass_enabled = bool(getattr(app_ref.config, 'ENABLE_SECOND_PASS', False))
            if second_pass_enabled:
                t.current_stage = 'second_pass'
                t.progress = 91  # 90% volt az első menet, most jön a második
                t.second_pass_model = model  # alapértelmezetten ugyanaz
                db.session.commit()
                _trans_log(f"[ID:{translation_id}] 🔍 Második menet indítása – minőségellenőrzés (modell: {model})...")
            else:
                _trans_log(f"[ID:{translation_id}] ⏭️ Második menet KIHAGYVA (ENABLE_SECOND_PASS=n)")
            for idx, item in enumerate(items):
                if not second_pass_enabled:
                    break
                # Leállítási kérés ellenőrzése a második menetben is
                if stop_requested_fresh():
                    _trans_log(f"[ID:{translation_id}] ⏹️ Leállítási kérés észlelve a második menetben (elem {idx+1}/{total})")
                    save_checkpoint(idx - 1) if idx > 0 else None
                    t.status = 'paused'
                    t.current_stage = 'paused'
                    db.session.commit()
                    return
                try:
                    # Csak azokat az elemeket ellenőrizzük, amikben van lefordított szöveg
                    soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                    review_text = soup.get_text().strip()
                    if not review_text or len(review_text) < 50:
                        # Túl rövid, nincs értelme ellenőrizni
                        continue
                    
                    _trans_log(f"[ID:{translation_id}] Második menet: elem {idx+1}/{total}, szöveghossz: {len(review_text)} karakter")
                    review_count += 1
                    
                    # Második menet prompt: az eredeti szöveget és a fordítást is beküldjük
                    # FONTOS: Az első menet után az items[idx] már lefordított szöveget tartalmaz,
                    # ezért az original_texts listából vesszük az EREDETI angol szöveget!
                    original_text = original_texts[idx] if idx < len(original_texts) else ""
                    
                    # A második menet promptja: ellenőrzés és javítás
                    review_prompt = f"""Ellenőrizd és javítsd az alábbi angolról magyarra fordítást.
Ellenőrzési szempontok:
- Nyelvtani pontosság (egyeztetés, ragozás, szórend)
- Természetes magyar kifejezések használata
- Stílus és tónus megőrzése
- Esetleges kihagyások vagy betoldások javítása

Eredeti angol szöveg (referencia):
{original_text[:800]}

Jelenlegi magyar fordítás:
{review_text[:1500]}

Kérlek, add vissza a JAVÍTOTT magyar fordítást. Csak a javított szöveget add vissza, semmi mást! 
Ha a fordítás megfelelő, akkor változtatás nélkül add vissza."""
                    review_prompt = sanitize_text(review_prompt)
                    
                    try:
                        review_resp = request_with_retry("POST", f"{ollama_host}/api/generate", json={
                            'model': model,
                            'prompt': review_prompt,
                            'stream': False,
                            'options': {
                                'num_predict': 2048,
                                'temperature': 0.15,  # még alacsonyabb hőmérséklet a pontos javításhoz
                                'repeat_penalty': 1.05,
                                'top_p': 0.9
                            }
                        }, timeout=None)
                        
                        if review_resp.status_code == 200:
                            review_data = review_resp.json()
                            improved_text = review_data.get('response', '').strip()
                            tokens_in_total += review_data.get('prompt_eval_count', 0)
                            tokens_out_total += review_data.get('eval_count', 0)
                            if improved_text and improved_text != review_text:
                                # A javított szöveg visszaírása az item-be
                                # A HTML struktúra megtartása érdekében a soup-ot használjuk
                                review_soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                                # Az összes text node-ot kicseréljük a javított szövegre
                                # (Az első menet után a text node-ok már magyarul vannak)
                                text_nodes = [n for n in review_soup.descendants if isinstance(n, NavigableString) and n.strip()]
                                if text_nodes:
                                    # A javított szöveget visszaírjuk az első text node-ba,
                                    # a többit töröljük (mivel a második menet egyben adja vissza a javított szöveget)
                                    for i, node in enumerate(text_nodes):
                                        if i == 0:
                                            node.replace_with(improved_text)
                                        else:
                                            node.replace_with('')
                                    
                                    item.set_content(str(review_soup).encode('utf-8'))
                                    review_improvements += 1
                                    _trans_log(f"[ID:{translation_id}] Második menet: elem {idx+1} javítva ({len(improved_text)} karakter)")
                                else:
                                    _trans_log(f"[ID:{translation_id}] Második menet: elem {idx+1} nem tartalmazott text node-okat")
                            else:
                                _trans_log(f"[ID:{translation_id}] Második menet: elem {idx+1} nem változott (a fordítás megfelelő)")
                        else:
                            _trans_log(f"[ID:{translation_id}] Második menet: Ollama hiba (HTTP {review_resp.status_code}) a(z) {idx+1}. elemnél")
                    except Exception as review_err:
                        _trans_log(f"[ID:{translation_id}] Második menet: hiba a(z) {idx+1}. elemnél: {review_err}")
                    
                    # Progressz frissítés (91% → 99%)
                    t.progress = 91 + int(8 * (idx + 1) / total)
                    t.current_chapter = idx + 1
                    db.session.commit()
                    
                except Exception as item_review_err:
                    _trans_log(f"[ID:{translation_id}] Második menet: elem feldolgozási hiba: {item_review_err}")
            
            if second_pass_enabled:
                _trans_log(f"[ID:{translation_id}] Második menet kész: {review_count} dokumentum ellenőrizve, {review_improvements} javítva")
            
            # === VÉGSŐ MENTÉS ===
            t.current_stage = 'post_processing'
            t.progress = 99
            db.session.commit()
            
            output_filename = f"translated_{uuid.uuid4().hex[:8]}.epub"
            output_path = os.path.join(app_ref.config['OUTPUT_FOLDER'], output_filename)
            epub_lib.write_epub(output_path, book)
            t.output_filename = output_filename; t.status = 'completed'; t.progress = 100
            t.current_stage = 'completed'
            if second_pass_enabled:
                # Minőségi pontszám: a review javítások aránya alapján
                t.quality_score = min(99, 75 + int((review_improvements / max(review_count, 1)) * 20))
            else:
                # Review nélkül: a hibás node-ok arányából becsülünk
                if total_nodes_translated > 0:
                    fail_ratio = failed_items / max(total_nodes_translated, 1)
                    t.quality_score = min(99, 95 - int(fail_ratio * 100 * 0.3))
                else:
                    t.quality_score = 85
            # Token/költség napló mentése (tényleges használat)
            t.input_tokens_used = tokens_in_total
            t.output_tokens_used = tokens_out_total
            if use_deepseek and ds_pricing:
                in_price = ds_pricing.get('input_price_per_mtok', 0.0)
                out_price = ds_pricing.get('output_price_per_mtok', 0.0)
                cost_total = (tokens_in_total / 1_000_000) * in_price + (tokens_out_total / 1_000_000) * out_price
            t.cost_usd = round(cost_total, 6)
            # A lefordított könyv a közös könyvtárhoz „várakozó" (pending) állapotba kerül,
            # admin jóváhagyás után lesz elérhető a könyvtárban. A letöltés addig is működik.
            if t.library_status == 'none':
                t.library_status = 'pending'
            db.session.commit()
            _trans_log(f"[ID:{translation_id}] ✅ Fordítás sikeresen befejezve: {output_filename} | Minőség: {t.quality_score}/100 | Lefordított node-ok: {total_nodes_translated}, hibás: {failed_items}")
            app_logger.info(f"Fordítás kész: {t.original_filename} -> {output_filename} (user: {user_info}, {total_nodes_translated} node)")
            
            # === ÉRTESÍTÉS A FORDÍTÁS BEFEJEZÉSEKOR (7. fejlesztés) ===
            # Email küldése a felhasználónak, hogy a fordítása elkészült
            try:
                from flask_mail import Mail, Message
                mail = Mail(app_ref)
                msg = Message(
                    f"✅ Fordítás kész: {t.original_filename}",
                    sender=app_ref.config.get('MAIL_DEFAULT_SENDER', 'epub-translator@localhost'),
                    recipients=[user.email]
                )

                # Csatolmány hozzáadása, ha a fájl a beállított limit alatt van
                attach_note = ""
                try:
                    file_size = os.path.getsize(output_path)
                    max_bytes = app_ref.config.get('EMAIL_ATTACHMENT_MAX_BYTES', 24 * 1024 * 1024)
                    if file_size <= max_bytes:
                        with open(output_path, 'rb') as fp:
                            msg.attach(f"forditott_{t.original_filename}", 'application/epub+zip', fp.read())
                        attach_note = f"\n📎 A lefordított EPUB ({file_size / 1024 / 1024:.1f} MB) csatolva.\n"
                    else:
                        attach_note = (f"\n📎 A lefordított EPUB túl nagy a csatoláshoz "
                                       f"({file_size / 1024 / 1024:.1f} MB). A fiókodban letöltheted.\n")
                except Exception as attach_err:
                    _trans_log(f"[ID:{translation_id}] Csatolmány hozzáadása nem sikerült: {attach_err}")

                msg.body = f"""Kedves {user.first_name}!

A(z) "{t.original_filename}" fordítása sikeresen befejeződött.

📊 Részletek:
  Fájl: {t.original_filename} → {output_filename}
  Modell: {model}
  Minőségi pontszám: {t.quality_score}/100
  Lefordított node-ok: {total_nodes_translated}
  Ellenőrzött elemek: {review_count}
  Javítások: {review_improvements}
{attach_note}
📥 Letöltés: http://localhost/download/{t.id}
📝 Átnézés és javítás: http://localhost/review/{t.id}

Köszönjük, hogy az EPUB Fordítót használod!

Üdv,
EPUB Fordító"""
                mail.send(msg)
                _trans_log(f"[ID:{translation_id}] 📧 Értesítő email elküldve: {user.email}")
            except Exception as mail_err:
                _trans_log(f"[ID:{translation_id}] Email értesítés nem sikerült: {mail_err}")
        except Exception as e:
            error_detail = _traceback.format_exc()
            t.status = 'failed'; t.progress = 0; t.output_filename = f"HIBA: {str(e)[:500]}"
            db.session.commit()
            _trans_log(f"[ID:{translation_id}] ❌ Fordítási hiba:\n{error_detail}")
            try:
                fh_trans.flush()
            except Exception:
                pass
            app_logger.error(f"Fordítás hiba: {t.original_filename} (user: {user_info}) - {str(e)[:200]}")
        finally:
            # Ha van checkpoint (megszakadt/folytatható), a forrásfájlt megtartjuk a
            # későbbi folytatáshoz; csak teljes kész/hiba esetén takarítunk.
            if os.path.exists(filepath) and not t.checkpoint_data:
                os.remove(filepath)
                _trans_log(f"[ID:{translation_id}] Ideiglenes fájl törölve: {filepath}")

def _is_sqlite():
    """True, ha az aktuális DB SQLite (önálló/desktop mód), egyébként False (Postgres)."""
    uri = Config.SQLALCHEMY_DATABASE_URI or ''
    return uri.startswith('sqlite')

def _ensure_column(table, col, col_type):
    """Oszlop létrehozása, ha még nem létezik – SQLite-on PRAGMA-val ellenőriz,
    Postgres-en az ADD COLUMN IF NOT EXISTS szintaxissal."""
    if _is_sqlite():
        # SQLite: nincs IF NOT EXISTS az ALTER TABLE-nél, PRAGMA table_info-val nézünk.
        cols = db.session.execute(db.text(f"PRAGMA table_info({table})")).fetchall()
        existing = {row[1] for row in cols}
        if col not in existing:
            db.session.execute(db.text(f"ALTER TABLE {table} ADD COLUMN {col} {col_type}"))
    else:
        db.session.execute(db.text(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {col} {col_type}"))

def init_db():
    """Adatbázis inicializálás – Alembic migrációval (verziókövetett séma).
    Ha az Alembic nem érhető el, fallback: db.create_all()."""
    with app.app_context():
        # Alembic migráció futtatása (verziókövetett adatbázis séma)
        try:
            from alembic.config import Config as AlembicConfig
            from alembic import command
            alembic_ini = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'alembic.ini')
            if os.path.exists(alembic_ini):
                alembic_cfg = AlembicConfig(alembic_ini)
                # Felülírjuk az adatbázis URL-t a Config-ból (környezeti változó)
                alembic_cfg.set_main_option('sqlalchemy.url', Config.SQLALCHEMY_DATABASE_URI or
                    os.environ.get('DATABASE_URL', 'postgresql://epub_user:epub_password@postgres:5432/epub_translator'))
                with app.app_context():
                    command.upgrade(alembic_cfg, "head")
                app_logger.info("✅ Adatbázis migráció sikeres (Alembic upgrade head)")
            else:
                db.create_all()
                app_logger.info("Adatbázis inicializálva (db.create_all – alembic.ini nem található)")
        except Exception as e:
            app_logger.warning(f"Alembic migráció sikertelen ({e}), fallback: db.create_all()")
            db.create_all()
        
        # Hiányzó oszlopok hozzáadása a users táblához (régebbi verziókból frissítve)
        try:
            for col, col_type in [
                ('address','VARCHAR(255)'),
                ('birth_date','VARCHAR(20)'),
                ('tax_id','VARCHAR(50)'),
                ('phone','VARCHAR(30)'),
                # DeepSeek Pro API + modell preferencia mezők (v11.0.69+)
                ('deepseek_api_key', "VARCHAR(255) DEFAULT ''"),
                ('preferred_model_source', "VARCHAR(20) DEFAULT 'local'"),
                ('preferred_model', "VARCHAR(100) DEFAULT ''"),
                # Sötét/világos téma preferencia (v11.0.69+, #10 fejlesztés)
                ('dark_mode', "BOOLEAN DEFAULT TRUE"),
                # Tegezés/magázás preferencia (v2.5.0+)
                ('formality', "VARCHAR(10) DEFAULT 'informal'"),
            ]:
                _ensure_column('users', col, col_type)
            db.session.commit()
        except Exception as e:
            db.session.rollback()
            app_logger.warning(f"Users tábla migráció figyelmeztetés: {e}")
        
        # Hiányzó oszlopok hozzáadása a translations táblához (v11.0.50+ mezők)
        try:
            for col, col_type in [
                ('current_stage', 'VARCHAR(30) DEFAULT \'pending\''),
                ('current_chapter', 'INTEGER DEFAULT 0'),
                ('total_chapters', 'INTEGER DEFAULT 0'),
                ('words_processed', 'INTEGER DEFAULT 0'),
                ('total_words', 'INTEGER DEFAULT 0'),
                ('nodes_translated', 'INTEGER DEFAULT 0'),
                ('nodes_failed', 'INTEGER DEFAULT 0'),
                ('first_pass_model', 'VARCHAR(100)'),
                ('second_pass_model', 'VARCHAR(100)'),
                # Fordítás leállítási kérés (v2.1.0+)
                ('stop_requested', 'BOOLEAN DEFAULT FALSE'),
                # Token/költség napló (v2.2.0+)
                ('input_tokens_used', 'INTEGER DEFAULT 0'),
                ('output_tokens_used', 'INTEGER DEFAULT 0'),
                ('cost_usd', 'DOUBLE PRECISION DEFAULT 0.0'),
                # Checkpoint/folytatás (v2.3.0+)
                ('checkpoint_data', 'TEXT'),
                ('last_checkpoint_at', 'TIMESTAMP'),
                # Könyvtár jóváhagyási állapot (v2.6.0+)
                ('library_status', "VARCHAR(20) DEFAULT 'none'")
            ]:
                _ensure_column('translations', col, col_type)
            db.session.commit()
        except Exception as e: db.session.rollback()
        # Új táblák létrehozása (pl. reading_history) – a db.create_all() csak
        # a hiányzó táblákat hozza létre, a meglévőket nem bántja.
        # Az Alembic migráció után is szükséges, mert az új modellek
        # nincsenek feltétlenül a migrációs szkriptekben.
        db.create_all()
        
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL, password_hash=generate_password_hash(Config.ADMIN_PASSWORD),
                        first_name='Admin', last_name='User', is_admin=True, tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin); db.session.commit()

        # Indítási önjavítás: egy friss worker indulásakor nincs élő fordítás-szál,
        # ezért a korábban megszakadt (pl. konténer újraindítás közben) és
        # "processing" státuszban ragadt sorokat visszaállítjuk "failed" állapotba,
        # hogy a felhasználó törölhesse vagy újraindíthassa őket.
        try:
            stuck = Translation.query.filter_by(status='processing').all()
            for st in stuck:
                # Ha van checkpoint, 'paused' (folytatható), különben 'failed'
                st.status = 'paused' if st.checkpoint_data else 'failed'
                st.current_stage = st.status
            if stuck:
                db.session.commit()
                app_logger.info(f"Önjavítás: {len(stuck)} beragadt 'processing' fordítás visszaállítva (paused/failed)")
        except Exception as stuck_err:
            db.session.rollback()
            app_logger.warning(f"Feldolgozás alatt álló fordítások visszaállítása nem sikerült: {stuck_err}")

with app.app_context():
    try: init_db()
    except Exception as e: app.logger.error(f"DB init error: {e}")

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)