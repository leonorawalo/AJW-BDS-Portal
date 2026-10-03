-- ============================================================
-- Workshops and registration lists (Terms of Reference)
-- ============================================================
-- Every ToR: "As part of the BDS trio, hold onboarding & induction
-- workshops/meetings for programme beneficiaries" and "Submit an excel
-- copy of class registration list to M & E team 5 days after each BDS
-- workshop". Beneficiaries usually don't have portal accounts yet, so
-- attendees are plain names (optionally linked to an enterprise).
--
-- Access: Admin and consultants (the BDS team) read and write; Owners
-- don't see these. Only the creator or an Admin deletes a workshop.
-- Idempotent.
-- ============================================================

create table if not exists public.workshops (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) > 0),
  kind text not null default 'Onboarding & induction'
    check (kind in ('Onboarding & induction', 'BDS workshop', 'Other')),
  held_on date not null,
  location text,
  notes text,
  created_by uuid not null references public.users (id) default auth.uid(),
  -- When the registration list went to the M&E team (ToR: within 5 days).
  registration_sent_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.workshop_attendees (
  id uuid primary key default gen_random_uuid(),
  workshop_id uuid not null references public.workshops (id) on delete cascade,
  full_name text not null check (length(trim(full_name)) > 0),
  phone text,
  business_name text,
  enterprise_id uuid references public.enterprises (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists workshops_held_on_idx on public.workshops (held_on desc);
create index if not exists workshop_attendees_workshop_idx on public.workshop_attendees (workshop_id);

-- Admins and consultants: the BDS team.
create or replace function public.is_bds_team()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.users u join public.roles r on r.id = u.role_id
    where u.id = (select auth.uid())
      and r.role_name in ('Administrator', 'Consultant')
      and u.status = 'active'
  );
$$;
revoke all on function public.is_bds_team() from public, anon;
grant execute on function public.is_bds_team() to authenticated;

alter table public.workshops enable row level security;
alter table public.workshop_attendees enable row level security;

drop policy if exists "workshops_team_select" on public.workshops;
drop policy if exists "workshops_team_insert" on public.workshops;
drop policy if exists "workshops_team_update" on public.workshops;
drop policy if exists "workshops_creator_or_admin_delete" on public.workshops;
drop policy if exists "workshop_attendees_team_all" on public.workshop_attendees;

create policy "workshops_team_select" on public.workshops for select to authenticated
  using (public.is_bds_team());
create policy "workshops_team_insert" on public.workshops for insert to authenticated
  with check (public.is_bds_team() and created_by = ((select auth.uid())));
create policy "workshops_team_update" on public.workshops for update to authenticated
  using (public.is_bds_team()) with check (public.is_bds_team());
create policy "workshops_creator_or_admin_delete" on public.workshops for delete to authenticated
  using (created_by = ((select auth.uid())) or public.is_admin());

create policy "workshop_attendees_team_all" on public.workshop_attendees for all to authenticated
  using (public.is_bds_team()) with check (public.is_bds_team());

revoke all on public.workshops, public.workshop_attendees from anon;
grant select, insert, update, delete on public.workshops, public.workshop_attendees to authenticated;
grant select, insert, update, delete on public.workshops, public.workshop_attendees to service_role;

create or replace function public.audit_workshops()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.audit_write(
    'workshop.created', 'workshop', new.id, null, null,
    public.audit_user_name(new.created_by) || ' recorded the workshop "' || new.title || '" on ' || to_char(new.held_on, 'DD Mon YYYY'),
    jsonb_build_object('kind', new.kind)
  );
  return new;
end;
$$;

drop trigger if exists audit_workshops on public.workshops;
create trigger audit_workshops after insert on public.workshops
  for each row execute function public.audit_workshops();
