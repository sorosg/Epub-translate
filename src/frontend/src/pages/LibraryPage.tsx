// ============================================================
// EPUB Fordító – Könyvtár oldal
// 2. fázis: könyvek listája, szűrés, feltöltés, szerkesztés,
// törlés, kiválasztás (kontextus).
// ============================================================
import { useMemo, useState, useRef, type ChangeEvent } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Library, Search, CloudUpload, Inbox } from 'lucide-react';
import type { Book } from '../api/types';
import {
  fetchLibraryBooks,
  uploadLibraryBook,
  deleteLibraryBook,
  toggleLibraryBook,
  extractLibraryMetadata,
} from '../api/library';
import { BookCard } from '../components/library/BookCard';
import { BookEditModal } from '../components/library/BookEditModal';
import { useUiStore } from '../stores/uiStore';

export function LibraryPage() {
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);
  const queryClient = useQueryClient();
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Szűrő állapotok
  const [filterTitle, setFilterTitle] = useState('');
  const [filterAuthor, setFilterAuthor] = useState('');
  const [filterGenre, setFilterGenre] = useState('');
  const [editingBook, setEditingBook] = useState<Book | null>(null);
  const [uploading, setUploading] = useState(false);

  const { data: books, isLoading, refetch } = useQuery<Book[]>({
    queryKey: ['library'],
    queryFn: fetchLibraryBooks,
  });

  // Szűrt lista
  const filteredBooks = useMemo(() => {
    if (!books) return [];
    return books.filter((b) => {
      if (filterTitle && !(b.title || '').toLowerCase().includes(filterTitle.toLowerCase())) return false;
      if (filterAuthor && !(b.author || '').toLowerCase().includes(filterAuthor.toLowerCase())) return false;
      if (filterGenre && b.genre !== filterGenre) return false;
      return true;
    });
  }, [books, filterTitle, filterAuthor, filterGenre]);

  const refresh = async () => {
    await queryClient.invalidateQueries({ queryKey: ['library'] });
    void refetch();
  };

  const handleUpload = async (e: ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files ?? []) as File[];
    if (files.length === 0) return;

    setUploading(true);
    try {
      for (const file of files) {
        if (!file.name.toLowerCase().endsWith('.epub')) {
          addToast('error', `"${file.name}" nem EPUB, kihagyva`);
          continue;
        }
        try {
          // Először metaadat kinyerés a fájl belső adataiból, majd feltöltés
          const meta = await extractLibraryMetadata(file);
          await uploadLibraryBook(file, meta.metadata || { title: file.name.replace(/\.epub$/i, '') });
          addToast('success', `"${file.name}" feltöltve a könyvtárba`);
        } catch (err) {
          addToast('error', `"${file.name}": ${err instanceof Error ? err.message : t('common.errorOccurred')}`);
        }
      }
      await refresh();
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('Biztosan törlöd ezt a könyvet?')) return;
    try {
      await deleteLibraryBook(id);
      addToast('success', 'Könyv törölve');
      await refresh();
    } catch {
      addToast('error', t('common.errorOccurred'));
    }
  };

  const handleToggle = async (id: number) => {
    try {
      await toggleLibraryBook(id);
      await refresh();
    } catch {
      addToast('error', t('common.errorOccurred'));
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <h1 className="text-2xl font-bold text-text-primary flex items-center gap-2">
          <Library className="w-6 h-6" />
          {t('nav.library')}
        </h1>
        {/* Feltöltés gomb */}
        <button onClick={() => fileInputRef.current?.click()} className="btn-primary" disabled={uploading}>
          <CloudUpload className="w-4 h-4" />
          {uploading ? t('common.loading') : t('common.upload')}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept=".epub"
          multiple
          className="hidden"
          onChange={(e) => void handleUpload(e)}
        />
      </div>

      {/* Szűrők */}
      <div className="card card-body space-y-3">
        <div className="flex items-center gap-2 text-text-secondary">
          <Search className="w-4 h-4" />
          <span className="text-sm font-medium">Szűrők</span>
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <input
            className="form-input"
            placeholder="Cím"
            value={filterTitle}
            onChange={(e) => setFilterTitle(e.target.value)}
          />
          <input
            className="form-input"
            placeholder="Szerző"
            value={filterAuthor}
            onChange={(e) => setFilterAuthor(e.target.value)}
          />
          <select
            className="form-input"
            value={filterGenre}
            onChange={(e) => setFilterGenre(e.target.value)}
          >
            <option value="">Minden műfaj</option>
            <option value="sci-fi">Sci-Fi</option>
            <option value="fantasy">Fantasy</option>
            <option value="adventure">Kaland</option>
            <option value="mystery">Krimi</option>
            <option value="romance">Romantikus</option>
            <option value="horror">Horror</option>
            <option value="historical">Történelmi</option>
            <option value="biography">Életrajz</option>
            <option value="science">Tudományos</option>
            <option value="other">Egyéb</option>
          </select>
        </div>
      </div>

      {/* Könyvek listája */}
      {isLoading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {[0, 1, 2].map((i) => <div key={i} className="skeleton h-48" />)}
        </div>
      ) : filteredBooks.length === 0 ? (
        <div className="card card-body text-center py-12 text-text-secondary">
          <Inbox className="w-12 h-12 mx-auto mb-3 opacity-50" />
          <p>{t('common.notFound')}</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredBooks.map((book) => (
            <BookCard
              key={book.id}
              book={book}
              onEdit={setEditingBook}
              onDelete={handleDelete}
              onToggle={handleToggle}
            />
          ))}
        </div>
      )}

      {/* Szerkesztő modal */}
      <BookEditModal
        book={editingBook}
        onClose={() => setEditingBook(null)}
        onSaved={refresh}
      />
    </div>
  );
}