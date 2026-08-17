# ============================================================
# Desktop (Electron) sidecar backend belépő.
# A közös backend/app.py-t importálja, és desktop módban szolgálja ki mind az
# API-t, mind a buildelt React SPA-t (index.html), egyetlen porton.
# ============================================================
import os, sys, webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
FROZEN = getattr(sys, 'frozen', False)

# --- 1) Flask app modul elérési út (csak fejlesztői módban) ---
if not FROZEN:
    for cand in [
        os.path.join(os.path.dirname(HERE), 'backend'),
        os.path.join(os.path.dirname(HERE), 'src', 'backend'),
    ]:
        if os.path.isdir(cand):
            sys.path.insert(0, cand)
            break

# --- 2) Desktop környezet kikényszerítése ---
os.environ['DESKTOP_MODE'] = '1'
os.environ.setdefault('DATA_DIR', os.path.join(os.path.expanduser('~'), '.epub-translator'))

from app import app  # noqa: E402


def _find_frontend():
    """Megkeresi a buildelt React SPA (index.html) könyvtárát."""
    candidates = []
    if FROZEN:
        exe_dir = os.path.dirname(sys.executable)
        candidates.append(os.path.join(os.path.dirname(exe_dir), 'frontend'))
        candidates.append(os.path.join(exe_dir, 'frontend'))
    else:
        candidates.append(os.path.join(os.path.dirname(HERE), 'src', 'frontend', 'dist'))
        candidates.append(os.path.join(os.path.dirname(HERE), 'frontend', 'dist'))
    candidates.append(os.path.join(HERE, 'frontend-dist'))

    for cand in candidates:
        if os.path.isfile(os.path.join(cand, 'index.html')):
            return cand
    return None


FRONTEND_DIST = _find_frontend()

# --- 3) SPA kiszolgálás: a nem-API GET kérések az index.html-t kapják ---
if FRONTEND_DIST:
    from flask import request, send_from_directory

    def _is_spa_asset(p):
        return os.path.isfile(os.path.join(FRONTEND_DIST, p.lstrip('/')))

    @app.before_request
    def _serve_spa():
        if request.method != 'GET':
            return None
        p = request.path
        if p == '/health':
            return None
        if p.startswith('/api/'):
            return None
        if p.startswith('/download/') or p.startswith('/logout'):
            return None
        if p.startswith('/upload') or p.startswith('/reference/'):
            return None
        if p != '/' and _is_spa_asset(p):
            return send_from_directory(FRONTEND_DIST, p.lstrip('/'))
        return send_from_directory(FRONTEND_DIST, 'index.html')

PORT = int(os.environ.get('PORT', '8765'))

if __name__ == '__main__':
    webbrowser.open(f'http://127.0.0.1:{PORT}')
    app.run(host='127.0.0.1', port=PORT, debug=False, threaded=True)