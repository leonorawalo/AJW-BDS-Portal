-- ============================================================
-- Google sign-in is for EXISTING accounts only
-- ============================================================
-- "Continue with Google" on the login screen is sign-in only. When the
-- Google email matches an existing (confirmed) account, Supabase links
-- the Google identity to that auth.users row — no insert, so this
-- trigger never runs. When it doesn't match, Supabase tries to insert a
-- brand-new auth.users row, and without a guard the trigger below would
-- silently make them an Enterprise Owner with blank names (Google sends
-- full_name, not first_name/last_name, and no role). Raising here aborts
-- that insert; Supabase redirects back with "Database error saving new
-- user", which the login screen turns into a readable message.
--
-- Accounts are still created via email registration (dev) or, later,
-- Admin invites (Phase 9).
--
-- Body is otherwise identical to the version in
-- 20260911000151_add_consultant_specialization.sql.
-- ============================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  default_role_id uuid;
begin
  if new.raw_app_meta_data ->> 'provider' = 'google' then
    raise exception 'Google sign-in is only for existing AJW accounts';
  end if;

  select id into default_role_id
  from public.roles
  where role_name = coalesce(new.raw_user_meta_data ->> 'role_name', 'Enterprise Owner');

  insert into public.users (id, first_name, last_name, email, phone_number, role_id, specialization)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    new.email,
    new.raw_user_meta_data ->> 'phone_number',
    default_role_id,
    new.raw_user_meta_data ->> 'specialization'
  );

  return new;
end;
$$;
