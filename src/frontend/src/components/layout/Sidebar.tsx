// ============================================================
// EPUB Fordító – Oldalsáv (Sidebar)
// Navigáció: Vezérlőpult, Könyvtár, Beállítások, Előzmények, Statisztika.
// Asztali nézetben fix, mobilon felülről becsúszó (slide-in).
// ============================================================
import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '../../stores/authStore';
import { useUiStore } from '../../stores/uiStore';
import { LogOut } from 'lucide-react';
import {
  LayoutDashboard,
  Library,
  Settings,
  History,
  BarChart3,
  Shield,
} from 'lucide-react';

/** A navigációs elemek listája – egy helyen definiálva */
const NAV_ITEMS = [
  { to: '/', icon: LayoutDashboard, labelKey: 'nav.dashboard', exact: true },
  { to: '/library', icon: Library, labelKey: 'nav.library' },
  { to: '/settings', icon: Settings, labelKey: 'nav.settings' },
  { to: '/history', icon: History, labelKey: 'nav.history' },
  { to: '/stats', icon: BarChart3, labelKey: 'nav.stats' },
];

export function Sidebar() {
  const { t } = useTranslation();
  const user = useAuthStore((state) => state.user);
  const logout = useAuthStore((state) => state.logout);
  const sidebarOpen = useUiStore((state) => state.sidebarOpen);
  const closeSidebar = useUiStore((state) => state.closeSidebar);

  const handleLogout = () => {
    closeSidebar();
    void logout();
  };

  return (
    <aside
      className={`fixed top-16 bottom-0 left-0 w-64 bg-bg-secondary border-r border-border-color
        z-50 flex flex-col transition-transform lg:translate-x-0
        ${sidebarOpen ? 'translate-x-0' : '-translate-x-full'}`}
    >
      {/* Navigációs lista */}
      <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.exact}
              onClick={closeSidebar}
              className={({ isActive }) =>
                `flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-accent-blue/15 text-accent-blue'
                    : 'text-text-secondary hover:text-text-primary hover:bg-bg-card'
                }`
              }
            >
              <Icon className="w-5 h-5 flex-shrink-0" />
              <span>{t(item.labelKey)}</span>
            </NavLink>
          );
        })}

        {/* Admin link – csak adminnak */}
        {user?.is_admin && (
          <NavLink
            to="/admin"
            onClick={closeSidebar}
            className={({ isActive }) =>
              `flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-accent-purple/15 text-accent-purple'
                  : 'text-text-secondary hover:text-text-primary hover:bg-bg-card'
              }`
            }
          >
            <Shield className="w-5 h-5 flex-shrink-0" />
            <span>{t('nav.admin')}</span>
          </NavLink>
        )}
      </nav>

      {/* Felhasználó + kijelentkezés */}
      <div className="p-4 border-t border-border-color">
        {user && (
          <div className="mb-3">
            <div className="text-sm font-semibold text-text-primary truncate">
              {user.first_name} {user.last_name}
            </div>
            <div className="text-xs text-text-secondary truncate">{user.email}</div>
          </div>
        )}
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm text-accent-red hover:bg-accent-red/10 transition-colors"
        >
          <LogOut className="w-5 h-5 flex-shrink-0" />
          <span>{t('nav.logout')}</span>
        </button>
      </div>
    </aside>
  );
}