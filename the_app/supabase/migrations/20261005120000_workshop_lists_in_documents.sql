-- ============================================================
-- Workshop registration lists are saved in the portal, not emailed.
--
-- The ToR asks for each workshop's registration list within 5 days.
-- Instead of exporting and emailing it, a consultant (or Admin) now
-- "submits" it: the app saves it as a file in Storage `documents` and a
-- `documents` row with NO enterprise and the workshop's id. Admins see
-- these on their Documents page, with a red dot for new ones.
--
-- documents.enterprise_id becomes nullable (programme-level files);
-- documents.workshop_id links a list to its workshop (kept if the
-- workshop is deleted: the record stays for M&E).
-- Storage path: '<workshop id>/<file>' (first folder must be a uuid, as
-- the existing per-enterprise storage policies cast it).
--
-- Access (RLS):
--   Admin       everything (existing documents_all_admin + storage policy)
--   BDS team    may INSERT a workshop list as themselves
--   Uploader    may SELECT their own programme files
--   Owners      never see programme files
-- Idempotent.
-- ============================================================

alter table public.documents alter column enterprise_id drop not null;
alter table public.documents
  add column if not exists workshop_id uuid references public.workshops (id) on delete set null;
create index if not exists documents_workshop_idx on public.documents (workshop_id);

drop policy if exists "documents_insert_workshop_list" on public.documents;
create policy "documents_insert_workshop_list"
  on public.documents for insert
  to authenticated
  with check (
    enterprise_id is null and workshop_id is not null
    and uploaded_by = (select auth.uid()) and public.is_bds_team()
  );

drop policy if exists "documents_select_own_programme_file" on public.documents;
create policy "documents_select_own_programme_file"
  on public.documents for select
  to authenticated
  using (enterprise_id is null and uploaded_by = (select auth.uid()));

drop policy if exists "storage_documents_insert_workshop_list" on storage.objects;
create policy "storage_documents_insert_workshop_list"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'documents' and public.is_bds_team()
    and exists (select 1 from public.workshops w where w.id::text = (storage.foldername(name))[1])
  );

drop policy if exists "storage_documents_select_own_workshop_list" on storage.objects;
create policy "storage_documents_select_own_workshop_list"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'documents' and owner = (select auth.uid())
    and exists (select 1 from public.workshops w where w.id::text = (storage.foldername(name))[1])
  );

-- Red dots: same as 20261005100000 plus the admins' new-list event.
create or replace function public.my_attention()
returns table (enterprise_id uuid, section text)
language sql
stable
security definer set search_path = public
as $$
  with me as (
    select u.id, u.created_at, r.role_name
    from public.users u
    join public.roles r on r.id = u.role_id
    where u.id = (select auth.uid())
  ),
  seen as (
    select s.enterprise_id, s.section, s.seen_at
    from public.attention_seen s
    where s.user_id = (select auth.uid())
  ),
  -- Enterprises this user works on, by role.
  mine as (
    select ca.enterprise_id
    from public.consultant_assignments ca, me
    where me.role_name = 'Consultant' and ca.consultant_id = me.id and ca.assignment_status = 'active'
    union
    select e.id
    from public.enterprises e, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id
  ),
  events as (
    -- Consultant: newly assigned enterprise.
    select ca.enterprise_id, 'new'::text as section, ca.created_at as at
    from public.consultant_assignments ca, me
    where me.role_name = 'Consultant' and ca.consultant_id = me.id and ca.assignment_status = 'active'

    -- Consultant: a custom task someone else added for them.
    union all
    select t.enterprise_id, 'tasks', t.created_at
    from public.tasks t, me
    where me.role_name = 'Consultant' and t.consultant_id = me.id
      and t.tor_key is null and t.created_by is distinct from me.id

    -- Consultant: someone else commented on their task.
    union all
    select t.enterprise_id, 'tasks', c.created_at
    from public.task_comments c
    join public.tasks t on t.id = c.task_id, me
    where me.role_name = 'Consultant' and t.consultant_id = me.id and c.author_id <> me.id

    -- Owner: someone else commented on a task on their enterprise.
    union all
    select t.enterprise_id, 'tasks', c.created_at
    from public.task_comments c
    join public.tasks t on t.id = c.task_id
    join public.enterprises e on e.id = t.enterprise_id, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id and c.author_id <> me.id

    -- Owner: a new recommendation.
    union all
    select r.enterprise_id, 'recommendations', r.created_at
    from public.recommendations r
    join public.enterprises e on e.id = r.enterprise_id, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id
      and r.consultant_id is distinct from me.id

    -- Owner: a document someone else uploaded.
    union all
    select d.enterprise_id, 'documents', d.uploaded_at
    from public.documents d
    join public.enterprises e on e.id = d.enterprise_id, me
    where me.role_name = 'Enterprise Owner' and e.owner_user_id = me.id
      and d.uploaded_by is distinct from me.id

    -- Anyone: invited to a session someone else organised.
    union all
    select s.enterprise_id, 'sessions', p.created_at
    from public.session_participants p
    join public.consultation_sessions s on s.id = p.session_id, me
    where p.user_id = me.id and s.organizer_id <> me.id and s.status = 'Scheduled'

    -- Admin: an invited user accepted (confirmed their email).
    union all
    select null::uuid, 'users', a.email_confirmed_at
    from auth.users a, me
    where me.role_name = 'Administrator' and a.invited_at is not null
      and a.email_confirmed_at is not null and a.id <> me.id

    -- Admin: a consultant submitted a workshop registration list (a
    -- programme document, Admin's Documents page).
    union all
    select null::uuid, 'documents', d.uploaded_at
    from public.documents d, me
    where me.role_name = 'Administrator' and d.enterprise_id is null
      and d.uploaded_by <> me.id

    -- Admin: a workshop's registration list went overdue (not submitted
    -- within 5 days; overdue from the start of day 6, Nairobi time, the
    -- same rule as Workshop.registrationOverdue in the app).
    union all
    select null::uuid, 'workshops',
           ((w.held_on + 6)::timestamp at time zone 'Africa/Nairobi')
    from public.workshops w, me
    where me.role_name = 'Administrator' and w.registration_sent_at is null
      and (now() at time zone 'Africa/Nairobi')::date > w.held_on + 5
  )
  select distinct ev.enterprise_id, ev.section
  from events ev, me
  where ev.at > coalesce(
    case
      when ev.section = 'new' then
        (select max(s.seen_at) from seen s where s.enterprise_id = ev.enterprise_id)
      else
        (select s.seen_at from seen s
          where s.enterprise_id is not distinct from ev.enterprise_id and s.section = ev.section)
    end,
    me.created_at
  )
  -- Enterprise dots only for enterprises the user still works on.
  and (ev.enterprise_id is null or ev.enterprise_id in (select enterprise_id from mine));
$$;
