// ============================================================
// EPUB Fordító – Hitelesítési állapot kezelés (Zustand)
// A felhasználó aktuális bejelentkezési állapotát tárolja.
// ============================================================
import { create } from 'zustand';
import type { User } from '../api/types';
import * as authApi from '../api/auth';

interface AuthState {
  /** A bejelentkezett felhasználó (null, ha nincs bejelentkezve) */
  user: User | null;
  /** Betöltés alatt áll-e a profil lekérés */
  loading: boolean;
  /** A bejelentkezési állapot lekérése a backendről */
  fetchUser: () => Promise<void>;
  /** Bejelentkezés – visszaadja a felhasználót, vagy null-t hiba esetén */
  login: (email: string, password: string) => Promise<User | null>;
  /** Kijelentkezés */
  logout: () => Promise<void>;
  /** Kézi felhasználó beállítás */
  setUser: (user: User | null) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  loading: true,

  fetchUser: async () => {
    set({ loading: true });
    try {
      const user = await authApi.fetchProfile();
      set({ user, loading: false });
    } catch {
      // 401 = nincs bejelentkezve, ezért user null
      set({ user: null, loading: false });
    }
  },

  login: async (email, password) => {
    const user = await authApi.login(email, password);
    if (user) {
      set({ user });
      return user;
    }
    set({ user: null });
    return null;
  },

  logout: async () => {
    await authApi.logout();
    set({ user: null });
  },

  setUser: (user) => set({ user }),
}));