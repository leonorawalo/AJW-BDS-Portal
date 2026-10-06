// Supabase Edge Function: manage-users   (Phase 9b: Admin user management)
//
// Only an Administrator can call it. Deploy with JWT verification ON.
//
//   POST {action: 'suspend',    user_id}  -> {ok: true}
//   POST {action: 'reactivate', user_id}  -> {ok: true}
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

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
/// Supabase has no "ban forever"; 100 years is the conventional stand-in.
const BAN_FOREVER = '876000h';

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
  if (!isAdmin) return json({ error: 'Only an Administrator can manage users' }, 403);

  let input: { action?: string; user_id?: string };
  try {
    input = await req.json();
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }
  const userId = input.user_id;
  if (!userId) return json({ error: 'user_id is required' }, 400);
  if (input.action !== 'suspend' && input.action !== 'reactivate') {
    return json({ error: `Unknown action: ${input.action}` }, 400);
  }

  try {
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
    console.error(e);
    return json({ error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
