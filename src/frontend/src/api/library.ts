// ============================================================
// EPUB Fordító – Könyvtár API hívások
// A LibraryPage-hez és a könyvtárkezeléshez szükséges végpontok.
// ============================================================
import { apiGet, apiPost, apiPostForm } from './client';
import type { Book, BookMetadata, Recommendation } from './types';

/** A könyvtárban lévő összes könyv lekérése */
export async function fetchLibraryBooks(): Promise<Book[]> {
  const data = await apiGet<{ books: Book[] }>('/api/library/list');
  return data.books;
}

/** EPUB fájl feltöltése a könyvtárba, metaadatokkal */
export async function uploadLibraryBook(
  file: File,
  metadata: Partial<BookMetadata>,
): Promise<{ success: boolean; id: number; message?: string }> {
  const formData = new FormData();
  formData.append('file', file);
  if (metadata.title) formData.append('title', metadata.title);
  if (metadata.author) formData.append('author', metadata.author);
  if (metadata.language) formData.append('language', metadata.language);
  if (metadata.genre) formData.append('genre', metadata.genre);
  if (metadata.series) formData.append('series', metadata.series);
  if (metadata.series_number != null) formData.append('series_number', String(metadata.series_number));

  return apiPostForm('/api/library/upload', formData);
}

/** Egy könyv szerkesztése (metaadatok frissítése) */
export async function editLibraryBook(
  id: number,
  metadata: Partial<BookMetadata>,
): Promise<{ success: boolean }> {
  const formData = new FormData();
  if (metadata.title) formData.append('title', metadata.title);
  if (metadata.author) formData.append('author', metadata.author);
  if (metadata.language) formData.append('language', metadata.language);
  if (metadata.genre) formData.append('genre', metadata.genre);
  if (metadata.series) formData.append('series', metadata.series);
  if (metadata.series_number != null) formData.append('series_number', String(metadata.series_number));

  return apiPostForm(`/api/library/edit/${id}`, formData);
}

/** Egy könyv törlése a könyvtárból */
export async function deleteLibraryBook(id: number): Promise<{ success: boolean }> {
  return apiPost(`/api/library/delete/${id}`);
}

/** Könyv kiválasztása/visszavonása fordításhoz (kontextusként) */
export async function toggleLibraryBook(id: number): Promise<{ success: boolean; is_selected: boolean }> {
  return apiPost(`/api/library/toggle/${id}`);
}

/** EPUB fájl belső metaadatainak kinyerése */
export async function extractLibraryMetadata(
  file: File,
): Promise<{ success: boolean; metadata: BookMetadata }> {
  const formData = new FormData();
  formData.append('file', file);
  return apiPostForm('/api/library/extract-metadata', formData);
}

/** OpenLibrary keresés (metaadat automatikus kitöltéshez) */
export async function fetchOpenLibraryMetadata(
  query: string,
): Promise<{ title: string; author: string; language: string }[]> {
  const data = await apiPost<{ results: { title: string; author: string; language: string }[] }>(
    '/api/library/fetch-metadata',
    { query },
  );
  return data.results;
}

/** Kapcsolódó könyvek ajánlása a feltöltött metadatok alapján */
export async function fetchRecommendations(metadata: Partial<BookMetadata>): Promise<Recommendation[]> {
  const data = await apiPost<{ recommendations: Recommendation[] }>(
    '/api/library/recommend',
    metadata,
  );
  return data.recommendations;
}