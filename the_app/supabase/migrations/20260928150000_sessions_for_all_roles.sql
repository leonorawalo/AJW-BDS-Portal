-- ============================================================
-- Sessions for all roles: organizer + participants
-- ============================================================
-- Decisions (2026-09-28):
--   - Admins, Consultants and Owners can all connect Google and schedule
--     meetings on an enterprise:
--       Admin      -> the enterprise's Owner and/or its active consultants
--       Consultant -> the Owner of an enterprise they're assigned to
--       Owner      -> their active consultants and/or Admins
--   - Only the organizer, the participants, and Admins see a session.
--     (Before this, every consultant on the enterprise plus the Owner saw
--     all of its sessions.)
--   - Participants see only themselves and the organizer, not the other
--     invitees, matching guestsCanSeeOtherGuests=false on the Google event.
--
-- The event lives on the organizer's Google Calendar; calendar-sessions
-- writes the rows below with the organizer's own JWT, so these policies
-- are the real boundary.
-- ============================================================


-- ---------- consultation_sessions.organizer_id ----------
alter table public.consultation_sessions
  add column if not exists organizer_id uuid references public.users (id);

update public.consultation_sessions
set organizer_id = consultant_id
where organizer_id is null;

alter table public.consultation_sessions alter column organizer_id set not null;
-- Kept for history; new sessions don't need a consultant at all.
alter table public.consultation_sessions alter column consultant_id drop not null;

create index if not exists consultation_sessions_organizer_id_idx
  on public.consultation_sessions (organizer_id);


-- ---------- session_participants ----------
create table if not exists public.session_participants (
  session_id uuid not null references public.consultation_sessions (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (session_id, user_id)
);

create index if not exists session_participants_user_id_idx
  on public.session_participants (user_id);

alter table public.session_participants enable row level security;

-- Existing sessions were consultant -> Owner; record the Owner.
insert into public.session_participants (session_id, user_id)
select s.id, e.owner_user_id
from public.consultation_sessions s
join public.enterprises e on e.id = s.enterprise_id
where e.owner_user_id is not null
  and e.owner_user_id <> s.organizer_id
on conflict do nothing;


-- ---------- helpers (SECURITY DEFINER: no RLS recursion) ----------

create or replace function public.can_schedule_for_enterprise(p_enterprise_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select public.is_admin()
      or public.is_assigned_consultant(p_enterprise_id)
      or public.is_enterprise_owner(p_enterprise_id);
$$;

-- Who the caller may invite to a meeting on this enterprise. The single
-- source of truth for the invite rules: the app's participant picker and
-- calendar-sessions both use it, and so does the participants insert
-- policy below. Returns names only; Owners can't otherwise read Admin
-- users rows.
create or replace function public.session_invitee_candidates(p_enterprise_id uuid)
returns table (user_id uuid, full_name text, role_name text)
language sql
stable
security definer set search_path = public
as $$
  with me as (
    select
      (select auth.uid()) as uid,
      public.is_admin() as is_admin,
      public.is_assigned_consultant(p_enterprise_id) as is_consultant,
      public.is_enterprise_owner(p_enterprise_id) as is_owner
  )
  select u.id, trim(u.first_name || ' ' || u.last_name), r.role_name::text
  from public.users u
  join public.roles r on r.id = u.role_id
  cross join me
  where u.id <> me.uid
    and u.status = 'active'
    and (
      -- the enterprise's Owner: invitable by Admin or an assigned consultant
      ((me.is_admin or me.is_consultant) and u.id = (
        select e.owner_user_id from public.enterprises e where e.id = p_enterprise_id
      ))
      -- its active consultants: invitable by Admin or the Owner
      or ((me.is_admin or me.is_owner) and exists (
        select 1 from public.consultant_assignments ca
        where ca.enterprise_id = p_enterprise_id
          and ca.consultant_id = u.id
          and ca.assignment_status = 'active'
      ))
      -- Admins: invitable by the Owner
      or (me.is_owner and r.role_name = 'Administrator')
    )
  order by 3, 2;
$$;

create or replace function public.is_session_organizer(p_session_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.consultation_sessions s
    where s.id = p_session_id and s.organizer_id = ((select auth.uid()))
  );
$$;

create or replace function public.is_session_participant(p_session_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.session_participants sp
    where sp.session_id = p_session_id and sp.user_id = ((select auth.uid()))
  );
$$;

create or replace function public.can_add_session_participant(p_session_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1
    from public.consultation_sessions s
    where s.id = p_session_id
      and s.organizer_id = ((select auth.uid()))
      and p_user_id in (
        select c.user_id from public.session_invitee_candidates(s.enterprise_id) c
      )
  );
$$;

-- Names of everyone on the sessions the caller can see, for the Sessions
-- tab. Admin and the organizer see all participants; a participant sees
-- only the organizer and themselves.
create or replace function public.session_people(p_enterprise_id uuid)
returns table (session_id uuid, user_id uuid, full_name text, is_organizer boolean)
language sql
stable
security definer set search_path = public
as $$
  with visible as (
    select s.id, s.organizer_id
    from public.consultation_sessions s
    where s.enterprise_id = p_enterprise_id
      and (
        public.is_admin()
        or s.organizer_id = ((select auth.uid()))
        or exists (
          select 1 from public.session_participants sp
          where sp.session_id = s.id and sp.user_id = ((select auth.uid()))
        )
      )
  ),
  people as (
    select v.id as session_id, v.organizer_id as user_id, true as is_organizer
    from visible v
    union
    select sp.session_id, sp.user_id, false
    from public.session_participants sp
    join visible v on v.id = sp.session_id
    where public.is_admin()
       or v.organizer_id = ((select auth.uid()))
       or sp.user_id = ((select auth.uid()))
  )
  select p.session_id, p.user_id, trim(u.first_name || ' ' || u.last_name), p.is_organizer
  from people p
  join public.users u on u.id = p.user_id;
$$;

revoke all on function public.can_schedule_for_enterprise(uuid) from public, anon;
revoke all on function public.session_invitee_candidates(uuid) from public, anon;
revoke all on function public.is_session_organizer(uuid) from public, anon;
revoke all on function public.is_session_participant(uuid) from public, anon;
revoke all on function public.can_add_session_participant(uuid, uuid) from public, anon;
revoke all on function public.session_people(uuid) from public, anon;
grant execute on function public.can_schedule_for_enterprise(uuid) to authenticated;
grant execute on function public.session_invitee_candidates(uuid) to authenticated;
grant execute on function public.is_session_organizer(uuid) to authenticated;
grant execute on function public.is_session_participant(uuid) to authenticated;
grant execute on function public.can_add_session_participant(uuid, uuid) to authenticated;
grant execute on function public.session_people(uuid) to authenticated;


-- ---------- RLS: consultation_sessions ----------
drop policy if exists "consultation_sessions_select_admin" on public.consultation_sessions;
drop policy if exists "consultation_sessions_select_assigned_consultant" on public.consultation_sessions;
drop policy if exists "consultation_sessions_select_owner" on public.consultation_sessions;
drop policy if exists "consultation_sessions_insert_own_assigned_consultant" on public.consultation_sessions;
drop policy if exists "consultation_sessions_update_own_assigned_consultant" on public.consultation_sessions;
drop policy if exists "consultation_sessions_select_member" on public.consultation_sessions;
drop policy if exists "consultation_sessions_insert_organizer" on public.consultation_sessions;
drop policy if exists "consultation_sessions_update_organizer_or_admin" on public.consultation_sessions;

create policy "consultation_sessions_select_member"
  on public.consultation_sessions for select
  to authenticated
  using (
    public.is_admin()
    or organizer_id = ((select auth.uid()))
    or public.is_session_participant(id)
  );

create policy "consultation_sessions_insert_organizer"
  on public.consultation_sessions for insert
  to authenticated
  with check (
    organizer_id = ((select auth.uid()))
    and public.can_schedule_for_enterprise(enterprise_id)
  );

-- Cancelling is the only update the app makes.
create policy "consultation_sessions_update_organizer_or_admin"
  on public.consultation_sessions for update
  to authenticated
  using (organizer_id = ((select auth.uid())) or public.is_admin())
  with check (organizer_id = ((select auth.uid())) or public.is_admin());


-- ---------- RLS: session_participants ----------
drop policy if exists "session_participants_select" on public.session_participants;
drop policy if exists "session_participants_insert_organizer" on public.session_participants;

-- Own row, or every row if you organised the session (or are Admin).
create policy "session_participants_select"
  on public.session_participants for select
  to authenticated
  using (
    user_id = ((select auth.uid()))
    or public.is_admin()
    or public.is_session_organizer(session_id)
  );

create policy "session_participants_insert_organizer"
  on public.session_participants for insert
  to authenticated
  with check (public.can_add_session_participant(session_id, user_id));

grant select, insert on public.session_participants to authenticated;
revoke all on public.session_participants from anon;
