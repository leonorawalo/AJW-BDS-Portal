-- ============================================================
-- Migration 3: Grants
-- Fixes 403 Forbidden on every authenticated query. RLS policies alone
-- don't let PostgREST touch a table — the underlying "authenticated"
-- Postgres role also needs an explicit GRANT. Normally Supabase adds
-- this automatically when a table is created, via the "Automatically
-- expose new tables" project setting — which we deliberately turned
-- off at project creation, not realizing it also skips this step.
--
-- These GRANTs only decide whether an operation can be *attempted* on
-- a table. Your existing RLS policies (is_admin(), own-row checks, etc.)
-- still decide which specific rows are actually visible/writable — this
-- migration doesn't loosen any of that.
-- ============================================================

grant usage on schema public to authenticated;

-- roles: everyone reads the list; only Admins can modify (RLS-enforced)
grant select, insert, update, delete on public.roles to authenticated;

-- users: read/update only — rows are created by the handle_new_user
-- trigger, which runs SECURITY DEFINER and bypasses grants entirely
grant select, update on public.users to authenticated;

-- enterprises: Admin needs full CRUD, Owner needs read/update on their
-- own row — both enforced by the existing RLS policies
grant select, insert, update on public.enterprises to authenticated;