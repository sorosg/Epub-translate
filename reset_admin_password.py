# Egyszeri admin jelszó visszaállító – teszteléshez
from app import app, db
from models import User
from werkzeug.security import generate_password_hash

with app.app_context():
    u = User.query.filter_by(email='admin@epub-translator.local').first()
    if u:
        u.password_hash = generate_password_hash('Abrakadabra')
        db.session.commit()
        print('OK: admin jelszo visszaallitva -> Abrakadabra')
    else:
        print('HIBA: admin felhasznalo nem talalhato')