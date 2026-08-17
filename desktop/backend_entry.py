# ============================================================
# Desktop (Electron) sidecar backend belépő.
# A közös backend/app.py-t importálja, és desktop módban szolgálja ki mind az
# API-t, mind a buildelt React SPA-t (frontend), egyetlen porton.
# NEM nyúl a docker/app.py-hez; a plusz catch-all route csak ITT regisztrálódik.
# ============================================================
import os, sys, webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))

# Fejlesztői módban (forráskódból) a backend/ vagy src/backend/ mappát tesszük
# a PATH-ra, hogy az 'import app' működjön. Csomagolt (PyInstaller) módban a
# PyInstaller maga építi be az app.py-t + függőségeit, ezért nincs mit keresnünk.
if not getattr(sys, 'frozen', False):
    for cand in [
        os.path.join(os.path.dirname(HERE), 'backend'),
        os.path.join(os.path.dirname(HERE), 'src', 'backend'),
    ]:
        if os.path.isdir(cand):
            sys.path.insert(0, cand)
            break

# Desktop környezet kikényszerítése (SQLite adatok + automatikus helyi user)
os.environ['DESKTOP_MODE'] = '1'
os.environ.setdefault('DATA_DIR', os.path.join(os.path.expanduser('~'), '.epub-translator'))

from app import app  # noqa: E402

# Az SPA build elérési útja (sorrendben ellenőrizve):
# 1. PyInstaller csomagolt mód: a bináris melletti 'frontend' mappa (resources).
# 2. Fejlesztői: repó 'frontend/dist' vagy 'src/frontend/dist'.
_FD = None
for cand in [
    os.path.join(os.path.dirname(sys.executable), 'frontend'),
    os.path.join(HERE, 'frontend-dist'),
    os.path.join(os.path.dirname(HERE), 'src', 'frontend', 'dist'),
    os.path.join(os.path.dirname(HERE), 'frontend', 'dist'),
]:
    if os.path.isdir(cand):
        _FD = cand
        break
FRONTEND_DIST = _FD

# --- SPA statikus kiszolgálás (csak ha létezik a buildelt dist) ---
if FRONTEND_DIST and os.path.isdir(FRONTEND_DIST):
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
    webbrowser.open(f'http://127.0.0.1:{PORT}')
    app.run(host='127.0.0.1', port=PORT, debug=False, threaded=True)