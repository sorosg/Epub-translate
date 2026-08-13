// ============================================================
// EPUB Fordító – Alkalmazás gyökere
// Útvonaltérkép + hitelesítés alapú átirányítás.
// ============================================================
import { useEffect } from 'react';
import { Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { useAuthStore } from './stores/authStore';
import { ToastContainer } from './components/ui/Toast';
import { AppShell } from './components/layout/AppShell';
import { LoginPage } from './pages/LoginPage';
import { DashboardPage } from './pages/DashboardPage';
import { LibraryPage } from './pages/LibraryPage';
import { ReaderPage } from './pages/ReaderPage';
import { SettingsPage } from './pages/SettingsPage';
import { HistoryPage } from './pages/HistoryPage';
import { StatsPage } from './pages/StatsPage';
import { ReviewPage } from './pages/ReviewPage';
import { AdminPage } from './pages/AdminPage';

/**
 * Olyan útvonal-őr, ami csak bejelentkezett felhasználónak enged belépést.
 * Ha nincs bejelentkezve, átirányít a /login oldalra.
 */
function RequireAuth({ children }: { children: React.ReactNode }) {
  const user = useAuthStore((state) => state.user);
  const loading = useAuthStore((state) => state.loading);
  const location = useLocation();

  // Amíg a profil betöltése folyamatban van, ne döntsünk még
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="skeleton w-32 h-10" />
      </div>
    );
  }

  if (!user) {
    // Visszaemlékszünk, honnan jöttünk, hogy belépés után oda térjünk vissza
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}

export default function App() {
  const fetchUser = useAuthStore((state) => state.fetchUser);

  // Alkalmazás indulásakor lekérjük a bejelentkezett felhasználót
  useEffect(() => {
    void fetchUser();
  }, [fetchUser]);

  return (
    <>
      <ToastContainer />
      <Routes>
        {/* Publikus útvonalak */}
        <Route path="/login" element={<LoginPage />} />

        {/* Védett útvonalak – az AppShell (topbar + sidebar) belsejében */}
        <Route
          element={
            <RequireAuth>
              <AppShell />
            </RequireAuth>
          }
        >
          <Route path="/" element={<DashboardPage />} />
          <Route path="/library" element={<LibraryPage />} />
          <Route path="/reader/:id" element={<ReaderPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/history" element={<HistoryPage />} />
          <Route path="/stats" element={<StatsPage />} />
          <Route path="/review/:id" element={<ReviewPage />} />

          <Route path="/admin" element={<AdminPage />} />

          {/* Ismeretlen útvonal -> kezdőlapra */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </>
  );
}