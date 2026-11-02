-- ============================================================
-- Success stories, in a guided structure
-- ============================================================
-- The monthly programme report's "Success stories" section used to be a
-- blank line to fill in by hand. Each story is now six guided parts
-- (before, what we did, results, human impact, in their words, what's
-- next), saved here so it isn't lost if a report export fails and can be
-- reused when the report is generated again.
--
-- Who: Admins see and edit all. A consultant writes stories about their
-- own assigned enterprises and sees those (theirs and their Trio
-- colleagues'). Owners don't see this table (it's a programme report).
-- Idempotent.
-- ============================================================

create table if not exists public.success_stories (
  id uuid primary key default gen_random_uuid(),
  enterprise_id uuid not null references public.enterprises (id) on delete cascade,
  -- First day of the report month the story belongs to.
  report_month date not null,
  before_story text not null default '',
  what_we_did text not null default '',
  results text not null default '',
  human_impact text not null default '',
  owner_quote text not null default '',
  whats_next text not null default '',
  created_by uuid not null references public.users (id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint success_stories_month_is_first check (extract(day from report_month) = 1)
);

create index if not exists success_stories_month_idx on public.success_stories (report_month, enterprise_id);

alter table public.success_stories enable row level security;

drop policy if exists "success_stories_select" on public.success_stories;
drop policy if exists "success_stories_insert" on public.success_stories;
drop policy if exists "success_stories_update" on public.success_stories;
drop policy if exists "success_stories_delete" on public.success_stories;

create policy "success_stories_select"
  on public.success_stories for select
  to authenticated
  using (public.is_admin() or public.is_assigned_consultant(enterprise_id));

create policy "success_stories_insert"
  on public.success_stories for insert
  to authenticated
  with check (
    created_by = ((select auth.uid()))
    and (public.is_admin() or public.is_assigned_consultant(enterprise_id))
  );

create policy "success_stories_update"
  on public.success_stories for update
  to authenticated
  using (created_by = ((select auth.uid())) or public.is_admin())
  with check (public.is_admin() or public.is_assigned_consultant(enterprise_id));

create policy "success_stories_delete"
  on public.success_stories for delete
  to authenticated
  using (created_by = ((select auth.uid())) or public.is_admin());

revoke all on public.success_stories from anon;
grant select, insert, update, delete on public.success_stories to authenticated;

create or replace function public.success_stories_touch()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists success_stories_touch on public.success_stories;
create trigger success_stories_touch
  before update on public.success_stories
  for each row execute function public.success_stories_touch();

notify pgrst, 'reload schema';
