// EPUB Fordító – Könyv szerkesztő modal
// A könyv metaadatainak szerkesztéséhez (cím, szerző, műfaj, sorozat, nyelv).
import { useEffect, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { X } from 'lucide-react';
import type { Book } from '../../api/types';
import { editLibraryBook } from '../../api/library';
import { useUiStore } from '../../stores/uiStore';

interface Props {
  book: Book | null;
  onClose: () => void;
  onSaved: () => void;
}

export function BookEditModal({ book, onClose, onSaved }: Props) {
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);

  const [title, setTitle] = useState('');
  const [author, setAuthor] = useState('');
  const [genre, setGenre] = useState('');
  const [series, setSeries] = useState('');
  const [seriesNumber, setSeriesNumber] = useState('');
  const [language, setLanguage] = useState('en');
  const [saving, setSaving] = useState(false);

  // A modal megnyitásakor a kiválasztott könyv adataival töltjük fel
  useEffect(() => {
    if (book) {
      setTitle(book.title || '');
      setAuthor(book.author || '');
      setGenre(book.genre || '');
      setSeries(book.series || '');
      setSeriesNumber(book.series_number != null ? String(book.series_number) : '');
      setLanguage(book.language || 'en');
    }
  }, [book]);

  if (!book) return null;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      await editLibraryBook(book.id, {
        title,
        author,
        genre,
        series,
        series_number: seriesNumber ? parseInt(seriesNumber, 10) : null,
        language,
      });
      addToast('success', 'Könyv mentve');
      onSaved();
      onClose();
    } catch (err) {
      addToast('error', err instanceof Error ? err.message : t('common.errorOccurred'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[90] flex items-center justify-center p-4">
      {/* Háttér overlay */}
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />

      {/* Modal tartalom */}
      <div className="relative card w-full max-w-md p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-text-primary">Könyv szerkesztése</h2>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary min-w-[40px] min-h-[40px] flex items-center justify-center">
            <X className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="form-label">Cím</label>
            <input
              className="form-input"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="form-label">Szerző</label>
              <input
                className="form-input"
                value={author}
                onChange={(e) => setAuthor(e.target.value)}
              />
            </div>
            <div>
              <label className="form-label">Műfaj</label>
              <input
                className="form-input"
                value={genre}
                onChange={(e) => setGenre(e.target.value)}
                placeholder="pl. sci-fi"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="form-label">Sorozat</label>
              <input
                className="form-input"
                value={series}
                onChange={(e) => setSeries(e.target.value)}
              />
            </div>
            <div>
              <label className="form-label">Sorozat #</label>
              <input
                className="form-input"
                type="number"
                min={1}
                value={seriesNumber}
                onChange={(e) => setSeriesNumber(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label className="form-label">Nyelv</label>
            <select
              className="form-input"
              value={language}
              onChange={(e) => setLanguage(e.target.value)}
            >
              <option value="en">Angol</option>
              <option value="hu">Magyar</option>
              <option value="de">Német</option>
              <option value="fr">Francia</option>
              <option value="es">Spanyol</option>
            </select>
          </div>

          <div className="flex gap-2 pt-2">
            <button type="button" onClick={onClose} className="btn-outline flex-1">
              {t('common.cancel')}
            </button>
            <button type="submit" disabled={saving} className="btn-primary flex-1">
              {saving ? t('common.loading') : t('common.save')}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}