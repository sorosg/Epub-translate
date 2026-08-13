// EPUB Fordító – Olvasási előzmények oldal
// 3. fázis: a felhasználó által legutóbb olvasott könyvek listája.
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router-dom';
import { History, BookOpen, Clock } from 'lucide-react';
import { fetchHistory } from '../api/reader';
import type { ReadingHistoryEntry } from '../api/types';

export function HistoryPage() {
  const { t } = useTranslation();

  const { data: history, isLoading } = useQuery<ReadingHistoryEntry[]>({
    queryKey: ['history'],
    queryFn: fetchHistory,
  });

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-text-primary flex items-center gap-2">
        <History className="w-6 h-6" />
        {t('nav.history')}
      </h1>

      {isLoading ? (
        <div className="space-y-3">
          <div className="skeleton h-20" />
          <div className="skeleton h-20" />
        </div>
      ) : !history || history.length === 0 ? (
        <div className="card card-body text-center py-12 text-text-secondary">
          <History className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>{t('common.notFound')}</p>
        </div>
      ) : (
        <div className="space-y-3">
          {history.map((entry) => (
            <Link
              key={entry.id}
              to={`/reader/${entry.book_id}`}
              className="card card-body flex items-center gap-4 hover:bg-bg-secondary transition-colors block"
            >
              <BookOpen className="w-6 h-6 text-accent-blue flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="font-medium text-text-primary truncate">{entry.book_title || 'Ismeretlen könyv'}</div>
                {entry.book_author && (
                  <div className="text-xs text-text-secondary truncate">{entry.book_author}</div>
                )}
              </div>
              {entry.last_read_at && (
                <div className="text-xs text-text-secondary flex items-center gap-1 flex-shrink-0">
                  <Clock className="w-3 h-3" />
                  {new Date(entry.last_read_at).toLocaleString('hu-HU')}
                </div>
              )}
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}