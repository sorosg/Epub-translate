// ============================================================
// EPUB Fordító – Beállítások oldal
// 4. fázis: modellválasztás EGY HELYEN + API kulcs + saját adatok.
// ============================================================
import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Settings, Cpu, Key, User as UserIcon } from 'lucide-react';
import type { ModelInfo, RemoteModel } from '../api/types';
import { fetchModels, fetchUserSettings, saveUserSettings } from '../api/settings';
import { apiGet, apiPost } from '../api/client';
import { useAuthStore } from '../stores/authStore';
import { useUiStore } from '../stores/uiStore';

export function SettingsPage() {
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);

  const [source, setSource] = useState<'local' | 'remote'>('local');
  const [selectedModel, setSelectedModel] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [formality, setFormality] = useState<'informal' | 'formal'>('informal');
  const [saving, setSaving] = useState(false);

  // Saját adatok (profil)
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [profileSaving, setProfileSaving] = useState(false);

  // Desktop/GPU állapot (a /health-ből) – a helyi (Ollama) fordítás
  // csak GPU jelenlétében ésszerű; CPU-n figyelmeztetünk.
  const [desktopMode, setDesktopMode] = useState(false);
  const [gpuAvailable, setGpuAvailable] = useState(false);

  // Adatmentés / visszaállítás (v3.0.1)
  const [backupBusy, setBackupBusy] = useState(false);

  const handleExport = async () => {
    setBackupBusy(true);
    try {
      const resp = await fetch('/api/backup/export', { credentials: 'same-origin' });
      if (!resp.ok) {
        const data = await resp.json().catch(() => ({}));
        throw new Error((data as { error?: string }).error || `Hiba (${resp.status})`);
      }
      const blob = await resp.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      const stamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
      a.download = `epub-translator-backup-${stamp}.zip`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
      addToast('success', 'Adatok exportálva.');
    } catch (e) {
      addToast('error', e instanceof Error ? e.message : 'Export hiba');
    } finally {
      setBackupBusy(false);
    }
  };

  const handleImport = async (file: File) => {
    setBackupBusy(true);
    try {
      const fd = new FormData();
      fd.append('file', file);
      const resp = await fetch('/api/backup/import', {
        method: 'POST',
        credentials: 'same-origin',
        body: fd,
      });
      const data = await resp.json().catch(() => ({}));
      if (!resp.ok) {
        throw new Error((data as { error?: string }).error || `Hiba (${resp.status})`);
      }
      addToast('success', 'Import kész. Az alkalmazás újraindítása ajánlott.');
    } catch (e) {
      addToast('error', e instanceof Error ? e.message : 'Import hiba');
    } finally {
      setBackupBusy(false);
    }
  };

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const h = await apiGet<{ desktop_mode?: boolean; gpu_available?: boolean }>('/health');
        if (cancelled) return;
        setDesktopMode(!!h.desktop_mode);
        setGpuAvailable(!!h.gpu_available);
      } catch {
        // csendben marad (a többi funkcionalitást nem befolyásolja)
      }
    })();
    return () => { cancelled = true; };
  }, []);

  const { data: models, isLoading: modelsLoading } = useQuery({
    queryKey: ['models'],
    queryFn: fetchModels,
  });

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        const s = await fetchUserSettings();
        if (cancelled) return;
        setSource(s.preferred_model_source || 'local');
        setSelectedModel(s.preferred_model || '');
        // A maszkolt kulcsot (***XXXX) NEM töltjük be az inputba, hogy a
        // felhasználó véletlenül se mentse vissza (felülírná a valódi kulcsot).
        if (s.deepseek_api_key && !s.deepseek_api_key.startsWith('***')) {
          setApiKey(s.deepseek_api_key);
        } else {
          setApiKey('');
        }
        setFormality(s.formality || 'informal');
      } catch {
        // csendben marad
      }
    };
    void load();
    return () => { cancelled = true; };
  }, []);

  // Saját adatok betöltése a bejelentkezett felhasználóból
  useEffect(() => {
    if (user) {
      setFirstName(user.first_name || '');
      setLastName(user.last_name || '');
      setEmail(user.email || '');
    }
  }, [user]);

  const handleSave = async () => {
    setSaving(true);
    try {
      await saveUserSettings({
        preferred_model_source: source,
        preferred_model: source === 'remote' ? selectedModel : '',
        // Csak akkor küldünk kulcsot, ha nem üres és nem maszkolt.
        deepseek_api_key: apiKey && !apiKey.startsWith('***') ? apiKey : undefined,
        formality,
      });
      addToast('success', 'Beállítások mentve');
    } catch {
      addToast('error', t('common.errorOccurred'));
    } finally {
      setSaving(false);
    }
  };

  const handleProfileSave = async () => {
    setProfileSaving(true);
    try {
      await apiPost('/api/profile', {
        first_name: firstName,
        last_name: lastName,
        email,
        password: password || undefined,
        deepseek_api_key: apiKey && !apiKey.startsWith('***') ? apiKey : undefined,
      });
      // Frissítjük a lokális user állapotot
      if (user) {
        setUser({ ...user, first_name: firstName, last_name: lastName, email });
      }
      setPassword('');
      addToast('success', 'Profil mentve');
    } catch (e) {
      addToast('error', (e as Error).message || t('common.errorOccurred'));
    } finally {
      setProfileSaving(false);
    }
  };

  return (
    <div className="space-y-6 max-w-2xl">
      <h1 className="text-2xl font-bold text-text-primary flex items-center gap-2">
        <Settings className="w-6 h-6" />
        {t('nav.settings')}
      </h1>

      {/* Saját adatok */}
      <div className="card card-body space-y-3">
        <div className="flex items-center gap-2 text-text-primary">
          <UserIcon className="w-5 h-5" />
          <h2 className="font-semibold">Saját adatok</h2>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <input className="form-input" placeholder="Vezetéknév" value={lastName}
            onChange={(e) => setLastName(e.target.value)} />
          <input className="form-input" placeholder="Keresztnév" value={firstName}
            onChange={(e) => setFirstName(e.target.value)} />
          <input className="form-input" placeholder="Email" type="email" value={email}
            onChange={(e) => setEmail(e.target.value)} />
          <input className="form-input" placeholder="Új jelszó (opcionális)" type="password" value={password}
            onChange={(e) => setPassword(e.target.value)} />
        </div>
        <button onClick={() => void handleProfileSave()} disabled={profileSaving} className="btn-primary">
          {profileSaving ? t('common.loading') : 'Profil mentése'}
        </button>
      </div>

      {/* Modellforrás */}
      <div className="card card-body space-y-4">
        <div className="flex items-center gap-2 text-text-primary">
          <Cpu className="w-5 h-5" />
          <h2 className="font-semibold">Fordító modell</h2>
        </div>

        <div className="flex gap-2">
          <button
            onClick={() => setSource('local')}
            className={`btn flex-1 ${source === 'local' ? 'btn-primary' : 'btn-outline'}`}
          >
            🖥️ Helyi (Ollama)
          </button>
          <button
            onClick={() => setSource('remote')}
            className={`btn flex-1 ${source === 'remote' ? 'btn-primary' : 'btn-outline'}`}
          >
            ☁️ DeepSeek Pro
          </button>
        </div>

        {/* GPU figyelmeztetés desktop módban: CPU-n a helyi fordítás hetekig tart */}
        {desktopMode && !gpuAvailable && source === 'local' && (
          <p className="text-xs text-accent-yellow">
            ⚠️ Nincs érzékelhető NVIDIA GPU. A helyi fordítás CPU-n nagyon lassú
            (akár hetekig is tarthat) — a DeepSeek Pro ajánlott, vagy csatlakoztass
            GPU-t (Ollama), és addig ne terheld másra.
          </p>
        )}

        {source === 'local' && (
          <div className="space-y-2">
            {modelsLoading ? (
              <div className="skeleton h-10" />
            ) : !models?.models?.length ? (
              <p className="text-text-secondary text-sm">Nincsenek letöltött helyi modellek.</p>
            ) : (
              models.models.map((m: ModelInfo) => (
                <button
                  key={m.name}
                  onClick={() => setSelectedModel(m.name)}
                  className={`w-full text-left px-4 py-3 rounded-xl border transition-colors ${
                    selectedModel === m.name
                      ? 'border-accent-blue bg-accent-blue/10 text-accent-blue'
                      : 'border-border-color text-text-primary hover:bg-bg-secondary'
                  }`}
                >
                  {m.name}
                </button>
              ))
            )}
          </div>
        )}

        {/* Tegezés/magázás */}
        <div className="space-y-2">
          <span className="text-sm font-medium text-text-primary">Megszólítás</span>
          <div className="flex gap-2">
            <button
              onClick={() => setFormality('informal')}
              className={`btn flex-1 ${formality === 'informal' ? 'btn-primary' : 'btn-outline'}`}
            >
              Tegezés
            </button>
            <button
              onClick={() => setFormality('formal')}
              className={`btn flex-1 ${formality === 'formal' ? 'btn-primary' : 'btn-outline'}`}
            >
              Magázás
            </button>
          </div>
        </div>

        {source === 'remote' && (
          <div className="space-y-2">
            <div className="flex items-start gap-2">
              <Key className="w-4 h-4 text-accent-yellow mt-3" />
              <input
                className="form-input"
                type="password"
                placeholder="sk-... (DeepSeek API kulcs)"
                value={apiKey}
                onChange={(e) => setApiKey(e.target.value)}
              />
            </div>
            {(models?.remote_models || []).map((m: RemoteModel) => (
              <button
                key={m.id}
                onClick={() => setSelectedModel(m.id)}
                className={`w-full text-left px-4 py-3 rounded-xl border transition-colors ${
                  selectedModel === m.id
                    ? 'border-accent-blue bg-accent-blue/10 text-accent-blue'
                    : 'border-border-color text-text-primary hover:bg-bg-secondary'
                }`}
              >
                {m.name} — {m.description}
              </button>
            ))}
          </div>
        )}
      </div>

      <button onClick={handleSave} disabled={saving} className="btn-primary w-full">
        {saving ? t('common.loading') : t('common.save')}
      </button>

      {/* Adatmentés / visszaállítás (v3.0.1) */}
      <div className="border-t border-border-color pt-4 mt-2 space-y-3">
        <h3 className="font-semibold text-sm text-text-secondary">
          Biztonsági mentés / visszaállítás
        </h3>
        <p className="text-xs text-text-muted">
          A kulcs, a beállítások, a könyvtár és a fordítások egyetlen ZIP-ben.
          Telepítés/új gép előtt érdemes exportálni, majd importálni.
        </p>
        <div className="flex gap-2">
          <button onClick={handleExport} disabled={backupBusy} className="btn-outline flex-1">
            {'⬇️ '}Adatok exportálása
          </button>
          <label className="btn-outline flex-1 text-center cursor-pointer">
            {'⬆️ '}Adatok importálása
            <input
              type="file"
              accept="application/zip,.zip"
              className="hidden"
              disabled={backupBusy}
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) handleImport(f);
                e.target.value = '';
              }}
            />
          </label>
        </div>
      </div>
    </div>
  );
}
