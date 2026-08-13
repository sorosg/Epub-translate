// EPUB Fordító – Fordítás kártya (Dashboard listaelem)
import type { Translation } from '../../api/types';
import { useTranslation } from 'react-i18next';
import { Download, Trash2, FileText } from 'lucide-react';

interface Props {
  translation: Translation;
  onDelete?: (id: number) => void;
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

export function TranslationCard({ translation: t_data, onDelete }: Props) {
  const { t } = useTranslation();
  const isProcessing = t_data.status === 'processing';
  const isCompleted = t_data.status === 'completed';

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