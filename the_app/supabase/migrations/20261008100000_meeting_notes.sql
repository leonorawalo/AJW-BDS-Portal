-- ============================================================
-- Meeting notes (Gemini "Take notes for me") and transcripts
-- ============================================================
-- After a Google Meet ends, the meeting-notes Edge Function asks the Meet
-- REST API (conferenceRecords.smartNotes / .transcripts) for the Google
-- Docs that Gemini wrote into the organizer's Drive, records the links on
-- the session, and lists them in the enterprise's Files tab. Those list
-- entries are visible ONLY to the meeting's organizer, participants and
-- Admins, unlike the other enterprise files (visible to everyone on the
-- enterprise).
--
-- notes_status:
--   pending      not checked yet, or the notes aren't ready
--   ready        notes and/or transcript found and linked
--   none         the meeting ended and nobody turned on notes
--   unavailable  the organizer's Google account can't provide them (no
--                Gemini in their Workspace plan, a personal Gmail
--                account, or the Meet scope isn't granted yet)
-- Idempotent: safe to run more than once.
-- ============================================================

alter table public.consultation_sessions
  add column if not exists notes_status text not null default 'pending',
  add column if not exists notes_doc_url text,
  add column if not exists transcript_doc_url text,
  add column if not exists notes_checked_at timestamptz;

alter table public.consultation_sessions
  drop constraint if exists consultation_sessions_notes_status_check;
alter table public.consultation_sessions
  add constraint consultation_sessions_notes_status_check
  check (notes_status in ('pending', 'ready', 'none', 'unavailable'));

alter table public.enterprise_files
  add column if not exists session_id uuid references public.consultation_sessions (id) on delete cascade;

create index if not exists enterprise_files_session_idx
  on public.enterprise_files (session_id) where session_id is not null;

-- Same members as before, except a meeting's notes stay with the people
-- who were in that meeting (and Admins).
drop policy if exists "enterprise_files_select_member" on public.enterprise_files;
create policy "enterprise_files_select_member"
  on public.enterprise_files for select
  to authenticated
  using (
    public.can_schedule_for_enterprise(enterprise_id)
    and (
      session_id is null
      or public.is_admin()
      or public.is_session_organizer(session_id)
      or public.is_session_participant(session_id)
    )
  );

-- Meeting-notes rows are written only by the Edge Function (service
-- role), never by the app.
drop policy if exists "enterprise_files_insert_own_member" on public.enterprise_files;
create policy "enterprise_files_insert_own_member"
  on public.enterprise_files for insert
  to authenticated
  with check (
    created_by = ((select auth.uid()))
    and session_id is null
    and public.can_schedule_for_enterprise(enterprise_id)
  );

grant select, insert, update on public.enterprise_files to service_role;
grant select, update on public.consultation_sessions to service_role;
grant select on public.session_participants to service_role;

notify pgrst, 'reload schema';
