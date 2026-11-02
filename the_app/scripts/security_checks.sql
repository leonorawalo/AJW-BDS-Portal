-- Read-only security checks for docs/security/SECURITY_CHECKLIST.md.
-- Run: npx supabase db query --linked -f scripts/security_checks.sql
-- Every row should say ok = true.
select 'A1 every public table has RLS on' as check, count(*) filter (where not c.relrowsecurity) = 0 as ok,
       coalesce(string_agg(c.relname, ', ') filter (where not c.relrowsecurity), '') as detail
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p')
union all
select 'A2 no public table or view readable by anon', count(*) = 0, coalesce(string_agg(c.relname, ', '), '')
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'v', 'm', 'p') and has_table_privilege('anon', c.oid, 'select')
union all
select 'A3 no SECURITY DEFINER function executable by anon', count(*) = 0, coalesce(string_agg(p.proname, ', '), '')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')
union all
select 'A4 trigger functions not callable by signed-in users', count(*) = 0, coalesce(string_agg(p.proname, ', '), '')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prorettype in ('trigger'::regtype, 'event_trigger'::regtype)
  and has_function_privilege('authenticated', p.oid, 'execute')
union all
select 'A5 every public function has a fixed search_path', count(*) = 0, coalesce(string_agg(p.proname, ', '), '')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
union all
select 'A6 only the downloads bucket is public', count(*) filter (where public and id <> 'downloads') = 0,
       coalesce(string_agg(id, ', ') filter (where public), '')
from storage.buckets
union all
select 'A7 documents bucket limit 20 MB', bool_and(file_size_limit = 20971520), max(file_size_limit)::text
from storage.buckets where id = 'documents'
union all
select 'A8 audit_log: app users cannot change or delete', not (has_table_privilege('authenticated', 'public.audit_log', 'update')
       or has_table_privilege('authenticated', 'public.audit_log', 'delete')
       or has_table_privilege('authenticated', 'public.audit_log', 'insert')), ''
union all
select 'A9 consent history is append-only', case when to_regclass('public.user_consents') is null then false
       else not (has_table_privilege('authenticated', 'public.user_consents', 'update')
       or has_table_privilege('authenticated', 'public.user_consents', 'delete')) end,
       case when to_regclass('public.user_consents') is null then 'migration 20261016100000 not applied' else '' end
union all
select 'A10 Google tokens unreadable by the app', not (has_table_privilege('authenticated', 'public.google_connections', 'select')
       and exists (select 1 from pg_policies where tablename = 'google_connections')), ''
union all
select 'A11 chat_messages still in the realtime publication', exists (select 1 from pg_publication_tables
       where pubname = 'supabase_realtime' and tablename = 'chat_messages'), '';
