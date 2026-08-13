// ============================================================
// EPUB Fordító – App Shell
// A fő keret: topbar (felső sáv) + összecsukható sidebar (oldalsáv)
// + mobil alsó navigáció. A tartalom a <Outlet />-ben renderelődik.
// ============================================================
import { Outlet } from 'react-router-dom';
import { Topbar } from './Topbar';
import { Sidebar } from './Sidebar';
import { MobileNav } from './MobileNav';
import { useUiStore } from '../../stores/uiStore';

export function AppShell() {
  const sidebarOpen = useUiStore((state) => state.sidebarOpen);
  const closeSidebar = useUiStore((state) => state.closeSidebar);

  return (
    <div className="min-h-screen bg-bg-primary">
      {/* Felső sáv – mindig látható */}
      <Topbar />

      {/* Oldalsáv overlay (mobilon, ha nyitva) */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={closeSidebar}
          aria-hidden="true"
        />
      )}

      {/* Oldalsáv */}
      <Sidebar />

      {/* Fő tartalom – a sidebar mellett */}
      <main className="lg:pl-64 pt-16 pb-20 lg:pb-8 min-h-screen">
        <div className="max-w-content mx-auto p-4 lg:p-8">
          {/* Itt renderelődik az aktuális útvonal oldala */}
          <Outlet />
        </div>
      </main>

      {/* Mobil alsó navigáció */}
      <MobileNav />
    </div>
  );
}