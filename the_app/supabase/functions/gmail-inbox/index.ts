// Supabase Edge Function: gmail-inbox
//
// The enterprise's emails, read from the CALLER's own Gmail: messages to
// or from the people on that enterprise (its Owner, active consultants,
// Admins and the enterprise's contact address). The search is built here
// from enterprise_email_contacts(), called with the caller's JWT, so
// nobody types a filter and nobody sees mail outside that circle.
// Deploy with JWT verification ON.
//
//   POST {action: 'list', enterprise_id, page_token?}
//     -> {messages: [{id, thread_id, from, to, subject, date, snippet, unread}],
//         next_page_token?}
//   POST {action: 'get', enterprise_id, message_id}
//     -> {id, thread_id, from, to, subject, date, body, gmail_url}
//
// 412 {error: 'not_connected'}: no Google connection.
// 412 {error: 'read_not_granted'}: the connection lacks gmail.readonly.
//
// Scope: https://www.googleapis.com/auth/gmail.readonly is a RESTRICTED
// Google scope. It is NOT requested by google-oauth yet: Google is
// reviewing the current scopes (DO_NOT_BREAK.md section 7), and a
// restricted scope needs its own verification plus an annual third-party
// security assessment before a public launch. While the app is in
// Testing, listed test users could use it once the scope is added.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { accessTokenFor, NotConnectedError } from '../_shared/google.ts';
import { rateLimited, serve, serverError } from '../_shared/http.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const GMAIL = 'https://gmail.googleapis.com/gmail/v1/users/me';
const PAGE_SIZE = 20;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

class ReadNotGrantedError extends Error {}

async function gmail(token: string, path: string): Promise<Record<string, unknown>> {
  const res = await fetch(`${GMAIL}/${path}`, { headers: { Authorization: `Bearer ${token}` } });
  const body = await res.json().catch(() => ({}));
  if (res.ok) return body;
  const message: string = body.error?.message ?? res.statusText;
  if (res.status === 403 && (/insufficient|scope/i.test(message) || JSON.stringify(body).includes('SCOPE_INSUFFICIENT'))) {
    throw new ReadNotGrantedError();
  }
  throw new Error(`Gmail: ${message}`);
}

type Header = { name: string; value: string };
type Part = { mimeType?: string; body?: { data?: string }; parts?: Part[]; headers?: Header[] };

const header = (headers: Header[] | undefined, name: string) =>
  headers?.find((h) => h.name.toLowerCase() === name.toLowerCase())?.value ?? '';

function decode(data: string): string {
  const bin = atob(data.replace(/-/g, '+').replace(/_/g, '/'));
  return new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
}

/// The message as plain text: its text/plain part, else its HTML with
/// the tags stripped.
function bodyText(part: Part): string {
  const find = (p: Part, type: string): string | null => {
    if (p.mimeType === type && p.body?.data) return decode(p.body.data);
    for (const child of p.parts ?? []) {
      const found = find(child, type);
      if (found) return found;
    }
    return null;
  };
  const plain = find(part, 'text/plain');
  if (plain) return plain;
  const html = find(part, 'text/html');
  if (!html) return '';
  return html
    .replace(/<(style|script)[\s\S]*?<\/\1>/gi, '')
    .replace(/<br\s*\/?>|<\/p>|<\/div>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/// Addresses on this enterprise, from the same RPC the "Write email"
/// dialog uses (so RLS-equivalent rules apply).
async function contactEmails(userClient: ReturnType<typeof createClient>, enterpriseId: string): Promise<string[]> {
  const { data, error } = await userClient.rpc('enterprise_email_contacts', { p_enterprise_id: enterpriseId });
  if (error) throw new Error(error.message);
  return [...new Set((data as { email: string | null }[]).map((c) => c.email?.trim().toLowerCase()).filter(Boolean) as string[])];
}

function query(emails: string[]): string {
  // Gmail search: any message from or to one of these addresses.
  return `{${emails.map((e) => `from:${e} to:${e} cc:${e}`).join(' ')}}`;
}

function involves(headers: Header[] | undefined, emails: string[]): boolean {
  const people = ['From', 'To', 'Cc'].map((h) => header(headers, h).toLowerCase()).join(' ');
  return emails.some((e) => people.includes(e));
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
  const limited = await rateLimited(`gmail-inbox:${userData.user.id}`, 300, 3600);
  if (limited) return limited;

  try {
    const input = await req.json();
    const enterpriseId = String(input.enterprise_id ?? '');
    if (!enterpriseId) return json({ error: 'enterprise_id is required' }, 400);
    const emails = await contactEmails(userClient, enterpriseId);
    if (emails.length === 0) return json({ messages: [] });
    const token = await accessTokenFor(userData.user.id);

    if (input.action === 'list') {
      const params = new URLSearchParams({ q: query(emails), maxResults: String(PAGE_SIZE) });
      if (input.page_token) params.set('pageToken', String(input.page_token));
      const list = await gmail(token, `messages?${params}`);
      const ids = ((list.messages ?? []) as { id: string }[]).map((m) => m.id);
      const metas = await Promise.all(
        ids.map((id) =>
          gmail(token, `messages/${id}?format=metadata&metadataHeaders=From&metadataHeaders=To&metadataHeaders=Subject&metadataHeaders=Date`),
        ),
      );
      return json({
        messages: metas.map((m) => {
          const headers = (m.payload as Part | undefined)?.headers;
          return {
            id: m.id,
            thread_id: m.threadId,
            from: header(headers, 'From'),
            to: header(headers, 'To'),
            subject: header(headers, 'Subject'),
            date: m.internalDate ? new Date(Number(m.internalDate)).toISOString() : null,
            snippet: m.snippet ?? '',
            unread: ((m.labelIds ?? []) as string[]).includes('UNREAD'),
          };
        }),
        next_page_token: list.nextPageToken ?? null,
      });
    }

    if (input.action === 'get') {
      const id = String(input.message_id ?? '');
      if (!/^[a-zA-Z0-9]+$/.test(id)) return json({ error: 'message_id is invalid' }, 400);
      const m = await gmail(token, `messages/${id}?format=full`);
      const payload = m.payload as Part;
      // Only mail involving this enterprise's people, never any message
      // the caller can guess an id for.
      if (!involves(payload.headers, emails)) return json({ error: 'Not an email for this enterprise' }, 403);
      return json({
        id: m.id,
        thread_id: m.threadId,
        from: header(payload.headers, 'From'),
        to: header(payload.headers, 'To'),
        subject: header(payload.headers, 'Subject'),
        date: m.internalDate ? new Date(Number(m.internalDate)).toISOString() : null,
        body: bodyText(payload).slice(0, 50_000),
        gmail_url: `https://mail.google.com/mail/u/0/#all/${m.threadId}`,
      });
    }
    return json({ error: `Unknown action: ${input.action}` }, 400);
  } catch (e) {
    if (e instanceof NotConnectedError) return json({ error: 'not_connected' }, 412);
    if (e instanceof ReadNotGrantedError) return json({ error: 'read_not_granted' }, 412);
    return serverError(e);
  }
});
