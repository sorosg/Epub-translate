// ============================================================
// EPUB Fordító – Bejelentkezési oldal
// A backend JSON /api/login végpontját használja (session cookie).
// ============================================================
import { useState, type FormEvent } from 'react';
import { useNavigate, useLocation, Navigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '../stores/authStore';
import { useUiStore } from '../stores/uiStore';
import { BookOpen } from 'lucide-react';

export function LoginPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const user = useAuthStore((state) => state.user);
  const loading = useAuthStore((state) => state.loading);
  const login = useAuthStore((state) => state.login);
  const addToast = useUiStore((state) => state.addToast);

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);

  // Ha már bejelentkezett, irányítsuk át a kezdőlapra
  if (!loading && user) {
    return <Navigate to="/" replace />;
  }

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const loggedInUser = await login(email, password);
      if (loggedInUser) {
        addToast('success', t('auth.success'));
        // Vissza arra az oldalra, ahonnan jöttünk (ha volt)
        const from = (location.state as { from?: { pathname: string } })?.from?.pathname;
        navigate(from ?? '/', { replace: true });
      } else {
        addToast('error', t('auth.error'));
      }
    } catch {
      addToast('error', t('common.errorOccurred'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-accent-blue/15 text-accent-blue mb-4">
            <BookOpen className="w-8 h-8" />
          </div>
          <h1 className="text-2xl font-bold text-text-primary">{t('app.title')}</h1>
          <p className="text-text-secondary mt-1">{t('app.tagline')}</p>
        </div>

        {/* Bejelentkezési űrlap */}
        <form onSubmit={handleSubmit} className="card p-6 space-y-4">
          <div>
            <label className="form-label" htmlFor="email">
              {t('auth.email')}
            </label>
            <input
              id="email"
              type="email"
              className="form-input"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
              autoFocus
            />
          </div>

          <div>
            <label className="form-label" htmlFor="password">
              {t('auth.password')}
            </label>
            <input
              id="password"
              type="password"
              className="form-input"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="btn-primary w-full"
          >
            {submitting ? t('common.loading') : t('auth.submit')}
          </button>
        </form>
      </div>
    </div>
  );
}