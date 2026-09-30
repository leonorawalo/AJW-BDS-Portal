-- ============================================================
-- Gmail contacts (B1) + wider meeting invite rules (C1)
-- ============================================================

-- ---------- B1: who you can email about an enterprise ----------
-- The "Write email" dialog and the gmail-send Edge Function both use this,
-- so the recipients the app offers and the ones the server accepts are the
-- same list: the enterprise's Owner, its active consultants, AJW's
-- Admins, and the enterprise's own contact email if it differs from the
-- Owner's login. Only for someone who works on that enterprise (Admin,
-- assigned consultant or Owner); everyone else gets nothing. Emails are
-- returned only here: it's the address book for people you already work
-- with.
create or replace function public.enterprise_email_contacts(p_enterprise_id uuid)
returns table (user_id uuid, full_name text, role_name text, email text)
language sql
stable
security definer set search_path = public
as $$
  with people as (
    select u.id, trim(u.first_name || ' ' || u.last_name) as full_name, r.role_name::text as role_name, u.email::text as email
    from public.users u
    join public.roles r on r.id = u.role_id
    where u.status = 'active'
      and u.id <> (select auth.uid())
      and (
        u.id = (select e.owner_user_id from public.enterprises e where e.id = p_enterprise_id)
        or exists (
          select 1 from public.consultant_assignments ca
          where ca.enterprise_id = p_enterprise_id
            and ca.consultant_id = u.id
            and ca.assignment_status = 'active'
        )
        or r.role_name = 'Administrator'
      )
  ),
  enterprise_contact as (
    select null::uuid as id, e.business_name || ' (contact email)' as full_name,
           'Enterprise contact'::text as role_name, e.email::text as email
    from public.enterprises e
    where e.id = p_enterprise_id
      and e.email is not null
      and lower(e.email) not in (select lower(p.email) from people p)
      and lower(e.email) <> coalesce((select lower(u.email) from public.users u where u.id = (select auth.uid())), '')
  )
  select id, full_name, role_name, email
  from (select * from people union all select * from enterprise_contact) all_contacts
  where public.can_schedule_for_enterprise(p_enterprise_id)
  order by case role_name
             when 'Enterprise Owner' then 1 when 'Enterprise contact' then 2
             when 'Consultant' then 3 else 4 end,
           full_name;
$$;

revoke all on function public.enterprise_email_contacts(uuid) from public, anon;
grant execute on function public.enterprise_email_contacts(uuid) to authenticated;


-- ---------- C1: wider meeting invite rules ----------
-- Before: a Consultant could invite only the Owner, and an Admin couldn't
-- invite other Admins. Now (user decision 2026-09-30):
--   Consultant (assigned) -> Owner + the OTHER active consultants + Admins
--   Admin                 -> Owner + active consultants + other Admins
--   Owner                 -> active consultants + Admins (unchanged)
-- calendar-sessions validates invitees with this same function, so the
-- server-side check changes with it.
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
    and (me.is_admin or me.is_consultant or me.is_owner)
    and (
      -- the enterprise's Owner: invitable by Admins and its consultants
      ((me.is_admin or me.is_consultant) and u.id = (
        select e.owner_user_id from public.enterprises e where e.id = p_enterprise_id
      ))
      -- its active consultants: invitable by everyone on the enterprise
      or exists (
        select 1 from public.consultant_assignments ca
        where ca.enterprise_id = p_enterprise_id
          and ca.consultant_id = u.id
          and ca.assignment_status = 'active'
      )
      -- Admins: invitable by everyone on the enterprise
      or r.role_name = 'Administrator'
    )
  order by 3, 2;
$$;
