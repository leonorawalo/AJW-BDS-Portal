-- ============================================================
-- Migration 1: Roles + Users
-- Module 1 (Auth & RBAC) foundation
-- ============================================================

-- ---------- ROLES ----------
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  role_name varchar(50) not null unique,
  description text,
  created_at timestamptz not null default now()
);

insert into public.roles (role_name, description) values
  ('Administrator', 'AJW Africa staff — full platform access'),
  ('Consultant', 'Assigned to a portfolio of enterprises'),
  ('Enterprise Owner', 'MSME owner receiving BDS support');

-- ---------- USERS ----------
-- Mirrors auth.users 1:1. id is the same UUID Supabase Auth issues,
-- so there is no separate "link" step after sign-up.
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name varchar(100) not null,
  last_name varchar(100) not null,
  email varchar(255) not null unique,
  phone_number varchar(20) unique,
  role_id uuid not null references public.roles (id),
  status varchar(20) not null default 'active' check (status in ('active', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index users_role_id_idx on public.users (role_id);

-- keep updated_at current on every row change
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- ---------- AUTO-CREATE PROFILE ON SIGN-UP ----------
-- Supabase Auth only knows email/password. This trigger copies the
-- extra profile fields (passed in at sign-up as user_metadata) into
-- public.users so a row always exists before any RLS policy needs it.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  default_role_id uuid;
begin
  select id into default_role_id
  from public.roles
  where role_name = coalesce(new.raw_user_meta_data ->> 'role_name', 'Enterprise Owner');

  insert into public.users (id, first_name, last_name, email, phone_number, role_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    new.email,
    new.raw_user_meta_data ->> 'phone_number',
    default_role_id
  );

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- RLS ----------
alter table public.roles enable row level security;
alter table public.users enable row level security;

-- Helper: is the calling user an Administrator? SECURITY DEFINER so it
-- can read public.users without itself being blocked by RLS (avoids
-- infinite recursion when used inside a users policy).
create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1
    from public.users u
    join public.roles r on r.id = u.role_id
    where u.id = auth.uid()
      and r.role_name = 'Administrator'
  );
$$;

-- Roles: every authenticated user can read the role list (needed for
-- role-based UI/redirects); only Admins can modify it.
create policy "roles_select_authenticated"
  on public.roles for select
  to authenticated
  using (true);

create policy "roles_all_admin"
  on public.roles for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Users: everyone can read/update their own row; Admins can read/update
-- every row (needed for FR-054/056 user management).
create policy "users_select_own_or_admin"
  on public.users for select
  to authenticated
  using (id = auth.uid() or public.is_admin());

create policy "users_update_own_or_admin"
  on public.users for update
  to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- No insert/delete policy for authenticated users: rows are created only
-- by the handle_new_user trigger (SECURITY DEFINER, bypasses RLS) and
-- deletion cascades from auth.users, never done directly.