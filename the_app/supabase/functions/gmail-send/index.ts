// Supabase Edge Function: gmail-send
//
// Sends an email the user wrote in the portal FROM THEIR OWN Gmail account
// (gmail.send scope: send only, no reading). It appears in their Sent
// folder and replies go to their own inbox. Deploy with JWT verification ON.
//
//   POST {enterprise_id?, to: string[], subject, body}
//        -> {id}  (the Gmail message id)
//
// Recipients are checked server-side: each must be in
// enterprise_email_contacts(enterprise_id), called with the user's own
// JWT (the same list the app offers). Admins may also email any portal
// user. So the portal can't be used to mail arbitrary addresses.
//
// 412 {error: 'not_connected' | 'reconnect_needed'}: no Google connection,
// or one made before gmail.send was added (reconnect once).

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { accessTokenFor, NotConnectedError, serviceClient } from '../_shared/google.ts';
import { base64Url, buildMessage } from '../_shared/gmail.ts';
import { rateLimited, serve, serverError } from '../_shared/http.ts';

const MAX_RECIPIENTS = 20;
const MAX_BODY_CHARS = 20_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in' }, 401);
  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(authHeader.replace('Bearer ', ''));
  if (userError || !userData.user) return json({ error: 'Not signed in' }, 401);
  const limited = await rateLimited(`gmail-send:${userData.user.id}`, 30, 3600);
  if (limited) return limited;

  let input: { enterprise_id?: string; to?: string[]; subject?: string; body?: string };
  try {
    input = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
  const to = [...new Set((input.to ?? []).map((e) => String(e).trim().toLowerCase()).filter(Boolean))];
  const subject = String(input.subject ?? '').replace(/[\r\n]+/g, ' ').trim();
  const body = String(input.body ?? '');
  if (to.length === 0) return json({ error: 'Pick at least one recipient' }, 400);
  if (to.length > MAX_RECIPIENTS) return json({ error: `At most ${MAX_RECIPIENTS} recipients` }, 400);
  if (!subject) return json({ error: 'A subject is required' }, 400);
  if (body.length > MAX_BODY_CHARS) return json({ error: 'The message is too long' }, 400);

  // Recipients must come from the portal's own address book.
  const allowed = new Set<string>();
  if (input.enterprise_id) {
    const { data: contacts, error } = await userClient.rpc('enterprise_email_contacts', {
      p_enterprise_id: input.enterprise_id,
    });
    if (error) return serverError(error);
    for (const c of (contacts ?? []) as { email: string | null }[]) if (c.email) allowed.add(c.email.toLowerCase());
  }
  const { data: isAdmin } = await userClient.rpc('is_admin');
  if (isAdmin) {
    const { data: users } = await serviceClient.from('users').select('email').eq('status', 'active');
    for (const u of users ?? []) if (u.email) allowed.add(String(u.email).toLowerCase());
  }
  const notAllowed = to.filter((e) => !allowed.has(e));
  if (notAllowed.length > 0) return json({ error: `You can't email: ${notAllowed.join(', ')}` }, 403);

  try {
    const token = await accessTokenFor(userData.user.id);
    const res = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ raw: base64Url(buildMessage(to, subject, body)) }),
    });
    const result = await res.json().catch(() => ({}));
    if (!res.ok) {
      const message: string = result.error?.message ?? res.statusText;
      if (res.status === 403 && (/insufficient/i.test(message) || JSON.stringify(result).includes('SCOPE_INSUFFICIENT'))) {
        return json({ error: 'reconnect_needed' }, 412);
      }
      console.error('Gmail send failed', res.status, message);
      return json({ error: `Gmail: ${message}` }, 502);
    }
    return json({ id: result.id });
  } catch (e) {
    if (e instanceof NotConnectedError) return json({ error: 'not_connected' }, 412);
    return serverError(e);
  }
});
