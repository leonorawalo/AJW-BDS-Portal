// Supabase Edge Function: drive-files   (B2: working Google files per enterprise)
//
// Deploy with JWT verification ON.
//
//   POST {action: 'create', enterprise_id, kind: 'doc'|'sheet'|'slides', title}
//        -> {file: <enterprise_files row>, shared_with: string[], not_shared: string[]}
//   POST {action: 'share', file_id}          (enterprise_files.id; creator only)
//        -> {shared_with: string[], not_shared: string[]}
//
// The file is created in the CALLER's own Drive (drive.file scope), inside
// "AJW BAGS Portal / <enterprise>", then shared as editor with the
// enterprise's Owner and active consultants. Admins see it listed in the
// portal and can request access in Google, which keeps their Drives
// uncluttered. The enterprise_files row is written with the caller's JWT, so
// its RLS is the boundary.
//
// Only the creator's Google account can change the file's sharing, so
// 'share' (e.g. after a new consultant is assigned) is the creator's action.
// Addresses Google can't share with (no Google account behind them) are
// returned in not_shared rather than failing the whole request.

import { createClient } from 'jsr:@supabase/supabase-js@2';
import {
  accessTokenFor,
  ensureEnterpriseFolder,
  google,
  NotConnectedError,
  ReconnectNeededError,
  serviceClient,
} from '../_shared/google.ts';

const MIME: Record<string, string> = {
  doc: 'application/vnd.google-apps.document',
  sheet: 'application/vnd.google-apps.spreadsheet',
  slides: 'application/vnd.google-apps.presentation',
};

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

/// The enterprise's Owner and active consultants, minus the creator.
async function memberEmails(enterpriseId: string, excludeUserId: string): Promise<string[]> {
  const { data: enterprise } = await serviceClient
    .from('enterprises')
    .select('owner_user_id')
    .eq('id', enterpriseId)
    .maybeSingle();
  const { data: assignments } = await serviceClient
    .from('consultant_assignments')
    .select('consultant_id')
    .eq('enterprise_id', enterpriseId)
    .eq('assignment_status', 'active');
  const ids = new Set<string>((assignments ?? []).map((a) => a.consultant_id as string));
  if (enterprise?.owner_user_id) ids.add(enterprise.owner_user_id as string);
  ids.delete(excludeUserId);
  if (ids.size === 0) return [];
  const { data: users } = await serviceClient
    .from('users')
    .select('email')
    .in('id', [...ids])
    .eq('status', 'active');
  return (users ?? []).map((u) => String(u.email).toLowerCase()).filter(Boolean);
}

/// Adds editor access for each address that doesn't have it yet. No
/// notification email: the file shows up in the portal's Files list.
async function shareWith(token: string, fileId: string, emails: string[]) {
  const existing = await google(
    token,
    `https://www.googleapis.com/drive/v3/files/${fileId}/permissions?fields=permissions(emailAddress)`,
  );
  const have = new Set(
    ((existing.permissions as { emailAddress?: string }[] | undefined) ?? [])
      .map((p) => p.emailAddress?.toLowerCase())
      .filter(Boolean),
  );
  const shared: string[] = [];
  const notShared: string[] = [];
  for (const email of emails) {
    if (have.has(email)) {
      shared.push(email);
      continue;
    }
    try {
      await google(
        token,
        `https://www.googleapis.com/drive/v3/files/${fileId}/permissions?sendNotificationEmail=false&fields=id`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ type: 'user', role: 'writer', emailAddress: email }),
        },
      );
      shared.push(email);
    } catch (e) {
      if (e instanceof ReconnectNeededError) throw e;
      console.warn(`Could not share ${fileId} with ${email}:`, e instanceof Error ? e.message : e);
      notShared.push(email);
    }
  }
  return { shared, notShared };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in' }, 401);
  const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser(authHeader.replace('Bearer ', ''));
  if (userError || !userData.user) return json({ error: 'Not signed in' }, 401);
  const userId = userData.user.id;

  let input: { action?: string; enterprise_id?: string; kind?: string; title?: string; file_id?: string };
  try {
    input = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }

  try {
    if (input.action === 'create') {
      const enterpriseId = input.enterprise_id;
      const kind = input.kind ?? '';
      const title = String(input.title ?? '').trim().slice(0, 200);
      if (!enterpriseId || !MIME[kind] || !title) return json({ error: 'enterprise_id, kind and title are required' }, 400);

      const { data: allowed } = await userClient.rpc('can_schedule_for_enterprise', { p_enterprise_id: enterpriseId });
      if (!allowed) return json({ error: "You don't work on this enterprise" }, 403);
      const { data: enterprise } = await userClient
        .from('enterprises')
        .select('business_name')
        .eq('id', enterpriseId)
        .maybeSingle();

      const token = await accessTokenFor(userId);
      const folderId = await ensureEnterpriseFolder(token, enterpriseId, enterprise?.business_name ?? 'Enterprise');
      const file = await google(token, 'https://www.googleapis.com/drive/v3/files?fields=id,webViewLink', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: title, mimeType: MIME[kind], parents: [folderId] }),
      });
      const fileId = file.id as string;
      const { shared, notShared } = await shareWith(token, fileId, await memberEmails(enterpriseId, userId));

      const { data: row, error } = await userClient
        .from('enterprise_files')
        .insert({
          enterprise_id: enterpriseId,
          google_file_id: fileId,
          kind,
          title,
          web_url: file.webViewLink as string,
          last_shared_at: new Date().toISOString(),
        })
        .select()
        .single();
      if (error) {
        // Don't leave a file in their Drive that the portal can't list.
        await google(token, `https://www.googleapis.com/drive/v3/files/${fileId}`, { method: 'DELETE' }).catch(() => {});
        return json({ error: error.message }, 403);
      }
      return json({ file: row, shared_with: shared, not_shared: notShared });
    }

    if (input.action === 'share') {
      const { data: row } = await userClient
        .from('enterprise_files')
        .select('id, enterprise_id, google_file_id, created_by')
        .eq('id', input.file_id ?? '')
        .maybeSingle();
      if (!row) return json({ error: 'File not found' }, 404);
      if (row.created_by !== userId) {
        return json({ error: "Only the person who created this file can update its sharing" }, 403);
      }
      const token = await accessTokenFor(userId);
      const result = await shareWith(token, row.google_file_id, await memberEmails(row.enterprise_id, userId));
      await userClient.from('enterprise_files').update({ last_shared_at: new Date().toISOString() }).eq('id', row.id);
      return json({ shared_with: result.shared, not_shared: result.notShared });
    }

    return json({ error: `Unknown action: ${input.action}` }, 400);
  } catch (e) {
    if (e instanceof NotConnectedError) return json({ error: 'not_connected' }, 412);
    if (e instanceof ReconnectNeededError) return json({ error: 'reconnect_needed' }, 412);
    console.error(e);
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
