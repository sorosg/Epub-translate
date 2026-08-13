// ============================================================
// EPUB Fordító – Beállítások oldal
// 4. fázis: modellválasztás EGY HELYEN (a dashboard + admin
// duplikáció megszüntetve), API kulcs kezelés.
// ============================================================
import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Settings, Cpu, Key } from 'lucide-react';
import type { ModelInfo, RemoteModel } from '../api/types';
import { fetchModels, fetchUserSettings, saveUserSettings } from '../api/settings';
import { useUiStore } from '../stores/uiStore';

export function SettingsPage() {
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);

  const [source, setSource] = useState<'local' | 'remote'>('local');
  const [selectedModel, setSelectedModel] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [saving, setSaving] = useState(false);

  // Elérhető modellek + jelenlegi beállítások
  const { data: models, isLoading: modelsLoading } = useQuery({
    queryKey: ['models'],
    queryFn: fetchModels,
  });

  // Jelenlegi beállítások betöltése
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
        // csendben marad, ha nem sikerül (pl. nincs bejelentkezve)
      }
    };
    void load();
    return () => { cancelled = true; };
  }, []);

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

  return (
    <div className="space-y-6 max-w-2xl">
      <h1 className="text-2xl font-bold text-text-primary flex items-center gap-2">
        <Settings className="w-6 h-6" />
        {t('nav.settings')}
      </h1>

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

        {/* Helyi modellek listája */}
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

        {/* Remote modellek listája */}
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

      {/* Mentés */}
      <button onClick={handleSave} disabled={saving} className="btn-primary w-full">
        {saving ? t('common.loading') : t('common.save')}
      </button>
    </div>
  );
}