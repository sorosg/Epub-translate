// ============================================================
// EPUB Fordító – Alkalmazás belépési pont
// Itt inicializáljuk a React gyökeret, a routert és a
// TanStack Query provider-t.
// ============================================================
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import App from './App';
import './styles/globals.css';
import './i18n'; // i18next inicializálás (hu/en)

// TanStack Query kliens – alapértelmezett beállítások
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1, // 1 újrapróbálkozás hiba esetén
      refetchOnWindowFocus: false, // ne refetch-eljünk fókuszkor feleslegesen
      staleTime: 30_000, // 30 mp-ig friss a cache
    },
  },
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>,
);