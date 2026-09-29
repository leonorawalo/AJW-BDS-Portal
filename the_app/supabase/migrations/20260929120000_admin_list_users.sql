-- ============================================================
-- Phase 9b: Admin user list
-- ============================================================
-- The Users screen shows each account's role, specialization, status and
-- whether they've accepted their invite. "Accepted" (email confirmed) and
-- "last sign-in" live in auth.users, which app users can't read. This
-- SECURITY DEFINER function exposes just those fields, to Admins only.
-- Everyone else gets an empty list.
-- ============================================================

create or replace function public.admin_list_users()
returns table (
  id uuid,
  first_name text,
  last_name text,
  email text,
  phone_number text,
  role_name text,
  specialization text,
  status text,
  invited_at timestamptz,
  accepted boolean,
  last_sign_in_at timestamptz,
  active_assignments integer
)
language sql
stable
security definer set search_path = public
as $$
  select
    u.id,
    u.first_name::text,
    u.last_name::text,
    u.email::text,
    u.phone_number::text,
    r.role_name::text,
    u.specialization::text,
    u.status::text,
    coalesce(au.invited_at, au.created_at),
    au.email_confirmed_at is not null,
    au.last_sign_in_at,
    (select count(*)::int from public.consultant_assignments ca
      where ca.consultant_id = u.id and ca.assignment_status = 'active')
  from public.users u
  join public.roles r on r.id = u.role_id
  left join auth.users au on au.id = u.id
  where public.is_admin()
  order by r.role_name, u.first_name, u.last_name;
$$;

revoke all on function public.admin_list_users() from public, anon;
grant execute on function public.admin_list_users() to authenticated;


-- ============================================================
-- SECURITY FIX: users could change their own role / status
-- ============================================================
-- Found 2026-09-29 while building 9b. users_update_own_or_admin lets every
-- signed-in user UPDATE their own row, and RLS can't limit which columns.
-- The API therefore allowed a Consultant or Owner to set their own role_id
-- to Administrator, lift their own suspension, or change their
-- specialization. The app never does this, but nothing stopped a direct
-- API call. Same pattern as restrict_non_admin_enterprise_updates: only
-- Admins (and server-side calls with no auth.uid(), e.g. the service role,
-- triggers, the SQL editor) may change anything beyond a user's own name
-- and phone number.
-- ============================================================

create or replace function public.restrict_non_admin_user_updates()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  editable constant text[] := array['first_name', 'last_name', 'phone_number', 'updated_at'];
begin
  if (select auth.uid()) is null or public.is_admin() then
    return new;
  end if;

  if (to_jsonb(new) - editable) is distinct from (to_jsonb(old) - editable) then
    raise exception 'Only an Administrator can change role, status, specialization or email'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists users_restrict_non_admin_updates on public.users;
create trigger users_restrict_non_admin_updates
  before update on public.users
  for each row execute function public.restrict_non_admin_user_updates();
