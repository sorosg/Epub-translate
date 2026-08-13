// EPUB Fordító – Olvasó oldal
// 3. fázis: EPUB olvasás, TOC panel, könyvjelző, előzmény mentés.
import { useState, useEffect, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, Bookmark, BookmarkCheck, List, ChevronLeft, ChevronRight } from 'lucide-react';
import { fetchChapters, fetchChapterContent, fetchBookmark, saveBookmark, saveHistory } from '../api/reader';
import type { Chapter } from '../api/types';
import { useUiStore } from '../stores/uiStore';

interface ChapterContent {
  title: string;
  html: string;
  text: string;
  index: number;
  total: number;
}

export function ReaderPage() {
  const { id } = useParams<{ id: string }>();
  const bookId = Number(id);
  const { t } = useTranslation();
  const addToast = useUiStore((s) => s.addToast);

  const [bookInfo, setBookInfo] = useState<{ title: string; author: string }>({ title: '', author: '' });
  const [chapters, setChapters] = useState<Chapter[]>([]);
  const [current, setCurrent] = useState<ChapterContent | null>(null);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [bookmarked, setBookmarked] = useState(false);
  const [tocOpen, setTocOpen] = useState(false);
  const [loading, setLoading] = useState(true);

  // Betöltés: fejezetek + könyvjelző
  useEffect(() => {
    let cancelled = false;
    const init = async () => {
      try {
        const data = await fetchChapters(bookId);
        if (cancelled) return;
        setBookInfo({ title: data.title, author: data.author });
        setChapters(data.chapters);

        // Könyvjelző betöltés
        const bm = await fetchBookmark(bookId);
        const startIdx = bm.bookmark?.chapter_index ?? 0;
        if (cancelled) return;
        setCurrentIdx(startIdx);

        // Előzmény mentés (könyv megnyitása)
        await saveHistory(bookId, startIdx, 0);
      } catch {
        addToast('error', t('common.errorOccurred'));
      }
    };
    void init();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bookId]);

  // Fejezet betöltése
  const loadChapter = useCallback(async (idx: number) => {
    setLoading(true);
    try {
      const data = await fetchChapterContent(bookId, idx);
      setCurrent({
        title: data.title,
        html: data.html || `<p>${data.text}</p>`,
        text: data.text,
        index: data.index,
        total: data.total,
      });
      setCurrentIdx(idx);

      // Előzmény mentés
      await saveHistory(bookId, idx, 0);
    } catch {
      addToast('error', t('common.errorOccurred'));
    } finally {
      setLoading(false);
    }
  }, [bookId, addToast, t]);

  // Fejezet automatikus betöltése, ha van fejezet lista
  useEffect(() => {
    if (chapters.length > 0 && !current) {
      void loadChapter(currentIdx);
    }
  }, [chapters, current, currentIdx, loadChapter]);

  const toggleBookmark = async () => {
    try {
      await saveBookmark(bookId, currentIdx, 0);
      setBookmarked((prev) => !prev);
      addToast('success', bookmarked ? 'Könyvjelző törölve' : 'Könyvjelző mentve');
    } catch {
      addToast('error', t('common.errorOccurred'));
    }
  };

  const prev = () => { if (currentIdx > 0) void loadChapter(currentIdx - 1); };
  const next = () => { if (currentIdx < chapters.length - 1) void loadChapter(currentIdx + 1); };

  return (
    <div className="max-w-3xl mx-auto">
      {/* Fejléc */}
      <div className="flex items-center gap-3 mb-4">
        <Link to="/library" className="btn-ghost min-w-[40px] min-h-[40px] p-2">
          <ArrowLeft className="w-5 h-5" />
        </Link>
        <div className="flex-1 min-w-0">
          <h1 className="font-bold text-text-primary truncate">{bookInfo.title || '...'}</h1>
          {bookInfo.author && <p className="text-xs text-text-secondary truncate">{bookInfo.author}</p>}
        </div>
        <button onClick={toggleBookmark} className="btn-ghost min-w-[40px] min-h-[40px] p-2" title="Könyvjelző">
          {bookmarked ? <BookmarkCheck className="w-5 h-5 text-accent-yellow" /> : <Bookmark className="w-5 h-5" />}
        </button>
        <button onClick={() => setTocOpen(true)} className="btn-ghost min-w-[40px] min-h-[40px] p-2" title="Tartalom">
          <List className="w-5 h-5" />
        </button>
      </div>

      {/* Szöveg */}
      <div className="card card-body min-h-[50vh]">
        {loading ? (
          <div className="space-y-3">
            <div className="skeleton h-6 w-2/3" />
            <div className="skeleton h-4" />
            <div className="skeleton h-4" />
            <div className="skeleton h-4" />
            <div className="skeleton h-4 w-5/6" />
          </div>
        ) : current ? (
          <div className="prose prose-invert max-w-none">
            <h2 className="text-xl font-bold mb-4">{current.title}</h2>
            <div dangerouslySetInnerHTML={{ __html: current.html }} />
          </div>
        ) : (
          <p className="text-text-secondary text-center py-10">{t('common.notFound')}</p>
        )}
      </div>

      {/* Navigáció */}
      <div className="flex items-center justify-between mt-4">
        <button onClick={prev} disabled={currentIdx <= 0} className="btn-outline disabled:opacity-50">
          <ChevronLeft className="w-4 h-4" /> Előző
        </button>
        <span className="text-sm text-text-secondary">{currentIdx + 1} / {chapters.length}</span>
        <button onClick={next} disabled={currentIdx >= chapters.length - 1} className="btn-outline disabled:opacity-50">
          Következő <ChevronRight className="w-4 h-4" />
        </button>
      </div>

      {/* TOC panel (slide-in) */}
      {tocOpen && (
        <div className="fixed inset-0 z-[90]">
          <div className="absolute inset-0 bg-black/50" onClick={() => setTocOpen(false)} />
          <div className="absolute right-0 top-0 bottom-0 w-80 max-w-[85%] bg-bg-secondary border-l border-border-color overflow-y-auto p-4">
            <div className="flex items-center justify-between mb-4">
              <h2 className="font-bold text-text-primary">Tartalom</h2>
              <button onClick={() => setTocOpen(false)} className="btn-ghost min-w-[40px] min-h-[40px] p-2">✕</button>
            </div>
            <div className="space-y-1">
              {chapters.map((ch, i) => (
                <button
                  key={ch.index}
                  onClick={() => { void loadChapter(i); setTocOpen(false); }}
                  className={`w-full text-left px-3 py-2 rounded-lg text-sm transition-colors ${
                    i === currentIdx ? 'bg-accent-blue/15 text-accent-blue' : 'text-text-secondary hover:bg-bg-card'
                  }`}
                >
                  {ch.title}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}