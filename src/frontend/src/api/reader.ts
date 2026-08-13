// EPUB Fordító – Olvasó API hívások
import { apiGet, apiPost } from './client';
import type { Chapter, ReadingHistoryEntry } from './types';

/** Egy könyv fejezeteinek listája */
export async function fetchChapters(bookId: number): Promise<{ chapters: Chapter[]; title: string; author: string }> {
  return apiGet(`/api/reader/${bookId}/chapters`);
}

/** Egy fejezet tartalma */
export async function fetchChapterContent(
  bookId: number,
  idx: number,
): Promise<{ title: string; text: string; html: string; index: number; length: number; total: number }> {
  return apiGet(`/api/reader/${bookId}/chapter/${idx}`);
}

/** Könyvjelző betöltése/mentése */
export async function fetchBookmark(bookId: number): Promise<{ bookmark: { chapter_index: number; scroll_position: number } | null }> {
  return apiGet(`/api/reader/${bookId}/bookmark`);
}

export async function saveBookmark(bookId: number, chapter_index: number, scroll_position: number): Promise<void> {
  await apiPost(`/api/reader/${bookId}/bookmark`, { chapter_index, scroll_position });
}

/** Olvasási előzmény mentése */
export async function saveHistory(bookId: number, chapter_index: number, scroll_position: number): Promise<void> {
  await apiPost('/api/history', { book_id: bookId, chapter_index, scroll_position });
}

/** Olvasási előzmények lekérése */
export async function fetchHistory(): Promise<ReadingHistoryEntry[]> {
  const data = await apiGet<{ history: ReadingHistoryEntry[] }>('/api/history');
  return data.history;
}
