// EPUB Fordító – Átnézés oldal (Review)
// 5. fázis: lefordított fejezetek böngészése és inline szerkesztése.
import { useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, BookOpen } from 'lucide-react';
import { apiGet, apiPost } from '../api/client';
import { useUiStore } from '../stores/uiStore';

interface ReviewChapter {
  index: number;
  text: string;
  length: number;
}

interface ReviewData {
  translation: { id: number; original_filename: string; quality_score: number | null; model_used: string };
  chapters: ReviewChapter[];
}

export function ReviewPage() {
  const { id } = useParams<{ id: string }>();
  const translationId = Number(id);
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);
  const queryClient = useQueryClient();

  const [editingIdx, setEditingIdx] = useState<number | null>(null);
  const [editText, setEditText] = useState('');

  const { data, isLoading } = useQuery<ReviewData>({
    queryKey: ['review', translationId],
    queryFn: () => apiGet<ReviewData>(`/api/review/${translationId}`),
  });

  const startEdit = (ch: ReviewChapter) => {
    setEditingIdx(ch.index);
    setEditText(ch.text);
  };

  const saveEdit = async (idx: number) => {
    try {
      await apiPost(`/api/review/save/${translationId}`, { chapter_index: idx, text: editText });
      addToast('success', `Fejezet ${idx + 1} mentve`);
      setEditingIdx(null);
      await queryClient.invalidateQueries({ queryKey: ['review', translationId] });
    } catch {
      addToast('error', t('common.errorOccurred'));
    }
  };

  return (
    <div className="space-y-4 max-w-3xl mx-auto">
      <div className="flex items-center gap-3">
        <Link to="/" className="btn-ghost min-w-[40px] min-h-[40px] p-2">
          <ArrowLeft className="w-5 h-5" />
        </Link>
        <div className="flex-1 min-w-0">
          <h1 className="text-xl font-bold text-text-primary truncate">
            {data?.translation?.original_filename || '...'}
          </h1>
          <p className="text-xs text-text-secondary">
            {data?.translation?.model_used} · minőség: {data?.translation?.quality_score ?? '?'}/100
          </p>
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          <div className="skeleton h-32" />
          <div className="skeleton h-32" />
          <div className="skeleton h-32" />
        </div>
      ) : !data?.chapters?.length ? (
        <div className="card card-body text-center py-12 text-text-secondary">
          <BookOpen className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>{t('common.notFound')}</p>
        </div>
      ) : (
        <div className="space-y-4">
          {data.chapters.map((ch) => (
            <div key={ch.index} className="card card-body">
              <div className="flex items-center justify-between mb-2">
                <span className="font-semibold text-text-primary">Fejezet {ch.index + 1}</span>
                <span className="badge bg-bg-secondary text-text-secondary">{ch.length} karakter</span>
              </div>

              {editingIdx === ch.index ? (
                <div className="space-y-2">
                  <textarea
                    className="form-input min-h-[150px] font-mono text-sm"
                    value={editText}
                    onChange={(e) => setEditText(e.target.value)}
                  />
                  <div className="flex gap-2">
                    <button onClick={() => saveEdit(ch.index)} className="btn-success flex-1">
                      {t('common.save')}
                    </button>
                    <button onClick={() => setEditingIdx(null)} className="btn-outline flex-1">
                      {t('common.cancel')}
                    </button>
                  </div>
                </div>
              ) : (
                <div className="flex items-start justify-between gap-3">
                  <p className="text-sm text-text-secondary flex-1 whitespace-pre-wrap">
                    {ch.text.slice(0, 500)}
                    {ch.text.length > 500 ? '...' : ''}
                  </p>
                  <button onClick={() => startEdit(ch)} className="btn-outline flex-shrink-0">
                    {t('common.edit')}
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}