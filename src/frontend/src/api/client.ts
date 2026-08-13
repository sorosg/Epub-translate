// ============================================================
// EPUB Fordító – API kliens
// Központi fetch wrapper, ami:
//  - JSON-t kezel
//  - hibákat egységes formátumban dob
//  - session cookie-t használ (same-origin)
//  - 401 esetén jelzi a kijelentkezést
// ============================================================

/** Az API hiba osztálya, hogy a hívó oldalak könnyen elkapják */
export class ApiError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

/** Általános beállítások a fetch hívásokhoz */
const BASE_OPTIONS: RequestInit = {
  credentials: 'same-origin', // a Flask session cookie küldése
};

/**
 * Egységes GET kérés.
 * @param url a végpont (pl. '/api/library/list')
 */
export async function apiGet<T>(url: string): Promise<T> {
  const resp = await fetch(url, {
    ...BASE_OPTIONS,
    method: 'GET',
  });
  return handleResponse<T>(resp);
}

/**
 * Egységes POST kérés JSON body-val.
 * @param url a végpont
 * @param body a JSON body (opcionális)
 */
export async function apiPost<T>(url: string, body?: unknown): Promise<T> {
  const resp = await fetch(url, {
    ...BASE_OPTIONS,
    method: 'POST',
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  return handleResponse<T>(resp);
}

/**
 * FormData POST kérés (fájl feltöltéshez).
 * @param url a végpont
 * @param formData a FormData (fájl + mezők)
 */
export async function apiPostForm<T>(url: string, formData: FormData): Promise<T> {
  const resp = await fetch(url, {
    ...BASE_OPTIONS,
    method: 'POST',
    body: formData,
  });
  return handleResponse<T>(resp);
}

/**
 * PUT kérés JSON body-val.
 * @param url a végpont
 * @param body a JSON body
 */
export async function apiPut<T>(url: string, body?: unknown): Promise<T> {
  const resp = await fetch(url, {
    ...BASE_OPTIONS,
    method: 'PUT',
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  return handleResponse<T>(resp);
}

/**
 * DELETE kérés.
 * @param url a végpont
 */
export async function apiDelete<T>(url: string): Promise<T> {
  const resp = await fetch(url, {
    ...BASE_OPTIONS,
    method: 'DELETE',
  });
  return handleResponse<T>(resp);
}

/**
 * A válasz feldolgozása: JSON parse + hibakezelés.
 * Ha a backend 401-gyel válaszol, a session lejárt – a hívót értesítjük.
 */
async function handleResponse<T>(resp: Response): Promise<T> {
  // A backend néha üres választ is adhat (pl. 204), ilyenkor ne parse-oljunk
  const text = await resp.text();
  let data: unknown = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      // nem JSON válasz (pl. redirect HTML), üresen hagyjuk
    }
  }

  if (!resp.ok) {
    // 401 = nincs bejelentkezve, 403 = nincs jogosultság
    const message =
      (data as { error?: string })?.error ||
      `Hiba történt (${resp.status})`;
    throw new ApiError(message, resp.status);
  }

  return data as T;
}