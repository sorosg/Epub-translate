// EPUB Fordító – Fordítás kártya (Dashboard listaelem)
import { useState } from 'react';
import type { Translation } from '../../api/types';
import { useTranslation } from 'react-i18next';
import { Download, Trash2, FileText, Square } from 'lucide-react';
import { stopTranslation } from '../../api/translations';
import { useUiStore } from '../../stores/uiStore';

interface Props {
  translation: Translation;
  onDelete?: (id: number) => void;
  onStopped?: () => void;
}

/** A fordítási szakasz magyar címkéje */
function stageLabel(stage: string, t: (k: string) => string): string {
  switch (stage) {
    case 'first_pass': return '🧠 Első menet (AI fordítás)';
    case 'second_pass': return '🔍 Második menet (minőségellenőrzés)';
    case 'post_processing': return '📦 Utófeldolgozás';
    case 'completed': return '✅ Kész';
    default: return t('status.processing');
  }
}

export function TranslationCard({ translation: t_data, onDelete, onStopped }: Props) {
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);
  const [stopping, setStopping] = useState(false);

  const isProcessing = t_data.status === 'processing';
  const isCompleted = t_data.status === 'completed';
  const isStopped = t_data.status === 'stopped';

  const handleStop = async () => {
    if (!window.confirm('Biztosan leállítod a fordítást?')) return;
    setStopping(true);
    try {
      await stopTranslation(t_data.id);
      addToast('success', 'Leállítási kérés elküldve');
      onStopped?.();
    } catch {
      addToast('error', 'Nem sikerült leállítani');
    } finally {
      setStopping(false);
    }
  };

  return (
    <div className="card p-4">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2 mb-1">
            <FileText className="w-4 h-4 text-accent-blue flex-shrink-0" />
            <span className="font-medium text-text-primary truncate" title={t_data.original_filename}>
              {t_data.original_filename}
            </span>
          </div>
          <div className="text-xs text-text-secondary mb-2">
            {t_data.model_used || '–'}
          </div>

          {/* Progressz sáv feldolgozásnál */}
          {isProcessing && (
            <div className="space-y-1">
              <div className="w-full h-2 bg-bg-secondary rounded-full overflow-hidden">
                <div
                  className="h-full bg-accent-blue transition-all"
                  style={{ width: `${t_data.progress}%` }}
                />
              </div>
              <div className="text-xs text-text-secondary">
                {stageLabel(t_data.current_stage, t)}
                {t_data.current_chapter > 0 && t_data.total_chapters > 0 && (
                  <span> · {t_data.current_chapter}/{t_data.total_chapters} fejezet</span>
                )}
              </div>
            </div>
          )}

          {/* Kész állapot */}
          {isCompleted && t_data.quality_score != null && (
            <div className="text-xs text-accent-green">
              ⭐ {t_data.quality_score}/100 minőség
            </div>
          )}

          {/* Leállított állapot */}
          {isStopped && (
            <div className="text-xs text-accent-yellow">⏹️ Leállítva</div>
          )}
        </div>

        <div className="flex items-center gap-1 flex-shrink-0">
          {isCompleted && (
            <a
              href={`/download/${t_data.id}`}
              className="btn-ghost min-w-[40px] min-h-[40px] p-2"
              title="Letöltés"
            >
              <Download className="w-4 h-4" />
            </a>
          )}

          {/* Leállítás gomb folyamatban lévő (vagy még pending) fordításnál */}
          {isProcessing && (
            <button
              onClick={() => void handleStop()}
              disabled={stopping}
              className="btn-ghost min-w-[40px] min-h-[40px] p-2 text-accent-red hover:bg-accent-red/10"
              title="Leállítás"
            >
              <Square className="w-4 h-4" />
            </button>
          )}

          {onDelete && (
            <button
              onClick={() => onDelete(t_data.id)}
              className="btn-ghost min-w-[40px] min-h-[40px] p-2 text-accent-red hover:bg-accent-red/10"
              title="Törlés"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          )}
        </div>
      </div>
    </div>
  );
}