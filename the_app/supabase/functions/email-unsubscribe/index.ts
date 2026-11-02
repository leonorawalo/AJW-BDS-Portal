// Supabase Edge Function: email-unsubscribe
//
// One-click unsubscribe from OPTIONAL portal emails (programme news,
// updates, reminders). Deploy with JWT verification OFF: the person
// clicking the link in an email is usually not signed in.
//
//   POST ?token=<uuid>   (or JSON {token})
//        -> {ok: true} once the person is unsubscribed, {ok: false} for
//           an unknown token. Recorded in user_consents
//           (source 'unsubscribe_link').
//
// The link in an email is https://portal.ajwafrica.org/unsubscribe.html?token=...
// (web/unsubscribe.html posts here), and the email's List-Unsubscribe
// header can point straight at this function (RFC 8058 one-click POST).
// Any server that sends an optional email must first call
// optional_email_permission(user) and put its token in the link.
// Essential account and security emails don't use this.

import { rateLimited, serve, serverError } from '../_shared/http.ts';
import { serviceClient } from '../_shared/google.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ error: 'Method not allowed' }, { status: 405 });

  let token = new URL(req.url).searchParams.get('token') ?? '';
  if (!token && req.headers.get('content-type')?.includes('application/json')) {
    const body = await req.json().catch(() => ({}));
    token = String(body.token ?? '');
  }
  if (!UUID.test(token)) return Response.json({ ok: false, error: 'This unsubscribe link is not valid.' }, { status: 400 });

  // Per address, not per user: the caller isn't signed in.
  const ip = (req.headers.get('x-forwarded-for') ?? 'unknown').split(',')[0].trim();
  const limited = await rateLimited(`email-unsubscribe:${ip}`, 30, 600);
  if (limited) return limited;

  const { data, error } = await serviceClient.rpc('unsubscribe_by_token', { p_token: token });
  if (error) return serverError(error);
  return Response.json({ ok: data === true });
});
