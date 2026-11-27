-- Membership integrity: keep organization membership keys stable and prevent orphaned orgs.
-- Apply after 008_api_integrity_hardening.sql.

create or replace function public.guard_organization_membership_integrity()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  remaining_owner_count integer;
begin
  if tg_op = 'UPDATE' then
    if old.organization_id is distinct from new.organization_id
       or old.user_id is distinct from new.user_id then
      raise exception 'Membership organization and user are immutable'
        using errcode = '23514';
    end if;
  end if;

  if old.role = 'owner'
     and (
       tg_op = 'DELETE'
       or (tg_op = 'UPDATE' and new.role is distinct from 'owner')
     ) then
    select count(*) into remaining_owner_count
    from public.organization_members m
    where m.organization_id = old.organization_id
      and m.role = 'owner'
      and m.user_id <> old.user_id;

    if remaining_owner_count = 0 then
      raise exception 'An organization must retain at least one owner'
        using errcode = '23514';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists organization_members_guard_integrity on public.organization_members;
create trigger organization_members_guard_integrity
before update or delete on public.organization_members
for each row execute function public.guard_organization_membership_integrity();

revoke all on function public.guard_organization_membership_integrity() from public, anon, authenticated;
