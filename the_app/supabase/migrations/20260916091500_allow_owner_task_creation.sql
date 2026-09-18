-- ============================================================
-- Owner can now create custom tasks (assigned to one of their
-- enterprise's active consultants) — reverses the original
-- "Owner workstream is fully read-only on tasks" decision. Owner
-- still cannot update or delete a task (status changes remain
-- Admin/Consultant-only) — this is insert-only.
-- ============================================================

create policy "tasks_insert_owner"
  on public.tasks for insert
  to authenticated
  with check (public.is_enterprise_owner(enterprise_id));
