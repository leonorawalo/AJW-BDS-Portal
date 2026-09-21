-- ============================================================
-- Migration 5: Legal Workstream
-- Module 4 (Assessments, Tasks, Recommendations, Documents)
-- ============================================================

-- ---------- Helper functions ----------
-- Used repeatedly below instead of repeating the same subquery in
-- every policy — same reasoning as is_admin() from migration 1.

create or replace function public.is_assigned_consultant(target_enterprise_id uuid)
returns boolean
language sql
security definer set search_path = public
stable
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
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.enterprises e
    where e.id = target_enterprise_id
      and e.owner_user_id = ((select auth.uid()))
  );
$$;

-- ---------- ASSESSMENTS ----------
create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id),
  consultant_id uuid not null references public.users (id),
  assessment_type varchar(100) not null,
  findings text,
  compliance_score numeric,
  created_at timestamptz not null default now()
);

alter table public.assessments enable row level security;

create policy "assessments_all_admin"
  on public.assessments for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "assessments_all_assigned_consultant"
  on public.assessments for all to authenticated
  using (public.is_assigned_consultant(enterprise_id))
  with check (public.is_assigned_consultant(enterprise_id));

create policy "assessments_select_owner"
  on public.assessments for select to authenticated
  using (public.is_enterprise_owner(enterprise_id));

-- ---------- TASKS ----------
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id),
  consultant_id uuid not null references public.users (id),
  title varchar(255) not null,
  description text,
  priority varchar(10) not null default 'Medium'
    check (priority in ('Low', 'Medium', 'High')),
  due_date date,
  status varchar(20) not null default 'Pending'
    check (status in ('Pending', 'In Progress', 'Completed', 'Overdue')),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_enterprise_id_idx on public.tasks (enterprise_id);
create index tasks_consultant_id_idx on public.tasks (consultant_id);

create trigger tasks_set_updated_at
  before update on public.tasks
  for each row execute function public.set_updated_at();

-- Keep completed_at consistent with status automatically — same
-- reasoning as the Going Concern timestamp trigger in migration 2.
create or replace function public.check_task_completed_consistency()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'Completed' and new.completed_at is null then
    new.completed_at := now();
  elsif new.status != 'Completed' then
    new.completed_at := null;
  end if;
  return new;
end;
$$;

create trigger tasks_completed_consistency
  before insert or update on public.tasks
  for each row execute function public.check_task_completed_consistency();

alter table public.tasks enable row level security;

create policy "tasks_all_admin"
  on public.tasks for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "tasks_all_assigned_consultant"
  on public.tasks for all to authenticated
  using (public.is_assigned_consultant(enterprise_id))
  with check (public.is_assigned_consultant(enterprise_id));

-- Owner's workstream view is read-only on the task itself — they act
-- via comments and marking recommendations actioned, not by editing
-- tasks directly (see SRS: "Owner: read-only workstream view").
create policy "tasks_select_owner"
  on public.tasks for select to authenticated
  using (public.is_enterprise_owner(enterprise_id));

-- ---------- TASK_COMMENTS ----------
create table public.task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks (id),
  author_id uuid not null references public.users (id),
  comment_text text not null,
  created_at timestamptz not null default now()
);

create index task_comments_task_id_idx on public.task_comments (task_id);

alter table public.task_comments enable row level security;

create policy "task_comments_all_admin"
  on public.task_comments for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Consultant and Owner can both comment — access is determined by
-- looking up the parent task's enterprise, not by a direct FK on this
-- table (there isn't one; enterprise is reached via tasks).
create policy "task_comments_all_assigned_consultant"
  on public.task_comments for all to authenticated
  using (
    exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and public.is_assigned_consultant(t.enterprise_id)
    )
  )
  with check (
    exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and public.is_assigned_consultant(t.enterprise_id)
    )
  );

create policy "task_comments_select_and_insert_owner"
  on public.task_comments for all to authenticated
  using (
    exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and public.is_enterprise_owner(t.enterprise_id)
    )
  )
  with check (
    exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id
        and public.is_enterprise_owner(t.enterprise_id)
    )
  );

-- ---------- RECOMMENDATIONS ----------
create table public.recommendations (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id),
  consultant_id uuid not null references public.users (id),
  recommendation text not null,
  priority varchar(10) not null default 'Medium'
    check (priority in ('Low', 'Medium', 'High')),
  status varchar(20) not null default 'Open'
    check (status in ('Open', 'Actioned', 'Dismissed')),
  created_at timestamptz not null default now()
);

alter table public.recommendations enable row level security;

create policy "recommendations_all_admin"
  on public.recommendations for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "recommendations_all_assigned_consultant"
  on public.recommendations for all to authenticated
  using (public.is_assigned_consultant(enterprise_id))
  with check (public.is_assigned_consultant(enterprise_id));

-- Owner can read AND update — specifically to mark a recommendation
-- "Actioned" (SRS: "mark-actioned"). Postgres RLS can't restrict this
-- to only the status column without a trigger; flagged as an accepted
-- MVP gap — an Owner could technically also edit the recommendation
-- text itself via a direct API call, though the app's UI never offers
-- that. Worth a column-level trigger if this becomes a real concern.
create policy "recommendations_select_and_update_owner"
  on public.recommendations for select to authenticated
  using (public.is_enterprise_owner(enterprise_id));

create policy "recommendations_update_owner"
  on public.recommendations for update to authenticated
  using (public.is_enterprise_owner(enterprise_id))
  with check (public.is_enterprise_owner(enterprise_id));

-- ---------- DOCUMENTS ----------
create table public.documents (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id),
  task_id uuid references public.tasks (id),
  uploaded_by uuid not null references public.users (id),
  category varchar(100),
  file_name varchar(255) not null,
  storage_path text not null,
  mime_type varchar(100),
  uploaded_at timestamptz not null default now()
);

create index documents_enterprise_id_idx on public.documents (enterprise_id);
create index documents_task_id_idx on public.documents (task_id);

alter table public.documents enable row level security;

create policy "documents_all_admin"
  on public.documents for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "documents_all_assigned_consultant"
  on public.documents for all to authenticated
  using (public.is_assigned_consultant(enterprise_id))
  with check (public.is_assigned_consultant(enterprise_id));

-- Owner can view and upload (insert) documents for their own
-- enterprise, per SRS ("comment/upload").
create policy "documents_select_and_insert_owner"
  on public.documents for select to authenticated
  using (public.is_enterprise_owner(enterprise_id));

create policy "documents_insert_owner"
  on public.documents for insert to authenticated
  with check (public.is_enterprise_owner(enterprise_id));

-- ---------- Grants ----------
-- Same reasoning as migrations 3 and 4 — "Automatically expose new
-- tables" is off, so baseline permissions must be granted explicitly.
grant select, insert, update on public.assessments to authenticated;
grant select, insert, update on public.tasks to authenticated;
grant select, insert, update on public.task_comments to authenticated;
grant select, insert, update on public.recommendations to authenticated;
grant select, insert on public.documents to authenticated;
