-- One-off: flush all test data before real users are invited (2026-09-30).
-- NOT a migration. Run with:
--   npx supabase db query --linked -f supabase/scripts/flush_test_data.sql
-- As written it ends in ROLLBACK (a dry run that changes nothing but proves
-- the whole flush succeeds and shows the counts it would leave). The real
-- run is the same file with the last line changed to COMMIT.
-- Backup taken first: C:\Users\user\AJW-BDS-Backups\2026-09-30-before-flush
--
-- Keeps: roles, schema, functions, migrations, Storage buckets, and these
-- two accounts (both Administrators):
--   ajw.bags.portal@gmail.com      (renamed "AJW Admin")
--   jonathan.maina@ajwafrica.org   (Jonathan Maina)
-- Deletes everything else. Uploaded files in Storage are removed separately
-- with `supabase storage rm` (Supabase blocks deleting them from SQL).

begin;

-- Database webhooks would otherwise call send-push once per deleted row.
alter table public.tasks disable trigger "notify-consultant-assignment";
alter table public.users disable trigger "notify-consultant-assignment";

create temporary table keep_users on commit drop as
select au.id, lower(au.email) as email
from auth.users au
where lower(au.email) in ('ajw.bags.portal@gmail.com', 'jonathan.maina@ajwafrica.org');

do $$
begin
  if (select count(*) from keep_users) <> 2 then
    raise exception 'Expected exactly 2 accounts to keep, found %', (select count(*) from keep_users);
  end if;
end $$;

update public.users set first_name = 'AJW', last_name = 'Admin'
where id = (select id from keep_users where email = 'ajw.bags.portal@gmail.com');

-- Enterprise data, children first.
delete from public.session_participants;
delete from public.consultation_sessions;
delete from public.task_comments;
delete from public.documents;
delete from public.recommendations;
delete from public.assessments;
delete from public.tasks;
delete from public.enterprise_files;
delete from public.consultant_assignments;
delete from public.enterprises;

-- Per-user data (also cascades from users, but cleared for the keepers too).
delete from public.google_connections;
delete from public.google_oauth_states;
delete from public.device_tokens;

-- Every other account. public.users, identities, sessions and refresh
-- tokens cascade from auth.users.
delete from auth.users where id not in (select id from keep_users);

-- Last, so no row written by the steps above survives.
delete from public.audit_log;

alter table public.tasks enable trigger "notify-consultant-assignment";
alter table public.users enable trigger "notify-consultant-assignment";

select 'users' as t, count(*) as remaining from public.users
union all select 'auth.users', count(*) from auth.users
union all select 'roles', count(*) from public.roles
union all select 'enterprises', count(*) from public.enterprises
union all select 'tasks', count(*) from public.tasks
union all select 'task_comments', count(*) from public.task_comments
union all select 'documents', count(*) from public.documents
union all select 'recommendations', count(*) from public.recommendations
union all select 'assessments', count(*) from public.assessments
union all select 'consultation_sessions', count(*) from public.consultation_sessions
union all select 'session_participants', count(*) from public.session_participants
union all select 'enterprise_files', count(*) from public.enterprise_files
union all select 'consultant_assignments', count(*) from public.consultant_assignments
union all select 'google_connections', count(*) from public.google_connections
union all select 'google_oauth_states', count(*) from public.google_oauth_states
union all select 'device_tokens', count(*) from public.device_tokens
union all select 'audit_log', count(*) from public.audit_log;

rollback;
