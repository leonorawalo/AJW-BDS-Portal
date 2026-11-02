// Shared by every Edge Function the app calls: CORS limited to the
// portal's own web addresses, generic error messages, and rate limits.
// Rules: docs/security/SECURITY.md (Edge Functions).

import { serviceClient } from './google.ts';

/// Browsers may call these functions only from the portal itself (and a
/// local development server). The Android app sends no Origin header,
/// so CORS doesn't apply to it. Keep in step with DO_NOT_BREAK.md
/// section 0 (live and fallback addresses).
const ALLOWED_ORIGINS = new Set([
  'https://portal.ajwafrica.org',
  'https://ajwafrica-bags-portal.web.app',
]);
const LOCAL_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d{1,5})?$/;

export function corsHeadersFor(req: Request): Record<string, string> {
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    Vary: 'Origin',
  };
  const origin = req.headers.get('Origin');
  if (origin && (ALLOWED_ORIGINS.has(origin) || LOCAL_ORIGIN.test(origin))) {
    headers['Access-Control-Allow-Origin'] = origin;
  }
  return headers;
}

export const GENERIC_ERROR = 'Something went wrong on our side. Please try again in a moment.';

/// Logs the real error for the function's logs; the caller only gets a
/// plain sentence (no stack traces, SQL or Google internals).
export function serverError(e: unknown): Response {
  console.error(e);
  return Response.json({ error: GENERIC_ERROR }, { status: 500 });
}

/// Deno.serve with the portal's CORS rules on every response (including
/// errors) and a last-resort generic 500.
export function serve(handler: (req: Request) => Promise<Response> | Response): void {
  Deno.serve(async (req) => {
    const cors = corsHeadersFor(req);
    if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
    let res: Response;
    try {
      res = await handler(req);
    } catch (e) {
      res = serverError(e);
    }
    const headers = new Headers(res.headers);
    headers.delete('Access-Control-Allow-Origin');
    for (const [k, v] of Object.entries(cors)) headers.set(k, v);
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
  });
}

/// Fixed-window limit per key (usually "<function>:<user id>"), counted
/// in public.rate_limits by rate_limit_hit(). Returns a 429 response when
/// the limit is reached, otherwise null. If the counter itself fails, the
/// call is allowed: a limit must never take a feature down.
export async function rateLimited(key: string, max: number, windowSeconds: number): Promise<Response | null> {
  const { data, error } = await serviceClient.rpc('rate_limit_hit', {
    p_key: key,
    p_max: max,
    p_window_seconds: windowSeconds,
  });
  if (error) {
    console.error('rate_limit_hit failed', error.message);
    return null;
  }
  if (data === false) {
    return Response.json(
      { error: 'Too many requests. Please wait a few minutes and try again.' },
      { status: 429, headers: { 'Retry-After': String(windowSeconds) } },
    );
  }
  return null;
}
