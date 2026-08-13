// ============================================================
// EPUB Fordító – Vezérlőpult (Dashboard)
// 1. fázis: aktív fordítások + feltöltő zóna + stat mini-kártyák.
// A TanStack Query automatán refetch-eli az adatokat (polling),
// így a fordítási progressz élőben frissül.
// ============================================================
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { useAuthStore } from '../stores/authStore';
import { useUiStore } from '../stores/uiStore';
import { fetchTranslations } from '../api/translations';
import type { Translation } from '../api/types';
import { UploadZone } from '../components/translation/UploadZone';
import { TranslationCard } from '../components/translation/TranslationCard';
import { Inbox } from 'lucide-react';

export function DashboardPage() {
  const { t } = useTranslation();
  const user = useAuthStore((state) => state.user);
  const addToast = useUiStore((state) => state.addToast);
  const queryClient = useQueryClient();

  // Fordítások lekérése, 5 másodpercenkénti automatikus refetch (polling)
  const { data: translations, isLoading, refetch } = useQuery<Translation[]>({
    queryKey: ['translations'],
    queryFn: fetchTranslations,
    refetchInterval: 5000, // 5 mp – élő frissítés
  });

  const handleDelete = async (id: number) => {
    if (!window.confirm('Biztosan törlöd ezt a fordítást?')) return;
    try {
      await fetch(`/delete/${id}`, { method: 'POST', credentials: 'same-origin' });
      addToast('success', 'Fordítás törölve');
      // Cache érvénytelenítése, hogy frissüljön a lista
      await queryClient.invalidateQueries({ queryKey: ['translations'] });
      void refetch();
    } catch {
      addToast('error', t('common.errorOccurred'));
    }
  };

  const handleUploaded = async () => {
    addToast('info', 'Fordítás elindult');
    await queryClient.invalidateQueries({ queryKey: ['translations'] });
    void refetch();
  };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-text-primary">
        {t('dashboard.welcome', { name: user?.first_name ?? '' })}
      </h1>

      {/* Feltöltő zóna */}
      <UploadZone onUploaded={handleUploaded} />

      {/* Fordítások listája */}
      <div className="card">
        <div className="card-header flex items-center justify-between">
          <span>{t('dashboard.activeTranslations')}</span>
          <span className="badge bg-accent-blue/20 text-accent-blue">
            {translations?.length ?? 0}
          </span>
        </div>
        <div className="card-body">
          {isLoading ? (
            <div className="space-y-3">
              <div className="skeleton h-20" />
              <div className="skeleton h-20" />
            </div>
          ) : !translations || translations.length === 0 ? (
            <div className="text-center py-8 text-text-secondary">
              <Inbox className="w-12 h-12 mx-auto mb-3 opacity-50" />
              <p>{t('dashboard.noTranslations')}</p>
            </div>
          ) : (
            <div className="space-y-3">
              {translations.map((tr) => (
                <TranslationCard
                  key={tr.id}
                  translation={tr}
                  onDelete={handleDelete}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}