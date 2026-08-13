import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Vite konfiguráció az EPUB Fordító React frontendjéhez.
//
// FEJLESZTÉS: a dev szerver (npm run dev) a 5173-as porton fut,
// és az `/api`, `/login`, `/logout`, `/upload`, `/download` kéréseket
// az Nginx-re proxizza (http://localhost:8080), ami továbbítja őket a
// backend konténerre (backend:5000).
//
// FONTOS: a backend konténer NINCS közvetlenül publikálva a host gépre,
// csak az Nginx a 8080-as porton. Ezért a proxy target a 8080, nem az 5000.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/login': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/logout': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/upload': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/download': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    chunkSizeWarningLimit: 1000,
  },
});