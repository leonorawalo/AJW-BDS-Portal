-- ============================================================
-- Audit log: actor role, append-only guard, weekly backup
-- ============================================================
-- The audit log has been an app table since 20260929130000 (permanent
-- unless deleted, written only by SECURITY DEFINER triggers, readable by
-- Admins only, no insert/update/delete grants for app users). This adds:
--
-- 1. actor_role: the actor's role at the time of the event (a later role
--    change doesn't rewrite history). Back-filled with the current role
--    for older rows.
-- 2. A database-level append-only guard: nobody, not even a dashboard
--    user or the service role, can delete an entry or change what it
--    says. The only update allowed is the foreign keys' own
--    "on delete set null" when a user or enterprise is removed.
-- 3. A private Storage bucket `backups` for audit-log exports (the
--    audit-backup Edge Function writes backups/audit-log/<date>.csv).
--    Admins can download backups (read only). Scheduling the export is a
--    separate, owner-approved step.
-- Idempotent.
-- ============================================================

-- ---------- 1. actor role ----------
alter table public.audit_log add column if not exists actor_role text;

update public.audit_log a
set actor_role = r.role_name
from public.users u
join public.roles r on r.id = u.role_id
where a.actor_id = u.id and a.actor_role is null;

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
  insert into public.audit_log
    (actor_id, actor_role, action, entity_type, entity_id, enterprise_id, subject_user_id, summary, details)
  select
    -- Only record an actor that exists as an app user (the FK would
    -- otherwise fail for, e.g., a brand-new user's own first request).
    u.id,
    r.role_name,
    p_action, p_entity_type, p_entity_id, p_enterprise_id, p_subject_user_id,
    -- A NULL anywhere in a summary's || chain makes the whole text NULL.
    coalesce(p_summary, p_action),
    coalesce(p_details, '{}'::jsonb)
  from (select (select auth.uid()) as uid) me
  left join public.users u on u.id = me.uid
  left join public.roles r on r.id = u.role_id;
exception when others then
  -- Auditing must never block the real change (an upload, an
  -- assignment, ...). Log a warning and carry on.
  raise warning 'audit_write(%) failed: %', p_action, sqlerrm;
end;
$$;

revoke all on function public.audit_write(text, text, uuid, uuid, uuid, text, jsonb) from public, anon, authenticated;

-- ---------- 2. append-only ----------
create or replace function public.audit_log_append_only()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'The audit log is append-only: entries cannot be deleted';
  end if;
  -- UPDATE: only the "on delete set null" of a removed user/enterprise.
  if new.id is distinct from old.id
     or new.occurred_at is distinct from old.occurred_at
     or new.action is distinct from old.action
     or new.entity_type is distinct from old.entity_type
     or new.entity_id is distinct from old.entity_id
     or new.summary is distinct from old.summary
     or new.details is distinct from old.details
     or new.actor_role is distinct from old.actor_role
     or (new.actor_id is distinct from old.actor_id and new.actor_id is not null)
     or (new.enterprise_id is distinct from old.enterprise_id and new.enterprise_id is not null)
     or (new.subject_user_id is distinct from old.subject_user_id and new.subject_user_id is not null) then
    raise exception 'The audit log is append-only: entries cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists audit_log_append_only on public.audit_log;
create trigger audit_log_append_only
  before update or delete on public.audit_log
  for each row execute function public.audit_log_append_only();

-- TRUNCATE skips row triggers; block it separately.
drop trigger if exists audit_log_no_truncate on public.audit_log;
create trigger audit_log_no_truncate
  before truncate on public.audit_log
  for each statement execute function public.audit_log_append_only();

grant select on public.audit_log to service_role;

-- ---------- 3. backups ----------
insert into storage.buckets (id, name, public)
values ('backups', 'backups', false)
on conflict (id) do update set public = false;

drop policy if exists "backups_admin_read" on storage.objects;
create policy "backups_admin_read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'backups' and public.is_admin());

-- The weekly schedule (pg_cron job calling the audit-backup function) is
-- NOT set up here: it waits for the project owner's approval.
