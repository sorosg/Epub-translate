// ============================================================
// EPUB Fordító – Felső sáv (Topbar)
// Tartalma: hamburger menü (mobil), logo, nyelvváltó, értesítő.
// ============================================================
import { useTranslation } from 'react-i18next';
import { useUiStore } from '../../stores/uiStore';
import { Menu, Languages, Bell } from 'lucide-react';
import { useAuthStore } from '../../stores/authStore';

export function Topbar() {
  const { t, i18n } = useTranslation();
  const toggleSidebar = useUiStore((state) => state.toggleSidebar);
  const user = useAuthStore((state) => state.user);

  // Nyelvváltás (hu <-> en)
  const toggleLanguage = () => {
    const next = i18n.language === 'hu' ? 'en' : 'hu';
    void i18n.changeLanguage(next);
  };

  return (
    <header className="fixed top-0 left-0 right-0 h-16 bg-bg-secondary border-b border-border-color z-50 flex items-center px-4 gap-3">
      {/* Hamburger menü – csak mobilon látszik (lg alatt) */}
      <button
        onClick={toggleSidebar}
        className="lg:hidden w-11 h-11 flex items-center justify-center rounded-xl text-text-secondary hover:text-text-primary hover:bg-bg-card transition-colors"
        aria-label="Menü"
      >
        <Menu className="w-6 h-6" />
      </button>

      {/* Logo + cím */}
      <div className="flex items-center gap-2">
        <span className="text-accent-blue font-bold text-lg">{t('app.title')}</span>
      </div>

      {/* Jobb oldali vezérlők */}
      <div className="ml-auto flex items-center gap-1">
        {/* Nyelvváltó */}
        <button
          onClick={toggleLanguage}
          className="w-11 h-11 flex items-center justify-center rounded-xl text-text-secondary hover:text-text-primary hover:bg-bg-card transition-colors"
          aria-label="Nyelvváltás"
          title="Nyelvváltás (hu/en)"
        >
          <Languages className="w-5 h-5" />
          <span className="text-xs font-semibold ml-1">{i18n.language.toUpperCase()}</span>
        </button>

        {/* Értesítő harang (placeholder – a későbbi fázisban lesz aktív) */}
        <button
          className="w-11 h-11 flex items-center justify-center rounded-xl text-text-secondary hover:text-text-primary hover:bg-bg-card transition-colors"
          aria-label="Értesítések"
          title="Értesítések"
        >
          <Bell className="w-5 h-5" />
        </button>

        {/* Felhasználói avatar (ha van felhasználó) */}
        {user && (
          <div className="w-9 h-9 rounded-full bg-accent-blue/20 text-accent-blue flex items-center justify-center font-semibold">
            {user.first_name?.[0] ?? '?'}
          </div>
        )}
      </div>
    </header>
  );
}