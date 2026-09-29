-- ============================================================
-- Phase 9c: Audit log (key events only)
-- ============================================================
-- Scope decided 2026-09-29: key events only.
--   users                    created (invited), role / status /
--                            specialization changed
--   enterprises              created; lifecycle, going concern or owner
--                            changed
--   consultant_assignments   assigned, ended
--   tasks                    status changed
--   documents                uploaded
--   consultation_sessions    booked, cancelled
--
-- Written ONLY by the AFTER triggers below (SECURITY DEFINER), never by
-- the app. App users have SELECT (Admins only, via RLS) and nothing else,
-- so entries can't be forged, edited or deleted through the API. This
-- follows this project's rule that derived records come from the database.
--
-- actor_id is auth.uid() of whoever made the change. It's NULL for
-- server-side changes (e.g. invites created by the invite-user function
-- with the service role), which the app shows as "System".
-- ============================================================

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  occurred_at timestamptz not null default now(),
  actor_id uuid references public.users (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  enterprise_id uuid references public.enterprises (id) on delete set null,
  -- The person the event is about (the consultant assigned, the user
  -- suspended, ...), so "filter by user" finds both what someone did and
  -- what happened to them.
  subject_user_id uuid references public.users (id) on delete set null,
  summary text not null,
  details jsonb not null default '{}'::jsonb
);

create index if not exists audit_log_occurred_at_idx on public.audit_log (occurred_at desc);
create index if not exists audit_log_enterprise_idx on public.audit_log (enterprise_id, occurred_at desc);
create index if not exists audit_log_actor_idx on public.audit_log (actor_id, occurred_at desc);
create index if not exists audit_log_subject_idx on public.audit_log (subject_user_id, occurred_at desc);

alter table public.audit_log enable row level security;

drop policy if exists "audit_log_select_admin" on public.audit_log;
create policy "audit_log_select_admin"
  on public.audit_log for select
  to authenticated
  using (public.is_admin());

revoke all on public.audit_log from anon, authenticated;
grant select on public.audit_log to authenticated;


-- ---------- helpers ----------
create or replace function public.audit_user_name(p_user_id uuid)
returns text
language sql
stable
security definer set search_path = public
as $$
  select coalesce(nullif(trim(u.first_name || ' ' || u.last_name), ''), u.email)
  from public.users u where u.id = p_user_id;
$$;

create or replace function public.audit_write(
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_enterprise_id uuid,
  p_subject_user_id uuid,
  p_summary text,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.audit_log (actor_id, action, entity_type, entity_id, enterprise_id, subject_user_id, summary, details)
  values (
    -- Only record an actor that exists as an app user (the FK would
    -- otherwise fail for, e.g., a brand-new user's own first request).
    (select u.id from public.users u where u.id = (select auth.uid())),
    p_action, p_entity_type, p_entity_id, p_enterprise_id, p_subject_user_id,
    -- A NULL anywhere in a summary's || chain makes the whole text NULL.
    coalesce(p_summary, p_action),
    coalesce(p_details, '{}'::jsonb)
  );
exception when others then
  -- Auditing must never block the real change (an upload, an
  -- assignment, ...). Log a warning and carry on.
  raise warning 'audit_write(%) failed: %', p_action, sqlerrm;
end;
$$;

-- Internal only: called by the triggers below, never by the app.
revoke all on function public.audit_write(text, text, uuid, uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function public.audit_user_name(uuid) from public, anon, authenticated;


-- ---------- users ----------
create or replace function public.audit_users()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  old_role text;
  new_role text;
begin
  select role_name into new_role from public.roles where id = new.role_id;

  if tg_op = 'INSERT' then
    perform public.audit_write('user.created', 'user', new.id, null, new.id,
      public.audit_user_name(new.id) || ' was added as ' || coalesce(new_role, 'a user')
        || coalesce(' (' || new.specialization || ')', ''),
      jsonb_build_object('role', new_role, 'specialization', new.specialization, 'email', new.email));
    return new;
  end if;

  if new.role_id is distinct from old.role_id then
    select role_name into old_role from public.roles where id = old.role_id;
    perform public.audit_write('user.role_changed', 'user', new.id, null, new.id,
      public.audit_user_name(new.id) || ': role ' || coalesce(old_role, '?') || ' -> ' || coalesce(new_role, '?'),
      jsonb_build_object('from', old_role, 'to', new_role));
  end if;
  if new.status is distinct from old.status then
    perform public.audit_write(
      case when new.status = 'suspended' then 'user.suspended' else 'user.reactivated' end,
      'user', new.id, null, new.id,
      public.audit_user_name(new.id) || case when new.status = 'suspended' then ' was suspended' else ' was reactivated' end,
      jsonb_build_object('from', old.status, 'to', new.status));
  end if;
  if new.specialization is distinct from old.specialization then
    perform public.audit_write('user.specialization_changed', 'user', new.id, null, new.id,
      public.audit_user_name(new.id) || ': specialization ' || coalesce(old.specialization, 'none')
        || ' -> ' || coalesce(new.specialization, 'none'),
      jsonb_build_object('from', old.specialization, 'to', new.specialization));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_users on public.users;
create trigger audit_users
  after insert or update on public.users
  for each row execute function public.audit_users();


-- ---------- enterprises ----------
create or replace function public.audit_enterprises()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.audit_write('enterprise.created', 'enterprise', new.id, new.id, new.owner_user_id,
      'Enterprise "' || new.business_name || '" was registered',
      jsonb_build_object('lifecycle_status', new.lifecycle_status));
    return new;
  end if;

  if new.lifecycle_status is distinct from old.lifecycle_status then
    perform public.audit_write('enterprise.lifecycle_changed', 'enterprise', new.id, new.id, null,
      '"' || new.business_name || '": lifecycle ' || old.lifecycle_status || ' -> ' || new.lifecycle_status,
      jsonb_build_object('from', old.lifecycle_status, 'to', new.lifecycle_status));
  end if;
  if new.going_concern_status is distinct from old.going_concern_status then
    perform public.audit_write('enterprise.going_concern_changed', 'enterprise', new.id, new.id, null,
      '"' || new.business_name || '": Going Concern ' || old.going_concern_status || ' -> ' || new.going_concern_status,
      jsonb_build_object('from', old.going_concern_status, 'to', new.going_concern_status));
  end if;
  if new.owner_user_id is distinct from old.owner_user_id then
    perform public.audit_write('enterprise.owner_linked', 'enterprise', new.id, new.id, new.owner_user_id,
      '"' || new.business_name || '": owner account '
        || coalesce('linked to ' || public.audit_user_name(new.owner_user_id), 'unlinked'),
      jsonb_build_object('from', old.owner_user_id, 'to', new.owner_user_id));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_enterprises on public.enterprises;
create trigger audit_enterprises
  after insert or update on public.enterprises
  for each row execute function public.audit_enterprises();


-- ---------- consultant_assignments ----------
create or replace function public.audit_consultant_assignments()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  business text;
begin
  select business_name into business from public.enterprises where id = new.enterprise_id;

  if tg_op = 'INSERT' and new.assignment_status = 'active' then
    perform public.audit_write('assignment.created', 'assignment', new.id, new.enterprise_id, new.consultant_id,
      public.audit_user_name(new.consultant_id) || coalesce(' (' || new.specialization || ')', '')
        || ' was assigned to "' || coalesce(business, '?') || '"',
      jsonb_build_object('specialization', new.specialization));
  elsif tg_op = 'UPDATE' and new.assignment_status is distinct from old.assignment_status
        and new.assignment_status = 'ended' then
    perform public.audit_write('assignment.ended', 'assignment', new.id, new.enterprise_id, new.consultant_id,
      public.audit_user_name(new.consultant_id) || coalesce(' (' || new.specialization || ')', '')
        || ' was unassigned from "' || coalesce(business, '?') || '"',
      jsonb_build_object('specialization', new.specialization));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_consultant_assignments on public.consultant_assignments;
create trigger audit_consultant_assignments
  after insert or update on public.consultant_assignments
  for each row execute function public.audit_consultant_assignments();


-- ---------- tasks (status changes only) ----------
create or replace function public.audit_tasks()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    perform public.audit_write('task.status_changed', 'task', new.id, new.enterprise_id, new.consultant_id,
      'Task "' || new.title || '": ' || old.status || ' -> ' || new.status,
      jsonb_build_object('from', old.status, 'to', new.status, 'specialization', new.specialization));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_tasks on public.tasks;
create trigger audit_tasks
  after update on public.tasks
  for each row execute function public.audit_tasks();


-- ---------- documents (uploads) ----------
create or replace function public.audit_documents()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.audit_write('document.uploaded', 'document', new.id, new.enterprise_id, new.uploaded_by,
    'Document "' || new.file_name || '" uploaded' || coalesce(' (' || new.category || ')', ''),
    jsonb_build_object('category', new.category, 'task_id', new.task_id, 'mime_type', new.mime_type));
  return new;
end;
$$;

drop trigger if exists audit_documents on public.documents;
create trigger audit_documents
  after insert on public.documents
  for each row execute function public.audit_documents();


-- ---------- consultation_sessions ----------
create or replace function public.audit_consultation_sessions()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.audit_write('session.booked', 'session', new.id, new.enterprise_id, new.organizer_id,
      'Session "' || new.title || '" booked for ' || to_char(new.starts_at at time zone 'Africa/Nairobi', 'YYYY-MM-DD HH24:MI'),
      jsonb_build_object('starts_at', new.starts_at, 'ends_at', new.ends_at));
  elsif new.status is distinct from old.status and new.status = 'Cancelled' then
    perform public.audit_write('session.cancelled', 'session', new.id, new.enterprise_id, new.organizer_id,
      'Session "' || new.title || '" was cancelled',
      jsonb_build_object('starts_at', new.starts_at));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_consultation_sessions on public.consultation_sessions;
create trigger audit_consultation_sessions
  after insert or update on public.consultation_sessions
  for each row execute function public.audit_consultation_sessions();
