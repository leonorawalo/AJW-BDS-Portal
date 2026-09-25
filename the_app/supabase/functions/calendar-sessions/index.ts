// Supabase Edge Function: calendar-sessions
//
// Books / cancels a consultation session on the calling Consultant's own
// Google Calendar, with a Google Meet link, inviting the enterprise
// Owner by email. Deploy with JWT verification ON.
//
//   POST {action: 'create', enterprise_id, title, description?,
//         starts_at, ends_at}          (ISO-8601 timestamps)
//        -> the inserted consultation_sessions row
//   POST {action: 'cancel', session_id}
//        -> {ok: true}
//
// Errors the app handles specially: 412 {error: 'not_connected'} when
// the consultant hasn't connected Google (or their grant was revoked /
// expired — the stale connection is deleted so the app shows "Connect"
// again).
//
// The consultation_sessions row is read/written with the *caller's*
// JWT, so RLS (assigned consultant, own sessions only) stays the real
// boundary. The service-role client is only used for what RLS
// deliberately hides from every app user: the stored refresh token and
// the Owner's email address.
//
// Required secrets: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET (shared with
// google-oauth). SUPABASE_URL / SUPABASE_ANON_KEY /
// SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const CALENDAR_API = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';
const TIME_ZONE = 'Africa/Nairobi';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

class NotConnectedError extends Error {}

/// Exchanges the stored refresh token for a short-lived access token.
/// invalid_grant means the user revoked access in their Google account
/// (or, while the OAuth app is in "Testing", the 7-day token lifetime
/// ran out) — drop the dead connection so the app offers to reconnect.
async function accessTokenFor(userId: string): Promise<string> {
  const { data } = await admin
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
      await admin.from('google_connections').delete().eq('user_id', userId);
      throw new NotConnectedError();
    }
    throw new Error(`Google token refresh failed: ${body.error_description ?? body.error}`);
  }
  return body.access_token as string;
}

/// The Owner's login email if the enterprise is linked to an account,
/// otherwise the enterprise's own contact email. Null if neither exists
/// — the session is still created, just without an invitee.
async function ownerEmail(enterpriseId: string): Promise<string | null> {
  const { data } = await admin
    .from('enterprises')
    .select('email, owner:owner_user_id(email)')
    .eq('id', enterpriseId)
    .maybeSingle();
  // deno-lint-ignore no-explicit-any
  return ((data?.owner as any)?.email as string | undefined) ?? data?.email ?? null;
}

async function create(userClient: SupabaseClient, userId: string, input: Record<string, unknown>) {
  const enterpriseId = input.enterprise_id as string;
  const title = String(input.title ?? '').trim();
  const startsAt = new Date(String(input.starts_at));
  const endsAt = new Date(String(input.ends_at));
  if (!enterpriseId || !title) return json({ error: 'enterprise_id and title are required' }, 400);
  if (isNaN(startsAt.getTime()) || isNaN(endsAt.getTime()) || endsAt <= startsAt) {
    return json({ error: 'starts_at/ends_at are invalid' }, 400);
  }

  // Checked before touching Google so an unassigned caller can't create
  // a calendar event even though the DB insert would be refused anyway.
  const { data: assigned } = await userClient.rpc('is_assigned_consultant', {
    target_enterprise_id: enterpriseId,
  });
  if (!assigned) return json({ error: 'You are not assigned to this enterprise' }, 403);

  const accessToken = await accessTokenFor(userId);
  const invitee = await ownerEmail(enterpriseId);

  const eventRes = await fetch(`${CALENDAR_API}?conferenceDataVersion=1&sendUpdates=all`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      summary: title,
      description: (input.description as string | undefined) ?? undefined,
      start: { dateTime: startsAt.toISOString(), timeZone: TIME_ZONE },
      end: { dateTime: endsAt.toISOString(), timeZone: TIME_ZONE },
      attendees: invitee ? [{ email: invitee }] : [],
      conferenceData: {
        createRequest: {
          requestId: crypto.randomUUID(),
          conferenceSolutionKey: { type: 'hangoutsMeet' },
        },
      },
    }),
  });
  const event = await eventRes.json();
  if (!eventRes.ok) {
    console.error('Calendar insert failed', event);
    return json({ error: `Google Calendar: ${event.error?.message ?? 'event creation failed'}` }, 502);
  }

  const { data: row, error } = await userClient
    .from('consultation_sessions')
    .insert({
      enterprise_id: enterpriseId,
      consultant_id: userId,
      title,
      description: input.description ?? null,
      starts_at: startsAt.toISOString(),
      ends_at: endsAt.toISOString(),
      google_event_id: event.id,
      meet_link: event.hangoutLink ?? null,
      calendar_html_link: event.htmlLink ?? null,
    })
    .select()
    .single();
  if (error) {
    // Don't leave an orphaned event (and a sent invite) the app can't see.
    await fetch(`${CALENDAR_API}/${event.id}?sendUpdates=all`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${accessToken}` },
    }).catch(() => {});
    return json({ error: error.message }, 403);
  }
  return json(row);
}

async function cancel(userClient: SupabaseClient, userId: string, sessionId: string) {
  const { data: session } = await userClient
    .from('consultation_sessions')
    .select('id, consultant_id, google_event_id, status')
    .eq('id', sessionId)
    .maybeSingle();
  if (!session) return json({ error: 'Session not found' }, 404);
  if (session.consultant_id !== userId) {
    return json({ error: 'Only the consultant who booked this session can cancel it' }, 403);
  }
  if (session.status === 'Cancelled') return json({ ok: true });

  if (session.google_event_id) {
    const accessToken = await accessTokenFor(userId);
    const res = await fetch(`${CALENDAR_API}/${session.google_event_id}?sendUpdates=all`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    // 404/410: already deleted on the Google side — still cancel here.
    if (!res.ok && res.status !== 404 && res.status !== 410) {
      const body = await res.json().catch(() => ({}));
      return json({ error: `Google Calendar: ${body.error?.message ?? res.statusText}` }, 502);
    }
  }

  const { error } = await userClient
    .from('consultation_sessions')
    .update({ status: 'Cancelled' })
    .eq('id', sessionId);
  if (error) return json({ error: error.message }, 403);
  return json({ ok: true });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in' }, 401);
  const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(
    authHeader.replace('Bearer ', ''),
  );
  if (userError || !userData.user) return json({ error: 'Not signed in' }, 401);
  const userId = userData.user.id;

  try {
    const input = await req.json();
    if (input.action === 'create') return await create(userClient, userId, input);
    if (input.action === 'cancel') return await cancel(userClient, userId, input.session_id);
    return json({ error: `Unknown action: ${input.action}` }, 400);
  } catch (e) {
    if (e instanceof NotConnectedError) return json({ error: 'not_connected' }, 412);
    console.error(e);
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
