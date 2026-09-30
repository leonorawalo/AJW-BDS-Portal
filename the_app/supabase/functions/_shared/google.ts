// Shared by the Edge Functions that call Google APIs on a user's behalf
// (calendar-sessions, google-export). Refresh tokens live in
// google_connections, which only the service role can read — they never
// reach the app.

import { createClient } from 'jsr:@supabase/supabase-js@2';

export const serviceClient = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

/// The user has no working Google connection — never connected, revoked
/// access, or (while the OAuth app is in "Testing") the 7-day refresh
/// token lifetime ran out.
export class NotConnectedError extends Error {}

/// Exchanges the stored refresh token for a short-lived access token.
/// invalid_grant drops the dead connection so the app offers to reconnect.
export async function accessTokenFor(userId: string): Promise<string> {
  const { data } = await serviceClient
    .from('google_connections')
    .select('refresh_token')
    .eq('user_id', userId)
    .maybeSingle();
  if (!data) throw new NotConnectedError();

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: Deno.env.get('GOOGLE_CLIENT_ID')!,
      client_secret: Deno.env.get('GOOGLE_CLIENT_SECRET')!,
      refresh_token: data.refresh_token,
      grant_type: 'refresh_token',
    }),
  });
  const body = await res.json();
  if (!res.ok) {
    if (body.error === 'invalid_grant') {
      await serviceClient.from('google_connections').delete().eq('user_id', userId);
      throw new NotConnectedError();
    }
    throw new Error(`Google token refresh failed: ${body.error_description ?? body.error}`);
  }
  return body.access_token as string;
}

const FOLDER_NAME = 'AJW BAGS Portal';
const FOLDER_MARKER = 'ajwBagsPortalFolder';

/// The user's token lacks a scope added after they connected (e.g.
/// drive.file, gmail.send) — they need to reconnect once.
export class ReconnectNeededError extends Error {}

/// fetch against a Google API with the user's token. A 403 about scopes
/// means the connection predates drive.file.
export async function google(token: string, url: string, init: RequestInit = {}): Promise<Record<string, unknown>> {
  const res = await fetch(url, {
    ...init,
    headers: { Authorization: `Bearer ${token}`, ...(init.headers ?? {}) },
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message: string = body.error?.message ?? res.statusText;
    const insufficient =
      res.status === 403 &&
      (/insufficient/i.test(message) || JSON.stringify(body).includes('ACCESS_TOKEN_SCOPE_INSUFFICIENT'));
    if (insufficient) throw new ReconnectNeededError();
    throw new Error(`Google: ${message}`);
  }
  return body;
}

/// The app's own folder, found by a private marker property (drive.file
/// can list files this app created), created on first export.
export async function ensureFolder(token: string): Promise<string> {
  const q = `appProperties has { key='${FOLDER_MARKER}' and value='1' } and trashed = false`;
  const found = await google(
    token,
    `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=files(id)&spaces=drive`,
  );
  const files = found.files as { id: string }[] | undefined;
  if (files && files.length > 0) return files[0].id;

  const created = await google(token, 'https://www.googleapis.com/drive/v3/files?fields=id', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: FOLDER_NAME,
      mimeType: 'application/vnd.google-apps.folder',
      appProperties: { [FOLDER_MARKER]: '1' },
    }),
  });
  return created.id as string;
}

/// A per-enterprise subfolder inside the app folder, found by a private
/// marker (the enterprise id), so renaming it in Drive doesn't break it.
export async function ensureEnterpriseFolder(token: string, enterpriseId: string, name: string): Promise<string> {
  const parent = await ensureFolder(token);
  const q = `appProperties has { key='ajwBagsEnterprise' and value='${enterpriseId}' } and trashed = false`;
  const found = await google(
    token,
    `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=files(id)&spaces=drive`,
  );
  const files = found.files as { id: string }[] | undefined;
  if (files && files.length > 0) return files[0].id;

  const created = await google(token, 'https://www.googleapis.com/drive/v3/files?fields=id', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name,
      mimeType: 'application/vnd.google-apps.folder',
      parents: [parent],
      appProperties: { ajwBagsEnterprise: enterpriseId },
    }),
  });
  return created.id as string;
}
