// EPUB Fordító – Könyv kártya (Könyvtár listaelem)
import type { Book } from '../../api/types';
import { BookOpen, Pencil, Trash2, Star } from 'lucide-react';

interface Props {
  book: Book;
  onEdit: (book: Book) => void;
  onDelete: (id: number) => void;
  onToggle: (id: number) => void;
}

export function BookCard({ book, onEdit, onDelete, onToggle }: Props) {
  return (
    <div className="card p-4 h-full flex flex-col">
      {/* Cím + szerző */}
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <h3 className="font-medium text-text-primary truncate" title={book.title}>
            {book.title || 'Ismeretlen'}
          </h3>
          {book.author && (
            <p className="text-xs text-text-secondary truncate">✍️ {book.author}</p>
          )}
        </div>
        {/* Kiválasztva kontextusnak */}
        <button
          onClick={() => onToggle(book.id)}
          className={`min-w-[40px] min-h-[40px] p-2 rounded-xl flex items-center justify-center transition-colors ${
            book.is_selected
              ? 'text-accent-yellow hover:bg-accent-yellow/10'
              : 'text-text-secondary hover:bg-bg-secondary'
          }`}
          title={book.is_selected ? 'Kiválasztva' : 'Kiválasztás fordításhoz'}
        >
          <Star className="w-5 h-5" fill={book.is_selected ? 'currentColor' : 'none'} />
        </button>
      </div>

      {/* Metaadat badgek */}
      <div className="flex flex-wrap gap-1 my-2">
        {book.language && <span className="badge bg-bg-secondary text-text-secondary">{book.language}</span>}
        {book.genre && <span className="badge bg-accent-blue/15 text-accent-blue">{book.genre}</span>}
        {book.series && (
          <span className="badge bg-bg-secondary text-text-secondary">
            📚 {book.series}
            {book.series_number ? ` #${book.series_number}` : ''}
          </span>
        )}
      </div>

      <p className="text-xs text-text-secondary mb-3">
        Feltöltő: {book.uploader_name || '-'}
      </p>

      {/* Műveletek */}
      <div className="flex gap-1 mt-auto">
        <a
          href={`/reader/${book.id}`}
          className="btn-ghost flex-1 min-h-[40px]"
          title="Könyv olvasása"
        >
          <BookOpen className="w-4 h-4" />
        </a>
        {book.is_owner && (
          <>
            <button
              onClick={() => onEdit(book)}
              className="btn-ghost flex-1 min-h-[40px] text-accent-blue"
              title="Szerkesztés"
            >
              <Pencil className="w-4 h-4" />
            </button>
            <button
              onClick={() => onDelete(book.id)}
              className="btn-ghost flex-1 min-h-[40px] text-accent-red hover:bg-accent-red/10"
              title="Törlés"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </>
        )}
      </div>
    </div>
  );
}