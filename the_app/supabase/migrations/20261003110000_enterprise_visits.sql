-- ============================================================
-- Visit log (Terms of Reference, "Going Concerns" deliverables)
-- ============================================================
-- Every ToR requires the consultant to "visit all the businesses in
-- portfolio twice a month" and to "log each customer visit in activity
-- report outlining outcomes of all visits ... 2 days after visit". This is
-- that log. One row = one visit (or call) by one consultant.
--
-- Who can do what (RLS is the boundary, not the app):
--   - read:   Admin; any consultant actively assigned to the enterprise
--             (the Trio works the business together); the Owner of it
--   - write:  only the consultant who made the visit, while assigned
--   - delete: the author, or an Admin
-- `logged_late` (logged more than 2 days after the visit) is computed by
-- the database, so it can't be edited to look on time.
-- Idempotent.
-- ============================================================

create table if not exists public.enterprise_visits (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id) on delete cascade,
  consultant_id uuid not null references public.users (id) default auth.uid(),
  specialization varchar(20) check (specialization in ('Legal', 'Accounting', 'Marketing')),
  visited_on date not null,
  mode text not null default 'In person' check (mode in ('In person', 'Phone or online')),
  outcome text not null check (length(trim(outcome)) > 0),
  next_steps text,
  logged_at timestamptz not null default now(),
  logged_late boolean generated always as ((logged_at at time zone 'Africa/Nairobi')::date - visited_on > 2) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint enterprise_visits_not_in_future check (visited_on <= (logged_at at time zone 'Africa/Nairobi')::date)
);

create index if not exists enterprise_visits_enterprise_idx
  on public.enterprise_visits (enterprise_id, visited_on desc);
create index if not exists enterprise_visits_consultant_idx
  on public.enterprise_visits (consultant_id, visited_on desc);

-- The visit belongs to the consultant's discipline, like their tasks.
create or replace function public.set_visit_specialization()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  select specialization into new.specialization from public.users where id = new.consultant_id;
  return new;
end;
$$;

drop trigger if exists enterprise_visits_set_specialization on public.enterprise_visits;
create trigger enterprise_visits_set_specialization
  before insert on public.enterprise_visits
  for each row execute function public.set_visit_specialization();

create or replace function public.touch_enterprise_visit()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  -- The visit date and logging time are the record of compliance; an
  -- edit may fix the notes, not move the visit.
  new.visited_on := old.visited_on;
  new.logged_at := old.logged_at;
  new.consultant_id := old.consultant_id;
  new.enterprise_id := old.enterprise_id;
  return new;
end;
$$;

drop trigger if exists enterprise_visits_touch on public.enterprise_visits;
create trigger enterprise_visits_touch
  before update on public.enterprise_visits
  for each row execute function public.touch_enterprise_visit();

alter table public.enterprise_visits enable row level security;

drop policy if exists "enterprise_visits_select" on public.enterprise_visits;
drop policy if exists "enterprise_visits_insert_own" on public.enterprise_visits;
drop policy if exists "enterprise_visits_update_own" on public.enterprise_visits;
drop policy if exists "enterprise_visits_delete_own_or_admin" on public.enterprise_visits;

create policy "enterprise_visits_select"
  on public.enterprise_visits for select
  to authenticated
  using (
    public.is_admin()
    or public.is_assigned_consultant(enterprise_id)
    or public.is_enterprise_owner(enterprise_id)
  );

create policy "enterprise_visits_insert_own"
  on public.enterprise_visits for insert
  to authenticated
  with check (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id));

create policy "enterprise_visits_update_own"
  on public.enterprise_visits for update
  to authenticated
  using (consultant_id = ((select auth.uid())))
  with check (consultant_id = ((select auth.uid())));

create policy "enterprise_visits_delete_own_or_admin"
  on public.enterprise_visits for delete
  to authenticated
  using (consultant_id = ((select auth.uid())) or public.is_admin());

revoke all on public.enterprise_visits from anon;
grant select, insert, update, delete on public.enterprise_visits to authenticated;
grant select, insert, update, delete on public.enterprise_visits to service_role;

-- ---------- audit (same pattern as 20260929130000) ----------
create or replace function public.audit_enterprise_visits()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.audit_write(
    'visit.logged', 'enterprise_visit', new.id, new.enterprise_id, new.consultant_id,
    public.audit_user_name(new.consultant_id) || ' logged a visit on ' || to_char(new.visited_on, 'DD Mon YYYY')
      || case when new.logged_late then ' (logged late)' else '' end,
    jsonb_build_object('mode', new.mode, 'logged_late', new.logged_late)
  );
  return new;
end;
$$;

drop trigger if exists audit_enterprise_visits on public.enterprise_visits;
create trigger audit_enterprise_visits
  after insert on public.enterprise_visits
  for each row execute function public.audit_enterprise_visits();
