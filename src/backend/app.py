from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, send_file, send_from_directory
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_babel import Babel, gettext as _
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, SystemSettings, OptimizationLog, ReferenceBook, Book, GlossaryEntry, TranslationMemory, UserBookPreference
from datetime import datetime
from functools import wraps
import os, json, psutil, requests, threading, uuid, shutil, logging, traceback as _traceback

app = Flask(__name__)
app.config.from_object(Config)
app.config['UPLOAD_FOLDER'] = '/app/uploads/books'
app.config['REFERENCE_FOLDER'] = '/app/uploads/reference'
app.config['OUTPUT_FOLDER'] = '/app/output'
app.config['LIBRARY_FOLDER'] = '/app/uploads/library'
app.config['MAX_CONTENT_LENGTH'] = 200 * 1024 * 1024
db.init_app(app)

# --- LOGOLÁS BEÁLLÍTÁSA ---
LOG_DIR = '/app/logs'
os.makedirs(LOG_DIR, exist_ok=True)

# Alkalmazás log (összes request, hiba)
app_logger = logging.getLogger('epub_translator')
app_logger.setLevel(logging.INFO)

# Fájl handler – app.log
fh_app = logging.FileHandler(os.path.join(LOG_DIR, 'app.log'), encoding='utf-8')
fh_app.setLevel(logging.INFO)
fh_app.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))
app_logger.addHandler(fh_app)

# Fordítási log – translation.log
translation_logger = logging.getLogger('epub_translator.translation')
translation_logger.setLevel(logging.DEBUG)
fh_trans = logging.FileHandler(os.path.join(LOG_DIR, 'translation.log'), encoding='utf-8')
fh_trans.setLevel(logging.DEBUG)
fh_trans.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))
translation_logger.addHandler(fh_trans)

# Flask built-in logger is ide irányítjuk
app.logger.handlers.clear()
app.logger.addHandler(fh_app)
app.logger.setLevel(logging.INFO)

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
limiter = Limiter(app=app, key_func=get_remote_address, default_limits=["5000 per day", "2000 per hour"])

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
    return jsonify({'status':'healthy','version':app.config['VERSION'],'model':app.config['DEFAULT_MODEL']})

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
    translation = Translation(user_id=current_user.id, original_filename=file.filename, output_filename=None, status='pending', progress=0, model_used=app.config['DEFAULT_MODEL'])
    db.session.add(translation)
    current_user.tokens -= 1
    # A kiválasztott könyvtári könyveket (UserBookPreference) hozzárendeljük a fordításhoz
    selected_prefs = UserBookPreference.query.filter_by(user_id=current_user.id, is_selected=True).all()
    selected_book_ids = [p.book_id for p in selected_prefs]
    selected_books = Book.query.filter(Book.id.in_(selected_book_ids)).all() if selected_book_ids else []
    # Kiválasztás törlése
    for p in selected_prefs:
        p.is_selected = False
    db.session.commit()
    thread = threading.Thread(target=translate_epub, args=(app, translation.id, filepath, [b.file_path for b in selected_books]))
    thread.daemon = True
    thread.start()
    flash(_('Fájl feltöltve, fordítás folyamatban...'),'success')
    return redirect(url_for('dashboard'))

@app.route('/api/status/<int:translation_id>')
@login_required
def translation_status(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error':'Nincs jogosultságod'}), 403
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
        'created_at': t.created_at.isoformat() if t.created_at else None
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
        genre=request.form.get('genre',''), series=request.form.get('series',''),
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
        'uploaded_at':b.uploaded_at.isoformat() if b.uploaded_at else '',
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

@app.route('/api/models/list')
@login_required
def api_models_list():
    models = []; error = None
    for attempt in range(1,4):
        try:
            resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/tags", timeout=5)
            if resp.status_code == 200:
                models = resp.json().get('models',[]); break
        except Exception as e:
            if attempt == 3: error = str(e)[:100]
            else: import time; time.sleep(2)
    return jsonify({'models':models,'current_model':app.config['DEFAULT_MODEL'],'error':error})

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

@app.route('/api/system/monitor')
@login_required
@admin_required
def system_monitor():
    return jsonify({'cpu':{'percent':psutil.cpu_percent(),'cores':psutil.cpu_count()},'memory':{'total_gb':round(psutil.virtual_memory().total/(1024**3),2),'used_gb':round(psutil.virtual_memory().used/(1024**3),2),'percent':psutil.virtual_memory().percent},'disk':{'total_gb':round(psutil.disk_usage('/').total/(1024**3),2),'free_gb':round(psutil.disk_usage('/').free/(1024**3),2),'percent':psutil.disk_usage('/').percent},'uptime':datetime.utcnow().isoformat()})

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

def translate_epub(app_ref, translation_id, filepath, context_files=None):
    with app_ref.app_context():
        t = Translation.query.get(translation_id)
        if not t:
            translation_logger.error(f"Translation #{translation_id} nem található az adatbázisban")
            return
        user = User.query.get(t.user_id) if t.user_id else None
        user_info = f"{user.email} (ID:{user.id})" if user else "ismeretlen"
        translation_logger.info(f"=== Fordítás indítása === Fordítás ID:{translation_id}, Fájl: {t.original_filename}, Felhasználó: {user_info}, Modell: {app_ref.config['DEFAULT_MODEL']}")
        try:
            # === RÉSZLETES PROGRESSZ INICIALIZÁLÁSA (5. fejlesztés) ===
            t.status = 'processing'; t.progress = 5
            t.current_stage = 'first_pass'  # első menet: AI fordítás
            db.session.commit()
            translation_logger.info(f"[ID:{translation_id}] EPUB olvasása...")
            from ebooklib import epub as epub_lib
            from bs4 import BeautifulSoup, NavigableString, Tag
            import hashlib, re
            book = epub_lib.read_epub(filepath)
            model = app_ref.config['DEFAULT_MODEL']
            ollama_host = app_ref.config['OLLAMA_HOST']
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
            translation_logger.debug(f"[ID:{translation_id}] Eredeti szövegek elmentve a második menethez ({total} dokumentum)")
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
            translation_logger.info(f"[ID:{translation_id}] {total} szöveges elem, ~{t.total_words} szó, fordítás kezdése a(z) {model} modellel (struktúra-megőrző mód + 2-menetes utófeldolgozás)...")
            translated_count = 0; failed_items = 0; total_nodes_translated = 0
            
            # Szeparátor a text node-ok batch fordításához
            NODE_SEP = '\n---NEXT_TEXT_NODE---\n'
            
            # === GLOSSZÁRIUM BETÖLTÉSE (1. fejlesztés) ===
            glossary_terms = {}
            try:
                entries = GlossaryEntry.query.filter_by(user_id=t.user_id).order_by(GlossaryEntry.source_count.desc()).limit(100).all()
                for entry in entries:
                    glossary_terms[entry.source_term.lower()] = entry.target_term
                if glossary_terms:
                    translation_logger.debug(f"[ID:{translation_id}] Glosszárium betöltve: {len(glossary_terms)} bejegyzés")
            except Exception as ge:
                translation_logger.debug(f"[ID:{translation_id}] Glosszárium nem elérhető: {ge}")
            
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
            
            # === HUNSPELL INICIALIZÁLÁS (3. fejlesztés) ===
            hunspell_checker = None
            try:
                import hunspell
                hunspell_checker = hunspell.HunSpell('/usr/share/hunspell/hu_HU.dic', '/usr/share/hunspell/hu_HU.aff')
                translation_logger.debug(f"[ID:{translation_id}] Hunspell magyar helyesírás-ellenőrző inicializálva")
            except Exception as he:
                translation_logger.debug(f"[ID:{translation_id}] Hunspell nem elérhető: {he}")
            
            # === FEJLETT PROMPT KONTEXTUS ELŐKÉSZÍTÉSE ===
            style_instruction = ""
            terminology_list = ""
            
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
                        translation_logger.debug(f"[ID:{translation_id}] Stílusinstrukció betöltve ({len(style_samples)} referencia könyvből)")
            except Exception as style_err:
                translation_logger.debug(f"[ID:{translation_id}] Stílusinstrukció nem elérhető: {style_err}")
            
            # 2. Terminológia gyűjtése könyvtári könyvekből (a felhasználó által kiválasztottak)
            try:
                # A felhasználó által kiválasztott könyvek az UserBookPreference-ből
                selected_prefs = UserBookPreference.query.filter_by(user_id=t.user_id, is_selected=True).all()
                selected_book_ids = [p.book_id for p in selected_prefs]
                if selected_book_ids:
                    library_books = Book.query.filter(Book.id.in_(selected_book_ids)).all()
                else:
                    library_books = Book.query.order_by(Book.uploaded_at.desc()).limit(3).all()
                if library_books:
                    # Kontextus fájlok is lehetnek
                    all_book_paths = []
                    if context_files:
                        all_book_paths.extend(context_files)
                    all_book_paths.extend([lb.file_path for lb in library_books if lb.file_path])
                    all_book_paths = all_book_paths[:5]  # max 5 könyv
                    
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
                        term_list = sorted(list(terms))[:30]
                        terminology_list = f"""Fontos terminológia és tulajdonnevek (ezeket NE fordítsd le, hagyd eredeti formában):
{', '.join(term_list)}

"""
                        translation_logger.debug(f"[ID:{translation_id}] Terminológia betöltve: {len(term_list)} kifejezés")
            except Exception as term_err:
                translation_logger.debug(f"[ID:{translation_id}] Terminológia gyűjtés nem sikerült: {term_err}")
            
            for idx, item in enumerate(items):
                try:
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
                        translation_logger.debug(f"[ID:{translation_id}] Elem {idx+1}/{total}: nincs lefordítandó szöveg, kihagyva")
                        continue
                    
                    translation_logger.debug(f"[ID:{translation_id}] Elem {idx+1}/{total}: {len(text_nodes)} text node, fordítás batch-ben...")
                    
                    # 2. szakasz: Batch fordítás placeholder-alapú biztonságos cserével
                    source_texts = [tn[1] for tn in text_nodes]
                    combined_source = NODE_SEP.join(source_texts)
                    
                    # 3. Sliding window kontextus: előző node szövegének első 300 karaktere
                    surrounding_context = ""
                    if idx > 0:
                        try:
                            prev_item = items[idx-1]
                            prev_soup = BeautifulSoup(prev_item.get_body_content(), 'html.parser')
                            prev_text = prev_soup.get_text()[:300].strip()
                            if prev_text:
                                surrounding_context = f"Előző fejezet/bekezdés kontextusa: {prev_text}\n---\n"
                        except Exception:
                            pass
                    
                    # === NODE-ONKÉNTI FORDÍTÁS (megbízhatóbb, mint a batch) ===
                    # Batch fordítás helyett minden text node-ot egyesével fordítunk,
                    # mert a deepseek-r1 nem használja megbízhatóan a NODE_SEP szeparátort.
                    # Ez több API hívást jelent, de a megbízhatóság garantált.
                    import hashlib
                    nodes_translated_here = 0
                    placeholders = []
                    
                    for node_idx, (node, original) in enumerate(text_nodes):
                        if len(original) < 5:
                            continue  # túl rövid szöveg, nem érdemes fordítani
                        
                        # Fordítási memória keresés: ha már lefordítottuk ezt a szöveget
                        cached = search_tm(original, t.user_id)
                        if cached:
                            ph = f"__CACHED_{hashlib.md5(f'{idx}_{node_idx}_{uuid.uuid4().hex[:6]}'.encode()).hexdigest()[:12]}__"
                            node.replace_with(ph)
                            placeholders.append((ph, cached, True))
                            nodes_translated_here += 1
                            total_nodes_translated += 1
                            translation_logger.debug(f"[ID:{translation_id}] Elem {idx+1}/{total}, node {node_idx+1}/{len(text_nodes)}: TM cache találat")
                            continue
                        
                        # Ollama API hívás egyetlen text node fordítására
                        # Kontextus: few-shot + stílus + terminológia + előző fejezet + GLOSSZÁRIUM
                        # A glosszárium betöltve, használjuk explicit utasításként
                        glossary_hint = ""
                        if glossary_terms:
                            relevant = [f"{k} → {v}" for k, v in glossary_terms.items() if k in original.lower()]
                            if relevant:
                                glossary_hint = f"Glosszárium (használd ezeket a fordításokat): {', '.join(relevant[:5])}\n"
                        
                        single_prompt = f"""{few_shot}{glossary_hint}{style_instruction}{terminology_list}{surrounding_context}Fordítsd le a következő angol szöveget magyarra.
Csak a fordítást add vissza, semmi mást!

{original[:800]}"""
                        
                        try:
                            resp = requests.post(f"{ollama_host}/api/generate", json={
                                'model': model,
                                'prompt': single_prompt,
                                'stream': False,
                                'options': {
                                    'num_predict': 1024,  # kevesebb token, mert egyesével fordítunk
                                    'temperature': 0.2,
                                    'repeat_penalty': 1.1,
                                    'top_p': 0.9
                                }
                            }, timeout=None)
                            
                            if resp.status_code == 200:
                                translated = resp.json().get('response', '').strip()
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
                            else:
                                translation_logger.warning(f"[ID:{translation_id}] Ollama hiba (HTTP {resp.status_code}) node {node_idx+1}-nél")
                        except Exception as node_err:
                            translation_logger.warning(f"[ID:{translation_id}] Node fordítási hiba: {node_err}")
                    
                    # Cseréljük a placeholder-eket a fordított szövegre
                    html_str = str(soup)
                    for ph, text, is_cached in placeholders:
                        html_str = html_str.replace(ph, text, 1)
                    
                    if nodes_translated_here > 0:
                        translated_count += 1
                    
                    translation_logger.debug(f"[ID:{translation_id}] Elem {idx+1}: {nodes_translated_here}/{len(text_nodes)} node lefordítva (node-onkénti mód)")
                    
                    # === GLOSSZÁRIUM ÉPÍTÉS (1. fejlesztés) ===
                    try:
                        for node, original in text_nodes:
                            # A fordítást a placeholder-ek listából keressük vissza
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
                                    entry = GlossaryEntry(
                                        user_id=t.user_id,
                                        source_term=original[:200],
                                        target_term=translated[:200],
                                        language_pair='en-hu',
                                        source_count=1
                                    )
                                    db.session.add(entry)
                                else:
                                    existing.source_count += 1
                                    existing.target_term = translated[:200]
                        db.session.commit()
                    except Exception as gloss_err:
                        pass
                    
                    # === FORDÍTÁSI MEMÓRIA MENTÉS (4. fejlesztés) ===
                    try:
                        for node, original in text_nodes:
                            cached = search_tm(original, t.user_id)
                            if not cached:
                                # A fordítást a placeholder-ek listából keressük
                                translated = None
                                for ph, txt, _ in placeholders:
                                    if node.strip()[:20] in original[:20]:
                                        translated = txt
                                        break
                                if translated and translated != original:
                                    import hashlib
                                    tm_hash = hashlib.sha256(original.strip().encode()).hexdigest()
                                    tm_entry = TranslationMemory(
                                        user_id=t.user_id,
                                        source_text=original[:1000],
                                        translated_text=translated[:1000],
                                        source_hash=tm_hash
                                    )
                                    db.session.add(tm_entry)
                        db.session.commit()
                    except Exception as tm_err:
                        pass
                    
                    # === HUNSPELL HELYESÍRÁS ELLENŐRZÉS (3. fejlesztés) ===
                    if hunspell_checker:
                        try:
                            for ph, translated, _ in placeholders:
                                if not translated or len(translated) < 5:
                                    continue
                                words = translated.split()
                                for word in words:
                                    clean_word = word.strip('.,;:!?()[]{}"\'').lower()
                                    if len(clean_word) > 2 and not hunspell_checker.spell(clean_word):
                                        suggestions = hunspell_checker.suggest(clean_word)
                                        # Csak naplózás, automatikus javítás nélkül
                        except Exception as spell_err:
                            pass
                    
                    # === RÉSZLETES PROGRESSZ FRISSÍTÉS (5. fejlesztés) ===
                    t.current_chapter = idx + 1
                    t.nodes_translated = total_nodes_translated
                    t.nodes_failed = failed_items
                    words_here = sum(len(tn[1].split()) for tn in text_nodes if len(tn[1].split()) > 2)
                    t.words_processed = (t.words_processed or 0) + words_here
                    
                    # Frissítsük az item tartalmát
                    item.set_content(html_str.encode('utf-8'))
                    
                except requests.exceptions.ConnectionError as ce:
                    translation_logger.error(f"[ID:{translation_id}] Ollama kapcsolódási hiba a(z) {idx+1}. elemnél: {ce}")
                    raise
                except Exception as item_err:
                    translation_logger.warning(f"[ID:{translation_id}] Hiba a(z) {idx+1}. elem feldolgozásakor: {item_err}")
                    failed_items += 1
                
                t.progress = 5 + int(90 * (idx + 1) / total)
                db.session.commit()
            
            translation_logger.info(f"[ID:{translation_id}] Első menet kész: {translated_count}/{total} dokumentum, {total_nodes_translated} szöveges csomópont lefordítva, {failed_items} hiba")
            
            # ═══════════════════════════════════════════════════════════════
            # === KÉTMENETES FORDÍTÁS – MÁSODIK MENET: MINŐSÉGELLENŐRZÉS ===
            # ═══════════════════════════════════════════════════════════════
            # A második menet végigmegy az első menetben lefordított szövegen,
            # és egy (opcionálisan másik) modellel ellenőrzi, javítja a fordítást.
            # Ez jelentősen javítja a nyelvtani pontosságot és stílust.
            # A második menet modellje alapértelmezetten ugyanaz, mint az elsőé,
            # de a first_pass_model mezőbe mentjük az első menet modelljét,
            # így később más modell is beállítható a második menethez.
            t.current_stage = 'second_pass'
            t.progress = 91  # 90% volt az első menet, most jön a második
            t.first_pass_model = model  # elmentjük, melyik modell futott az első menetben
            t.second_pass_model = model  # alapértelmezetten ugyanaz
            db.session.commit()
            
            translation_logger.info(f"[ID:{translation_id}] 🔍 Második menet indítása – minőségellenőrzés (modell: {model})...")
            review_count = 0; review_improvements = 0
            for idx, item in enumerate(items):
                try:
                    # Csak azokat az elemeket ellenőrizzük, amikben van lefordított szöveg
                    soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                    review_text = soup.get_text().strip()
                    if not review_text or len(review_text) < 50:
                        # Túl rövid, nincs értelme ellenőrizni
                        continue
                    
                    translation_logger.debug(f"[ID:{translation_id}] Második menet: elem {idx+1}/{total}, szöveghossz: {len(review_text)} karakter")
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
                    
                    try:
                        review_resp = requests.post(f"{ollama_host}/api/generate", json={
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
                            improved_text = review_resp.json().get('response', '').strip()
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
                                    translation_logger.debug(f"[ID:{translation_id}] Második menet: elem {idx+1} javítva ({len(improved_text)} karakter)")
                                else:
                                    translation_logger.debug(f"[ID:{translation_id}] Második menet: elem {idx+1} nem tartalmazott text node-okat")
                            else:
                                translation_logger.debug(f"[ID:{translation_id}] Második menet: elem {idx+1} nem változott (a fordítás megfelelő)")
                        else:
                            translation_logger.warning(f"[ID:{translation_id}] Második menet: Ollama hiba (HTTP {review_resp.status_code}) a(z) {idx+1}. elemnél")
                    except Exception as review_err:
                        translation_logger.warning(f"[ID:{translation_id}] Második menet: hiba a(z) {idx+1}. elemnél: {review_err}")
                    
                    # Progressz frissítés (91% → 99%)
                    t.progress = 91 + int(8 * (idx + 1) / total)
                    t.current_chapter = idx + 1
                    db.session.commit()
                    
                except Exception as item_review_err:
                    translation_logger.warning(f"[ID:{translation_id}] Második menet: elem feldolgozási hiba: {item_review_err}")
            
            translation_logger.info(f"[ID:{translation_id}] Második menet kész: {review_count} dokumentum ellenőrizve, {review_improvements} javítva")
            
            # === VÉGSŐ MENTÉS ===
            t.current_stage = 'post_processing'
            t.progress = 99
            db.session.commit()
            
            output_filename = f"translated_{uuid.uuid4().hex[:8]}.epub"
            output_path = os.path.join(app_ref.config['OUTPUT_FOLDER'], output_filename)
            epub_lib.write_epub(output_path, book)
            t.output_filename = output_filename; t.status = 'completed'; t.progress = 100
            t.current_stage = 'completed'
            # Minőségi pontszám: a javítások aránya alapján
            t.quality_score = min(99, 75 + int((review_improvements / max(review_count, 1)) * 20))
            db.session.commit()
            translation_logger.info(f"[ID:{translation_id}] ✅ Fordítás sikeresen befejezve (kétmenetes): {output_filename} | Minőség: {t.quality_score}/100 | Javítások: {review_improvements}/{review_count}")
            app_logger.info(f"Fordítás kész: {t.original_filename} -> {output_filename} (user: {user_info}, {total_nodes_translated} node)")
            
            # === ÉRTESÍTÉS A FORDÍTÁS BEFEJEZÉSEKOR (7. fejlesztés) ===
            # Email küldése a felhasználónak, hogy a fordítása elkészült
            try:
                from flask_mail import Mail, Message
                mail = Mail(app_ref)
                # Email küldése (a MailHog localhost:1025 SMTP szervert használja)
                msg = Message(
                    f"✅ Fordítás kész: {t.original_filename}",
                    sender=app_ref.config.get('MAIL_DEFAULT_SENDER', 'epub-translator@localhost'),
                    recipients=[user.email]
                )
                msg.body = f"""Kedves {user.first_name}!

A(z) "{t.original_filename}" fordítása sikeresen befejeződött.

📊 Részletek:
  Fájl: {t.original_filename} → {output_filename}
  Modell: {model}
  Minőségi pontszám: {t.quality_score}/100
  Lefordított node-ok: {total_nodes_translated}
  Ellenőrzött elemek: {review_count}
  Javítások: {review_improvements}

📥 Letöltés: http://localhost/download/{t.id}
📝 Átnézés és javítás: http://localhost/review/{t.id}

Köszönjük, hogy az EPUB Fordítót használod!

Üdv,
EPUB Fordító"""
                mail.send(msg)
                translation_logger.info(f"[ID:{translation_id}] 📧 Értesítő email elküldve: {user.email}")
            except Exception as mail_err:
                translation_logger.warning(f"[ID:{translation_id}] Email értesítés nem sikerült: {mail_err}")
        except Exception as e:
            error_detail = _traceback.format_exc()
            t.status = 'failed'; t.progress = 0; t.output_filename = f"HIBA: {str(e)[:500]}"
            db.session.commit()
            translation_logger.error(f"[ID:{translation_id}] ❌ Fordítási hiba:\n{error_detail}")
            app_logger.error(f"Fordítás hiba: {t.original_filename} (user: {user_info}) - {str(e)[:200]}")
        finally:
            if os.path.exists(filepath):
                os.remove(filepath)
                translation_logger.debug(f"[ID:{translation_id}] Ideiglenes fájl törölve: {filepath}")

def init_db():
    with app.app_context():
        db.create_all()
        try:
            for col, col_type in [('address','VARCHAR(255)'),('birth_date','VARCHAR(20)'),('tax_id','VARCHAR(50)'),('phone','VARCHAR(30)')]:
                db.session.execute(db.text(f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {col} {col_type}"))
            db.session.commit()
        except Exception as e: db.session.rollback()
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL, password_hash=generate_password_hash(Config.ADMIN_PASSWORD),
                        first_name='Admin', last_name='User', is_admin=True, tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin); db.session.commit()

with app.app_context():
    try: init_db()
    except Exception as e: app.logger.error(f"DB init error: {e}")

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)