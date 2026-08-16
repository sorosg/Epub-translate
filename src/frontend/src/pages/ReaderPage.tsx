// EPUB Fordító – Olvasó oldal
// 3. fázis: EPUB olvasás, TOC panel, könyvjelző, előzmény mentés.
// v2.6.3: megbízható JS-alapú, felbontás-függő oldaltördelés
//         (a CSS-oszlopos trükk nem adott megbízható oldalszámot, ezért elhagyva).
import { useState, useEffect, useCallback, useRef } from 'react';
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

  // Lapozás: a fejezet tartalmát blokkonként mérjük egy fix magasságú ablakhoz.
  // A lapozás a belső konténer translateY-jával történik (offsetTop-alapú mérés,
  // amit a translate NEM befolyásol, így az oldalszám pontos).
  const pagerRef = useRef<HTMLDivElement>(null);
  const innerRef = useRef<HTMLDivElement>(null);
  const proseRef = useRef<HTMLDivElement>(null);
  const [page, setPage] = useState(0);
  const [pageCount, setPageCount] = useState(1);
  const [pageHeight, setPageHeight] = useState(0);

  // Betöltés: fejezetek + könyvjelző
  useEffect(() => {
    let cancelled = false;
    const init = async () => {
      try {
        const data = await fetchChapters(bookId);
        if (cancelled) return;
        setBookInfo({ title: data.title, author: data.author });
        setChapters(data.chapters);

        const bm = await fetchBookmark(bookId);
        const startIdx = bm.bookmark?.chapter_index ?? 0;
        if (cancelled) return;
        setCurrentIdx(startIdx);

        await saveHistory(bookId, startIdx, 0);
      } catch {
        addToast('error', t('common.errorOccurred'));
      }
    };
    void init();
    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bookId]);

  const loadChapter = useCallback(async (idx: number) => {
    setLoading(true);
    setPage(0); // új fejezetnél az első oldalra
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
      await saveHistory(bookId, idx, 0);
    } catch {
      addToast('error', t('common.errorOccurred'));
    } finally {
      setLoading(false);
    }
  }, [bookId, addToast, t]);

  useEffect(() => {
    if (chapters.length > 0 && !current) {
      void loadChapter(currentIdx);
    }
  }, [chapters, current, currentIdx, loadChapter]);

  // Oldalszám mérése blokkonként, a fix magasságú pager-hez viszonyítva.
  function measurePages() {
    const pager = pagerRef.current;
    const prose = proseRef.current;
    if (!pager || !prose) return;
    const h = pager.clientHeight;
    if (h <= 0) return;
    setPageHeight(h);

    const blocks = Array.from(prose.children) as HTMLElement[];
    if (blocks.length === 0) {
      setPageCount(1);
      setPage(0);
      return;
    }

    // offsetTop: a bloKK offsetParentje az innerRef (position:relative), tehát
    // az érték az innerRef tetejétől mérve a layout-pozíció — a translateY nem
    // befolyásolja, így a mérés mindig ugyanaz, akárhányadik oldalon is állunk.
    let count = 1;
    for (const b of blocks) {
      const bottom = b.offsetTop + b.offsetHeight;
      const needed = Math.ceil(bottom / h);
      if (needed > count) count = needed;
    }
    count = Math.max(1, count);
    setPageCount(count);
    setPage((p) => Math.min(p, count - 1));
  }

  // Mérés a tartalom betöltése után (rövid halasztás a DOM rendereléséhez).
  useEffect(() => {
    if (!current) return;
    const t = setTimeout(() => measurePages(), 50);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [current]);

  // Mérés ablakméret-változásnál (mobil/desktop váltás).
  useEffect(() => {
    const pager = pagerRef.current;
    if (!pager) return;
    const ro = new ResizeObserver(() => measurePages());
    ro.observe(pager);
    return () => ro.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const prevPage = () => setPage((p) => Math.max(0, p - 1));
  const nextPage = () => setPage((p) => Math.min(pageCount - 1, p + 1));

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
          <>
            <h2 className="text-xl font-bold mb-3">{current.title}</h2>

            {/* Lapozó ablak: fix magasság, a belső tartalom translateY-val mozog */}
            <div ref={pagerRef} className="overflow-hidden" style={{ height: '60vh' }}>
              <div
                ref={innerRef}
                style={{
                  position: 'relative',
                  transform: `translateY(-${page * pageHeight}px)`,
                  transition: 'transform 0.25s ease',
                }}
              >
                <div
                  ref={proseRef}
                  className="prose prose-invert max-w-none"
                  dangerouslySetInnerHTML={{ __html: current.html }}
                />
              </div>
            </div>

            {/* Oldal-navigáció (oldalszinten) */}
            <div className="flex items-center justify-center gap-3 mt-3">
              <button onClick={prevPage} disabled={page <= 0} className="btn-outline disabled:opacity-50 px-4">
                <ChevronLeft className="w-4 h-4" /> Előző oldal
              </button>
              <span className="text-sm text-text-secondary">{page + 1} / {pageCount}</span>
              <button onClick={nextPage} disabled={page >= pageCount - 1} className="btn-outline disabled:opacity-50 px-4">
                Következő oldal <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </>
        ) : (
          <p className="text-text-secondary text-center py-10">{t('common.notFound')}</p>
        )}
      </div>

      {/* Navigáció (fejezetszinten) */}
      <div className="flex items-center justify-between mt-4">
        <button onClick={prev} disabled={currentIdx <= 0} className="btn-outline disabled:opacity-50">
          <ChevronLeft className="w-4 h-4" /> Előző fejezet
        </button>
        <span className="text-sm text-text-secondary">Fejezet {currentIdx + 1} / {chapters.length}</span>
        <button onClick={next} disabled={currentIdx >= chapters.length - 1} className="btn-outline disabled:opacity-50">
          Következő fejezet <ChevronRight className="w-4 h-4" />
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