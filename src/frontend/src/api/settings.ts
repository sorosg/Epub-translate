// EPUB Fordító – Modell/bedllítás API hívások
import { apiGet, apiPost } from './client';
import type { ModelInfo, RemoteModel, User } from './types';

interface ModelsResponse {
  models: ModelInfo[];
  remote_models: RemoteModel[];
  remote_available: boolean;
  current_model: string;
}

/** Elérhető modellek lekérése (helyi Ollama + távoli DeepSeek) */
export async function fetchModels(): Promise<ModelsResponse> {
  return apiGet<ModelsResponse>('/api/models/list');
}

/** Felhasználói beállítások mentése (preferált modell / forrás / API kulcs) */
export async function saveUserSettings(settings: {
  preferred_model_source?: 'local' | 'remote';
  preferred_model?: string;
  deepseek_api_key?: string;
  formality?: 'informal' | 'formal';
}): Promise<User> {
  return apiPost<User>('/api/user/settings', settings);
}

/** Felhasználói beállítások lekérése */
export async function fetchUserSettings(): Promise<{
  preferred_model_source: 'local' | 'remote';
  preferred_model: string;
  deepseek_api_key: string;
  dark_mode: boolean;
  formality: 'informal' | 'formal';
}> {
  return apiGet('/api/user/settings');
}
