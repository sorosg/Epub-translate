// EPUB Fordító Service Worker v11.0 – PWA offline támogatás
const CACHE_NAME = 'epub-translator-v11.0.69';

// Cache-elendő erőforrások
const PRECACHE_URLS = [
  '/',
  '/static/manifest.json',
  '/static/icons/icon-192.svg',
  '/static/icons/icon-512.svg',
  '/login'
];

// Telepítés – alap erőforrások cache-elése
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(PRECACHE_URLS).catch(err => {
        // Ha valamelyik nem elérhető (pl. login oldal POST miatt), nem állunk meg
        console.log('[SW] Precache részleges:', err.message);
      }))
      .then(() => self.skipWaiting())
  );
});

// Aktiválás – régi cache-ek törlése
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
    )).then(() => self.clients.claim())
  );
});

// Fetch – Network First stratégia (friss tartalom, cache fallback)
self.addEventListener('fetch', event => {
  // Csak GET kéréseket cache-elünk
  if (event.request.method !== 'GET') return;
  
  // API hívásokat nem cache-elünk
  if (event.request.url.includes('/api/')) return;
  
  event.respondWith(
    fetch(event.request)
      .then(response => {
        // Ha sikeres a válasz, cache-eljük
        if (response.status === 200) {
          const cloned = response.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, cloned);
          });
        }
        return response;
      })
      .catch(() => {
        // Hálózati hiba esetén cache-ből szolgálunk
        return caches.match(event.request);
      })
  );
});