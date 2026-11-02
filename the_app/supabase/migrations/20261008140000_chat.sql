-- ============================================================
-- In-app chat (Supabase Realtime)
-- ============================================================
-- Two kinds of conversation:
--   enterprise  one group chat per enterprise. Members are whoever is on
--               that enterprise right now: its Owner, its active
--               consultants and Admins (can_schedule_for_enterprise()),
--               so assigning or ending a consultant changes access
--               immediately, with no member list to keep in sync.
--   direct      two people. Allowed between people who share an
--               enterprise, or when either is an Admin
--               (can_message_user()).
--
-- RLS is the boundary: chat_messages, chat_members, chat_reads and the
-- private `chat-attachments` bucket all check can_access_conversation().
-- The app only ever creates conversations through the two RPCs below.
-- New messages reach open screens through Realtime (postgres_changes),
-- which applies the same RLS to every subscriber.
-- Idempotent.
-- ============================================================

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('enterprise', 'direct')),
  enterprise_id uuid references public.enterprises (id) on delete cascade,
  -- "<smaller user id>:<larger user id>" for a direct chat, so a pair has
  -- exactly one.
  direct_key text unique,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  constraint chat_conversations_shape check (
    (kind = 'enterprise' and enterprise_id is not null and direct_key is null)
    or (kind = 'direct' and enterprise_id is null and direct_key is not null)
  )
);

create unique index if not exists chat_conversations_one_per_enterprise
  on public.chat_conversations (enterprise_id) where kind = 'enterprise';

create table if not exists public.chat_members (
  conversation_id uuid not null references public.chat_conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  primary key (conversation_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations (id) on delete cascade,
  sender_id uuid not null references public.users (id) default auth.uid(),
  body text not null default '' check (length(body) <= 4000),
  attachment_path text,
  attachment_name text,
  attachment_mime text,
  attachment_size integer,
  created_at timestamptz not null default now(),
  constraint chat_messages_not_empty check (length(trim(body)) > 0 or attachment_path is not null)
);

create index if not exists chat_messages_conversation_idx
  on public.chat_messages (conversation_id, created_at desc);

-- When each person last read each conversation (read/unread).
create table if not exists public.chat_reads (
  conversation_id uuid not null references public.chat_conversations (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade default auth.uid(),
  last_read_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

-- ---------- helpers ----------
create or replace function public.can_access_conversation(p_conversation_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.chat_conversations c
    where c.id = p_conversation_id
      and (
        (c.kind = 'enterprise' and public.can_schedule_for_enterprise(c.enterprise_id))
        or (c.kind = 'direct' and exists (
          select 1 from public.chat_members m
          where m.conversation_id = c.id and m.user_id = (select auth.uid())
        ))
      )
  );
$$;

-- Whether the caller may start a direct chat with p_other: they share an
-- enterprise (as Owner or active consultant), or either is an Admin.
create or replace function public.can_message_user(p_other uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  with me as (select (select auth.uid()) as uid),
  people as (
    select e.id as enterprise_id, e.owner_user_id as user_id from public.enterprises e
    where e.owner_user_id is not null
    union
    select ca.enterprise_id, ca.consultant_id from public.consultant_assignments ca
    where ca.assignment_status = 'active'
  )
  select p_other is not null
    and p_other <> (select uid from me)
    and exists (select 1 from public.users u where u.id = p_other and u.status = 'active')
    and (
      public.is_admin()
      or exists (
        select 1 from public.users u join public.roles r on r.id = u.role_id
        where u.id = p_other and r.role_name = 'Administrator'
      )
      or exists (
        select 1 from people a join people b on a.enterprise_id = b.enterprise_id
        where a.user_id = (select uid from me) and b.user_id = p_other
      )
    );
$$;

-- People the caller can start a direct chat with.
create or replace function public.chat_contacts()
returns table (user_id uuid, full_name text, role_name text)
language sql
stable
security definer set search_path = public
as $$
  select u.id, trim(u.first_name || ' ' || u.last_name), r.role_name::text
  from public.users u join public.roles r on r.id = u.role_id
  where u.status = 'active' and public.can_message_user(u.id)
  order by 2;
$$;

create or replace function public.open_enterprise_chat(p_enterprise_id uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_id uuid;
begin
  if not public.can_schedule_for_enterprise(p_enterprise_id) then
    raise exception 'You are not on this enterprise';
  end if;
  insert into public.chat_conversations (kind, enterprise_id)
  values ('enterprise', p_enterprise_id)
  on conflict (enterprise_id) where kind = 'enterprise' do nothing;
  select id into v_id from public.chat_conversations
  where kind = 'enterprise' and enterprise_id = p_enterprise_id;
  return v_id;
end;
$$;

create or replace function public.open_direct_chat(p_other uuid)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_me uuid := (select auth.uid());
  v_key text;
  v_id uuid;
begin
  if not public.can_message_user(p_other) then
    raise exception 'You cannot message this person';
  end if;
  v_key := least(v_me::text, p_other::text) || ':' || greatest(v_me::text, p_other::text);
  insert into public.chat_conversations (kind, direct_key) values ('direct', v_key)
  on conflict (direct_key) do nothing;
  select id into v_id from public.chat_conversations where direct_key = v_key;
  insert into public.chat_members (conversation_id, user_id)
  values (v_id, v_me), (v_id, p_other)
  on conflict do nothing;
  return v_id;
end;
$$;

-- The caller's conversations, newest activity first, with a title, the
-- last message and how many messages they haven't read.
create or replace function public.my_chats()
returns table (
  conversation_id uuid,
  kind text,
  enterprise_id uuid,
  title text,
  other_user_id uuid,
  last_message text,
  last_message_at timestamptz,
  unread integer
)
language sql
stable
security definer set search_path = public
as $$
  select
    c.id,
    c.kind,
    c.enterprise_id,
    case when c.kind = 'enterprise' then e.business_name
         else trim(o.first_name || ' ' || o.last_name) end,
    o.id,
    (select case when length(trim(m.body)) > 0 then m.body else coalesce(m.attachment_name, 'Attachment') end
       from public.chat_messages m where m.conversation_id = c.id order by m.created_at desc limit 1),
    c.last_message_at,
    (select count(*)::int from public.chat_messages m
       where m.conversation_id = c.id
         and m.sender_id <> (select auth.uid())
         and m.created_at > coalesce(
           (select r.last_read_at from public.chat_reads r
             where r.conversation_id = c.id and r.user_id = (select auth.uid())),
           '-infinity'::timestamptz))
  from public.chat_conversations c
  left join public.enterprises e on e.id = c.enterprise_id
  left join lateral (
    select u.* from public.chat_members mm join public.users u on u.id = mm.user_id
    where mm.conversation_id = c.id and mm.user_id <> (select auth.uid())
    limit 1
  ) o on c.kind = 'direct'
  where public.can_access_conversation(c.id)
  order by c.last_message_at desc nulls last;
$$;

create or replace function public.mark_chat_read(p_conversation_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.can_access_conversation(p_conversation_id) then return; end if;
  insert into public.chat_reads (conversation_id, user_id, last_read_at)
  values (p_conversation_id, (select auth.uid()), now())
  on conflict (conversation_id, user_id) do update set last_read_at = excluded.last_read_at;
end;
$$;

-- Keeps the conversation list ordered by latest activity.
create or replace function public.chat_touch_conversation()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  update public.chat_conversations set last_message_at = new.created_at where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists chat_touch_conversation on public.chat_messages;
create trigger chat_touch_conversation
  after insert on public.chat_messages
  for each row execute function public.chat_touch_conversation();

revoke all on function public.can_access_conversation(uuid) from public, anon;
revoke all on function public.can_message_user(uuid) from public, anon;
revoke all on function public.chat_contacts() from public, anon;
revoke all on function public.open_enterprise_chat(uuid) from public, anon;
revoke all on function public.open_direct_chat(uuid) from public, anon;
revoke all on function public.my_chats() from public, anon;
revoke all on function public.mark_chat_read(uuid) from public, anon;
grant execute on function public.can_access_conversation(uuid) to authenticated;
grant execute on function public.can_message_user(uuid) to authenticated;
grant execute on function public.chat_contacts() to authenticated;
grant execute on function public.open_enterprise_chat(uuid) to authenticated;
grant execute on function public.open_direct_chat(uuid) to authenticated;
grant execute on function public.my_chats() to authenticated;
grant execute on function public.mark_chat_read(uuid) to authenticated;

-- ---------- RLS ----------
alter table public.chat_conversations enable row level security;
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_reads enable row level security;

drop policy if exists "chat_conversations_select" on public.chat_conversations;
create policy "chat_conversations_select"
  on public.chat_conversations for select to authenticated
  using (public.can_access_conversation(id));

drop policy if exists "chat_members_select" on public.chat_members;
create policy "chat_members_select"
  on public.chat_members for select to authenticated
  using (public.can_access_conversation(conversation_id));

drop policy if exists "chat_messages_select" on public.chat_messages;
create policy "chat_messages_select"
  on public.chat_messages for select to authenticated
  using (public.can_access_conversation(conversation_id));

-- Only as yourself, only where you belong, and an attachment must sit in
-- that conversation's own folder.
drop policy if exists "chat_messages_insert" on public.chat_messages;
create policy "chat_messages_insert"
  on public.chat_messages for insert to authenticated
  with check (
    sender_id = ((select auth.uid()))
    and public.can_access_conversation(conversation_id)
    and (attachment_path is null or split_part(attachment_path, '/', 1) = conversation_id::text)
  );

drop policy if exists "chat_reads_select_own" on public.chat_reads;
create policy "chat_reads_select_own"
  on public.chat_reads for select to authenticated
  using (user_id = ((select auth.uid())));

-- Conversations, members and reads are written only by the functions
-- above; messages are never edited or deleted from the app.
revoke all on public.chat_conversations, public.chat_members, public.chat_messages, public.chat_reads from anon;
grant select on public.chat_conversations, public.chat_members, public.chat_reads to authenticated;
grant select, insert on public.chat_messages to authenticated;

-- ---------- attachments: private bucket, 10 MB, common file types ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'chat-attachments', 'chat-attachments', false, 10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/plain']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Path: <conversation id>/<random>-<file name>. The folder is checked to
-- be a uuid before the cast, so odd paths fail closed instead of erroring.
create or replace function public.chat_object_conversation(p_name text)
returns uuid
language sql
immutable
as $$
  select case when split_part(p_name, '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then split_part(p_name, '/', 1)::uuid end;
$$;

drop policy if exists "chat_attachments_select" on storage.objects;
create policy "chat_attachments_select"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and public.can_access_conversation(public.chat_object_conversation(name))
  );

drop policy if exists "chat_attachments_insert" on storage.objects;
create policy "chat_attachments_insert"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and public.can_access_conversation(public.chat_object_conversation(name))
  );

-- ---------- Realtime ----------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end $$;

notify pgrst, 'reload schema';
