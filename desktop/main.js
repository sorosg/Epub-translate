// EPUB Fordító – Electron fő folyamat.
// Elindítja a Flask sidecar backendet (backend_entry.py), megvárja a /health-et,
// majd megnyitja a 8765-ös porton futó SPA-t.
const { app, BrowserWindow, shell } = require('electron');
const { spawn } = require('child_process');
const path = require('path');

const PORT = process.env.PORT || '8765';
const URL = `http://127.0.0.1:${PORT}`;
let backend = null;

function startBackend() {
  const isPackaged = app.isPackaged;
  let cmd;
  if (isPackaged) {
    // Csomagolt módban a Python sideCar külön futtatható fájl (PyInstaller).
    const exe = process.platform === 'win32'
      ? path.join(process.resourcesPath, 'backend', 'backend.exe')
      : path.join(process.resourcesPath, 'backend', 'backend');
    cmd = spawn(exe, [], { env: { ...process.env, PORT } });
  } else {
    // Fejlesztői mód: platformfüggő Python indítás (Win: python, egyébként: python3)
    const python = process.platform === 'win32' ? 'python' : 'python3';
    cmd = spawn(python, ['backend_entry.py'], {
      cwd: __dirname,
      env: { ...process.env, PORT },
      stdio: 'inherit'
    });
  }
  backend = cmd;
}

function waitForHealth(cb) {
  const http = require('http');
  const t = Date.now();
  const check = () => {
    const req = http.get(`${URL}/health`, (res) => {
      res.resume();
      if (res.statusCode === 200) return cb();
      retry();
    });
    req.on('error', retry);
    req.setTimeout(1000, () => { req.destroy(); retry(); });
  };
  const retry = () => {
    if (Date.now() - t > 30000) return cb(new Error('Backend nem indult el'));
    setTimeout(check, 500);
  };
  check();
}

app.whenReady().then(() => {
  startBackend();
  waitForHealth((err) => {
    const win = new BrowserWindow({
      width: 1280, height: 800,
      webPreferences: { contextIsolation: true }
    });
    win.loadURL(URL);
    win.webContents.setWindowOpenHandler(({ url }) => {
      // Külső linkek (pl. OpenLibrary) a rendszer böngészőjében nyílnak
      if (url.startsWith('http')) shell.openExternal(url);
      return { action: 'deny' };
    });
  });
});

app.on('window-all-closed', () => {
  if (backend) backend.kill();
  app.quit();
});
