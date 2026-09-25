-- ============================================================
-- Migration 15: Fix critical RLS boundaries & consultant reassignment
-- ============================================================
-- Fixes cross-role access bugs:
--   1. Owner could not select from consultant_assignments, which
--      broke "Add a custom task" (active assignments list was always empty).
--   2. Consultants could not SELECT tasks assigned to other specializations
--      on the same enterprise, which broke the Loan-Readiness dashboard
--      (Credit Readiness was always 0% for Legal, Business Health incomplete
--      for Accounting).
--   3. Consultants could not UPDATE financial facts on enterprises.
--   4. Non-admins could not select collaborators' users rows, making
--      comment author names and consultant names show as "Unknown".
--   5. Reassigning a consultant left incomplete tasks under the old
--      consultant ID ("ghost tasks" invisible to the new consultant).
--
-- Commit 6be2e70 edited several *already-applied* migration files in
-- place to attempt some of the above. Those edits never reached any
-- database that had already run the originals, and two of them
-- (assignments_select_owner / enterprises_*_assigned_consultant as
-- raw subqueries) reference each other's tables directly, which makes
-- Postgres raise "infinite recursion detected in policy". This
-- migration is therefore written to be idempotent and to converge to
-- the correct state whether the live DB has the original files, the
-- edited ones, or an earlier draft of this migration applied: every
-- policy it touches is dropped under all of its known names first, and
-- cross-table checks go through SECURITY DEFINER helpers only.
-- ============================================================


-- ---------- 0. HELPERS ----------
-- Re-declared with the ((select auth.uid())) initplan pattern so RLS
-- evaluates auth.uid() once per query, not once per row.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1
    from public.users u
    join public.roles r on r.id = u.role_id
    where u.id = ((select auth.uid()))
      and r.role_name = 'Administrator'
  );
$$;

create or replace function public.is_assigned_consultant(target_enterprise_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.consultant_assignments ca
    where ca.enterprise_id = target_enterprise_id
      and ca.consultant_id = ((select auth.uid()))
      and ca.assignment_status = 'active'
  );
$$;

create or replace function public.is_enterprise_owner(target_enterprise_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.enterprises e
    where e.id = target_enterprise_id
      and e.owner_user_id = ((select auth.uid()))
  );
$$;

-- True when the caller and target_user_id are both on at least one
-- common enterprise (as its owner or an active consultant). Lets
-- collaborators read each other's names without opening the whole
-- users table (emails/phones) to every signed-in account.
create or replace function public.is_collaborator(target_user_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  with my_enterprises as (
    select e.id from public.enterprises e
    where e.owner_user_id = ((select auth.uid()))
    union
    select ca.enterprise_id from public.consultant_assignments ca
    where ca.consultant_id = ((select auth.uid()))
      and ca.assignment_status = 'active'
  )
  select exists (
    select 1 from public.enterprises e
    where e.id in (select id from my_enterprises)
      and e.owner_user_id = target_user_id
  ) or exists (
    select 1 from public.consultant_assignments ca
    where ca.enterprise_id in (select id from my_enterprises)
      and ca.consultant_id = target_user_id
      and ca.assignment_status = 'active'
  );
$$;


-- ---------- 1. CONSULTANT_ASSIGNMENTS ----------
drop policy if exists "assignments_select_own_consultant" on public.consultant_assignments;
create policy "assignments_select_own_consultant"
  on public.consultant_assignments for select
  to authenticated
  using (consultant_id = ((select auth.uid())));

drop policy if exists "assignments_select_owner" on public.consultant_assignments;
create policy "assignments_select_owner"
  on public.consultant_assignments for select
  to authenticated
  using (public.is_enterprise_owner(enterprise_id));

-- Co-consultants on the same enterprise can see each other's
-- assignment (needed for names on the Trio's shared task list).
drop policy if exists "assignments_select_assigned_consultant" on public.consultant_assignments;
create policy "assignments_select_assigned_consultant"
  on public.consultant_assignments for select
  to authenticated
  using (public.is_assigned_consultant(enterprise_id));


-- ---------- 2. TASKS ----------
drop policy if exists "tasks_all_assigned_consultant" on public.tasks;
drop policy if exists "tasks_all_own_assigned_consultant" on public.tasks;
drop policy if exists "tasks_select_assigned_consultant" on public.tasks;
drop policy if exists "tasks_insert_assigned_consultant" on public.tasks;
drop policy if exists "tasks_insert_own_assigned_consultant" on public.tasks;
drop policy if exists "tasks_update_own_assigned_consultant" on public.tasks;
drop policy if exists "tasks_delete_own_assigned_consultant" on public.tasks;

-- Read: every task on the enterprise (the loan-readiness score spans
-- all specializations). Write: only the consultant's own tasks.
create policy "tasks_select_assigned_consultant"
  on public.tasks for select
  to authenticated
  using (public.is_assigned_consultant(enterprise_id));

create policy "tasks_insert_own_assigned_consultant"
  on public.tasks for insert
  to authenticated
  with check (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id));

create policy "tasks_update_own_assigned_consultant"
  on public.tasks for update
  to authenticated
  using (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id))
  with check (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id));

create policy "tasks_delete_own_assigned_consultant"
  on public.tasks for delete
  to authenticated
  using (consultant_id = ((select auth.uid())) and public.is_assigned_consultant(enterprise_id));


-- ---------- 3. ENTERPRISES ----------
drop policy if exists "enterprises_select_assigned_consultant" on public.enterprises;
create policy "enterprises_select_assigned_consultant"
  on public.enterprises for select
  to authenticated
  using (public.is_assigned_consultant(id));

drop policy if exists "enterprises_update_assigned_consultant" on public.enterprises;
create policy "enterprises_update_assigned_consultant"
  on public.enterprises for update
  to authenticated
  using (public.is_assigned_consultant(id))
  with check (public.is_assigned_consultant(id));

drop policy if exists "enterprises_select_own_owner" on public.enterprises;
create policy "enterprises_select_own_owner"
  on public.enterprises for select
  to authenticated
  using (owner_user_id = ((select auth.uid())));

drop policy if exists "enterprises_update_own_owner" on public.enterprises;
create policy "enterprises_update_own_owner"
  on public.enterprises for update
  to authenticated
  using (owner_user_id = ((select auth.uid())))
  with check (owner_user_id = ((select auth.uid())));

-- RLS can't limit an UPDATE to specific columns, and the two policies
-- above would otherwise let a consultant/owner rewrite business_name,
-- lifecycle_status, going_concern_status, owner_user_id, etc. Only
-- Admins (and server-side calls with no auth.uid(), e.g. the service
-- role or the SQL editor) may change anything beyond the loan-readiness
-- facts.
create or replace function public.restrict_non_admin_enterprise_updates()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  editable constant text[] := array[
    'annual_turnover', 'business_started_date', 'loan_purpose', 'updated_at'
  ];
begin
  if (select auth.uid()) is null or public.is_admin() then
    return new;
  end if;

  if (to_jsonb(new) - editable) is distinct from (to_jsonb(old) - editable) then
    raise exception 'Only an Administrator can change enterprise details other than financial facts'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists enterprises_restrict_non_admin_updates on public.enterprises;
create trigger enterprises_restrict_non_admin_updates
  before update on public.enterprises
  for each row execute function public.restrict_non_admin_enterprise_updates();


-- ---------- 4. USERS (collaborator names) ----------
drop policy if exists "users_select_own_or_admin" on public.users;
drop policy if exists "users_select_own_or_admin_or_collaborator" on public.users;
drop policy if exists "users_select_authenticated" on public.users;

create policy "users_select_own_or_admin_or_collaborator"
  on public.users for select
  to authenticated
  using (
    id = ((select auth.uid()))
    or public.is_admin()
    or public.is_collaborator(id)
  );

drop policy if exists "users_update_own_or_admin" on public.users;
create policy "users_update_own_or_admin"
  on public.users for update
  to authenticated
  using (id = ((select auth.uid())) or public.is_admin())
  with check (id = ((select auth.uid())) or public.is_admin());


-- ---------- 5. TASK COMMENTS ----------
-- Any assigned consultant can read and join a task's thread (matching
-- the widened task SELECT above), but can only post as themselves and
-- can't edit anyone else's comment.
drop policy if exists "task_comments_all_assigned_consultant" on public.task_comments;
drop policy if exists "task_comments_all_own_assigned_consultant" on public.task_comments;
drop policy if exists "task_comments_select_assigned_consultant" on public.task_comments;
drop policy if exists "task_comments_insert_assigned_consultant" on public.task_comments;

create policy "task_comments_select_assigned_consultant"
  on public.task_comments for select
  to authenticated
  using (
    exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and public.is_assigned_consultant(t.enterprise_id)
    )
  );

create policy "task_comments_insert_assigned_consultant"
  on public.task_comments for insert
  to authenticated
  with check (
    author_id = ((select auth.uid()))
    and exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and public.is_assigned_consultant(t.enterprise_id)
    )
  );


-- ---------- 6. REASSIGNMENT TRIGGER ----------
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
    -- End prior active assignments of the same specialization
    update public.consultant_assignments
    set assignment_status = 'ended'
    where enterprise_id = new.enterprise_id
      and specialization = new.specialization
      and assignment_status = 'active';

    -- Hand over incomplete tasks of this specialization to the new
    -- consultant (completed ones stay credited to whoever did them)
    update public.tasks
    set consultant_id = new.consultant_id
    where enterprise_id = new.enterprise_id
      and specialization = new.specialization
      and status <> 'Completed'
      and consultant_id is distinct from new.consultant_id;
  end if;

  return new;
end;
$$;
