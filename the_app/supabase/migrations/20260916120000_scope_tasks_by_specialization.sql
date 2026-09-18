-- ============================================================
-- Scope tasks by specialization
-- ============================================================
-- Now that up to three consultants (Legal / Accounting / Marketing)
-- can be concurrently active on one enterprise, tasks need two things
-- they never needed under the old single-consultant model:
--   1. A way to tell which specialization a task belongs to (for
--      display — Admin/Owner still see all tasks on an enterprise).
--   2. RLS that actually restricts each consultant to their own
--      tasks. Previously `tasks_all_assigned_consultant` only checked
--      "is this person *an* active consultant on this enterprise" —
--      not whether the task was actually theirs, so e.g. a Marketing
--      consultant could see and edit a Legal consultant's tasks. That
--      was harmless when there was only ever one active consultant;
--      it's a real boundary violation now.
-- ============================================================

alter table public.tasks
  add column specialization varchar(20)
    check (specialization in ('Legal', 'Accounting', 'Marketing'));

update public.tasks t
set specialization = u.specialization
from public.users u
where t.consultant_id = u.id
  and t.specialization is null;

create or replace function public.set_task_specialization()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  select specialization into new.specialization
  from public.users
  where id = new.consultant_id;
  return new;
end;
$$;

create trigger tasks_before_insert_specialization
  before insert on public.tasks
  for each row execute function public.set_task_specialization();

-- ---------- Narrow consultant access to their own tasks ----------
drop policy if exists "tasks_all_assigned_consultant" on public.tasks;

create policy "tasks_all_own_assigned_consultant"
  on public.tasks for all
  to authenticated
  using (consultant_id = auth.uid() and public.is_assigned_consultant(enterprise_id))
  with check (consultant_id = auth.uid() and public.is_assigned_consultant(enterprise_id));

-- task_comments follow the same boundary — a comment thread belongs to
-- whichever consultant the task belongs to, not to "anyone assigned to
-- this enterprise".
drop policy if exists "task_comments_all_assigned_consultant" on public.task_comments;

create policy "task_comments_all_own_assigned_consultant"
  on public.task_comments for all
  to authenticated
  using (
    exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and t.consultant_id = auth.uid()
        and public.is_assigned_consultant(t.enterprise_id)
    )
  )
  with check (
    exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and t.consultant_id = auth.uid()
        and public.is_assigned_consultant(t.enterprise_id)
    )
  );
