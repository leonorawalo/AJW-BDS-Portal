// Supabase Edge Function: manage-users   (Phase 9b: Admin user management)
//
// Only an Administrator can call it. Deploy with JWT verification ON.
//
//   POST {action: 'suspend',    user_id}  -> {ok: true}
//   POST {action: 'reactivate', user_id}  -> {ok: true}
//   POST {action: 'reset_mfa',  user_id}  -> {ok: true, removed: n}
//        Removes the person's two-step verification (authenticator app),
//        e.g. after a lost phone; they set it up again at next sign-in.
//        Not on your own account: another Admin has to do it.
//   POST {action: 'erase', user_id, request_id?}  -> {ok: true, emailed}
//        Carries out an approved deletion request (Kenya Data Protection
//        Act, 2019). erase_user_personal_data() deletes or anonymises the
//        person's personal data in the database (see migration
//        20261016100000 for what is kept). Then: their chat attachments
//        are removed from Storage, their two-step factors deleted, and
//        their login gets a placeholder email, no metadata and a
//        permanent ban. The data request is marked completed, and a
//        confirmation goes to their old address from the calling Admin's
//        own Gmail if they have connected Google (emailed: false
//        otherwise: the Admin tells them another way).
//        Not on your own account, nor on the last active Administrator.
//
// Suspending does three things:
//   1. public.users.status = 'suspended' (written with the Admin's JWT, so
//      users RLS stays the boundary). The app's router already signs out a
//      suspended user.
//   2. Bans the account in Supabase Auth, so it can't sign in or refresh its
//      session. This is the real enforcement; the router check alone can
//      be bypassed. A session already open keeps its current access token
//      until it expires (at most 1 hour) but can't renew it.
//   3. Removes the user's device tokens, so they stop receiving pushes.
// Reactivating undoes 1 and 2. They sign in again normally.
//
// Guards: an Admin can't suspend themselves, and the last active
// Administrator can't be suspended (someone must be able to reactivate).

import { createClient } from 'jsr:@supabase/supabase-js@2';
import { emailFooter } from '../_shared/business.ts';
import { sendGmail } from '../_shared/gmail.ts';
import { accessTokenFor } from '../_shared/google.ts';
import { rateLimited, serve, serverError } from '../_shared/http.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
/// Supabase has no "ban forever"; 100 years is the conventional stand-in.
const BAN_FOREVER = '876000h';

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/// True if [userId] is the only active Administrator left.
async function isLastActiveAdmin(userId: string): Promise<boolean> {
  const { data: target } = await admin.from('users').select('status, roles(role_name)').eq('id', userId).maybeSingle();
  // deno-lint-ignore no-explicit-any
  if ((target?.roles as any)?.role_name !== 'Administrator' || target?.status !== 'active') return false;
  const { count } = await admin
    .from('users')
    .select('id, roles!inner(role_name)', { count: 'exact', head: true })
    .eq('roles.role_name', 'Administrator')
    .eq('status', 'active');
  return (count ?? 0) <= 1;
}

// deno-lint-ignore no-explicit-any
async function erase(userClient: any, callerId: string, userId: string, requestId?: string): Promise<Response> {
  if (userId === callerId) return json({ error: 'Another Administrator has to delete your data' }, 400);
  if (await isLastActiveAdmin(userId)) return json({ error: "The last active Administrator's data can't be deleted" }, 400);

  const { data: erased, error } = await admin.rpc('erase_user_personal_data', { p_user: userId });
  if (error) {
    // Raised on purpose (e.g. active assignments): a sentence for the Admin.
    if (error.code === '23514' || error.code === 'P0002') return json({ error: error.message }, 400);
    return serverError(error);
  }
  const oldEmail = erased?.email as string | null;
  const attachments = (erased?.attachments ?? []) as string[];

  if (attachments.length > 0) {
    const { error: storageError } = await admin.storage.from('chat-attachments').remove(attachments);
    if (storageError) console.error('Removing chat attachments failed', storageError.message);
  }
  const { data: factors } = await admin.auth.admin.mfa.listFactors({ userId });
  for (const f of factors?.factors ?? []) await admin.auth.admin.mfa.deleteFactor({ userId, id: f.id });
  const { error: authError } = await admin.auth.admin.updateUserById(userId, {
    email: `deleted-${userId}@deleted.invalid`,
    email_confirm: true,
    user_metadata: { erased: true },
    ban_duration: BAN_FOREVER,
  });
  if (authError) console.error('Anonymising the login failed', authError.message);

  if (requestId) {
    await userClient
      .from('data_requests')
      .update({
        status: 'completed',
        resolution_note: `Your personal data was deleted on ${new Date().toISOString().slice(0, 10)}.`,
      })
      .eq('id', requestId)
      .eq('user_id', userId);
  }

  let emailed = false;
  if (oldEmail) {
    try {
      const token = await accessTokenFor(callerId);
      await sendGmail(
        token,
        [oldEmail],
        'Your data has been deleted from the AJW BAGS Portal',
        [
          'Hello,',
          '',
          'As you asked, we have deleted your personal data from the AJW Business Advancement and Growth Services (BAGS) Portal and closed your account.',
          '',
          'What we kept, without your name or contact details: programme records others rely on (for example tasks and documents of the enterprises you worked with) and our activity log, as our Privacy Policy explains.',
          '',
          'If you did not ask for this, or have questions, reply to this email.',
          '',
          emailFooter(),
        ].join('\n'),
      );
      emailed = true;
    } catch (e) {
      console.error('Deletion confirmation email not sent', e instanceof Error ? e.message : e);
    }
  }
  return json({ ok: true, emailed });
}

serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Not signed in' }, 401);
  const userClient = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: caller, error: callerError } = await userClient.auth.getUser(authHeader.replace('Bearer ', ''));
  if (callerError || !caller.user) return json({ error: 'Not signed in' }, 401);
  const { data: isAdmin } = await userClient.rpc('is_admin');
  if (!isAdmin) return json({ error: 'Only an Administrator can manage users' }, 403);
  const limited = await rateLimited(`manage-users:${caller.user.id}`, 60, 3600);
  if (limited) return limited;

  let input: { action?: string; user_id?: string; request_id?: string };
  try {
    input = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
  const userId = input.user_id;
  if (!userId) return json({ error: 'user_id is required' }, 400);
  if (!['suspend', 'reactivate', 'reset_mfa', 'erase'].includes(input.action ?? '')) {
    return json({ error: `Unknown action: ${input.action}` }, 400);
  }

  try {
    if (input.action === 'reset_mfa') {
      if (userId === caller.user.id) {
        return json({ error: 'Another Administrator has to reset your two-step verification' }, 400);
      }
      const { data: listed, error: listError } = await admin.auth.admin.mfa.listFactors({ userId });
      if (listError) return serverError(listError);
      let removed = 0;
      for (const f of listed?.factors ?? []) {
        const { error } = await admin.auth.admin.mfa.deleteFactor({ userId, id: f.id });
        if (error) return serverError(error);
        removed++;
      }
      return json({ ok: true, removed });
    }

    if (input.action === 'erase') return await erase(userClient, caller.user.id, userId, input.request_id);

    if (input.action === 'suspend') {
      if (userId === caller.user.id) return json({ error: "You can't suspend your own account" }, 400);

      const { data: target } = await admin
        .from('users')
        .select('id, status, roles(role_name)')
        .eq('id', userId)
        .maybeSingle();
      if (!target) return json({ error: 'User not found' }, 404);
      // deno-lint-ignore no-explicit-any
      if ((target.roles as any)?.role_name === 'Administrator') {
        const { count } = await admin
          .from('users')
          .select('id, roles!inner(role_name)', { count: 'exact', head: true })
          .eq('roles.role_name', 'Administrator')
          .eq('status', 'active');
        if ((count ?? 0) <= 1) return json({ error: "The last active Administrator can't be suspended" }, 400);
      }

      const { error: statusError } = await userClient.from('users').update({ status: 'suspended' }).eq('id', userId);
      if (statusError) return json({ error: statusError.message }, 403);
      const { error: banError } = await admin.auth.admin.updateUserById(userId, { ban_duration: BAN_FOREVER });
      if (banError) {
        // Keep the two in step: don't leave someone "suspended" in the app
        // but still able to sign in.
        await userClient.from('users').update({ status: 'active' }).eq('id', userId);
        return json({ error: `Could not block sign-in: ${banError.message}` }, 500);
      }
      await admin.from('device_tokens').delete().eq('user_id', userId);
      return json({ ok: true });
    }

    const { error: unbanError } = await admin.auth.admin.updateUserById(userId, { ban_duration: 'none' });
    if (unbanError) return json({ error: `Could not unblock sign-in: ${unbanError.message}` }, 500);
    const { error: statusError } = await userClient.from('users').update({ status: 'active' }).eq('id', userId);
    if (statusError) return json({ error: statusError.message }, 403);
    return json({ ok: true });
  } catch (e) {
    return serverError(e);
  }
});
