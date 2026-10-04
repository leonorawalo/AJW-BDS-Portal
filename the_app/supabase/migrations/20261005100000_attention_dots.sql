-- ============================================================
-- Red dots: "something here needs your attention" (approved 4 Oct).
--
-- A small red dot (no number) on a side-menu item / enterprise card
-- when something new arrived there that someone ELSE did, since the
-- person last opened that place. Opening the place clears it.
--
-- attention_seen   when each user last opened each place. Written only
--                  by mark_seen() for the caller; read only by
--                  my_attention(). RLS on, no policies, no grants: the
--                  app never touches the table directly.
-- mark_seen()      called by the app shell whenever a page/section opens.
-- my_attention()   the caller's dots as (enterprise_id, section) rows;
--                  enterprise_id null = a role-level page.
--
-- Events (sections match the app's ShellSection / globalKey names):
--   Consultant  new active assignment ............ (enterprise, 'new')
--               custom task added for them by someone else,
--               or a comment by someone else on their task (enterprise, 'tasks')
--               invited to a session .............. (enterprise, 'sessions')
--   Owner       new recommendation ................ (enterprise, 'recommendations')
--               comment by someone else on a task  (enterprise, 'tasks')
--               document uploaded by someone else  (enterprise, 'documents')
--               invited to a session .............. (enterprise, 'sessions')
--   Admin       an invited user accepted ......... (null, 'users')
--               a workshop list went overdue ...... (null, 'workshops')
-- 'new' clears when ANY section of that enterprise is opened.
-- With no seen row yet, the baseline is when the user's account was made.
-- ============================================================

create table if not exists public.attention_seen (
  user_id uuid not null references public.users (id) on delete cascade,
  -- Null for role-level pages (Users, Workshops, ...).
  enterprise_id uuid references public.enterprises (id) on delete cascade,
  section text not null check (length(section) between 1 and 40),
  seen_at timestamptz not null default now()
);

create unique index if not exists attention_seen_place
  on public.attention_seen (user_id, coalesce(enterprise_id, '00000000-0000-0000-0000-000000000000'::uuid), section);

alter table public.attention_seen enable row level security;
revoke all on public.attention_seen from anon, authenticated;

create or replace function public.mark_seen(p_enterprise_id uuid, p_section text)
returns void
language sql
security definer set search_path = public
as $$
  insert into public.attention_seen (user_id, enterprise_id, section, seen_at)
  select (select auth.uid()), p_enterprise_id, p_section, now()
  where (select auth.uid()) is not null
    and exists (select 1 from public.users where id = (select auth.uid()))
  on conflict (user_id, coalesce(enterprise_id, '00000000-0000-0000-0000-000000000000'::uuid), section)
  do update set seen_at = excluded.seen_at;
$$;

create or replace function public.my_attention()
returns table (enterprise_id uuid, section text)
language sql
stable
security definer set search_path = public
as $$
  with me as (
    select u.id, u.created_at, r.role_name
    from public.users u
    join public.roles r on r.id = u.role_id
    where u.id = (select auth.uid())
  ),
  seen as (
    select s.enterprise_id, s.section, s.seen_at
    from public.attention_seen s
    where s.user_id = (select auth.uid())
  ),
  -- Enterprises this user works on, by role.
  mine as (
    select ca.enterprise_id
    from public.consultant_assignments ca, me
    where me.role_name = 'Consultant' and ca.consultant_id = me.id and ca.assignment_status = 'active'
    union
    select e.id
    from public.enterprises e, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id
  ),
  events as (
    -- Consultant: newly assigned enterprise.
    select ca.enterprise_id, 'new'::text as section, ca.created_at as at
    from public.consultant_assignments ca, me
    where me.role_name = 'Consultant' and ca.consultant_id = me.id and ca.assignment_status = 'active'

    -- Consultant: a custom task someone else added for them.
    union all
    select t.enterprise_id, 'tasks', t.created_at
    from public.tasks t, me
    where me.role_name = 'Consultant' and t.consultant_id = me.id
      and t.tor_key is null and t.created_by is distinct from me.id

    -- Consultant: someone else commented on their task.
    union all
    select t.enterprise_id, 'tasks', c.created_at
    from public.task_comments c
    join public.tasks t on t.id = c.task_id, me
    where me.role_name = 'Consultant' and t.consultant_id = me.id and c.author_id <> me.id

    -- Owner: someone else commented on a task on their enterprise.
    union all
    select t.enterprise_id, 'tasks', c.created_at
    from public.task_comments c
    join public.tasks t on t.id = c.task_id
    join public.enterprises e on e.id = t.enterprise_id, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id and c.author_id <> me.id

    -- Owner: a new recommendation.
    union all
    select r.enterprise_id, 'recommendations', r.created_at
    from public.recommendations r
    join public.enterprises e on e.id = r.enterprise_id, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id
      and r.consultant_id is distinct from me.id

    -- Owner: a document someone else uploaded.
    union all
    select d.enterprise_id, 'documents', d.uploaded_at
    from public.documents d
    join public.enterprises e on e.id = d.enterprise_id, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id
      and d.uploaded_by is distinct from me.id

    -- Anyone: invited to a session someone else organised.
    union all
    select s.enterprise_id, 'sessions', p.created_at
    from public.session_participants p
    join public.consultation_sessions s on s.id = p.session_id, me
    where p.user_id = me.id and s.organizer_id <> me.id and s.status = 'Scheduled'

    -- Admin: an invited user accepted (confirmed their email).
    union all
    select null::uuid, 'users', a.email_confirmed_at
    from auth.users a, me
    where me.role_name = 'Administrator' and a.invited_at is not null
      and a.email_confirmed_at is not null and a.id <> me.id

    -- Admin: a workshop's registration list went overdue (not sent to M&E
    -- within 5 days; overdue from the start of day 6, Nairobi time, the
    -- same rule as Workshop.registrationOverdue in the app).
    union all
    select null::uuid, 'workshops',
           ((w.held_on + 6)::timestamp at time zone 'Africa/Nairobi')
    from public.workshops w, me
    where me.role_name = 'Administrator' and w.registration_sent_at is null
      and (now() at time zone 'Africa/Nairobi')::date > w.held_on + 5
  )
  select distinct ev.enterprise_id, ev.section
  from events ev, me
  where ev.at > coalesce(
    case
      when ev.section = 'new' then
        (select max(s.seen_at) from seen s where s.enterprise_id = ev.enterprise_id)
      else
        (select s.seen_at from seen s
          where s.enterprise_id is not distinct from ev.enterprise_id and s.section = ev.section)
    end,
    me.created_at
  )
  -- Enterprise dots only for enterprises the user still works on.
  and (ev.enterprise_id is null or ev.enterprise_id in (select enterprise_id from mine));
$$;

revoke all on function public.mark_seen(uuid, text) from public, anon;
revoke all on function public.my_attention() from public, anon;
grant execute on function public.mark_seen(uuid, text) to authenticated;
grant execute on function public.my_attention() to authenticated;
