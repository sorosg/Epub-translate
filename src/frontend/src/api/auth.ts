// ============================================================
// EPUB Fordító – Hitelesítési API hívások
// A backend session cookie alapú auth-ját használjuk.
// ============================================================
import { apiGet, apiPost } from './client';
import type { User } from './types';

/** Bejelentkezés a JSON /api/login végponton keresztül (React SPA-hoz).
 *  A backend session cookie-t állít be, és a felhasználó adatait adja vissza. */
export async function login(email: string, password: string): Promise<User | null> {
  const data = await apiPost<{ success: boolean; user?: User; error?: string }>(
    '/api/login',
    { email, password },
  );
  return data.success && data.user ? data.user : null;
}

/** Az aktuális felhasználó lekérése (az új GET /api/profile végpontból) */
export async function fetchProfile(): Promise<User> {
  return apiGet<User>('/api/profile');
}

/** Kijelentkezés (a session cookie törlődik a szerveren) */
export async function logout(): Promise<void> {
  // A /logout redirect-el válaszol, de fetch-csel hívva csak lefuttatjuk,
  // a redirectet a böngésző nem rendereli (nem dokumentum-navigáció).
  await fetch('/logout', { method: 'GET', credentials: 'same-origin' });
}

/** Felhasználói beállítások mentése */
export async function saveSettings(
  settings: Partial<Pick<User, 'preferred_model_source' | 'preferred_model' | 'dark_mode'>>,
): Promise<User> {
  return apiPost<User>('/api/user/settings', settings);
}