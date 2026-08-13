// ============================================================
// EPUB Fordító – TypeScript típusdefiníciók
// Az összes backend API válasz típusa itt van definiálva, hogy
// a frontend típusbiztos legyen.
// ============================================================

/** Fordítási státusz enum – megfelel a backend értékeinek */
export type TranslationStatus = 'pending' | 'processing' | 'completed' | 'failed';

/** Fordítási szakasz (stage) – a részletes progresszhez */
export type TranslationStage =
  | 'first_pass'
  | 'second_pass'
  | 'post_processing'
  | 'completed'
  | 'pending';

/** Felhasználó modell */
export interface User {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  tokens: number;
  points: number;
  level: number;
  is_admin: boolean;
  preferred_model_source: 'local' | 'remote';
  preferred_model: string;
  deepseek_api_key?: string;
  dark_mode?: boolean;
}

/** Fordítás modell – a `GET /api/status/:id` válasza */
export interface Translation {
  id: number;
  status: TranslationStatus;
  progress: number;
  original_filename: string;
  current_stage: TranslationStage;
  current_chapter: number;
  total_chapters: number;
  words_processed: number;
  total_words: number;
  nodes_translated: number;
  nodes_failed: number;
  first_pass_model: string;
  second_pass_model: string;
  output_filename: string | null;
  model_used: string;
  quality_score: number | null;
  created_at: string | null;
  elapsed_seconds: number;
  estimated_seconds: number;
}

/** Könyv modell – a `GET /api/library/list` eleme */
export interface Book {
  id: number;
  title: string;
  author: string;
  language: string;
  genre: string;
  series: string;
  series_number: number | null;
  is_selected: boolean;
  is_owner: boolean;
  uploader_name: string;
  uploaded_at: string;
  filename: string;
}

/** Olvasó fejezet – a `GET /api/reader/:id/chapters` eleme */
export interface Chapter {
  index: number;
  title: string;
  length: number;
  preview: string;
}

/** Értesítési esemény – a `GET /api/notifications` eleme */
export interface NotificationEvent {
  id: number;
  type: TranslationStatus;
  icon: string;
  message: string;
  time: string;
  progress: number;
  quality_score: number | null;
}

/** Modell lista elem – a `GET /api/models/list` válasza */
export interface ModelInfo {
  name: string;
  size?: number;
  modified_at?: string;
}

/** Remote modell (DeepSeek Pro) */
export interface RemoteModel {
  id: string;
  name: string;
  provider: string;
  description: string;
}

/** Statisztika összefoglaló – az új `GET /api/stats/summary` válasza */
export interface StatsSummary {
  total_translations: number;
  completed_translations: number;
  total_words: number;
  average_quality: number;
  active_translations: number;
}

/** Olvasási előzmény – az új `GET /api/history` eleme */
export interface ReadingHistoryEntry {
  id: number;
  book_id: number;
  book_title: string;
  book_author: string;
  chapter_index: number;
  scroll_position: number;
  last_read_at: string;
}

/** Ajánlás – a `POST /api/library/recommend` eleme */
export interface Recommendation {
  id: number;
  title: string;
  author: string;
  language: string;
  genre: string;
  series: string;
  series_number: number | null;
  reason: 'series' | 'author' | 'genre';
}

/** Metaadat kinyerés eredménye – a `POST /api/library/extract-metadata` válasza */
export interface BookMetadata {
  title: string;
  author: string;
  language: string;
  description: string;
  genre: string;
  series: string;
  series_number: number | null;
}