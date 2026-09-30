-- ============================================================
-- B2: working Google files per enterprise
-- ============================================================
-- "New Doc / Sheet / Slides" on an enterprise creates a Google file in the
-- creator's own Drive (drive-files Edge Function, drive.file scope) and
-- shares it as editor with the enterprise's Owner and active consultants.
-- This table is the portal's list of those files, so everyone on the
-- enterprise can find them. Access to the file's CONTENT is still Google's
-- sharing; this only controls who sees the list entry.
-- ============================================================

create table if not exists public.enterprise_files (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id) on delete cascade,
  google_file_id text not null unique,
  kind text not null check (kind in ('doc', 'sheet', 'slides')),
  title text not null,
  web_url text not null,
  created_by uuid not null references public.users (id) default auth.uid(),
  created_at timestamptz not null default now(),
  -- When the creator last (re)shared it with the enterprise's members.
  last_shared_at timestamptz
);

create index if not exists enterprise_files_enterprise_idx
  on public.enterprise_files (enterprise_id, created_at desc);

alter table public.enterprise_files enable row level security;

drop policy if exists "enterprise_files_select_member" on public.enterprise_files;
drop policy if exists "enterprise_files_insert_own_member" on public.enterprise_files;
drop policy if exists "enterprise_files_update_creator" on public.enterprise_files;
drop policy if exists "enterprise_files_delete_creator_or_admin" on public.enterprise_files;

-- Admin, the Owner and the enterprise's active consultants (the whole
-- Trio: these are shared working files, unlike tasks).
create policy "enterprise_files_select_member"
  on public.enterprise_files for select
  to authenticated
  using (public.can_schedule_for_enterprise(enterprise_id));

create policy "enterprise_files_insert_own_member"
  on public.enterprise_files for insert
  to authenticated
  with check (created_by = ((select auth.uid())) and public.can_schedule_for_enterprise(enterprise_id));

-- Only the creator's Google account can change the file's sharing, so only
-- they record a re-share.
create policy "enterprise_files_update_creator"
  on public.enterprise_files for update
  to authenticated
  using (created_by = ((select auth.uid())))
  with check (created_by = ((select auth.uid())));

-- "Remove from list" (the Google file itself stays in the creator's Drive).
create policy "enterprise_files_delete_creator_or_admin"
  on public.enterprise_files for delete
  to authenticated
  using (created_by = ((select auth.uid())) or public.is_admin());

revoke all on public.enterprise_files from anon;
grant select, insert, update, delete on public.enterprise_files to authenticated;


-- ---------- audit (same pattern as 20260929130000) ----------
create or replace function public.audit_enterprise_files()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  perform public.audit_write('file.created', 'file', new.id, new.enterprise_id, new.created_by,
    'Google ' || case new.kind when 'doc' then 'Doc' when 'sheet' then 'Sheet' else 'Slides' end
      || ' "' || new.title || '" created',
    jsonb_build_object('kind', new.kind, 'google_file_id', new.google_file_id));
  return new;
end;
$$;

drop trigger if exists audit_enterprise_files on public.enterprise_files;
create trigger audit_enterprise_files
  after insert on public.enterprise_files
  for each row execute function public.audit_enterprise_files();
