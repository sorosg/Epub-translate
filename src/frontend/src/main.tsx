// ============================================================
// EPUB Fordító – Alkalmazás belépési pont
// Itt inicializáljuk a React gyökeret, a routert és a
// TanStack Query provider-t. Egy ErrorBoundary is védi a fát,
// hogy a futásidejű hibák ne csendes üres lapot adjanak.
// ============================================================
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import App from './App';
import './styles/globals.css';
import './i18n'; // i18next inicializálás (hu/en)

/**
 * Hibahatár: ha bármely komponens renderelés közben elszáll,
 * akkor a hibaüzenetet jelenítjük meg a képernyőn (hogy ne
 * maradjunk néma, fehér oldalon, és azonnal lássuk mi a gond).
 */
class ErrorBoundary extends React.Component<
  { children: React.ReactNode },
  { error: Error | null }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props);
    this.state = { error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    // A böngésző konzoljára is kiírjuk a teljes hibát
    console.error('EPUB Fordító – renderelési hiba:', error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <div
          style={{
            minHeight: '100vh',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '24px',
            background: '#0d1117',
            color: '#f85149',
            fontFamily: 'monospace',
          }}
        >
          <div style={{ maxWidth: '720px', width: '100%' }}>
            <h1 style={{ fontSize: '20px', marginBottom: '12px' }}>
              ⚠️ Renderelési hiba
            </h1>
            <pre
              style={{
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-word',
                background: '#161b22',
                padding: '16px',
                borderRadius: '8px',
                fontSize: '13px',
              }}
            >
              {String(this.state.error?.message || this.state.error)}
              {'\n\n'}
              {this.state.error?.stack || ''}
            </pre>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

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
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </QueryClientProvider>
    </ErrorBoundary>
  </React.StrictMode>,
);