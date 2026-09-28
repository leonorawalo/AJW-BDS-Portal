-- ============================================================
-- get_my_google_connection(): also return the granted scopes
-- ============================================================
-- google-oauth now requests calendar.freebusy and drive.file on top of
-- calendar.events. People who connected before those were added keep a
-- token without them until they reconnect. Returning the stored scope
-- string lets the app show "Reconnect to enable availability checks and
-- exports" instead of failing later. Still never returns the token.
--
-- The return type changes, so the function is dropped and recreated
-- (CREATE OR REPLACE can't change a function's result columns).
-- ============================================================

drop function if exists public.get_my_google_connection();

create function public.get_my_google_connection()
returns table (google_email varchar, connected_at timestamptz, scope text)
language sql
stable
security definer set search_path = public
as $$
  select gc.google_email, gc.connected_at, gc.scope
  from public.google_connections gc
  where gc.user_id = ((select auth.uid()));
$$;

revoke all on function public.get_my_google_connection() from public, anon;
grant execute on function public.get_my_google_connection() to authenticated;
