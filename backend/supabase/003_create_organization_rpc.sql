-- Authenticated organization bootstrap. Creates the organization and first owner atomically.
create or replace function public.create_organization(org_name text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_org_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if org_name is null or length(trim(org_name)) not between 1 and 120 then
    raise exception 'Organization name must be 1–120 characters';
  end if;

  insert into public.organizations (name, created_by)
  values (trim(org_name), auth.uid())
  returning id into new_org_id;

  insert into public.organization_members (organization_id, user_id, role)
  values (new_org_id, auth.uid(), 'owner');

  return new_org_id;
end;
$$;

revoke all on function public.create_organization(text) from public;
grant execute on function public.create_organization(text) to authenticated;
