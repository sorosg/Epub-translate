// ============================================================
// EPUB Fordító – UI állapot kezelés (Zustand)
// Sidebar nyitás/zárás + globális toast értesítések.
// ============================================================
import { create } from 'zustand';

/** Toast értesítés típusa */
export type ToastType = 'success' | 'error' | 'info' | 'warning';

/** Egy toast értesítés adata */
export interface Toast {
  id: string;
  type: ToastType;
  message: string;
}

interface UiState {
  /** Oldalsáv nyitva van-e (mobilon) */
  sidebarOpen: boolean;
  /** Aktív toast értesítések */
  toasts: Toast[];

  toggleSidebar: () => void;
  closeSidebar: () => void;
  /** Új toast megjelenítése */
  addToast: (type: ToastType, message: string) => void;
  /** Toast eltávolítása id alapján */
  removeToast: (id: string) => void;
}

let toastCounter = 0;

export const useUiStore = create<UiState>((set) => ({
  sidebarOpen: false,
  toasts: [],

  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  closeSidebar: () => set({ sidebarOpen: false }),

  addToast: (type, message) => {
    const id = `toast-${Date.now()}-${toastCounter++}`;
    set((state) => ({
      toasts: [...state.toasts, { id, type, message }],
    }));
    // Automatikus eltávolítás 5 mp után
    setTimeout(() => {
      set((state) => ({
        toasts: state.toasts.filter((t) => t.id !== id),
      }));
    }, 5000);
  },

  removeToast: (id) =>
    set((state) => ({
      toasts: state.toasts.filter((t) => t.id !== id),
    })),
}));