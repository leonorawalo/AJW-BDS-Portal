-- ============================================================
-- Legal, privacy and security hardening (16 Oct 2026)
-- ============================================================
-- Prompt: 06/10/2026_meeting_updates_requested.txt, second part
-- (Legal, Privacy and Accessibility Compliance). See
-- docs/security/AUDIT_REPORT.md for why each piece is here.
--
-- 1. Advisor fixes, no behaviour change:
--    - trigger functions are no longer callable as plain functions by
--      anon/authenticated (triggers still fire: EXECUTE is only checked
--      when a trigger is created);
--    - the five functions without a fixed search_path get one.
-- 2. rate_limits + rate_limit_hit(): per-user limits for the Edge
--    Functions that send email, create meetings or call Google. Only the
--    service role (Edge Functions) can call it.
-- 3. user_consents: an append-only history of what each person agreed to
--    (Terms of Service, Privacy Policy, 18 or over, optional programme
--    emails), with the document version and time.
-- 4. email_preferences: whether someone wants optional programme emails,
--    plus a random token for one-click unsubscribe links (the
--    email-unsubscribe function). Optional emails are off unless the
--    person ticks the box.
-- 5. success_stories: a story that names or shows someone under 18 needs
--    a parent or guardian's consent (Kenya Data Protection Act, 2019,
--    section 33).
-- 6. data_requests: refusing a request needs a reason.
-- 7. erase_user_personal_data(): carries out an approved deletion
--    request (called by manage-users with the service role).
-- 8. export_my_data(): also includes consents and email preferences.
-- Idempotent.
-- ============================================================

-- ---------- 1a. trigger functions: not callable directly ----------
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prorettype in ('trigger'::regtype, 'event_trigger'::regtype)
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', r.fn);
  end loop;
end $$;

-- ---------- 1b. fixed search_path ----------
do $$
declare f text;
begin
  foreach f in array array[
    'public.set_updated_at()',
    'public.check_going_concern_consistency()',
    'public.check_task_completed_consistency()',
    'public.touch_enterprise_visit()',
    'public.chat_object_conversation(text)'
  ] loop
    if to_regprocedure(f) is not null then
      execute format('alter function %s set search_path = public', f);
    end if;
  end loop;
end $$;

-- ---------- 2. rate limiting ----------
create table if not exists public.rate_limits (
  key text not null,
  window_start timestamptz not null,
  hits integer not null default 0,
  primary key (key, window_start)
);

alter table public.rate_limits enable row level security;
revoke all on public.rate_limits from anon, authenticated;
grant select, insert, update, delete on public.rate_limits to service_role;

-- Counts one call for p_key in the current fixed window. True = allowed.
create or replace function public.rate_limit_hit(p_key text, p_max integer, p_window_seconds integer)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  v_start timestamptz := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);
  v_hits integer;
begin
  insert into public.rate_limits as r (key, window_start, hits)
  values (p_key, v_start, 1)
  on conflict (key, window_start) do update set hits = r.hits + 1
  returning r.hits into v_hits;
  -- Old windows are useless; tidy up now and then.
  if random() < 0.02 then
    delete from public.rate_limits where window_start < now() - interval '2 days';
  end if;
  return v_hits <= p_max;
end;
$$;

revoke all on function public.rate_limit_hit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.rate_limit_hit(text, integer, integer) to service_role;

-- ---------- 3. consent history ----------
create table if not exists public.user_consents (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.users (id) on delete cascade,
  purpose text not null check (purpose in ('terms_of_service', 'privacy_policy', 'age_18_or_over', 'programme_emails')),
  document_version text not null default '' check (length(document_version) <= 40),
  granted boolean not null,
  source text not null default 'app' check (source in ('app', 'settings', 'unsubscribe_link')),
  recorded_at timestamptz not null default now()
);

create index if not exists user_consents_user_purpose_idx on public.user_consents (user_id, purpose, recorded_at desc);

-- The time is the database's, never the app's.
create or replace function public.user_consents_rules()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  new.recorded_at := now();
  return new;
end;
$$;

drop trigger if exists user_consents_rules on public.user_consents;
create trigger user_consents_rules
  before insert on public.user_consents
  for each row execute function public.user_consents_rules();

alter table public.user_consents enable row level security;

drop policy if exists "user_consents_select" on public.user_consents;
create policy "user_consents_select"
  on public.user_consents for select to authenticated
  using (user_id = ((select auth.uid())) or public.is_admin());

-- People record their own answers, from the app only ('unsubscribe_link'
-- rows are written by the server).
drop policy if exists "user_consents_insert_own" on public.user_consents;
create policy "user_consents_insert_own"
  on public.user_consents for insert to authenticated
  with check (user_id = ((select auth.uid())) and source in ('app', 'settings'));

-- Append-only: no update or delete for anyone in the app.
revoke all on public.user_consents from anon, authenticated;
grant select, insert on public.user_consents to authenticated;
grant select, insert on public.user_consents to service_role;

-- The latest answer per purpose for the caller.
create or replace function public.my_consents()
returns table (purpose text, document_version text, granted boolean, recorded_at timestamptz)
language sql
stable
security definer set search_path = public
as $$
  select distinct on (c.purpose) c.purpose, c.document_version, c.granted, c.recorded_at
  from public.user_consents c
  where c.user_id = (select auth.uid())
  order by c.purpose, c.recorded_at desc, c.id desc;
$$;

revoke all on function public.my_consents() from public, anon;
grant execute on function public.my_consents() to authenticated;

-- ---------- 4. email preferences ----------
create table if not exists public.email_preferences (
  user_id uuid primary key references public.users (id) on delete cascade,
  programme_emails boolean not null default false,
  unsubscribe_token uuid not null unique default gen_random_uuid(),
  updated_at timestamptz not null default now()
);

alter table public.email_preferences enable row level security;

drop policy if exists "email_preferences_select_own" on public.email_preferences;
create policy "email_preferences_select_own"
  on public.email_preferences for select to authenticated
  using (user_id = ((select auth.uid())) or public.is_admin());

-- Changed only through user_consents (below), so every change is in the
-- consent history.
revoke all on public.email_preferences from anon, authenticated;
grant select (user_id, programme_emails, updated_at) on public.email_preferences to authenticated;
grant select, insert, update, delete on public.email_preferences to service_role;

create or replace function public.sync_email_preferences()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.purpose = 'programme_emails' then
    insert into public.email_preferences (user_id, programme_emails, updated_at)
    values (new.user_id, new.granted, now())
    on conflict (user_id) do update set programme_emails = excluded.programme_emails, updated_at = now();
  end if;
  return new;
end;
$$;

drop trigger if exists sync_email_preferences on public.user_consents;
create trigger sync_email_preferences
  after insert on public.user_consents
  for each row execute function public.sync_email_preferences();

-- For a server that sends an OPTIONAL email (newsletter, update,
-- reminder): may it, and which token goes in the unsubscribe link.
-- Essential account and security emails don't ask.
create or replace function public.optional_email_permission(p_user uuid)
returns table (allowed boolean, unsubscribe_token uuid)
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.email_preferences (user_id) values (p_user) on conflict (user_id) do nothing;
  return query
    select p.programme_emails and u.status = 'active', p.unsubscribe_token
    from public.email_preferences p join public.users u on u.id = p.user_id
    where p.user_id = p_user;
end;
$$;

revoke all on function public.optional_email_permission(uuid) from public, anon, authenticated;
grant execute on function public.optional_email_permission(uuid) to service_role;

-- One-click unsubscribe (email-unsubscribe function, service role).
-- True if the token was found. Recorded in the consent history.
create or replace function public.unsubscribe_by_token(p_token uuid)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare v_user uuid;
begin
  select user_id into v_user from public.email_preferences where unsubscribe_token = p_token;
  if v_user is null then return false; end if;
  insert into public.user_consents (user_id, purpose, document_version, granted, source)
  values (v_user, 'programme_emails', '', false, 'unsubscribe_link');
  return true;
end;
$$;

revoke all on function public.unsubscribe_by_token(uuid) from public, anon, authenticated;
grant execute on function public.unsubscribe_by_token(uuid) to service_role;

-- ---------- 5. success stories about children ----------
alter table public.success_stories
  add column if not exists involves_minor boolean not null default false,
  add column if not exists guardian_consent boolean not null default false;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'success_stories_minor_needs_guardian') then
    alter table public.success_stories
      add constraint success_stories_minor_needs_guardian check (not involves_minor or guardian_consent);
  end if;
end $$;

-- ---------- 6. refusing a data request needs a reason ----------
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
    if new.status = 'rejected' and old.status <> 'rejected' and coalesce(trim(new.resolution_note), '') = '' then
      raise exception 'Give the person a reason when refusing a request' using errcode = '23514';
    end if;
    if new.status in ('completed', 'rejected') and old.status not in ('completed', 'rejected') then
      new.resolved_at := now();
      new.resolved_by := (select auth.uid());
    end if;
  end if;
  return new;
end;
$$;

-- ---------- 7. erasure ----------
-- Removes or anonymises one person's personal data. Kept, without their
-- identity: programme records others rely on (tasks, documents, visit
-- notes, comments, meetings) and the audit log (names and email
-- replaced by "a deleted user"). The account itself is blocked and its
-- email replaced by manage-users, which also deletes the person's chat
-- attachments from Storage (returned here) and their two-step factors.
create or replace function public.erase_user_personal_data(p_user uuid)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  v_name text;
  v_email text;
  v_paths text[];
  v_placeholder constant text := 'a deleted user';
begin
  select nullif(trim(coalesce(first_name, '') || ' ' || coalesce(last_name, '')), ''), email
    into v_name, v_email
  from public.users where id = p_user;
  if not found then
    raise exception 'User not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.consultant_assignments
             where consultant_id = p_user and assignment_status = 'active') then
    raise exception 'End this consultant''s active assignments before deleting their data' using errcode = '23514';
  end if;

  select coalesce(array_agg(attachment_path) filter (where attachment_path is not null), '{}')
    into v_paths
  from public.chat_messages where sender_id = p_user;

  update public.chat_messages
     set body = '[Message deleted at the sender''s request]',
         attachment_path = null, attachment_name = null, attachment_mime = null, attachment_size = null
   where sender_id = p_user;

  delete from public.device_tokens where user_id = p_user;
  delete from public.google_connections where user_id = p_user;
  delete from public.google_oauth_states where user_id = p_user;
  delete from public.attention_seen where user_id = p_user;
  delete from public.email_preferences where user_id = p_user;

  -- Contact details they gave for an enterprise they own (the business
  -- record itself stays: it belongs to the programme).
  update public.enterprises
     set owner_name = 'Deleted user', email = null, phone_number = null
   where owner_user_id = p_user;

  update public.users
     set first_name = 'Deleted', last_name = 'user',
         email = 'deleted-' || p_user || '@deleted.invalid',
         phone_number = null, status = 'suspended'
   where id = p_user;

  -- The audit log keeps what happened, not who it was.
  if v_name is not null then
    update public.audit_log set summary = replace(summary, v_name, v_placeholder)
     where position(v_name in summary) > 0;
    update public.audit_log set details = replace(details::text, v_name, v_placeholder)::jsonb
     where position(v_name in details::text) > 0;
  end if;
  if v_email is not null then
    update public.audit_log set summary = replace(summary, v_email, v_placeholder)
     where position(v_email in summary) > 0;
    update public.audit_log set details = details - 'email'
     where details ->> 'email' = v_email;
  end if;

  perform public.audit_write('user.erased', 'user', p_user, null, p_user,
    'Personal data of a user was deleted on their request', '{}'::jsonb);

  return jsonb_build_object('email', v_email, 'name', v_name, 'attachments', to_jsonb(v_paths));
end;
$$;

revoke all on function public.erase_user_personal_data(uuid) from public, anon, authenticated;
grant execute on function public.erase_user_personal_data(uuid) to service_role;

-- ---------- 8. export: consents and email preferences ----------
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
    'consent_history', coalesce((select jsonb_agg(to_jsonb(c) - 'user_id' order by c.recorded_at)
                                 from public.user_consents c where c.user_id = (select id from me)), '[]'::jsonb),
    'email_preferences', (select jsonb_build_object('programme_emails', p.programme_emails, 'updated_at', p.updated_at)
                          from public.email_preferences p where p.user_id = (select id from me)),
    'data_requests', coalesce((select jsonb_agg(to_jsonb(q)) from public.data_requests q
                               where q.user_id = (select id from me)), '[]'::jsonb)
  );
$$;

revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- New trigger functions above: not callable directly either.
revoke execute on function public.user_consents_rules() from public, anon, authenticated;
revoke execute on function public.sync_email_preferences() from public, anon, authenticated;

notify pgrst, 'reload schema';
