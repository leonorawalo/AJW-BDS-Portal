-- ============================================================
-- Migration 4: Consultant Assignments
-- Module 3 (Consultant Assignment & Portfolio)
-- ============================================================

create table public.consultant_assignments (
  id uuid primary key default gen_random_uuid(),
  consultant_id uuid not null references public.users (id),
  enterprise_id uuid not null references public.enterprises (id),
  assigned_date timestamptz not null default now(),
  assigned_by uuid not null references public.users (id),
  assignment_status varchar(20) not null default 'active'
    check (assignment_status in ('active', 'ended')),
  created_at timestamptz not null default now()
);

create index consultant_assignments_consultant_id_idx
  on public.consultant_assignments (consultant_id);
create index consultant_assignments_enterprise_id_idx
  on public.consultant_assignments (enterprise_id);

-- Prevent the same consultant being actively assigned to the same
-- enterprise twice (a repeat assignment should end the old one first).
create unique index consultant_assignments_unique_active
  on public.consultant_assignments (consultant_id, enterprise_id)
  where assignment_status = 'active';

-- ---------- RLS: consultant_assignments ----------
alter table public.consultant_assignments enable row level security;

create policy "assignments_all_admin"
  on public.consultant_assignments for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "assignments_select_own_consultant"
  on public.consultant_assignments for select
  to authenticated
  using (consultant_id = auth.uid());

-- ---------- Follow-up policy on enterprises (flagged in Phase 2) ----------
-- Now that consultant_assignments exists, a Consultant can see the
-- enterprises actually assigned to them — nothing more, nothing less.
create policy "enterprises_select_assigned_consultant"
  on public.enterprises for select
  to authenticated
  using (
    exists (
      select 1
      from public.consultant_assignments ca
      where ca.enterprise_id = enterprises.id
        and ca.consultant_id = auth.uid()
        and ca.assignment_status = 'active'
    )
  );

-- ---------- Grants ----------
-- authenticated needs baseline table-level permission, same reasoning
-- as migration 3 — "Automatically expose new tables" is off, so this
-- doesn't happen automatically.
grant select, insert, update on public.consultant_assignments to authenticated;
