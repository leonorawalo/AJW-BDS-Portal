// Supabase Edge Function: send-push
//
// Triggered by a Database Webhook (configured in the Supabase dashboard,
// NOT in a committed migration — see setup notes handed to the developer
// separately) on INSERT to `consultant_assignments` and `tasks`. Resolves
// who should be notified, looks up their device_tokens, and sends a push
// via the FCM HTTP v1 API using a Firebase service account.
//
// Required secrets (set with `supabase secrets set`, never committed):
//   FIREBASE_PROJECT_ID   — e.g. ajwafrica-bags-portal
//   FIREBASE_CLIENT_EMAIL — from the service account JSON
//   FIREBASE_PRIVATE_KEY  — from the service account JSON, `\n` literal
//                            escapes are unescaped to real newlines below
//   WEBHOOK_SECRET         — shared secret checked against the
//                            x-webhook-secret header set on the Database
//                            Webhook, so this function can't be invoked
//                            by anyone who just finds the URL
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically
// by the Edge Functions runtime — no need to set them.

import { createClient } from 'jsr:@supabase/supabase-js@2';

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  record: Record<string, unknown>;
  /// Only present on UPDATE — the row's values before this change.
  old_record?: Record<string, unknown>;
  schema: string;
}

interface NotificationTarget {
  userIds: string[];
  title: string;
  body: string;
}

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

/// The ToR/Accounting checklist tasks that actually move the
/// Business Health / Credit Readiness scores — see
/// lib/features/legal_workstream/models/loan_readiness.dart. Kept as
/// its own list (not importable from the Dart side) so completing one
/// of these gets a "loan readiness improved" message instead of a
/// generic "task completed" one. Keep in sync with that file.
const SCORE_RELEVANT_TASK_TITLES = new Set([
  'Complete business registration',
  'Acquire KRA PIN',
  'Confirm monthly KRA returns filed',
  'Acquire trading licenses',
  'Set up financial record-keeping system',
  'Compile 6 months of bank statements',
  'Obtain 3 years of audited accounts',
  'Document available collateral for financing',
  'Check CRB status',
]);

/// Admin gets oversight visibility on assignment/completion events, on
/// top of whoever the event is specifically about. Cached per-request
/// isn't needed — Deno instances are warm/short-lived either way.
async function getAdminUserIds(): Promise<string[]> {
  const { data: admins } = await supabase
    .from('users')
    .select('id, roles!inner(role_name)')
    .eq('roles.role_name', 'Administrator');
  return (admins ?? []).map((a) => a.id as string);
}

/// Decides who gets notified and what the push says, based on which
/// table fired the webhook. Returns null for rows that shouldn't
/// trigger anything (e.g. an 'ended' assignment row, a task edit that
/// isn't a completion).
async function resolveTarget(payload: WebhookPayload): Promise<NotificationTarget | null> {
  const { type, table, record, old_record } = payload;

  if (table === 'users' && type === 'INSERT') {
    const adminIds = await getAdminUserIds();
    if (adminIds.length === 0) return null;

    return {
      userIds: adminIds,
      title: 'New user registered',
      body: `${record.first_name} ${record.last_name} signed up.`,
    };
  }

  if (table === 'consultant_assignments' && type === 'INSERT') {
    if (record.assignment_status !== 'active') return null;

    const enterpriseId = record.enterprise_id as string;
    const consultantId = record.consultant_id as string;
    const specialization = (record.specialization as string | null) ?? 'A';

    const { data: enterprise } = await supabase
      .from('enterprises')
      .select('owner_user_id, business_name')
      .eq('id', enterpriseId)
      .maybeSingle();
    if (!enterprise) return null;

    // owner_user_id can be null — an enterprise registered before its
    // Owner has an account, or one an Admin hasn't linked yet (see
    // EnterpriseDetailsTab._OwnerAccountLink). Still notify the
    // consultant and admins either way.
    const userIds = [consultantId, ...(await getAdminUserIds())];
    if (enterprise.owner_user_id) userIds.push(enterprise.owner_user_id as string);

    return {
      userIds,
      title: 'Consultant assigned',
      body: `${specialization} consultant assigned to ${enterprise.business_name}.`,
    };
  }

  if (table === 'tasks' && type === 'INSERT') {
    const { data: enterprise } = await supabase
      .from('enterprises')
      .select('business_name')
      .eq('id', record.enterprise_id as string)
      .maybeSingle();

    return {
      userIds: [record.consultant_id as string],
      title: 'New task assigned',
      body: `"${record.title}" on ${enterprise?.business_name ?? 'your enterprise'}.`,
    };
  }

  if (table === 'tasks' && type === 'UPDATE') {
    const justCompleted = record.status === 'Completed' && old_record?.status !== 'Completed';
    if (!justCompleted) return null;

    const { data: enterprise } = await supabase
      .from('enterprises')
      .select('owner_user_id, business_name')
      .eq('id', record.enterprise_id as string)
      .maybeSingle();
    if (!enterprise) return null;

    const userIds = await getAdminUserIds();
    if (enterprise.owner_user_id) userIds.push(enterprise.owner_user_id as string);
    if (userIds.length === 0) return null;

    const scoreRelevant = SCORE_RELEVANT_TASK_TITLES.has(record.title as string);
    return {
      userIds,
      title: scoreRelevant ? 'Loan readiness improved' : 'Task completed',
      body: `"${record.title}" completed on ${enterprise.business_name}.`,
    };
  }

  return null;
}

// ---------- Google OAuth2 (service account, JWT bearer flow) ----------
// Cached across warm invocations of the same function instance so a
// burst of webhook calls doesn't request a fresh token every time.
let cachedToken: { token: string; expiresAt: number } | null = null;

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const raw = atob(base64);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes.buffer;
}

function base64UrlEncode(input: string | ArrayBuffer): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function getAccessToken(): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.token;
  }

  const clientEmail = Deno.env.get('FIREBASE_CLIENT_EMAIL')!;
  const privateKeyPem = Deno.env.get('FIREBASE_PRIVATE_KEY')!.replace(/\\n/g, '\n');

  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${base64UrlEncode(
    JSON.stringify({
      iss: clientEmail,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )}`;

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlEncode(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`OAuth token request failed: ${response.status} ${await response.text()}`);
  }

  const json = await response.json();
  cachedToken = { token: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  return cachedToken.token;
}

async function sendToToken(fcmToken: string, title: string, body: string): Promise<void> {
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID')!;
  const accessToken = await getAccessToken();

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message: { token: fcmToken, notification: { title, body } } }),
    },
  );

  if (!response.ok) {
    const errorBody = await response.text();
    // A token FCM reports as unregistered is stale (app uninstalled,
    // token rotated) — remove it so future sends don't keep failing.
    if (response.status === 404 || errorBody.includes('UNREGISTERED')) {
      await supabase.from('device_tokens').delete().eq('fcm_token', fcmToken);
    } else {
      console.error(`FCM send failed for a token: ${response.status} ${errorBody}`);
    }
  }
}

Deno.serve(async (req) => {
  // Fail closed: with Verify JWT off, a missing secret would otherwise
  // leave this function open to anyone who finds the URL.
  const expectedSecret = Deno.env.get('WEBHOOK_SECRET');
  if (!expectedSecret) {
    console.error('WEBHOOK_SECRET is not set — refusing all calls');
    return new Response('Server misconfigured', { status: 500 });
  }
  if (req.headers.get('x-webhook-secret') !== expectedSecret) {
    console.error('Rejected call: missing or wrong x-webhook-secret header');
    return new Response('Unauthorized', { status: 401 });
  }

  const payload = (await req.json()) as WebhookPayload;
  const target = await resolveTarget(payload);
  if (!target) {
    return new Response(JSON.stringify({ skipped: true }), { status: 200 });
  }

  const { data: tokens } = await supabase
    .from('device_tokens')
    .select('fcm_token')
    .in('user_id', target.userIds);

  await Promise.all(
    (tokens ?? []).map((row) => sendToToken(row.fcm_token as string, target.title, target.body)),
  );

  return new Response(JSON.stringify({ sent: tokens?.length ?? 0 }), { status: 200 });
});
