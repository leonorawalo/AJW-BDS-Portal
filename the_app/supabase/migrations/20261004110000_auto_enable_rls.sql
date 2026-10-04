-- ============================================================
-- Automatically enable RLS on every new table in `public`.
--
-- This is Supabase's "Automatically enable RLS on new tables" setting.
-- It was already switched on in the live database (event trigger
-- `ensure_rls` -> function `public.rls_auto_enable`, found 2026-10-04)
-- but existed in no migration, so a database rebuilt from migrations
-- would have lacked it. This copies the live definition exactly and is
-- idempotent: on the live DB it changes nothing.
--
-- Consequence (DO_NOT_BREAK.md section 4): a new table starts with RLS
-- ON and no policies, so nobody but service_role can read it until it
-- gets policies AND explicit GRANTs.
-- ============================================================

create or replace function public.rls_auto_enable()
returns event_trigger
language plpgsql
security definer
set search_path to 'pg_catalog'
as $function$
declare
  cmd record;
begin
  for cmd in
    select *
    from pg_event_trigger_ddl_commands()
    where command_tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      and object_type in ('table', 'partitioned table')
  loop
    if cmd.schema_name is not null and cmd.schema_name in ('public')
       and cmd.schema_name not in ('pg_catalog', 'information_schema')
       and cmd.schema_name not like 'pg_toast%'
       and cmd.schema_name not like 'pg_temp%' then
      begin
        execute format('alter table if exists %s enable row level security', cmd.object_identity);
        raise log 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      exception
        when others then
          raise log 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      end;
    else
      raise log 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
    end if;
  end loop;
end;
$function$;

do $$
begin
  if not exists (select 1 from pg_event_trigger where evtname = 'ensure_rls') then
    create event trigger ensure_rls
      on ddl_command_end
      when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      execute function public.rls_auto_enable();
  end if;
end $$;
