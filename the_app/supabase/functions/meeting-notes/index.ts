// Supabase Edge Function: meeting-notes
//
// Finds the Gemini meeting notes ("Take notes for me") and the transcript
// of a finished Google Meet, using the ORGANIZER's Google connection and
// the Meet REST API, then links them on the session and in the
// enterprise's Files tab (visible only to that meeting's people and
// Admins: see migration 20261008100000). Deploy with JWT verification ON.
//
//   POST {session_id}
//     -> {status: 'pending' | 'ready' | 'none' | 'unavailable',
//         notes_url?, transcript_url?, reason?}
//
// Any member who can see the session may ask (the app asks automatically
// when a past meeting is shown, and from a "Check again" button).
//
// Needs, on the organizer's Google account:
// - the scope https://www.googleapis.com/auth/meetings.space.readonly
//   (NOT requested yet: Google's verification of the current scopes is
//   under review, see DO_NOT_BREAK.md section 7). Until it is added to
//   google-oauth and the organizer reconnects, every meeting comes back
//   'unavailable' with reason 'scope', and the app says notes aren't
//   available for this account.
// - a Google Workspace plan that includes Gemini, for smart notes.
//   Transcripts need a Workspace plan with Meet recording/transcripts.
// - the Google Meet REST API enabled in Cloud project ajw-bags-portal.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { accessTokenFor, NotConnectedError, serviceClient as admin } from '../_shared/google.ts';
import { rateLimited, serve, serverError } from '../_shared/http.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const MEET_API = 'https://meet.googleapis.com/v2';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

type Status = 'pending' | 'ready' | 'none' | 'unavailable';

/// Why notes can't be fetched for this organizer at all (as opposed to
/// "not ready yet").
class UnavailableError extends Error {}

async function meet(token: string, path: string): Promise<Record<string, unknown>> {
  const res = await fetch(`${MEET_API}/${path}`, { headers: { Authorization: `Bearer ${token}` } });
  const body = await res.json().catch(() => ({}));
  if (res.ok) return body;
  const message: string = body.error?.message ?? res.statusText;
  // 403: scope not granted, Meet API disabled, or the account's plan
  // doesn't allow it. 401: token problem. None of these fix themselves.
  if (res.status === 403 || res.status === 401) {
    const scope = /insufficient|scope/i.test(message) || JSON.stringify(body).includes('SCOPE_INSUFFICIENT');
    throw new UnavailableError(scope ? 'scope' : message);
  }
  throw new Error(`Google Meet: ${message}`);
}

/// abc-defg-hij from https://meet.google.com/abc-defg-hij
function meetingCode(link: string | null): string | null {
  const m = link?.match(/meet\.google\.com\/([a-z]{3}-[a-z]{4}-[a-z]{3})/i);
  return m ? m[1] : null;
}

type DocsDestination = { document?: string; exportUri?: string };

function docUrl(dest: DocsDestination | undefined): string | null {
  if (!dest) return null;
  if (dest.exportUri) return dest.exportUri;
  return dest.document ? `https://docs.google.com/document/d/${dest.document}/edit` : null;
}

async function findArtifacts(token: string, code: string) {
  const filter = encodeURIComponent(`space.meeting_code = "${code}"`);
  const records = ((await meet(token, `conferenceRecords?filter=${filter}`)).conferenceRecords ?? []) as {
    name: string;
    endTime?: string;
  }[];
  let notes: { url: string; id?: string } | null = null;
  let transcript: { url: string; id?: string } | null = null;
  let stillRunning = false;
  let anyStarted = false;

  for (const record of records) {
    if (!record.endTime) stillRunning = true;
    const smart = ((await meet(token, `${record.name}/smartNotes`).catch((e) => {
      // Accounts without Gemini get an error here; transcripts may still work.
      if (e instanceof UnavailableError && e.message === 'scope') throw e;
      return {};
    })).smartNotes ?? []) as { state?: string; docsDestination?: DocsDestination }[];
    for (const n of smart) {
      anyStarted = true;
      const url = n.state === 'FILE_GENERATED' ? docUrl(n.docsDestination) : null;
      if (url) notes = { url, id: n.docsDestination?.document };
    }
    const transcripts = ((await meet(token, `${record.name}/transcripts`).catch((e) => {
      if (e instanceof UnavailableError && e.message === 'scope') throw e;
      return {};
    })).transcripts ?? []) as { state?: string; docsDestination?: DocsDestination }[];
    for (const t of transcripts) {
      anyStarted = true;
      const url = t.state === 'FILE_GENERATED' ? docUrl(t.docsDestination) : null;
      if (url) transcript = { url, id: t.docsDestination?.document };
    }
  }
  return { records: records.length, notes, transcript, stillRunning, anyStarted };
}

async function listInFiles(
  session: Record<string, unknown>,
  kindLabel: string,
  doc: { url: string; id?: string },
) {
  await admin.from('enterprise_files').upsert(
    {
      enterprise_id: session.enterprise_id,
      session_id: session.id,
      google_file_id: doc.id ?? doc.url,
      kind: 'doc',
      title: `${kindLabel}: ${session.title}`,
      web_url: doc.url,
      created_by: session.organizer_id,
    },
    { onConflict: 'google_file_id', ignoreDuplicates: true },
  );
}

async function check(sessionId: string, userClient: ReturnType<typeof createClient>) {
  // Read through the caller's JWT first: RLS decides whether they may
  // see this session at all.
  const { data: visible } = await userClient
    .from('consultation_sessions')
    .select('id')
    .eq('id', sessionId)
    .maybeSingle();
  if (!visible) return json({ error: 'Session not found' }, 404);

  const { data: session } = await admin
    .from('consultation_sessions')
    .select('id, enterprise_id, organizer_id, title, meet_link, ends_at, status, notes_status, notes_doc_url, transcript_doc_url')
    .eq('id', sessionId)
    .single();
  if (!session) return json({ error: 'Session not found' }, 404);

  const save = async (status: Status, extra: Record<string, unknown> = {}) => {
    await admin
      .from('consultation_sessions')
      .update({ notes_status: status, notes_checked_at: new Date().toISOString(), ...extra })
      .eq('id', sessionId);
    return json({
      status,
      notes_url: extra.notes_doc_url ?? session.notes_doc_url ?? null,
      transcript_url: extra.transcript_doc_url ?? session.transcript_doc_url ?? null,
      reason: extra.reason,
    });
  };

  if (session.status === 'Cancelled') return save('none');
  if (session.notes_status === 'ready' && session.notes_doc_url && session.transcript_doc_url) {
    return json({ status: 'ready', notes_url: session.notes_doc_url, transcript_url: session.transcript_doc_url });
  }
  const code = meetingCode(session.meet_link as string | null);
  if (!code) return save('none');

  let token: string;
  try {
    token = await accessTokenFor(session.organizer_id as string);
  } catch (e) {
    if (e instanceof NotConnectedError) {
      await admin.from('consultation_sessions').update({ notes_status: 'unavailable', notes_checked_at: new Date().toISOString() }).eq('id', sessionId);
      return json({ status: 'unavailable', reason: 'organizer_not_connected' });
    }
    throw e;
  }

  try {
    const found = await findArtifacts(token, code);
    const notesUrl = found.notes?.url ?? null;
    const transcriptUrl = found.transcript?.url ?? null;
    if (found.notes) await listInFiles(session, 'Meeting notes', found.notes);
    if (found.transcript) await listInFiles(session, 'Transcript', found.transcript);

    if (notesUrl || transcriptUrl) {
      return save('ready', {
        ...(notesUrl ? { notes_doc_url: notesUrl } : {}),
        ...(transcriptUrl ? { transcript_doc_url: transcriptUrl } : {}),
      });
    }
    // Google can take a while after the call to write the documents.
    const endedLongAgo = Date.now() - new Date(session.ends_at as string).getTime() > 24 * 3600_000;
    if (found.stillRunning || found.anyStarted || !endedLongAgo) return save('pending');
    return save('none');
  } catch (e) {
    if (e instanceof UnavailableError) {
      await admin.from('consultation_sessions').update({ notes_status: 'unavailable', notes_checked_at: new Date().toISOString() }).eq('id', sessionId);
      return json({ status: 'unavailable', reason: e.message });
    }
    throw e;
  }
}

serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in' }, 401);
  const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(authHeader.replace('Bearer ', ''));
  if (userError || !userData.user) return json({ error: 'Not signed in' }, 401);
  const limited = await rateLimited(`meeting-notes:${userData.user.id}`, 200, 3600);
  if (limited) return limited;

  try {
    const input = await req.json();
    if (!input.session_id) return json({ error: 'session_id is required' }, 400);
    return await check(String(input.session_id), userClient);
  } catch (e) {
    return serverError(e);
  }
});
