-- ============================================================
-- Data protection (Kenya Data Protection Act, 2019) and hardening
-- ============================================================
-- 1. Fix: public.assessments had row level security (RLS) switched OFF on
--    the live database (its policies existed but weren't enforced), so
--    any signed-in user could read and change every enterprise's
--    assessment rows. Turned on; the existing policies now apply.
-- 2. Helper functions is_admin / is_assigned_consultant /
--    is_enterprise_owner / is_collaborator: no longer callable by
--    anonymous (signed-out) visitors. They returned false for them, but
--    there's no reason to expose them.
-- 3. Documents bucket: 20 MB per file (the app also checks type and size).
-- 4. data_consents: who accepted which version of the privacy notice.
-- 5. data_requests: "Download my data" / correction / deletion requests,
--    with the Act's response deadlines (access 7 days, correction 14
--    days; deletion is given 14 days too), tracked for Admins.
-- 6. export_my_data(): everything the portal holds about the caller, as
--    JSON (the "Download my data" file).
-- 7. log_document_access(): records document views and downloads in the
--    audit log. A trigger can't see a read, so this is the one audit
--    entry written on the app's request; it checks the caller can see
--    the document first, and the entry's actor is always the caller.
-- 8. retention_settings + apply_retention(): configurable retention for
--    data that can age out. Nothing is deleted until an Admin sets a
--    period and runs it. The audit log is never subject to it.
-- Idempotent.
-- ============================================================

-- ---------- 1. assessments ----------
alter table public.assessments enable row level security;

-- ---------- 2. helpers not for anonymous callers ----------
do $$
declare f text;
begin
  foreach f in array array[
    'public.is_admin()',
    'public.is_assigned_consultant(uuid)',
    'public.is_enterprise_owner(uuid)',
    'public.is_collaborator(uuid)'
  ] loop
    if to_regprocedure(f) is not null then
      execute format('revoke execute on function %s from public, anon', f);
      execute format('grant execute on function %s to authenticated, service_role', f);
    end if;
  end loop;
end $$;

-- ---------- 3. documents bucket size ----------
update storage.buckets set file_size_limit = 20971520 where id = 'documents';

-- ---------- 4. consent ----------
create table if not exists public.data_consents (
  user_id uuid not null references public.users (id) on delete cascade default auth.uid(),
  notice_version text not null,
  consented_at timestamptz not null default now(),
  primary key (user_id, notice_version)
);

alter table public.data_consents enable row level security;

drop policy if exists "data_consents_select" on public.data_consents;
create policy "data_consents_select"
  on public.data_consents for select to authenticated
  using (user_id = ((select auth.uid())) or public.is_admin());

drop policy if exists "data_consents_insert_own" on public.data_consents;
create policy "data_consents_insert_own"
  on public.data_consents for insert to authenticated
  with check (user_id = ((select auth.uid())));

revoke all on public.data_consents from anon;
grant select, insert on public.data_consents to authenticated;

-- ---------- 5. data subject requests ----------
create table if not exists public.data_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade default auth.uid(),
  kind text not null check (kind in ('access', 'correction', 'deletion')),
  details text not null default '' check (length(details) <= 4000),
  status text not null default 'open' check (status in ('open', 'in_progress', 'completed', 'rejected')),
  created_at timestamptz not null default now(),
  due_at timestamptz not null,
  resolved_at timestamptz,
  resolved_by uuid references public.users (id) on delete set null,
  resolution_note text
);

create index if not exists data_requests_status_due_idx on public.data_requests (status, due_at);

-- Deadline set by the database (never by the app): access 7 days,
-- correction and deletion 14 days. Resolving stamps who and when.
create or replace function public.data_requests_rules()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.status := 'open';
    new.due_at := now() + case new.kind when 'access' then interval '7 days' else interval '14 days' end;
    new.resolved_at := null;
    new.resolved_by := null;
  else
    new.user_id := old.user_id;
    new.kind := old.kind;
    new.created_at := old.created_at;
    new.due_at := old.due_at;
    if new.status in ('completed', 'rejected') and old.status not in ('completed', 'rejected') then
      new.resolved_at := now();
      new.resolved_by := (select auth.uid());
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists data_requests_rules on public.data_requests;
create trigger data_requests_rules
  before insert or update on public.data_requests
  for each row execute function public.data_requests_rules();

create or replace function public.audit_data_requests()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.audit_write('data_request.created', 'data_request', new.id, null, new.user_id,
      'Data ' || new.kind || ' request made by ' || coalesce(public.audit_user_name(new.user_id), 'a user'),
      jsonb_build_object('kind', new.kind, 'due_at', new.due_at));
  elsif new.status is distinct from old.status then
    perform public.audit_write('data_request.' || new.status, 'data_request', new.id, null, new.user_id,
      'Data ' || new.kind || ' request ' || replace(new.status, '_', ' '),
      jsonb_build_object('kind', new.kind, 'from', old.status, 'to', new.status));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_data_requests on public.data_requests;
create trigger audit_data_requests
  after insert or update on public.data_requests
  for each row execute function public.audit_data_requests();

alter table public.data_requests enable row level security;

drop policy if exists "data_requests_select" on public.data_requests;
create policy "data_requests_select"
  on public.data_requests for select to authenticated
  using (user_id = ((select auth.uid())) or public.is_admin());

drop policy if exists "data_requests_insert_own" on public.data_requests;
create policy "data_requests_insert_own"
  on public.data_requests for insert to authenticated
  with check (user_id = ((select auth.uid())));

drop policy if exists "data_requests_update_admin" on public.data_requests;
create policy "data_requests_update_admin"
  on public.data_requests for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

revoke all on public.data_requests from anon;
grant select, insert, update on public.data_requests to authenticated;

-- ---------- 6. export ----------
create or replace function public.export_my_data()
returns jsonb
language sql
stable
security definer set search_path = public
as $$
  with me as (select (select auth.uid()) as id)
  select jsonb_build_object(
    'exported_at', now(),
    'about', 'Everything the AJW BAGS Portal holds about you. Google account tokens are never included.',
    'profile', (select to_jsonb(u) - 'id' || jsonb_build_object('role', r.role_name)
                from public.users u join public.roles r on r.id = u.role_id where u.id = (select id from me)),
    'enterprises_owned', coalesce((select jsonb_agg(to_jsonb(e)) from public.enterprises e
                                   where e.owner_user_id = (select id from me)), '[]'::jsonb),
    'consultant_assignments', coalesce((select jsonb_agg(to_jsonb(ca)) from public.consultant_assignments ca
                                        where ca.consultant_id = (select id from me)), '[]'::jsonb),
    'tasks_assigned_to_you', coalesce((select jsonb_agg(to_jsonb(t)) from public.tasks t
                                       where t.consultant_id = (select id from me)), '[]'::jsonb),
    'task_comments', coalesce((select jsonb_agg(to_jsonb(c)) from public.task_comments c
                               where c.author_id = (select id from me)), '[]'::jsonb),
    'documents_uploaded', coalesce((select jsonb_agg(to_jsonb(d) - 'storage_path') from public.documents d
                                    where d.uploaded_by = (select id from me)), '[]'::jsonb),
    'meetings', coalesce((select jsonb_agg(to_jsonb(s)) from public.consultation_sessions s
                          where s.organizer_id = (select id from me)
                             or exists (select 1 from public.session_participants p
                                        where p.session_id = s.id and p.user_id = (select id from me))), '[]'::jsonb),
    'chat_messages_sent', coalesce((select jsonb_agg(jsonb_build_object('sent_at', m.created_at, 'text', m.body,
                                     'attachment', m.attachment_name)) from public.chat_messages m
                                    where m.sender_id = (select id from me)), '[]'::jsonb),
    'google_connection', (select jsonb_build_object('google_email', g.google_email, 'connected_at', g.connected_at)
                          from public.google_connections g where g.user_id = (select id from me)),
    'consents', coalesce((select jsonb_agg(to_jsonb(c)) from public.data_consents c
                          where c.user_id = (select id from me)), '[]'::jsonb),
    'data_requests', coalesce((select jsonb_agg(to_jsonb(q)) from public.data_requests q
                               where q.user_id = (select id from me)), '[]'::jsonb)
  );
$$;

revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- ---------- 7. document views / downloads ----------
create or replace function public.log_document_access(p_document_id uuid, p_action text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  d record;
begin
  if p_action not in ('viewed', 'downloaded') then
    raise exception 'Unknown document action %', p_action;
  end if;
  select * into d from public.documents where id = p_document_id;
  if not found then return; end if;
  -- Same people the documents policies let read it.
  if not (
    public.is_admin()
    or d.uploaded_by = (select auth.uid())
    or (d.enterprise_id is not null and (public.is_assigned_consultant(d.enterprise_id)
                                         or public.is_enterprise_owner(d.enterprise_id)))
  ) then
    return;
  end if;
  perform public.audit_write('document.' || p_action, 'document', d.id, d.enterprise_id, null,
    'Document "' || d.file_name || '" ' || p_action || ' by '
      || coalesce(public.audit_user_name((select auth.uid())), 'a user'),
    jsonb_build_object('file_name', d.file_name));
end;
$$;

revoke all on function public.log_document_access(uuid, text) from public, anon;
grant execute on function public.log_document_access(uuid, text) to authenticated;

-- ---------- 8. retention ----------
create table if not exists public.retention_settings (
  key text primary key,
  label text not null,
  -- Null = keep forever.
  keep_days integer check (keep_days is null or keep_days >= 30),
  updated_at timestamptz not null default now()
);

insert into public.retention_settings (key, label, keep_days) values
  ('chat_messages', 'Chat messages', null),
  ('closed_data_requests', 'Completed or rejected data requests', null)
on conflict (key) do nothing;

alter table public.retention_settings enable row level security;

drop policy if exists "retention_settings_admin" on public.retention_settings;
create policy "retention_settings_admin"
  on public.retention_settings for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

revoke all on public.retention_settings from anon;
grant select, update on public.retention_settings to authenticated;

-- Deletes data older than its configured period. Admin only. Returns
-- how many rows went, per kind. The audit log records each run.
create or replace function public.apply_retention()
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  v_days integer;
  v_result jsonb := '{}'::jsonb;
  v_count integer;
begin
  if not public.is_admin() then
    raise exception 'Only administrators can apply retention';
  end if;

  select keep_days into v_days from public.retention_settings where key = 'chat_messages';
  if v_days is not null then
    delete from public.chat_messages where created_at < now() - make_interval(days => v_days);
    get diagnostics v_count = row_count;
    v_result := v_result || jsonb_build_object('chat_messages', v_count);
  end if;

  select keep_days into v_days from public.retention_settings where key = 'closed_data_requests';
  if v_days is not null then
    delete from public.data_requests
    where status in ('completed', 'rejected') and resolved_at < now() - make_interval(days => v_days);
    get diagnostics v_count = row_count;
    v_result := v_result || jsonb_build_object('closed_data_requests', v_count);
  end if;

  perform public.audit_write('retention.applied', 'retention', null, null, null,
    'Data retention applied', v_result);
  return v_result;
end;
$$;

revoke all on function public.apply_retention() from public, anon;
grant execute on function public.apply_retention() to authenticated;

notify pgrst, 'reload schema';
