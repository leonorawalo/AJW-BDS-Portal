-- ============================================================
-- An enterprise has exactly one owner, and once its owner's login is
-- linked that link is permanent (project owner's decision, 6 Oct 2026).
-- One owner may still own several enterprises (rare): linking the same
-- owner account to another enterprise is allowed.
--
-- Enforced here, not only in the app, so no screen, Edge Function
-- (invite-user) or direct edit can swap an enterprise's owner:
--   - owner_user_id can go from empty to an account, never from one
--     account to another (or back to empty).
--   - the linked account must be an Enterprise Owner.
-- Idempotent.
-- ============================================================

create or replace function public.enterprise_owner_link_rules()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and old.owner_user_id is not null
     and new.owner_user_id is distinct from old.owner_user_id then
    raise exception using
      errcode = 'P0001',
      message = 'This enterprise is already linked to its owner''s account, and that link can''t be changed.';
  end if;

  if new.owner_user_id is not null and not exists (
    select 1 from public.users u join public.roles r on r.id = u.role_id
    where u.id = new.owner_user_id and r.role_name = 'Enterprise Owner'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'Only an Enterprise Owner account can be linked as an enterprise''s owner.';
  end if;

  return new;
end;
$$;

drop trigger if exists enterprises_owner_link_rules on public.enterprises;
create trigger enterprises_owner_link_rules
  before insert or update of owner_user_id on public.enterprises
  for each row execute function public.enterprise_owner_link_rules();
