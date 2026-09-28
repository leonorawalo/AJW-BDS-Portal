-- ============================================================
-- Consultants see only their own discipline's tasks
-- ============================================================
-- Product decision (2026-09-28): a Marketing consultant has no business
-- seeing Legal tasks. 20260920120000 had widened consultant SELECT to
-- every task on the enterprise, only so the loan-readiness dashboard
-- could score from all disciplines' tasks. That need is now met by
-- completed_loan_readiness_tasks() below, which reveals only *whether*
-- specific score-relevant tasks are done — never the tasks themselves.
--
-- A consultant can read a task when they're actively assigned to the
-- enterprise AND either:
--   - it's their own task (consultant_id), or
--   - it's in their specialization — so after a reassignment the new
--     consultant still sees the predecessor's completed history in their
--     own discipline (incomplete ones are handed over by the assignment
--     trigger anyway).
-- Admin and Owner visibility is unchanged. Write policies are unchanged
-- (already own-tasks only).
--
-- task_comments needs no change: its consultant policies check the task
-- through a subquery on public.tasks, which is itself RLS-filtered, so
-- comment visibility narrows along with task visibility.
-- ============================================================

-- SECURITY DEFINER so the policy can read the caller's specialization
-- without depending on (or recursing into) users RLS.
create or replace function public.current_user_specialization()
returns varchar
language sql
stable
security definer set search_path = public
as $$
  select u.specialization from public.users u where u.id = ((select auth.uid()));
$$;

revoke all on function public.current_user_specialization() from public, anon;
grant execute on function public.current_user_specialization() to authenticated;

drop policy if exists "tasks_select_assigned_consultant" on public.tasks;
create policy "tasks_select_assigned_consultant"
  on public.tasks for select
  to authenticated
  using (
    public.is_assigned_consultant(enterprise_id)
    and (
      consultant_id = ((select auth.uid()))
      or specialization = ((select public.current_user_specialization()))
    )
  );


-- ---------- Dashboard: completion status only ----------
-- Returns the subset of p_titles that exist as Completed tasks on the
-- enterprise. Only callers who may view that enterprise's dashboard
-- (Admin, an active assigned consultant, or the Owner) get anything back;
-- everyone else gets an empty set. The app passes the fixed list of
-- score-relevant ToR titles (loanReadinessTaskTitles in
-- loan_readiness.dart).
create or replace function public.completed_loan_readiness_tasks(
  p_enterprise_id uuid,
  p_titles text[]
)
returns setof text
language sql
stable
security definer set search_path = public
as $$
  select distinct t.title::text
  from public.tasks t
  where t.enterprise_id = p_enterprise_id
    and t.status = 'Completed'
    and t.title = any (p_titles)
    and (
      public.is_admin()
      or public.is_assigned_consultant(p_enterprise_id)
      or public.is_enterprise_owner(p_enterprise_id)
    );
$$;

revoke all on function public.completed_loan_readiness_tasks(uuid, text[]) from public, anon;
grant execute on function public.completed_loan_readiness_tasks(uuid, text[]) to authenticated;
