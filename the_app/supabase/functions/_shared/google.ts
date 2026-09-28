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
