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
import { apiPost } from '../api/client';
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
  const [saving, setSaving] = useState(false);

  // Saját adatok (profil)
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [profileSaving, setProfileSaving] = useState(false);

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
        setApiKey(s.deepseek_api_key || '');
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
        deepseek_api_key: apiKey || undefined,
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
        deepseek_api_key: apiKey || undefined,
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
    </div>
  );
}