// Supabase Edge Function: invite-user   (Phase 9a: Admin-driven onboarding)
//
// Only an Administrator can call it. Deploy with JWT verification ON.
//
//   POST {action: 'invite', email, first_name, last_name, role_name,
//         specialization?, enterprise_id?}
//        -> {status: 'sent', user_id}             invite email sent
//        -> {status: 'linked_existing', user_id}  an Owner account already
//                                                  existed; just linked it
//        -> 502 {error: 'email_failed'}           email couldn't be sent;
//                                                  use action 'link' instead
//   POST {action: 'link', ...same fields}
//        -> {status: 'link', user_id, link}       a set-password link for the
//                                                  Admin to share (copy /
//                                                  WhatsApp): the fallback
//                                                  when email isn't possible,
//                                                  and a "resend" that never
//                                                  depends on email delivery
//
// role_name: 'Enterprise Owner' | 'Consultant' | 'Administrator'.
// Consultants need specialization. enterprise_id (Owners only) links the new
// account to that enterprise straight away.
//
// The user record is created by the existing handle_new_user trigger from
// the invite's metadata (role, names, specialization). needs_password: true
// sends them to the app's Set password screen on first sign-in.
//
// Links point at the APP (APP_URL/#/set-password?token_hash=…), not at
// Supabase's default /verify redirect: the app uses the PKCE auth flow,
// which can't pick up the session from Supabase's default invite redirect.
// The app exchanges the token itself (verifyOTP). The Invite email template
// must use the same format: see context.txt.
//
// Secrets: APP_URL (https://portal.ajwafrica.org). SUPABASE_*
// are provided automatically.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const ROLES = ['Enterprise Owner', 'Consultant', 'Administrator'];
const SPECIALIZATIONS = ['Legal', 'Accounting', 'Marketing'];

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

function appUrl(): string | null {
  const url = Deno.env.get('APP_URL');
  return url ? url.replace(/\/+$/, '') : null;
}

function setPasswordLink(tokenHash: string, type: 'invite' | 'magiclink'): string {
  return `${appUrl()}/#/set-password?token_hash=${encodeURIComponent(tokenHash)}&type=${type}`;
}

type Input = {
  action: 'invite' | 'link';
  email: string;
  first_name: string;
  last_name: string;
  role_name: string;
  specialization?: string | null;
  enterprise_id?: string | null;
  /// Set by the app on its one automatic retry after a network failure.
  retry?: boolean;
};

/// A retry within this window doesn't email again: the first attempt most
/// likely went through and only its response was lost.
const RETRY_DEDUPE_MS = 2 * 60 * 1000;

/// "an Administrator", "a Legal Consultant", "an Enterprise Owner": for the
/// invite email's "… invited you as …" line.
function rolePhrase(roleName: string, specialization: string | null | undefined): string {
  if (roleName === 'Consultant' && specialization) return `a ${specialization} Consultant`;
  return /^[AEIOU]/.test(roleName) ? `an ${roleName}` : `a ${roleName}`;
}

function validate(input: Input): string | null {
  if (input.action !== 'invite' && input.action !== 'link') return `Unknown action: ${input.action}`;
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(input.email ?? '')) return 'A valid email is required';
  // Enterprises record the Owner's name as one field, so a last name may be empty.
  if (!input.first_name?.trim()) return 'A first name is required';
  if (!ROLES.includes(input.role_name)) return 'Invalid role';
  if (input.role_name === 'Consultant' && !SPECIALIZATIONS.includes(input.specialization ?? '')) {
    return 'Consultants need a specialization (Legal, Accounting or Marketing)';
  }
  if (input.enterprise_id && input.role_name !== 'Enterprise Owner') {
    return 'Only an Enterprise Owner can be linked to an enterprise';
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in' }, 401);
  const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: caller, error: callerError } = await userClient.auth.getUser(authHeader.replace('Bearer ', ''));
  if (callerError || !caller.user) return json({ error: 'Not signed in' }, 401);
  const { data: isAdmin } = await userClient.rpc('is_admin');
  if (!isAdmin) return json({ error: 'Only an Administrator can invite users' }, 403);
  if (!appUrl()) return json({ error: 'APP_URL secret is not set' }, 500);

  let input: Input;
  try {
    input = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
  input.email = String(input.email ?? '').trim().toLowerCase();
  const invalid = validate(input);
  if (invalid) return json({ error: invalid }, 400);

  const { data: inviter } = await admin
    .from('users')
    .select('first_name, last_name')
    .eq('id', caller.user.id)
    .maybeSingle();
  const invitedBy = [inviter?.first_name, inviter?.last_name].filter(Boolean).join(' ').trim();

  // invited_by / invited_as are only for the Invite email template:
  //   {{ .Data.invited_by }} invited you as {{ .Data.invited_as }}.
  const metadata = {
    first_name: input.first_name.trim(),
    last_name: (input.last_name ?? '').trim(),
    role_name: input.role_name,
    specialization: input.role_name === 'Consultant' ? input.specialization : null,
    needs_password: true,
    invited_by: invitedBy ? `${invitedBy} (AJW)` : 'AJW Africa',
    invited_as: rolePhrase(input.role_name, input.specialization),
  };

  /// Links the Owner to the enterprise with the Admin's own JWT, so the
  /// enterprises RLS (Admin update) stays the boundary.
  async function linkEnterprise(userId: string): Promise<string | null> {
    if (!input.enterprise_id) return null;
    const { error } = await userClient
      .from('enterprises')
      .update({ owner_user_id: userId })
      .eq('id', input.enterprise_id);
    return error ? error.message : null;
  }

  try {
    const { data: existing } = await admin
      .from('users')
      .select('id, roles(role_name)')
      .ilike('email', input.email)
      .maybeSingle();

    if (existing) {
      // deno-lint-ignore no-explicit-any
      const existingRole = (existing.roles as any)?.role_name as string | undefined;
      const { data: authUser } = await admin.auth.admin.getUserById(existing.id);
      const accepted = !!authUser.user?.email_confirmed_at;

      if (accepted) {
        // A working account already exists: an Owner can simply be linked;
        // anything else is a mistake worth surfacing.
        if (input.enterprise_id && existingRole === 'Enterprise Owner') {
          const linkError = await linkEnterprise(existing.id);
          if (linkError) return json({ error: linkError }, 403);
          return json({ status: 'linked_existing', user_id: existing.id });
        }
        return json({ error: `This email already has an active ${existingRole ?? ''} account` }, 409);
      }

      // Invited before but hasn't accepted yet: resend.
      const linkError = await linkEnterprise(existing.id);
      if (linkError) return json({ error: linkError }, 403);
      if (input.action === 'invite') {
        const invitedAt = authUser.user?.invited_at ? Date.parse(authUser.user.invited_at) : 0;
        if (input.retry && Date.now() - invitedAt < RETRY_DEDUPE_MS) {
          return json({ status: 'sent', user_id: existing.id });
        }
        const { error } = await admin.auth.admin.inviteUserByEmail(input.email, {
          data: metadata,
          redirectTo: appUrl()!,
        });
        if (error) {
          console.error('Invite email failed', error.message);
          return json({ error: 'email_failed', detail: error.message }, 502);
        }
        return json({ status: 'sent', user_id: existing.id });
      }
      const { data, error } = await admin.auth.admin.generateLink({ type: 'magiclink', email: input.email });
      if (error) return json({ error: error.message }, 500);
      return json({
        status: 'link',
        user_id: existing.id,
        link: setPasswordLink(data.properties.hashed_token, 'magiclink'),
      });
    }

    if (input.action === 'invite') {
      const { data, error } = await admin.auth.admin.inviteUserByEmail(input.email, {
        data: metadata,
        redirectTo: appUrl()!,
      });
      if (error || !data.user) {
        console.error('Invite email failed', error?.message);
        return json({ error: 'email_failed', detail: error?.message }, 502);
      }
      const linkError = await linkEnterprise(data.user.id);
      if (linkError) return json({ error: linkError }, 403);
      return json({ status: 'sent', user_id: data.user.id });
    }

    const { data, error } = await admin.auth.admin.generateLink({
      type: 'invite',
      email: input.email,
      options: { data: metadata, redirectTo: appUrl()! },
    });
    if (error || !data.user) return json({ error: error?.message ?? 'Could not create invite link' }, 500);
    const linkError = await linkEnterprise(data.user.id);
    if (linkError) return json({ error: linkError }, 403);
    return json({
      status: 'link',
      user_id: data.user.id,
      link: setPasswordLink(data.properties.hashed_token, 'invite'),
    });
  } catch (e) {
    console.error(e);
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
