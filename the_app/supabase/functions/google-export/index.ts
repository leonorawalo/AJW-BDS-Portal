// Supabase Edge Function: google-export
//
// Creates a Google Doc, Sheet or Slides deck in the CALLER's own Google
// Drive, inside an "AJW BAGS Portal" folder, and returns its link.
// Deploy with JWT verification ON.
//
//   POST {kind: 'doc', title, html}
//   POST {kind: 'sheet', title, tabs: [{name, rows: (string|number|null)[][]}]}
//        (the first row of each tab is treated as a header)
//   POST {kind: 'slides', title, subtitle?, slides: [{title, bullets: string[]}]}
//     -> {id, url}
//
// "The app composes, the server publishes": the app builds the content
// from data it already loaded under the user's own RLS, so an export can
// never contain more than the user can see in the app, and the
// loan-readiness scoring isn't duplicated here. This function only holds
// the Google token and talks to Google.
//
// Scope: drive.file — the app can create files and see only the files it
// created, never the rest of the user's Drive.
//
// Errors the app handles specially (412):
//   {error: 'not_connected'}    no working Google connection
//   {error: 'reconnect_needed'} connected before drive.file was added —
//                                reconnect once to grant it

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { accessTokenFor, ensureFolder, google, NotConnectedError, ReconnectNeededError } from '../_shared/google.ts';

const MAX_BODY_BYTES = 2_000_000;

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

/// Sheets/Slides create files in My Drive's root; move them into the folder.
async function moveToFolder(token: string, fileId: string, folderId: string): Promise<void> {
  const file = await google(token, `https://www.googleapis.com/drive/v3/files/${fileId}?fields=parents`);
  const parents = ((file.parents as string[] | undefined) ?? []).join(',');
  await google(
    token,
    `https://www.googleapis.com/drive/v3/files/${fileId}?addParents=${folderId}` +
      (parents ? `&removeParents=${parents}` : '') +
      '&fields=id',
    { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: '{}' },
  );
}

/// HTML uploaded with conversion to a Google Doc: Drive turns headings,
/// lists and tables into native Docs formatting in one call.
async function createDoc(token: string, folderId: string, title: string, html: string) {
  const boundary = `ajw${crypto.randomUUID()}`;
  const metadata = {
    name: title,
    mimeType: 'application/vnd.google-apps.document',
    parents: [folderId],
  };
  const body =
    `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${JSON.stringify(metadata)}\r\n` +
    `--${boundary}\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n${html}\r\n` +
    `--${boundary}--`;
  const file = await google(
    token,
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,webViewLink',
    { method: 'POST', headers: { 'Content-Type': `multipart/related; boundary=${boundary}` }, body },
  );
  return { id: file.id as string, url: file.webViewLink as string };
}

type Cell = string | number | null;

function cell(value: Cell, header: boolean) {
  const userEnteredValue =
    typeof value === 'number' ? { numberValue: value } : { stringValue: value == null ? '' : String(value) };
  return header ? { userEnteredValue, userEnteredFormat: { textFormat: { bold: true } } } : { userEnteredValue };
}

async function createSheet(
  token: string,
  folderId: string,
  title: string,
  tabs: { name: string; rows: Cell[][] }[],
) {
  const sheet = await google(token, 'https://sheets.googleapis.com/v4/spreadsheets', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      properties: { title },
      sheets: tabs.map((tab) => ({
        properties: { title: tab.name.slice(0, 100), gridProperties: { frozenRowCount: 1 } },
        data: [{ rowData: tab.rows.map((row, i) => ({ values: row.map((v) => cell(v, i === 0)) })) }],
      })),
    }),
  });
  const id = sheet.spreadsheetId as string;
  await moveToFolder(token, id, folderId);
  return { id, url: sheet.spreadsheetUrl as string };
}

/// A title slide, then one "title and body" slide per entry with the
/// bullets as a bulleted list.
async function createSlides(
  token: string,
  folderId: string,
  title: string,
  subtitle: string | undefined,
  slides: { title: string; bullets: string[] }[],
) {
  const deck = await google(token, 'https://slides.googleapis.com/v1/presentations', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title }),
  });
  const id = deck.presentationId as string;
  const defaultSlideId = (deck.slides as { objectId: string }[] | undefined)?.[0]?.objectId;

  const requests: Record<string, unknown>[] = [];
  if (defaultSlideId) requests.push({ deleteObject: { objectId: defaultSlideId } });

  requests.push({
    createSlide: {
      objectId: 'slide_cover',
      slideLayoutReference: { predefinedLayout: 'TITLE' },
      placeholderIdMappings: [
        { layoutPlaceholder: { type: 'CENTERED_TITLE' }, objectId: 'slide_cover_title' },
        { layoutPlaceholder: { type: 'SUBTITLE' }, objectId: 'slide_cover_subtitle' },
      ],
    },
  });
  requests.push({ insertText: { objectId: 'slide_cover_title', text: title } });
  if (subtitle) requests.push({ insertText: { objectId: 'slide_cover_subtitle', text: subtitle } });

  slides.forEach((slide, i) => {
    const titleId = `slide_${i}_title`;
    const bodyId = `slide_${i}_body`;
    const bullets = slide.bullets.filter((b) => b.trim().length > 0);
    requests.push({
      createSlide: {
        objectId: `slide_${i}`,
        slideLayoutReference: { predefinedLayout: 'TITLE_AND_BODY' },
        placeholderIdMappings: [
          { layoutPlaceholder: { type: 'TITLE' }, objectId: titleId },
          { layoutPlaceholder: { type: 'BODY' }, objectId: bodyId },
        ],
      },
    });
    requests.push({ insertText: { objectId: titleId, text: slide.title || ' ' } });
    requests.push({ insertText: { objectId: bodyId, text: bullets.length > 0 ? bullets.join('\n') : '—' } });
    if (bullets.length > 0) {
      requests.push({
        createParagraphBullets: {
          objectId: bodyId,
          textRange: { type: 'ALL' },
          bulletPreset: 'BULLET_DISC_CIRCLE_SQUARE',
        },
      });
    }
  });

  await google(token, `https://slides.googleapis.com/v1/presentations/${id}:batchUpdate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ requests }),
  });
  await moveToFolder(token, id, folderId);
  return { id, url: `https://docs.google.com/presentation/d/${id}/edit` };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in' }, 401);
  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(
    authHeader.replace('Bearer ', ''),
  );
  if (userError || !userData.user) return json({ error: 'Not signed in' }, 401);

  const raw = await req.text();
  if (raw.length > MAX_BODY_BYTES) return json({ error: 'Export is too large' }, 413);

  try {
    const input = JSON.parse(raw);
    const title = String(input.title ?? '').trim().slice(0, 200);
    if (!title) return json({ error: 'title is required' }, 400);

    const token = await accessTokenFor(userData.user.id);
    const folderId = await ensureFolder(token);

    if (input.kind === 'doc') {
      if (typeof input.html !== 'string') return json({ error: 'html is required' }, 400);
      return json(await createDoc(token, folderId, title, input.html));
    }
    if (input.kind === 'sheet') {
      if (!Array.isArray(input.tabs) || input.tabs.length === 0) return json({ error: 'tabs are required' }, 400);
      return json(await createSheet(token, folderId, title, input.tabs));
    }
    if (input.kind === 'slides') {
      if (!Array.isArray(input.slides)) return json({ error: 'slides are required' }, 400);
      return json(await createSlides(token, folderId, title, input.subtitle, input.slides));
    }
    return json({ error: `Unknown kind: ${input.kind}` }, 400);
  } catch (e) {
    if (e instanceof NotConnectedError) return json({ error: 'not_connected' }, 412);
    if (e instanceof ReconnectNeededError) return json({ error: 'reconnect_needed' }, 412);
    console.error(e);
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
