-- ============================================================
-- Migration 16: Google Calendar + Meet consultation sessions (Phase 7)
-- ============================================================
-- Each Consultant connects their *own* Google account once; sessions
-- they schedule are created on their primary calendar with a Meet link,
-- and the enterprise Owner is invited by email (Google sends the invite
-- and puts it on the Owner's calendar — the Owner never has to connect
-- anything).
--
-- All Google API calls happen in Edge Functions (google-oauth,
-- calendar-sessions). The Flutter app never sees a Google token.
-- ============================================================


-- ---------- GOOGLE_CONNECTIONS ----------
-- One row per user who has connected Google. refresh_token is a
-- long-lived credential for that person's calendar, so RLS is enabled
-- with NO policies: only the service role (Edge Functions) can touch
-- this table. The app reads connection status through
-- get_my_google_connection() below, which never returns the token.
create table public.google_connections (
  user_id uuid primary key references public.users (id) on delete cascade,
  google_email varchar(255),
  refresh_token text not null,
  scope text,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger google_connections_set_updated_at
  before update on public.google_connections
  for each row execute function public.set_updated_at();

alter table public.google_connections enable row level security;

create or replace function public.get_my_google_connection()
returns table (google_email varchar, connected_at timestamptz)
language sql
stable
security definer set search_path = public
as $$
  select gc.google_email, gc.connected_at
  from public.google_connections gc
  where gc.user_id = ((select auth.uid()));
$$;

grant execute on function public.get_my_google_connection() to authenticated;


-- ---------- GOOGLE_OAUTH_STATES ----------
-- Short-lived random `state` values tying a Google consent redirect back
-- to the user who started it (the redirect itself carries no Supabase
-- JWT). Service role only, same as above.
create table public.google_oauth_states (
  state text primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.google_oauth_states enable row level security;


-- ---------- CONSULTATION_SESSIONS ----------
create table public.consultation_sessions (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id),
  consultant_id uuid not null references public.users (id),
  title varchar(255) not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status varchar(20) not null default 'Scheduled'
    check (status in ('Scheduled', 'Cancelled')),
  google_event_id text,
  meet_link text,
  calendar_html_link text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index consultation_sessions_enterprise_id_idx
  on public.consultation_sessions (enterprise_id, starts_at);
create index consultation_sessions_consultant_id_idx
  on public.consultation_sessions (consultant_id);

create trigger consultation_sessions_set_updated_at
  before update on public.consultation_sessions
  for each row execute function public.set_updated_at();

alter table public.consultation_sessions enable row level security;

create policy "consultation_sessions_select_admin"
  on public.consultation_sessions for select
  to authenticated
  using (public.is_admin());

-- The whole Trio sees every session on their enterprise.
create policy "consultation_sessions_select_assigned_consultant"
  on public.consultation_sessions for select
  to authenticated
  using (public.is_assigned_consultant(enterprise_id));

create policy "consultation_sessions_select_owner"
  on public.consultation_sessions for select
  to authenticated
  using (public.is_enterprise_owner(enterprise_id));

-- Rows are written by the calendar-sessions Edge Function *using the
-- caller's own JWT*, so these policies are still the real boundary: a
-- consultant can only book/cancel their own sessions on an enterprise
-- they're actively assigned to.
create policy "consultation_sessions_insert_own_assigned_consultant"
  on public.consultation_sessions for insert
  to authenticated
  with check (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id));

create policy "consultation_sessions_update_own_assigned_consultant"
  on public.consultation_sessions for update
  to authenticated
  using (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id))
  with check (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id));

grant select, insert, update on public.consultation_sessions to authenticated;
