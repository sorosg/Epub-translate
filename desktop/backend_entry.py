# ============================================================
# Desktop (Electron) sidecar backend belépő.
# A közös backend/app.py-t importálja, és desktop módban szolgálja ki mind az
# API-t, mind a buildelt React SPA-t (frontend/dist), egyetlen porton.
# NEM nyúl a docker/app.py-hez; a plusz catch-all route csak ITT regisztrálódik.
# ============================================================
import os, sys, threading, webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# A backend/ vagy src/backend/ mappát is felismerjük:
# - WSL build-forrásban: backend/
# - GitHub repóban: src/backend/
_BACKEND = os.path.join(ROOT, 'backend')
if not os.path.isdir(_BACKEND):
    _BACKEND = os.path.join(ROOT, 'src', 'backend')
sys.path.insert(0, _BACKEND)

# Desktop környezet kikényszerítése (SQLite adatok + automatikus helyi user)
os.environ['DESKTOP_MODE'] = '1'
os.environ.setdefault('DATA_DIR', os.path.join(os.path.expanduser('~'), '.epub-translator'))

from app import app, db, init_db  # noqa: E402

_FD = os.path.join(ROOT, 'frontend', 'dist')
if not os.path.isdir(_FD):
    _FD = os.path.join(ROOT, 'src', 'frontend', 'dist')
FRONTEND_DIST = _FD

# --- 2) SPA statikus kiszolgálás (csak ha létezik a buildelt dist) ---
if os.path.isdir(FRONTEND_DIST):
    from flask import send_from_directory

    @app.route('/', defaults={'path': ''})
    @app.route('/<path:path>')
    def _spa(path):
        full = os.path.join(FRONTEND_DIST, path)
        if path and os.path.isfile(full):
            return send_from_directory(FRONTEND_DIST, path)
        return send_from_directory(FRONTEND_DIST, 'index.html')

PORT = int(os.environ.get('PORT', '8765'))

if __name__ == '__main__':
    # Az adatbázis inicializálása már az app.py importálásakor megtörténik.
    url = f'http://127.0.0.1:{PORT}'
    def _open():
        webbrowser.open(url)
    threading.Timer(1.2, _open).start()
    app.run(host='127.0.0.1', port=PORT, debug=False, threaded=True)
