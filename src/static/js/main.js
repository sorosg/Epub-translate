// === EPUB FORDÍTÓ JS (v1.2.0) ===
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
  if (!html) return;
  
  const isDark = html.getAttribute('data-bs-theme') === 'dark';
  const newTheme = isDark ? 'light' : 'dark';
  
  // Vizuális váltás azonnal (akkor is, ha a mentés elbukik)
  html.setAttribute('data-bs-theme', newTheme);
  
  const iconClass = 'bi ' + (newTheme === 'dark' ? 'bi-moon-stars-fill' : 'bi-sun-fill');
  const icon = document.getElementById('themeIcon');
  if (icon) icon.className = iconClass;
  const iconBottom = document.getElementById('themeIconBottom');
  if (iconBottom) iconBottom.className = iconClass;
  
  // Mentés a háttérben (nem blokkol)
  try {
    await fetch('/api/user/settings', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({dark_mode: newTheme === 'dark'})
    });
  } catch(e) { /* csendes hiba – a vizuális váltás már megtörtént */ }
}

// === PWA SERVICE WORKER ===
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/static/sw.js')
      .then(reg => console.log('[PWA] SW regisztrálva:', reg.scope))
      .catch(err => console.log('[PWA] SW hiba:', err));
  });
}

// === ÉRTESÍTÉSI KÖZPONT ===
let notifPanel = null;
function ensureNotifPanel() {
  if (!notifPanel) {
    notifPanel = document.createElement('div');
    notifPanel.id = 'notifPanel';
    notifPanel.style.cssText = 'display:none;position:fixed;top:60px;right:20px;width:360px;max-height:70vh;overflow-y:auto;background:var(--bg-card);border:1px solid var(--border-color);border-radius:14px;box-shadow:0 12px 40px rgba(0,0,0,.5);z-index:1070;padding:.5rem 0;';
    document.body.appendChild(notifPanel);
  }
  return notifPanel;
}

async function loadNotifications() {
  try {
    const resp = await fetch('/api/notifications', {credentials:'same-origin'});
    const data = await resp.json();
    const events = data.events || [];
    const badge = document.getElementById('notifBadge');
    const active = events.filter(e => e.type === 'pending' || e.type === 'processing').length;
    if (active > 0) {
      badge.style.display = 'block';
      badge.textContent = active;
    } else {
      badge.style.display = 'none';
    }
    return events;
  } catch(e) { return []; }
}

async function toggleNotifications() {
  const panel = ensureNotifPanel();
  if (panel.style.display === 'block') {
    panel.style.display = 'none';
    return;
  }
  const events = await loadNotifications();
  let html = '<div style="padding:.5rem 1rem;border-bottom:1px solid var(--border-color);font-weight:600;font-size:.9rem;"><i class="bi bi-bell-fill me-2"></i>Értesítések</div>';
  if (events.length === 0) {
    html += '<div class="text-center py-4 text-secondary"><i class="bi bi-inbox" style="font-size:2rem"></i><p class="mt-2 mb-0 small">Nincsenek értesítéseid</p></div>';
  } else {
    events.forEach(e => {
      html += `<div style="padding:.6rem 1rem;border-bottom:1px solid rgba(48,54,61,.4);cursor:pointer;" onclick="window.location='/download/${e.id}'">
        <div style="font-size:.85rem;">${e.message}</div>
        <small class="text-secondary">${e.time ? new Date(e.time).toLocaleString('hu-HU') : ''}${e.progress > 0 && e.progress < 100 ? ' · '+e.progress+'%' : ''}</small>
      </div>`;
    });
  }
  panel.innerHTML = html;
  panel.style.display = 'block';
  // Kattintás máshova bezárja
  setTimeout(() => {
    document.addEventListener('click', function closeNotif(e) {
      if (!panel.contains(e.target) && e.target.id !== 'notifToggle' && !e.target.closest('#notifToggle')) {
        panel.style.display = 'none';
        document.removeEventListener('click', closeNotif);
      }
    });
  }, 100);
}

// === GYORSMŰVELETEK GOMB ===
function ensureQuickActions() {
  if (document.getElementById('quickActionsBtn')) return;
  const btn = document.createElement('button');
  btn.id = 'quickActionsBtn';
  btn.innerHTML = '<i class="bi bi-plus-lg"></i>';
  btn.title = 'Gyorsműveletek';
  btn.style.cssText = 'position:fixed;bottom:20px;right:20px;z-index:1050;width:56px;height:56px;border-radius:50%;background:linear-gradient(135deg,var(--accent-blue),var(--accent-purple));color:#fff;border:none;box-shadow:0 6px 24px rgba(88,166,255,.4);cursor:pointer;font-size:1.5rem;display:flex;align-items:center;justify-content:center;transition:transform .2s ease';
  btn.onclick = toggleQuickActions;
  document.body.appendChild(btn);
}

function toggleQuickActions() {
  let menu = document.getElementById('quickActionsMenu');
  if (menu) { menu.remove(); return; }
  menu = document.createElement('div');
  menu.id = 'quickActionsMenu';
  menu.style.cssText = 'position:fixed;bottom:85px;right:20px;z-index:1051;background:var(--bg-card);border:1px solid var(--border-color);border-radius:14px;box-shadow:0 8px 32px rgba(0,0,0,.5);padding:.5rem;min-width:200px';
  const actions = [
    ['/dashboard', 'bi-speedometer2', 'Vezérlőpult'],
    ['/library', 'bi-collection', 'Könyvtár'],
    ['/profile', 'bi-person-circle', 'Profil'],
  ];
  actions.forEach(([url, icon, label]) => {
    menu.innerHTML += `<a href="${url}" style="display:flex;align-items:center;gap:.75rem;padding:.65rem .85rem;border-radius:10px;color:var(--text-secondary);text-decoration:none;font-size:.9rem;transition:all .15s ease;" onmouseover="this.style.background='var(--hover-bg)';this.style.color='var(--accent-blue)'" onmouseout="this.style.background='';this.style.color=''"><i class="bi ${icon}"></i>${label}</a>`;
  });
  document.body.appendChild(menu);
  setTimeout(() => {
    document.addEventListener('click', function closeQA(e) {
      if (!menu.contains(e.target) && e.target.id !== 'quickActionsBtn' && !e.target.closest('#quickActionsBtn')) {
        menu.remove();
        document.removeEventListener('click', closeQA);
      }
    });
  }, 100);
}

// Gyorsműveletek gomb csak mobilon jelenik meg (asztali gépen a sidebar elég)
function updateQuickActionsVisibility() {
  const btn = document.getElementById('quickActionsBtn');
  if (!btn) return;
  btn.style.display = window.innerWidth <= 1024 ? 'flex' : 'none';
}
window.addEventListener('resize', updateQuickActionsVisibility);

// Oldal betöltésekor inicializálás
document.addEventListener('DOMContentLoaded', () => {
  loadNotifications();
  ensureQuickActions();
  updateQuickActionsVisibility();
});

// Theme color meta tag frissítése (DOMContentLoaded után, hogy az elemek létezzenek)
document.addEventListener('DOMContentLoaded', () => {
  const themeColorMeta = document.getElementById('themeColorMeta');
  const htmlRoot = document.getElementById('htmlRoot');
  if (themeColorMeta && htmlRoot) {
    const observer = new MutationObserver(() => {
      const theme = htmlRoot.getAttribute('data-bs-theme');
      themeColorMeta.setAttribute('content', theme === 'dark' ? '#0d1117' : '#f6f8fa');
    });
    observer.observe(htmlRoot, { attributes: true, attributeFilter: ['data-bs-theme'] });
  }
});
