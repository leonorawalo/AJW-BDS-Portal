// Supabase Edge Function: google-oauth
//
// Connects a user's own Google account (Calendar + Meet) to the app.
// Deploy with JWT verification OFF — Google's redirect back to this
// function carries no Supabase JWT. The POST actions verify the caller's
// JWT themselves instead.
//
//   POST {action: 'start'}      (Authorization: Bearer <user JWT>)
//        -> {url}: Google consent page for the app to open in a browser
//   GET  ?code=...&state=...    (Google's redirect after consent)
//        -> stores the refresh token, shows a "you can close this" page
//   POST {action: 'disconnect'} (Authorization: Bearer <user JWT>)
//        -> revokes the token at Google and deletes the connection
//
// Required secrets (Dashboard -> Edge Functions -> Secrets):
//   GOOGLE_CLIENT_ID     — OAuth client (type "Web application")
//   GOOGLE_CLIENT_SECRET — same client
// The OAuth client's "Authorized redirect URI" must be exactly
//   https://<project-ref>.supabase.co/functions/v1/google-oauth
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const GOOGLE_CLIENT_ID = Deno.env.get('GOOGLE_CLIENT_ID')!;
const GOOGLE_CLIENT_SECRET = Deno.env.get('GOOGLE_CLIENT_SECRET')!;
// Google verification needs redirect URIs on a domain AJW owns, so in
// production this is set to the relay page on the hosted site
// (https://ajwafrica-bags-portal.web.app/oauth/google-callback.html), which
// forwards Google's result here unchanged. Unset = the direct function URL
// (the pre-verification setup). The same value must be listed as an
// Authorised redirect URI on the OAuth client, and is used for both the
// consent URL and the token exchange.
const REDIRECT_URI = Deno.env.get('GOOGLE_OAUTH_REDIRECT_URI') ?? `${SUPABASE_URL}/functions/v1/google-oauth`;
const SCOPES = [
  'openid',
  'email',
  'https://www.googleapis.com/auth/calendar.events',
  // Availability checks before booking (calendar-sessions). Busy/free
  // only — no event details.
  'https://www.googleapis.com/auth/calendar.freebusy',
  // Exports to Docs/Sheets/Slides (google-export). drive.file only sees
  // files this app created — never the rest of the user's Drive.
  'https://www.googleapis.com/auth/drive.file',
  // "Write email" (gmail-send): send-only, as the user, from their own
  // Gmail. No read access to their mailbox.
  'https://www.googleapis.com/auth/gmail.send',
].join(' ');
/// A consent link older than this is refused on the way back.
const STATE_TTL_MS = 15 * 60 * 1000;

const admin = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

/// Supabase serves Edge Function HTML as text/plain on the default
/// domain, so the post-consent page is deliberately plain text.
function text(body: string, status = 200): Response {
  return new Response(body, { status, headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
}

async function callerId(req: Request): Promise<string | null> {
  const jwt = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!jwt) return null;
  const { data, error } = await admin.auth.getUser(jwt);
  return error ? null : data.user.id;
}

/// The id_token comes straight from Google's token endpoint over TLS in
/// this same request, so reading its payload without re-verifying the
/// signature is safe here.
function emailFromIdToken(idToken: string | undefined): string | null {
  if (!idToken) return null;
  try {
    const payload = idToken.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(atob(payload)).email ?? null;
  } catch {
    return null;
  }
}

async function start(userId: string): Promise<Response> {
  const state = crypto.randomUUID();
  // Opportunistic cleanup of abandoned consent attempts.
  await admin
    .from('google_oauth_states')
    .delete()
    .lt('created_at', new Date(Date.now() - STATE_TTL_MS).toISOString());
  const { error } = await admin.from('google_oauth_states').insert({ state, user_id: userId });
  if (error) return json({ error: error.message }, 500);

  const url = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  url.search = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    scope: SCOPES,
    // offline + consent: Google only returns a refresh_token when both
    // are set, including on a reconnect after a previous grant.
    access_type: 'offline',
    prompt: 'consent',
    include_granted_scopes: 'true',
    state,
  }).toString();
  return json({ url: url.toString() });
}

async function callback(params: URLSearchParams): Promise<Response> {
  const state = params.get('state');
  const code = params.get('code');
  if (params.get('error')) {
    return text(`Google account was not connected (${params.get('error')}). You can close this tab.`, 400);
  }
  if (!state || !code) return text('Missing code or state.', 400);

  const { data: stateRow } = await admin
    .from('google_oauth_states')
    .select('user_id, created_at')
    .eq('state', state)
    .maybeSingle();
  // Single use, whether or not the rest succeeds.
  await admin.from('google_oauth_states').delete().eq('state', state);
  if (!stateRow || Date.now() - Date.parse(stateRow.created_at) > STATE_TTL_MS) {
    return text('This connection link has expired. Go back to the app and tap "Connect" again.', 400);
  }

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: REDIRECT_URI,
      grant_type: 'authorization_code',
    }),
  });
  const tokens = await tokenRes.json();
  if (!tokenRes.ok || !tokens.refresh_token) {
    console.error('Token exchange failed', tokens);
    return text('Google did not return a usable token. Go back to the app and try connecting again.', 502);
  }
  if (!String(tokens.scope ?? '').includes('calendar.events')) {
    return text('Calendar access was not granted. Go back to the app and tick the Calendar permission.', 400);
  }

  const { error } = await admin.from('google_connections').upsert({
    user_id: stateRow.user_id,
    google_email: emailFromIdToken(tokens.id_token),
    refresh_token: tokens.refresh_token,
    scope: tokens.scope,
    connected_at: new Date().toISOString(),
  });
  if (error) {
    console.error('Saving connection failed', error);
    return text('Could not save the connection. Please try again.', 500);
  }
  return text('Google account connected. You can close this tab and return to the AJW BAGS Portal app.');
}

async function disconnect(userId: string): Promise<Response> {
  const { data } = await admin
    .from('google_connections')
    .select('refresh_token')
    .eq('user_id', userId)
    .maybeSingle();
  if (data?.refresh_token) {
    // Best effort — the local row is removed even if Google already
    // considers the token revoked.
    await fetch(`https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(data.refresh_token)}`, {
      method: 'POST',
    }).catch(() => {});
  }
  await admin.from('google_connections').delete().eq('user_id', userId);
  return json({ ok: true });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  if (req.method === 'GET') return callback(new URL(req.url).searchParams);

  if (req.method === 'POST') {
    const userId = await callerId(req);
    if (!userId) return json({ error: 'Not signed in' }, 401);
    const { action } = await req.json().catch(() => ({}));
    if (action === 'start') return start(userId);
    if (action === 'disconnect') return disconnect(userId);
    return json({ error: `Unknown action: ${action}` }, 400);
  }

  return json({ error: 'Method not allowed' }, 405);
});
