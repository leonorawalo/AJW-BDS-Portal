-- ============================================================
-- Task status edits: Admin loses it, Owner gains it.
-- ============================================================
-- Previously `tasks_all_admin` gave Admin unrestricted access
-- (select/insert/update/delete). Admin should still be able to view
-- and create/assign tasks (per the earlier "Admin/Owner can assign
-- custom tasks" change), but marking a task's status — Pending / In
-- Progress / Completed / Overdue — is now Owner/Consultant only, not
-- Admin. Admin stays able to comment (task_comments_all_admin is
-- untouched — comments aren't "task details").
-- ============================================================

drop policy if exists "tasks_all_admin" on public.tasks;

create policy "tasks_select_admin"
  on public.tasks for select
  to authenticated
  using (public.is_admin());

create policy "tasks_insert_admin"
  on public.tasks for insert
  to authenticated
  with check (public.is_admin());

-- Owner can now update task status on their own enterprise (previously
-- select+insert only). Same accepted MVP gap as recommendations_update_owner:
-- RLS can't restrict this to the status column alone without a trigger,
-- though the UI only ever offers a status control.
create policy "tasks_update_owner"
  on public.tasks for update
  to authenticated
  using (public.is_enterprise_owner(enterprise_id))
  with check (public.is_enterprise_owner(enterprise_id));
