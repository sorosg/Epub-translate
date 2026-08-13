// ============================================================
// EPUB Fordító – Mobil alsó navigáció
// Csak mobilon látszik (lg alatt). A fő funkciók gyors elérése.
// ============================================================
import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { LayoutDashboard, Library, Settings, History } from 'lucide-react';

/** Mobil navigációs elemek – a legfontosabb útvonalak */
const MOBILE_NAV_ITEMS = [
  { to: '/', icon: LayoutDashboard, labelKey: 'nav.dashboard', exact: true },
  { to: '/library', icon: Library, labelKey: 'nav.library' },
  { to: '/settings', icon: Settings, labelKey: 'nav.settings' },
  { to: '/history', icon: History, labelKey: 'nav.history' },
];

export function MobileNav() {
  const { t } = useTranslation();

  return (
    <nav className="lg:hidden fixed bottom-0 left-0 right-0 h-16 bg-bg-secondary border-t border-border-color z-50 flex items-stretch justify-around">
      {MOBILE_NAV_ITEMS.map((item) => {
        const Icon = item.icon;
        return (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.exact}
            className={({ isActive }) =>
              `flex-1 flex flex-col items-center justify-center gap-1 text-[11px] font-medium transition-colors ${
                isActive ? 'text-accent-blue' : 'text-text-secondary'
              }`
            }
          >
            <Icon className="w-6 h-6" />
            <span>{t(item.labelKey)}</span>
          </NavLink>
        );
      })}
    </nav>
  );
}