// EPUB Fordító – Electron fő folyamat.
// Elindítja a Flask sidecar backendet, megvárja a /health-et, majd megnyitja
// a SPA-t. Ha bármi nem jó, a TÉNYLEGES hibaszöveget mutatja (nem fehér ablakot).
const { app, BrowserWindow, shell, dialog } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const PORT = process.env.PORT || '8765';
const URL = `http://127.0.0.1:${PORT}`;
let backend = null;

let capturedOutput = [];

function startBackend() {
  const isPackaged = app.isPackaged;
  const logPath = path.join(app.getPath('userData'), 'backend.log');
  let logStream;
  try { logStream = fs.createWriteStream(logPath, { flags: 'a' }); } catch (e) {}

  capturedOutput = [];
  const tee = (d) => {
    capturedOutput.push(String(d));
    if (capturedOutput.length > 40) capturedOutput = capturedOutput.slice(-40);
    if (logStream) logStream.write(d);
  };

  let cmd;
  if (isPackaged) {
    const exe = process.platform === 'win32'
      ? path.join(process.resourcesPath, 'backend', 'backend.exe')
      : path.join(process.resourcesPath, 'backend', 'backend');
    if (logStream) logStream.write(`\n=== start: ${exe} (${new Date().toISOString()}) ===\n`);
    cmd = spawn(exe, [], { env: { ...process.env, PORT } });
  } else {
    const python = process.platform === 'win32' ? 'python' : 'python3';
    cmd = spawn(python, ['backend_entry.py'], {
      cwd: __dirname,
      env: { ...process.env, PORT }
    });
  }
  cmd.stdout.on('data', tee);
  cmd.stderr.on('data', tee);
  cmd.on('error', (e) => tee(`[electron] spawn hiba: ${e.message}\n`));
  cmd.on('exit', (code) => tee(`[electron] backend kilépett: ${code}\n`));
  backend = cmd;
}

function waitForHealth(cb) {
  const http = require('http');
  const started = Date.now();
  const check = () => {
    if (backend.exitCode !== null) {
      return cb(new Error(
        'A háttérszolgáltatás azonnal kilépett.\n\n' +
        'Hibakimenet (utolsó sorok):\n' + capturedOutput.slice(-15).join('')
      ));
    }
    const req = http.get(`${URL}/health`, (res) => {
      res.resume();
      if (res.statusCode === 200) return cb(null);
      retry();
    });
    req.on('error', retry);
    req.setTimeout(1000, () => { req.destroy(); retry(); });
  };
  const retry = () => {
    if (Date.now() - started > 45000) {
      return cb(new Error(
        'A háttérszolgáltatás nem indult el 45 másodpercen belül.\n\n' +
        'Hibakimenet (utolsó sorok):\n' + capturedOutput.slice(-15).join('')
      ));
    }
    setTimeout(check, 500);
  };
  check();
}

app.whenReady().then(() => {
  startBackend();
  waitForHealth((err) => {
    if (err) {
      dialog.showErrorBox('EPUB Fordító – indítási hiba', err.message);
      app.quit();
      return;
    }
    const win = new BrowserWindow({
      width: 1280, height: 800,
      webPreferences: { contextIsolation: true, nodeIntegration: false }
    });
    win.loadURL(URL);
    win.webContents.setWindowOpenHandler(({ url }) => {
      if (url.startsWith('http')) shell.openExternal(url);
      return { action: 'deny' };
    });
  });
});

app.on('window-all-closed', () => {
  if (backend) backend.kill();
  app.quit();
});