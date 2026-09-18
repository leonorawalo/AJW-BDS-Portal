-- ============================================================
-- Migration 7: Consultant specialization
-- ============================================================
-- The ToR describes three consultant types per enterprise (the
-- "Trio"): Legal, Accounting/Tax, and Marketing. The MVP builds full
-- task support for Legal only (locked scope decision), but the
-- distinction itself needs to exist now — a Consultant account should
-- know which type it is, even before Accounting/Marketing task
-- templates are built out.

alter table public.users
  add column specialization varchar(20)
    check (specialization in ('Legal', 'Accounting', 'Marketing'));

-- Only meaningful for Consultant accounts — Admin/Owner rows stay null.
-- Not enforced as a hard constraint (would need a trigger cross-checking
-- role_id) since a null specialization on a non-Consultant is harmless
-- and the app layer already only shows/uses this field for Consultants.

-- Update the sign-up trigger (from migration 1) to also read
-- specialization out of sign-up metadata, same pattern as role_name.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  default_role_id uuid;
begin
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