-- ============================================================
-- Consultant assignments: support the ToR "Trio" model properly
-- ============================================================
-- Previously the app treated an enterprise as having at most one
-- active consultant, full stop — assign() always ended *every*
-- active assignment on the enterprise before inserting the new one.
-- The ToR actually wants up to three concurrent active assignments
-- per enterprise, one per specialization (Legal / Accounting /
-- Marketing). This migration makes "one active consultant per
-- specialization per enterprise" the real constraint.
--
-- specialization is denormalized onto this table (copied from the
-- consultant's public.users row at insert time) rather than joined
-- every time — it's fixed per consultant in practice, and this lets
-- the "end the conflicting assignment" trigger and any query filter
-- on it directly without a join.
-- ============================================================

alter table public.consultant_assignments
  add column specialization varchar(20)
    check (specialization in ('Legal', 'Accounting', 'Marketing'));

update public.consultant_assignments ca
set specialization = u.specialization
from public.users u
where ca.consultant_id = u.id
  and ca.specialization is null;

-- The old invariant ("this consultant can't be double-booked on the
-- same enterprise") is superseded by the specialization-scoped one
-- below.
drop index if exists public.consultant_assignments_unique_active;

-- Derives specialization from the consultant's profile, then ends
-- any existing active assignment for the same enterprise+specialization
-- before the new row lands — so the app never has to orchestrate the
-- "end old, then insert new" sequence itself, and a reassignment
-- within one specialization can never leave two active rows even
-- under a race. BEFORE INSERT (not AFTER) specifically so the
-- conflicting row is already ended by the time this row is written —
-- an AFTER trigger would be too late to avoid a would-be duplicate
-- active state existing, even momentarily.
create or replace function public.set_assignment_specialization_and_end_conflicts()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  select specialization into new.specialization
  from public.users
  where id = new.consultant_id;

  if new.assignment_status = 'active' then
    update public.consultant_assignments
    set assignment_status = 'ended'
    where enterprise_id = new.enterprise_id
      and specialization = new.specialization
      and assignment_status = 'active';
  end if;

  return new;
end;
$$;

create trigger consultant_assignments_before_insert
  before insert on public.consultant_assignments
  for each row execute function public.set_assignment_specialization_and_end_conflicts();
