-- ============================================================
-- Migration 2: Enterprises
-- Module 2 (Enterprise Management)
-- ============================================================

create table public.enterprises (
  id uuid primary key default gen_random_uuid(),

  business_name varchar(255) not null,
  owner_name varchar(255) not null,
  owner_user_id uuid references public.users (id), -- nullable: Admin may register
                                                     -- an enterprise before its Owner
                                                     -- has a login (see ERD decision log)
  phone_number varchar(20),
  email varchar(255),
  county varchar(100),
  industry varchar(100),
  registration_number varchar(100) unique,
  kra_pin varchar(100) unique,

  -- SRS FR-013/BR-009 lifecycle, unchanged from the spec
  lifecycle_status varchar(30) not null default 'New'
    check (lifecycle_status in (
      'New', 'Active', 'Under Assessment', 'In Progress',
      'Loan Ready', 'Graduated', 'Inactive'
    )),

  -- TOR-driven KPI, deliberately independent of lifecycle_status
  -- (see ERD v1: "Going Concern vs. Loan Ready are two different KPIs")
  going_concern_status varchar(20) not null default 'Not Yet'
    check (going_concern_status in ('Not Yet', 'Achieved')),
  going_concern_achieved_at timestamptz,

  enrolled_at timestamptz not null default now(),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index enterprises_owner_user_id_idx on public.enterprises (owner_user_id);
create index enterprises_lifecycle_status_idx on public.enterprises (lifecycle_status);

create trigger enterprises_set_updated_at
  before update on public.enterprises
  for each row execute function public.set_updated_at(); -- reuses the helper
                                                            -- from migration 1

-- Enforce: going_concern_achieved_at is set if and only if the status says
-- "Achieved" — keeps the KPI's date field from silently drifting out of
-- sync with its own status.
create or replace function public.check_going_concern_consistency()
returns trigger
language plpgsql
as $$
begin
  if new.going_concern_status = 'Achieved' and new.going_concern_achieved_at is null then
    new.going_concern_achieved_at := now();
  elsif new.going_concern_status = 'Not Yet' then
    new.going_concern_achieved_at := null;
  end if;
  return new;
end;
$$;

create trigger enterprises_going_concern_consistency
  before insert or update on public.enterprises
  for each row execute function public.check_going_concern_consistency();

-- ---------- RLS ----------
alter table public.enterprises enable row level security;

-- Admin: full access.
create policy "enterprises_all_admin"
  on public.enterprises for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Enterprise Owner: can see and update their own enterprise only.
-- (Consultant access is deliberately NOT added here — it depends on
-- ConsultantAssignments, which doesn't exist until Phase 3. A follow-up
-- migration adds a consultant-scoped policy once that table lands.)
create policy "enterprises_select_own_owner"
  on public.enterprises for select
  to authenticated
  using (owner_user_id = auth.uid());

create policy "enterprises_update_own_owner"
  on public.enterprises for update
  to authenticated
  using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- No insert/delete policy for non-admins: enterprises are registered by
-- Admins only (FR-009), never self-registered by Owners.