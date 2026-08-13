// ============================================================
// EPUB Fordító – Placeholder oldal
// Átmeneti komponens, amíg az oldal tényleges tartalma el nem készül.
// Az App.tsx admin útvonala használja egyelőre.
// ============================================================
import { useTranslation } from 'react-i18next';

interface PlaceholderPageProps {
  title: string;
}

export function PlaceholderPage({ title }: PlaceholderPageProps) {
  const { t } = useTranslation();
  return (
    <div className="card p-8 text-center">
      <h1 className="text-xl font-bold text-text-primary mb-2">{title}</h1>
      <p className="text-text-secondary">{t('common.loading')}</p>
      <div className="mt-4 skeleton w-40 h-8 mx-auto" />
    </div>
  );
}