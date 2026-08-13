// EPUB Fordító – Statisztika oldal (5. fázis: bekötés)
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { BarChart3, BookOpen, CheckCircle, Type, Star } from 'lucide-react';
import { fetchTranslations } from '../api/translations';
import type { Translation } from '../api/types';

export function StatsPage() {
  const { t } = useTranslation();

  // Fordítások lekérése – abból számolunk statisztikát
  const { data: translations, isLoading } = useQuery<Translation[]>({
    queryKey: ['translations'],
    queryFn: fetchTranslations,
  });

  const stats = {
    total: translations?.length ?? 0,
    completed: translations?.filter((x) => x.status === 'completed').length ?? 0,
    totalWords: translations?.reduce((sum, x) => sum + (x.total_words || 0), 0) ?? 0,
    avgQuality:
      translations?.filter((x) => x.quality_score != null).length
        ? Math.round(
            translations
              .filter((x) => x.quality_score != null)
              .reduce((sum, x) => sum + (x.quality_score || 0), 0) /
              translations.filter((x) => x.quality_score != null).length,
          )
        : null,
  };

  if (isLoading) {
    return <div className="skeleton h-40" />;
  }

  const cards = [
    { icon: BookOpen, label: 'Összes fordítás', value: stats.total, color: 'text-accent-blue' },
    { icon: CheckCircle, label: 'Kész', value: stats.completed, color: 'text-accent-green' },
    { icon: Type, label: 'Szavak', value: stats.totalWords, color: 'text-accent-purple' },
    { icon: Star, label: 'Átlag minőség', value: stats.avgQuality ?? '-', color: 'text-accent-yellow' },
  ];

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-text-primary flex items-center gap-2">
        <BarChart3 className="w-6 h-6" />
        {t('nav.stats')}
      </h1>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map(({ icon: Icon, label, value, color }) => (
          <div key={label} className="card card-body text-center">
            <Icon className={`w-6 h-6 mx-auto mb-2 ${color}`} />
            <div className="text-2xl font-bold text-text-primary">{value}</div>
            <div className="text-xs text-text-secondary mt-1">{label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}