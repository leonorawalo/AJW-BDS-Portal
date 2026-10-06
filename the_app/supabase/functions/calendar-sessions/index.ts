// Supabase Edge Function: calendar-sessions
//
// Books / cancels a meeting on the ORGANIZER's own Google Calendar (with a
// Google Meet link), inviting the chosen participants by email. Any role
// can organise, within the invite rules in session_invitee_candidates()
// (Admin -> Owner/consultants, Consultant -> Owner, Owner ->
// consultants/Admins). Deploy with JWT verification ON.
//
//   POST {action: 'check_availability', enterprise_id, participant_ids,
//         starts_at, ends_at}
//        -> {availability: [{user_id, name, status}]}, status is one of
//           'free' | 'busy' | 'not_connected' | 'unknown'. Includes the
//           organizer (the caller). Only free/busy is read, never event
//           details.
//   POST {action: 'create', enterprise_id, participant_ids, title,
//         description?, starts_at, ends_at, force?}
//        -> the inserted consultation_sessions row
//        -> 409 {error: 'clash', availability} when someone is busy and
//           force isn't true (the app then offers "Book anyway")
//   POST {action: 'cancel', session_id}   (organizer or Admin)
//        -> {ok: true}
//
// 412 {error: 'not_connected'} means the ORGANIZER has no working Google
// connection (or it was revoked / expired: the stale row is deleted so
// the app shows "Connect" again).
//
// Session and participant rows are read/written with the caller's JWT, so
// RLS stays the real boundary. The service-role client is only used for
// what RLS deliberately hides from app users: stored refresh tokens and
// participants' email addresses.
//
// Required secrets: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET (shared with
// google-oauth). SUPABASE_URL / SUPABASE_ANON_KEY /
// SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { accessTokenFor, NotConnectedError, serviceClient as admin } from '../_shared/google.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const CALENDAR_API = 'https://www.googleapis.com/calendar/v3/calendars/primary/events';
const FREEBUSY_API = 'https://www.googleapis.com/calendar/v3/freeBusy';
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

type Availability = { user_id: string; name: string; status: 'free' | 'busy' | 'not_connected' | 'unknown' };

/// Validates the request's time window and participants. Participants
/// must all come from session_invitee_candidates(), called with the
/// caller's JWT, so the invite rules live in one place (the database).
type Meeting = {
  enterpriseId: string;
  startsAt: Date;
  endsAt: Date;
  participantIds: string[];
  names: Map<string, string>;
};

async function parseMeeting(
  userClient: SupabaseClient,
  input: Record<string, unknown>,
): Promise<{ ok: false; response: Response } | ({ ok: true } & Meeting)> {
  const enterpriseId = input.enterprise_id as string | undefined;
  const startsAt = new Date(String(input.starts_at));
  const endsAt = new Date(String(input.ends_at));
  const participantIds = [...new Set((input.participant_ids as string[] | undefined) ?? [])];
  if (!enterpriseId) return { ok: false, response: json({ error: 'enterprise_id is required' }, 400) };
  if (isNaN(startsAt.getTime()) || isNaN(endsAt.getTime()) || endsAt <= startsAt) {
    return { ok: false, response: json({ error: 'starts_at/ends_at are invalid' }, 400) };
  }
  if (participantIds.length === 0) return { ok: false, response: json({ error: 'Pick at least one participant' }, 400) };

  const { data: canSchedule } = await userClient.rpc('can_schedule_for_enterprise', {
    p_enterprise_id: enterpriseId,
  });
  if (!canSchedule) return { ok: false, response: json({ error: 'You cannot schedule meetings for this enterprise' }, 403) };

  const { data: candidates, error } = await userClient.rpc('session_invitee_candidates', {
    p_enterprise_id: enterpriseId,
  });
  if (error) return { ok: false, response: json({ error: error.message }, 500) };
  const names = new Map<string, string>(
    (candidates as { user_id: string; full_name: string }[]).map((c) => [c.user_id, c.full_name]),
  );
  const notAllowed = participantIds.filter((id) => !names.has(id));
  if (notAllowed.length > 0) return { ok: false, response: json({ error: 'You cannot invite some of these people' }, 403) };

  return { ok: true, enterpriseId, startsAt, endsAt, participantIds, names };
}

/// Free/busy for one person on their own primary calendar. Only whether
/// the slot is taken is read: never event titles or details.
async function statusFor(userId: string, startsAt: Date, endsAt: Date): Promise<Availability['status']> {
  let token: string;
  try {
    token = await accessTokenFor(userId);
  } catch (e) {
    if (e instanceof NotConnectedError) return 'not_connected';
    console.error('Token refresh failed during availability check', e);
    return 'unknown';
  }
  const res = await fetch(FREEBUSY_API, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      timeMin: startsAt.toISOString(),
      timeMax: endsAt.toISOString(),
      items: [{ id: 'primary' }],
    }),
  });
  const body = await res.json().catch(() => ({}));
  // 403 here usually means the person connected before the
  // calendar.freebusy scope was added: they need to reconnect.
  if (!res.ok) {
    console.error('freeBusy failed', res.status, body.error?.message);
    return 'unknown';
  }
  const busy = body.calendars?.primary?.busy ?? [];
  return busy.length > 0 ? 'busy' : 'free';
}

async function availability(
  organizerId: string,
  participantIds: string[],
  names: Map<string, string>,
  startsAt: Date,
  endsAt: Date,
): Promise<Availability[]> {
  const people = [organizerId, ...participantIds];
  const statuses = await Promise.all(people.map((id) => statusFor(id, startsAt, endsAt)));
  return people.map((id, i) => ({
    user_id: id,
    name: id === organizerId ? 'You' : names.get(id) ?? 'Participant',
    status: statuses[i],
  }));
}

async function checkAvailability(userClient: SupabaseClient, userId: string, input: Record<string, unknown>) {
  const m = await parseMeeting(userClient, input);
  if (!m.ok) return m.response;
  return json({ availability: await availability(userId, m.participantIds, m.names, m.startsAt, m.endsAt) });
}

async function create(userClient: SupabaseClient, userId: string, input: Record<string, unknown>) {
  const title = String(input.title ?? '').trim();
  if (!title) return json({ error: 'title is required' }, 400);
  const m = await parseMeeting(userClient, input);
  if (!m.ok) return m.response;

  // Fails fast with not_connected before anything else if the organizer
  // can't book on their own calendar.
  const accessToken = await accessTokenFor(userId);

  // Re-checked here even though the app checks as the user picks a time:
  // calendars change, and the app's check could be stale.
  const avail = await availability(userId, m.participantIds, m.names, m.startsAt, m.endsAt);
  if (input.force !== true && avail.some((a) => a.status === 'busy')) {
    return json({ error: 'clash', availability: avail }, 409);
  }

  const { data: users } = await admin.from('users').select('id, email').in('id', m.participantIds);
  const emails = (users ?? []).map((u) => u.email as string).filter(Boolean);

  const eventRes = await fetch(`${CALENDAR_API}?conferenceDataVersion=1&sendUpdates=all`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      summary: title,
      description: (input.description as string | undefined) ?? undefined,
      start: { dateTime: m.startsAt.toISOString(), timeZone: TIME_ZONE },
      end: { dateTime: m.endsAt.toISOString(), timeZone: TIME_ZONE },
      attendees: emails.map((email) => ({ email })),
      // Group meetings: invitees don't see each other (same rule the app
      // applies in session_people()).
      guestsCanSeeOtherGuests: emails.length <= 1,
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

  const deleteEvent = () =>
    fetch(`${CALENDAR_API}/${event.id}?sendUpdates=all`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${accessToken}` },
    }).catch(() => {});

  const { data: row, error } = await userClient
    .from('consultation_sessions')
    .insert({
      enterprise_id: m.enterpriseId,
      organizer_id: userId,
      title,
      description: input.description ?? null,
      starts_at: m.startsAt.toISOString(),
      ends_at: m.endsAt.toISOString(),
      google_event_id: event.id,
      meet_link: event.hangoutLink ?? null,
      calendar_html_link: event.htmlLink ?? null,
    })
    .select()
    .single();
  if (error) {
    // Don't leave an orphaned event (and sent invites) the app can't see.
    await deleteEvent();
    return json({ error: error.message }, 403);
  }

  const { error: participantsError } = await userClient
    .from('session_participants')
    .insert(m.participantIds.map((id) => ({ session_id: row.id, user_id: id })));
  if (participantsError) {
    // Rows can't be deleted by app users; cancel it instead so it's never
    // a live session nobody can see.
    await deleteEvent();
    await userClient.from('consultation_sessions').update({ status: 'Cancelled' }).eq('id', row.id);
    return json({ error: participantsError.message }, 403);
  }
  return json(row);
}

async function cancel(userClient: SupabaseClient, userId: string, sessionId: string) {
  const { data: session } = await userClient
    .from('consultation_sessions')
    .select('id, organizer_id, google_event_id, status')
    .eq('id', sessionId)
    .maybeSingle();
  if (!session) return json({ error: 'Session not found' }, 404);
  const { data: isAdmin } = await userClient.rpc('is_admin');
  if (session.organizer_id !== userId && !isAdmin) {
    return json({ error: 'Only the organizer (or an Admin) can cancel this session' }, 403);
  }
  if (session.status === 'Cancelled') return json({ ok: true });

  if (session.google_event_id) {
    // The event lives on the organizer's calendar, even when an Admin
    // cancels someone else's session.
    const accessToken = await accessTokenFor(session.organizer_id);
    const res = await fetch(`${CALENDAR_API}/${session.google_event_id}?sendUpdates=all`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    // 404/410: already deleted on the Google side: still cancel here.
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
    if (input.action === 'check_availability') return await checkAvailability(userClient, userId, input);
    if (input.action === 'create') return await create(userClient, userId, input);
    if (input.action === 'cancel') return await cancel(userClient, userId, input.session_id);
    return json({ error: `Unknown action: ${input.action}` }, 400);
  } catch (e) {
    if (e instanceof NotConnectedError) return json({ error: 'not_connected' }, 412);
    console.error(e);
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
