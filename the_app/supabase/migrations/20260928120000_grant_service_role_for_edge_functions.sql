-- ============================================================
-- Grants for Edge Functions running as service_role
-- ============================================================
-- This project has "Automatically expose new tables" turned off (see
-- migration 3), so tables created by migrations get NO select/insert/
-- update/delete for any API role, service_role included. Migration 3
-- granted `authenticated`; nothing ever granted `service_role`. RLS
-- doesn't apply to service_role, but table privileges still do, so every
-- server-side query failed with "permission denied" — e.g. Connect in
-- google-oauth, and every lookup send-push makes (it then silently skipped
-- every notification).
--
-- Least privilege: only the tables and operations the functions' code
-- actually uses as service_role. consultation_sessions needs nothing here —
-- calendar-sessions writes it with the caller's own JWT, so the existing
-- `authenticated` grant plus RLS stays the boundary.
--
-- GRANT/REVOKE are idempotent, so re-running this is harmless.
-- ============================================================

-- google-oauth: create state on start, look it up + delete it on callback.
grant select, insert, delete on public.google_oauth_states to service_role;

-- google-oauth (upsert on callback, delete on disconnect) and
-- calendar-sessions (read refresh token, drop dead connections).
grant select, insert, update, delete on public.google_connections to service_role;

-- calendar-sessions: Owner's email for the invite (enterprises -> users).
-- send-push: who to notify (enterprises, users joined to roles).
grant select on public.enterprises to service_role;
grant select on public.users to service_role;
grant select on public.roles to service_role;

-- send-push: read FCM tokens, delete ones Google reports unregistered.
grant select, delete on public.device_tokens to service_role;

-- The two token tables are server-only. The project's default privileges
-- still gave anon/authenticated TRUNCATE/REFERENCES/TRIGGER on them;
-- take those away so no client role holds any privilege on them at all.
-- (The app reads connection status through get_my_google_connection(),
-- a SECURITY DEFINER function, which is unaffected.)
revoke all on public.google_oauth_states from anon, authenticated;
revoke all on public.google_connections from anon, authenticated;
