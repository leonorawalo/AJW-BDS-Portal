-- ============================================================
-- ToR tasks follow the consultant's specialization, automatically
-- ============================================================
-- Before: ToR tasks were added once, by the Admin's Assign screen, in
-- the app. Marketing got none, failures were swallowed, and the Tasks
-- tab's "apply checklist" was hard-coded to the Legal list. So a
-- Marketing consultant could see no tasks and be offered Legal's.
--
-- Now:
--   - tasks.tor_key identifies a ToR checklist item (the lists stay a
--     static Dart list, see task_template.dart; this is only their key).
--     A partial unique index makes each item exist at most once per
--     enterprise and specialization, whoever adds it and however often.
--   - ensure_tor_tasks() adds the missing items of one specialization's
--     checklist for the consultant currently assigned to it. The app
--     calls it on assignment and whenever the Tasks tab opens, so it
--     also back-fills existing enterprises. Only an Admin or that
--     consultant may call it.
--   - A consultant without a specialization can't be assigned (their
--     tasks would belong to no discipline).
-- Idempotent.
-- ============================================================

alter table public.tasks add column if not exists tor_key varchar(40);

create unique index if not exists tasks_one_tor_item_per_enterprise
  on public.tasks (enterprise_id, specialization, tor_key)
  where tor_key is not null;

create or replace function public.ensure_tor_tasks(
  p_enterprise_id uuid,
  p_specialization text,
  p_items jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_consultant uuid;
  v_added integer;
begin
  if p_specialization not in ('Legal', 'Accounting', 'Marketing') then
    raise exception 'Unknown specialization: %', p_specialization;
  end if;

  select ca.consultant_id into v_consultant
  from public.consultant_assignments ca
  where ca.enterprise_id = p_enterprise_id
    and ca.specialization = p_specialization
    and ca.assignment_status = 'active'
  limit 1;

  if v_consultant is null then
    return 0; -- nobody holds this discipline on the enterprise yet
  end if;

  if not (public.is_admin() or v_consultant = (select auth.uid())) then
    raise exception 'Only an administrator or the assigned % consultant can add these tasks', p_specialization;
  end if;

  insert into public.tasks (enterprise_id, consultant_id, title, description, priority, due_date, tor_key)
  select p_enterprise_id, v_consultant, x.title, x.description, x.priority, x.due_date, x.tor_key
  from jsonb_to_recordset(p_items) as x(tor_key text, title text, description text, priority text, due_date date)
  on conflict (enterprise_id, specialization, tor_key) where tor_key is not null do nothing;

  get diagnostics v_added = row_count;
  return v_added;
end;
$$;

revoke all on function public.ensure_tor_tasks(uuid, text, jsonb) from public, anon;
grant execute on function public.ensure_tor_tasks(uuid, text, jsonb) to authenticated;

-- Runs after consultant_assignments_before_insert (triggers fire in name
-- order), which copies the consultant's specialization onto the row.
create or replace function public.require_assignment_specialization()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.specialization is null then
    raise exception using
      errcode = 'P0001',
      message = 'This consultant has no specialization yet. Set it on the Users screen (Legal, Accounting or Marketing), then assign them.';
  end if;
  return new;
end;
$$;

drop trigger if exists consultant_assignments_require_specialization on public.consultant_assignments;
create trigger consultant_assignments_require_specialization
  before insert on public.consultant_assignments
  for each row
  execute function public.require_assignment_specialization();
