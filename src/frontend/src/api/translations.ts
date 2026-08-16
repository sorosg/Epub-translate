// ============================================================
// EPUB Fordító – Fordítás API hívások
// A dashboardhoz és a fordításkezeléshez szükséges végpontok.
// ============================================================
import { apiGet, apiPostForm } from './client';
import type { Translation, StatsSummary, NotificationEvent, EstimateResult } from './types';

/** A felhasználó összes fordításának lekérése (a React Dashboard listához) */
export async function fetchTranslations(): Promise<Translation[]> {
  const data = await apiGet<{ translations: Translation[] }>('/api/translations');
  return data.translations;
}

/** A felhasználó fordítási eseményeinek lekérése (értesítési központ / dashboard) */
export async function fetchTranslationEvents(): Promise<NotificationEvent[]> {
  const data = await apiGet<{ events: NotificationEvent[] }>('/api/translations/events');
  return data.events;
}

/** Egy fordítás állapotának lekérése (polling-hez) */
export async function fetchTranslationStatus(id: number): Promise<Translation> {
  return apiGet<Translation>(`/api/status/${id}`);
}

/** Fordítási statisztika összefoglaló */
export async function fetchStatsSummary(): Promise<StatsSummary> {
  return apiGet<StatsSummary>('/api/stats/summary');
}

/** Folyamatban lévő fordítás leállítása */
export async function stopTranslation(id: number): Promise<void> {
  await fetch(`/api/translations/${id}/stop`, {
    method: 'POST',
    credentials: 'same-origin',
  });
}

/** Megszakadt (paused) fordítás folytatása a checkpoint alapján */
export async function resumeTranslation(id: number): Promise<void> {
  await fetch(`/api/translations/${id}/resume`, {
    method: 'POST',
    credentials: 'same-origin',
  });
}

/**
 * EPUB fájl feltöltése fordításra.
 * A backend form-encoded választ ad redirect-el, ezért itt FormData-t használunk.
 * A sikerességet a hívó oldal a status polling-gal ellenőrzi.
 */
export async function uploadForTranslation(
  file: File,
  options?: { modelSource?: string; selectedModel?: string; referenceIds?: number[] },
): Promise<void> {
  const formData = new FormData();
  formData.append('file', file);
  if (options?.modelSource) formData.append('model_source', options.modelSource);
  if (options?.selectedModel) formData.append('selected_model', options.selectedModel);
  if (options?.referenceIds?.length) {
    options.referenceIds.forEach((id) => formData.append('reference_ids[]', String(id)));
  }

  // A backend /upload flash+redirect-el válaszol, ezért nem apiPostForm-ot használunk,
  // hanem közvetlen fetch-et, és nem parse-oljuk a választ.
  const resp = await fetch('/upload', {
    method: 'POST',
    credentials: 'same-origin',
    body: formData,
  });

  if (!resp.ok && !resp.redirected) {
    throw new Error('Feltöltési hiba');
  }
}

/**
 * Előzetes fordítási becslés a feltöltött EPUB alapján.
 * Elküldi a fájlt + a kiválasztott modellt, és visszakapja a szószámot,
 * becsült tokeneket, időt és költséget.
 */
export async function estimateTranslation(
  file: File,
  options: { modelSource: string; selectedModel?: string },
): Promise<EstimateResult> {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('model_source', options.modelSource);
  if (options.selectedModel) formData.append('selected_model', options.selectedModel);
  return apiPostForm<EstimateResult>('/api/estimate', formData);
}
