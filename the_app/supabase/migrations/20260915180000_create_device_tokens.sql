-- ============================================================
-- Phase 6: Notifications — device token registry
-- Stores each signed-in user's FCM token(s) so a future Edge
-- Function (triggered by DB events) can push to the right
-- devices via the FCM HTTP v1 API using the service role key,
-- which bypasses RLS entirely. RLS here only needs to cover the
-- client's own read/write path.
-- ============================================================

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  fcm_token text not null,
  platform varchar(20) not null default 'android'
    check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, fcm_token)
);

create index device_tokens_user_id_idx on public.device_tokens (user_id);

create trigger device_tokens_set_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

-- ---------- RLS: device_tokens ----------
-- A user only ever manages their own device's token row. No Admin
-- policy is needed — sending happens server-side with the service
-- role key, which is not subject to RLS.
alter table public.device_tokens enable row level security;

create policy "device_tokens_all_own"
  on public.device_tokens for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------- Grants ----------
grant select, insert, update, delete on public.device_tokens to authenticated;
