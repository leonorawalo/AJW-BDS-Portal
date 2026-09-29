-- ============================================================
-- Push targeting fix: one device token belongs to ONE user
-- ============================================================
-- Bug (2026-09-29): a phone signed in as the Blue Farm Owner received
-- pushes for other enterprises. The live table had 9 rows with the same
-- fcm_token under 9 different users. Two causes:
--   1. Uniqueness was on (user_id, fcm_token), so each new user signing in
--      on the same phone added another row for the same device.
--   2. The app deleted the token AFTER signing out, when it had no session
--      left, so RLS silently blocked the delete.
-- Fix here: keep only the most recent owner of each token, make fcm_token
-- itself unique, and let the app "claim" a token for the current user
-- (claim_device_token). The app now also releases its token BEFORE signing
-- out (AuthRepository.signOut hooks).
--
-- Also adds tasks.created_by (filled in by the database) so send-push can
-- skip telling a consultant about tasks they created themselves (applying
-- a ToR checklist creates 5-10 at once).
-- ============================================================

-- ---------- 1. Clean up duplicates: keep each token's latest user ----------
delete from public.device_tokens d
using public.device_tokens newer
where d.fcm_token = newer.fcm_token
  and (d.updated_at < newer.updated_at
       or (d.updated_at = newer.updated_at and d.id < newer.id));

-- ---------- 2. One row per device token ----------
alter table public.device_tokens drop constraint if exists device_tokens_user_id_fcm_token_key;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.device_tokens'::regclass and conname = 'device_tokens_fcm_token_key'
  ) then
    alter table public.device_tokens add constraint device_tokens_fcm_token_key unique (fcm_token);
  end if;
end;
$$;

-- ---------- 3. Claim this device's token for the signed-in user ----------
-- SECURITY DEFINER because the row may still belong to whoever used this
-- device before, and RLS (own rows only) would stop the new user from
-- taking it over. It can only ever assign the token to the CALLER.
create or replace function public.claim_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  insert into public.device_tokens (user_id, fcm_token, platform)
  values ((select auth.uid()), p_token, p_platform)
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        updated_at = now();
end;
$$;

revoke all on function public.claim_device_token(text, text) from public, anon;
grant execute on function public.claim_device_token(text, text) to authenticated;

-- ---------- 4. tasks.created_by ----------
alter table public.tasks
  add column if not exists created_by uuid references public.users (id) default auth.uid();
