-- A consultant's specialization is copied onto each of their assignments
-- (consultant_assignments.specialization) and onto the tasks created
-- under them, so the "trio" model (one Legal, one Accounting, one
-- Marketing consultant per enterprise) and the task lists stay correct.
-- Changing it on the profile while they still hold active assignments
-- would leave those rows saying the old discipline. So it's refused,
-- with a message the Users screen shows as-is: end or reassign the
-- assignments first, then change the specialization.
--
-- Idempotent: safe to run more than once.

create or replace function public.block_specialization_change_with_assignments()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_count int;
begin
  if new.specialization is distinct from old.specialization then
    select count(*) into active_count
    from public.consultant_assignments
    where consultant_id = new.id
      and assignment_status = 'active';

    if active_count > 0 then
      raise exception using
        errcode = 'P0001',
        message = format(
          '%s has %s active assignment%s as a %s consultant. End or reassign %s first (open the enterprise, then Assign consultants), then change the specialization.',
          trim(coalesce(new.first_name, '') || ' ' || coalesce(new.last_name, '')),
          active_count,
          case when active_count = 1 then '' else 's' end,
          coalesce(old.specialization, 'current'),
          case when active_count = 1 then 'it' else 'them' end
        );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists users_block_specialization_change on public.users;
create trigger users_block_specialization_change
  before update of specialization on public.users
  for each row
  execute function public.block_specialization_change_with_assignments();
