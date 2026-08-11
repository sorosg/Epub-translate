// === EPUB FORDÍTÓ JS (v11.0.71) ===
// Toast-ok automatikus megjelenítése
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.toast').forEach(t => new bootstrap.Toast(t).show());
});

// === SIDEBAR MOBIL TOGGLE ===
function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('open');
  document.getElementById('sidebarOverlay').classList.toggle('open');
}

function closeSidebar() {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebarOverlay').classList.remove('open');
}

// === TÉMAVÁLTÁS ===
async function toggleTheme() {
  const html = document.getElementById('htmlRoot');
  const isDark = html.getAttribute('data-bs-theme') === 'dark';
  const newTheme = isDark ? 'light' : 'dark';
  html.setAttribute('data-bs-theme', newTheme);
  
  const iconClass = 'bi ' + (newTheme === 'dark' ? 'bi-moon-stars-fill' : 'bi-sun-fill');
  const icon = document.getElementById('themeIcon');
  if (icon) icon.className = iconClass;
  const iconBottom = document.getElementById('themeIconBottom');
  if (iconBottom) iconBottom.className = iconClass;
  
  try {
    await fetch('/api/user/settings', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({dark_mode: newTheme === 'dark'})
    });
  } catch(e) { console.error('Téma mentési hiba:', e); }
}

// === PWA SERVICE WORKER ===
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/static/sw.js')
      .then(reg => console.log('[PWA] SW regisztrálva:', reg.scope))
      .catch(err => console.log('[PWA] SW hiba:', err));
  });
}

// Theme color meta tag frissítése
const themeColorMeta = document.getElementById('themeColorMeta');
const observer = new MutationObserver(() => {
  const theme = document.getElementById('htmlRoot').getAttribute('data-bs-theme');
  themeColorMeta.setAttribute('content', theme === 'dark' ? '#0d1117' : '#f6f8fa');
});
observer.observe(document.getElementById('htmlRoot'), { attributes: true, attributeFilter: ['data-bs-theme'] });