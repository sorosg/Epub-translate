// ============================================================
// EPUB Fordító – Toast értesítések
// Egységes visszajelzés minden művelethez (success/error/info/warning).
// ============================================================
import type { ReactNode } from 'react';
import { useUiStore } from '../../stores/uiStore';
import type { ToastType } from '../../stores/uiStore';
import { CheckCircle, XCircle, Info, AlertTriangle, X } from 'lucide-react';

/** Toast típushoz tartozó megjelenítés (ikon + szín) */
const TOAST_STYLES: Record<ToastType, { icon: ReactNode; className: string }> = {
  success: {
    icon: <CheckCircle className="w-5 h-5 text-accent-green" />,
    className: 'border-accent-green',
  },
  error: {
    icon: <XCircle className="w-5 h-5 text-accent-red" />,
    className: 'border-accent-red',
  },
  info: {
    icon: <Info className="w-5 h-5 text-accent-blue" />,
    className: 'border-accent-blue',
  },
  warning: {
    icon: <AlertTriangle className="w-5 h-5 text-accent-yellow" />,
    className: 'border-accent-yellow',
  },
};

/**
 * A globális toast konténer – a uiStore-ban lévő aktív üzeneteket jeleníti meg.
 * A jobb felső sarokba rögzített, z-index magas, hogy minden felett látszódjon.
 */
export function ToastContainer() {
  const toasts = useUiStore((state) => state.toasts);
  const removeToast = useUiStore((state) => state.removeToast);

  if (toasts.length === 0) return null;

  return (
    <div className="fixed top-20 right-4 z-[100] flex flex-col gap-2 max-w-sm">
      {toasts.map((toast) => {
        const style = TOAST_STYLES[toast.type];
        return (
          <div
            key={toast.id}
            className={`card border-l-4 ${style.className} px-4 py-3 flex items-center gap-3 shadow-lg animate-in`}
          >
            {style.icon}
            <span className="flex-1 text-sm text-text-primary">{toast.message}</span>
            <button
              onClick={() => removeToast(toast.id)}
              className="text-text-secondary hover:text-text-primary transition-colors min-w-[32px] min-h-[32px] flex items-center justify-center"
              aria-label="Bezárás"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        );
      })}
    </div>
  );
}