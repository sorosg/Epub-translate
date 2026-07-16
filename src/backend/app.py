from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, send_file, send_from_directory
from flask_login import LoginManager, login_user, login_required, logout_user, current_user
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_babel import Babel, gettext as _
from werkzeug.utils import secure_filename
from werkzeug.security import generate_password_hash, check_password_hash
from config import Config
from models import db, User, Translation, SystemSettings, OptimizationLog, ReferenceBook
from datetime import datetime
from functools import wraps
import os, json, psutil, requests, threading, uuid, shutil

app = Flask(__name__)
app.config.from_object(Config)
app.config['UPLOAD_FOLDER'] = '/app/uploads/books'
app.config['REFERENCE_FOLDER'] = '/app/uploads/reference'
app.config['OUTPUT_FOLDER'] = '/app/output'
app.config['MAX_CONTENT_LENGTH'] = 200 * 1024 * 1024  # 200MB max
db.init_app(app)
def get_locale():
    return 'hu'

babel = Babel(app, locale_selector=get_locale)

os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(app.config['REFERENCE_FOLDER'], exist_ok=True)
os.makedirs(app.config['OUTPUT_FOLDER'], exist_ok=True)

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'
limiter = Limiter(app=app, key_func=get_remote_address, default_limits=["500 per day", "100 per hour"])

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
        'status': 'healthy',
        'version': app.config['VERSION'],
        'codename': app.config['CODENAME'],
        'release_date': app.config['RELEASE_DATE'],
        'model': app.config['DEFAULT_MODEL'],
        'memory': f"{psutil.virtual_memory().percent}%",
        'cpu': f"{psutil.cpu_percent()}%"
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
            email = request.form.get('email', '').strip()
            password = request.form.get('password', '')
            user = User.query.filter_by(email=email).first()
            if user and user.password_hash and check_password_hash(user.password_hash, password):
                login_user(user)
                return redirect(url_for('admin') if user.is_admin else url_for('dashboard'))
            flash(_('Hibás email vagy jelszó!'), 'error')
        except Exception as e:
            app.logger.error(f"Login error: {_traceback.format_exc()}")
            flash(_(f'Bejelentkezési hiba: {str(e)[:100]}'), 'error')
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
    return render_template('dashboard.html', user=current_user, translations=translations, ref_books=ref_books, Config=Config)

@app.route('/upload', methods=['POST'])
@login_required
def upload_epub():
    if 'file' not in request.files:
        flash(_('Nincs fájl kiválasztva!'), 'error')
        return redirect(url_for('dashboard'))
    file = request.files['file']
    if file.filename == '':
        flash(_('Nincs fájl kiválasztva!'), 'error')
        return redirect(url_for('dashboard'))
    if not allowed_file(file.filename):
        flash(_('Csak EPUB fájlok tölthetők fel!'), 'error')
        return redirect(url_for('dashboard'))
    if current_user.tokens <= 0:
        flash(_('Nincs elég tokened a fordításhoz!'), 'error')
        return redirect(url_for('dashboard'))
    
    filename = f"{uuid.uuid4().hex}_{secure_filename(file.filename)}"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)
    
    translation = Translation(
        user_id=current_user.id,
        original_filename=file.filename,
        output_filename=None,
        status='pending',
        progress=0,
        model_used=app.config['DEFAULT_MODEL']
    )
    db.session.add(translation)
    current_user.tokens -= 1
    db.session.commit()
    
    thread = threading.Thread(target=translate_epub, args=(app, translation.id, filepath))
    thread.daemon = True
    thread.start()
    
    flash(_('Fájl feltöltve, fordítás folyamatban...'), 'success')
    return redirect(url_for('dashboard'))

@app.route('/api/status/<int:translation_id>')
@login_required
def translation_status(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        return jsonify({'error': 'Nincs jogosultságod'}), 403
    return jsonify({'id': t.id, 'status': t.status, 'progress': t.progress, 'original_filename': t.original_filename})

@app.route('/api/model/status')
@login_required
@admin_required
def model_status():
    try:
        resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/ps", timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            models = data.get('models', [])
            result = []
            for m in models:
                model_name = m.get('name', '')
                details = m.get('details', {})
                size = m.get('size', 0)
                digest = m.get('digest', '')
                result.append({
                    'name': model_name,
                    'size_gb': round(size / (1024**3), 2) if size else 0,
                    'digest': digest,
                    'status': m.get('status', ''),
                    'details': details
                })
            return jsonify({'models': result})
        return jsonify({'error': 'Nem érhető el az Ollama'}), resp.status_code
    except Exception as e:
        return jsonify({'error': str(e)[:100]}), 500

@app.route('/download/<int:translation_id>')
@login_required
def download_translation(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        flash(_('Nincs jogosultságod'), 'error')
        return redirect(url_for('dashboard'))
    if t.status != 'completed' or not t.output_filename:
        flash(_('A fordítás még nem készült el'), 'error')
        return redirect(url_for('dashboard'))
    output_path = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
    if not os.path.exists(output_path):
        flash(_('A fájl nem található'), 'error')
        return redirect(url_for('dashboard'))
    return send_file(output_path, as_attachment=True, download_name=f"forditott_{t.original_filename}")

@app.route('/delete/<int:translation_id>', methods=['POST'])
@login_required
def delete_translation(translation_id):
    t = Translation.query.get_or_404(translation_id)
    if t.user_id != current_user.id:
        flash(_('Nincs jogosultságod'), 'error')
        return redirect(url_for('dashboard'))
    if t.output_filename:
        out = os.path.join(app.config['OUTPUT_FOLDER'], t.output_filename)
        if os.path.exists(out): os.remove(out)
    db.session.delete(t)
    db.session.commit()
    flash(_('Fordítás törölve'), 'success')
    return redirect(url_for('dashboard'))

@app.route('/reference/upload', methods=['POST'])
@login_required
def upload_reference():
    if 'file' not in request.files:
        flash(_('Nincs fájl kiválasztva!'), 'error')
        return redirect(url_for('dashboard'))
    file = request.files['file']
    if file.filename == '' or not allowed_file(file.filename):
        flash(_('Csak EPUB fájlok tölthetők fel!'), 'error')
        return redirect(url_for('dashboard'))
    title = request.form.get('title', file.filename.rsplit('.', 1)[0])
    filename = f"ref_{uuid.uuid4().hex}_{secure_filename(file.filename)}"
    filepath = os.path.join(app.config['REFERENCE_FOLDER'], filename)
    file.save(filepath)
    
    ref = ReferenceBook(
        user_id=current_user.id,
        filename=file.filename,
        title=title,
        language=request.form.get('language', 'hu'),
        file_path=filepath
    )
    db.session.add(ref)
    db.session.commit()
    flash(_('Mintakönyv feltöltve!'), 'success')
    return redirect(url_for('dashboard'))

@app.route('/reference/delete/<int:ref_id>', methods=['POST'])
@login_required
def delete_reference(ref_id):
    ref = ReferenceBook.query.get_or_404(ref_id)
    if ref.user_id != current_user.id:
        flash(_('Nincs jogosultságod'), 'error')
        return redirect(url_for('dashboard'))
    if ref.file_path and os.path.exists(ref.file_path):
        os.remove(ref.file_path)
    db.session.delete(ref)
    db.session.commit()
    flash(_('Mintakönyv törölve'), 'success')
    return redirect(url_for('dashboard'))

@app.route('/admin')
@login_required
@admin_required
def admin():
    sys_info = {
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent,
        'memory_used_gb': round(psutil.virtual_memory().used / (1024**3), 2),
        'memory_total_gb': round(psutil.virtual_memory().total / (1024**3), 2),
        'disk_percent': psutil.disk_usage('/').percent,
        'disk_free_gb': round(psutil.disk_usage('/').free / (1024**3), 2)
    }
    return render_template('admin.html', sys_info=sys_info,
                          current_model=app.config['DEFAULT_MODEL'],
                          translations_count=Translation.query.count(),
                          users_count=User.query.count())

@app.route('/api/models/pull', methods=['POST'])
@login_required
@admin_required
def api_models_pull():
    data = request.get_json()
    model_name = data.get('model', '').strip()
    if not model_name:
        return jsonify({'error': 'Modell név szükséges'}), 400
    try:
        resp = requests.post(f"{app.config['OLLAMA_HOST']}/api/pull", json={
            'name': model_name, 'stream': False
        }, timeout=5)
        if resp.status_code == 200:
            return jsonify({'success': True, 'message': f'Modell letöltés elindítva: {model_name}'})
        return jsonify({'error': f'Ollama API hiba: {resp.status_code}'}), resp.status_code
    except Exception as e:
        return jsonify({'error': f'Nem sikerült elindítani a letöltést: {str(e)[:100]}'}), 500

@app.route('/api/models/list')
@login_required
def api_models_list():
    models = []
    error = None
    for attempt in range(1, 4):
        try:
            resp = requests.get(f"{app.config['OLLAMA_HOST']}/api/tags", timeout=5)
            if resp.status_code == 200:
                models = resp.json().get('models', [])
                break
        except Exception as e:
            if attempt == 3:
                error = str(e)[:100]
            else:
                import time
                time.sleep(2)
    return jsonify({'models': models, 'current_model': app.config['DEFAULT_MODEL'], 'error': error})

@app.route('/admin/users')
@login_required
@admin_required
def admin_users():
    users = User.query.order_by(User.created_at.desc()).all()
    return render_template('users.html', users=users)

@app.route('/admin/users/add', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_users_add():
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '').strip()
        tokens = request.form.get('tokens', '5').strip()
        if not email or not password:
            flash(_('Az email és a jelszó kötelező!'), 'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=False)
        if User.query.filter_by(email=email).first():
            flash(_('Ez az email cím már használatban van!'), 'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=False)
        user = User(
            username=email.split('@')[0], email=email,
            password_hash=generate_password_hash(password),
            first_name=request.form.get('first_name', '').strip(),
            last_name=request.form.get('last_name', '').strip(),
            address=request.form.get('address', '').strip(),
            birth_date=request.form.get('birth_date', '').strip(),
            tax_id=request.form.get('tax_id', '').strip(),
            phone=request.form.get('phone', '').strip(),
            tokens=int(tokens) if tokens.isdigit() else 5,
            is_admin=request.form.get('is_admin') == '1'
        )
        db.session.add(user)
        db.session.commit()
        flash(_('Felhasználó létrehozva!'), 'success')
        return redirect(url_for('admin_users'))
    return render_template('users_form.html', user_data={}, edit_mode=False)

@app.route('/admin/users/edit/<int:user_id>', methods=['GET', 'POST'])
@login_required
@admin_required
def admin_users_edit(user_id):
    user = User.query.get_or_404(user_id)
    if request.method == 'POST':
        email = request.form.get('email', '').strip()
        password = request.form.get('password', '').strip()
        tokens = request.form.get('tokens', str(user.tokens)).strip()
        existing = User.query.filter_by(email=email).first()
        if existing and existing.id != user.id:
            flash(_('Ez az email cím már használatban van!'), 'error')
            return render_template('users_form.html', user_data=request.form, edit_mode=True, user=user)
        user.email = email
        user.first_name = request.form.get('first_name', '').strip()
        user.last_name = request.form.get('last_name', '').strip()
        user.address = request.form.get('address', '').strip()
        user.birth_date = request.form.get('birth_date', '').strip()
        user.tax_id = request.form.get('tax_id', '').strip()
        user.phone = request.form.get('phone', '').strip()
        user.tokens = int(tokens) if tokens.isdigit() else user.tokens
        user.is_admin = request.form.get('is_admin') == '1'
        if password:
            user.password_hash = generate_password_hash(password)
        db.session.commit()
        flash(_('Felhasználó módosítva!'), 'success')
        return redirect(url_for('admin_users'))
    return render_template('users_form.html', user_data={}, edit_mode=True, user=user)

@app.route('/admin/users/delete/<int:user_id>', methods=['POST'])
@login_required
@admin_required
def admin_users_delete(user_id):
    if user_id == current_user.id:
        flash(_('Saját magadat nem törölheted!'), 'error')
        return redirect(url_for('admin_users'))
    user = User.query.get_or_404(user_id)
    Translation.query.filter_by(user_id=user.id).delete()
    db.session.delete(user)
    db.session.commit()
    flash(_('Felhasználó törölve!'), 'success')
    return redirect(url_for('admin_users'))

@app.route('/api/models/switch', methods=['POST'])
@login_required
@admin_required
def switch_model():
    data = request.get_json()
    model_name = data.get('model')
    if not model_name:
        return jsonify({'error': 'Modell név szükséges'}), 400
    app.config['DEFAULT_MODEL'] = model_name
    log = OptimizationLog(model=model_name, action='switch', details=json.dumps({'switched_by': current_user.email}), created_at=datetime.utcnow())
    db.session.add(log); db.session.commit()
    return jsonify({'success': True, 'message': f'Modell átváltva: {model_name}'})

@app.route('/admin/update')
@login_required
@admin_required
def admin_update():
    return render_template('update.html', current_version=app.config['VERSION'])

@app.route('/api/update/check')
@login_required
@admin_required
def api_update_check():
    for attempt in range(1, 4):
        try:
            resp = requests.get('https://api.github.com/repos/sorosg/Epub-translate/releases/latest',
                               headers={'Accept': 'application/vnd.github.v3+json'}, timeout=30, verify=True)
            if resp.status_code == 200:
                data = resp.json()
                remote_version = data.get('tag_name', '').lstrip('v')
                has_update = remote_version > app.config['VERSION']
                return jsonify({
                    'remote_version': remote_version or 'ismeretlen',
                    'current': app.config['VERSION'],
                    'has_update': has_update,
                    'release_url': data.get('html_url', ''),
                    'release_notes': (data.get('body', '') or '')[:500]
                })
            return jsonify({'error': f'GitHub API hiba: {resp.status_code}'}), resp.status_code
        except requests.exceptions.SSLError:
            # SSL hiba esetén próbáljuk verify=False-szal
            try:
                import urllib3
                urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
                resp = requests.get('https://api.github.com/repos/sorosg/Epub-translate/releases/latest',
                                   headers={'Accept': 'application/vnd.github.v3+json'}, timeout=30, verify=False)
                if resp.status_code == 200:
                    data = resp.json()
                    remote_version = data.get('tag_name', '').lstrip('v')
                    has_update = remote_version > app.config['VERSION']
                    return jsonify({
                        'remote_version': remote_version or 'ismeretlen',
                        'current': app.config['VERSION'],
                        'has_update': has_update,
                        'release_url': data.get('html_url', ''),
                        'release_notes': (data.get('body', '') or '')[:500]
                    })
            except:
                pass
            if attempt == 3:
                return jsonify({
                    'error': 'SSL tanúsítvány hiba. A konténer nem éri el a GitHub API-t.',
                    'current': app.config['VERSION'],
                    'has_update': False
                })
        except Exception as e:
            if attempt == 3:
                return jsonify({
                    'error': f'Nem sikerült ellenőrizni a frissítéseket: {str(e)[:100]}',
                    'current': app.config['VERSION'],
                    'has_update': False
                })
            import time
            time.sleep(3)

@app.route('/api/update/run', methods=['POST'])
@login_required
@admin_required
def api_update_run():
    import subprocess
    try:
        result = subprocess.run(['bash', '/app/../scripts/update.sh'], capture_output=True, text=True, timeout=600)
        log = OptimizationLog(model='system', action='update', 
                             details=json.dumps({'output': result.stdout[-500:], 'returncode': result.returncode}),
                             created_at=datetime.utcnow())
        db.session.add(log); db.session.commit()
        return jsonify({'success': result.returncode == 0, 'output': result.stdout[-500:]})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)[:200]}), 500

@app.route('/api/system/monitor')
@login_required
@admin_required
def system_monitor():
    return jsonify({
        'cpu': {'percent': psutil.cpu_percent(), 'cores': psutil.cpu_count()},
        'memory': {'total_gb': round(psutil.virtual_memory().total/(1024**3),2), 'used_gb': round(psutil.virtual_memory().used/(1024**3),2), 'percent': psutil.virtual_memory().percent},
        'disk': {'total_gb': round(psutil.disk_usage('/').total/(1024**3),2), 'free_gb': round(psutil.disk_usage('/').free/(1024**3),2), 'percent': psutil.disk_usage('/').percent},
        'uptime': datetime.utcnow().isoformat()
    })

def translate_epub(app_ref, translation_id, filepath):
    """EPUB fordítás Ollama API-val (háttérszálban fut)"""
    with app_ref.app_context():
        t = Translation.query.get(translation_id)
        if not t: return
        try:
            t.status = 'processing'; t.progress = 5; db.session.commit()

            from ebooklib import epub
            from bs4 import BeautifulSoup
            
            book = epub.read_epub(filepath)
            model = app_ref.config['DEFAULT_MODEL']
            ollama_host = app_ref.config['OLLAMA_HOST']
            
            items = list(book.get_items_of_type(9))
            total = len(items)
            
            for idx, item in enumerate(items):
                soup = BeautifulSoup(item.get_body_content(), 'html.parser')
                text = soup.get_text().strip()
                if not text or len(text) < 10:
                    continue

                resp = requests.post(f"{ollama_host}/api/generate", json={
                    'model': model,
                    'prompt': f"Fordítsd le magyar nyelvre a következő szöveget. Csak a fordítást add vissza, semmi mást:\n\n{text[:3000]}",
                    'stream': False
                }, timeout=120)
                
                if resp.status_code == 200:
                    translated = resp.json().get('response', text)
                    new_tag = soup.new_tag('p')
                    new_tag.string = translated
                    soup.clear()
                    soup.append(new_tag)
                    item.set_content(str(soup).encode('utf-8'))
                
                t.progress = 5 + int(90 * (idx + 1) / total)
                db.session.commit()
            
            output_filename = f"translated_{uuid.uuid4().hex[:8]}.epub"
            output_path = os.path.join(app_ref.config['OUTPUT_FOLDER'], output_filename)
            epub.write_epub(output_path, book)
            
            t.output_filename = output_filename
            t.status = 'completed'; t.progress = 100; t.quality_score = 85
            db.session.commit()
        except Exception as e:
            t.status = 'failed'; t.progress = 0; t.output_filename = str(e)[:200]
            db.session.commit()
        finally:
            if os.path.exists(filepath):
                os.remove(filepath)

def init_db():
    with app.app_context():
        db.create_all()
        try:
            for col, col_type in [('address', 'VARCHAR(255)'), ('birth_date', 'VARCHAR(20)'), ('tax_id', 'VARCHAR(50)'), ('phone', 'VARCHAR(30)')]:
                db.session.execute(db.text(f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {col} {col_type}"))
            db.session.commit()
        except Exception as e:
            db.session.rollback()
        
        admin = User.query.filter_by(email=Config.ADMIN_EMAIL).first()
        if not admin:
            admin = User(username='admin', email=Config.ADMIN_EMAIL,
                        password_hash=generate_password_hash(Config.ADMIN_PASSWORD),
                        first_name='Admin', last_name='User', is_admin=True,
                        tokens=999999, internal_email='admin@epub.local')
            db.session.add(admin); db.session.commit()

with app.app_context():
    try:
        init_db()
    except Exception as e:
        app.logger.error(f"DB init error: {e}")

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=5000)