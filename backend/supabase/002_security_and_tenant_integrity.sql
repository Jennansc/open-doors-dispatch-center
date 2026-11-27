-- Hardening migration for the initial backend schema.
-- Apply after 001_initial_schema.sql.

-- Permit the account that created an organization to add its first owner membership.
create or replace function public.is_org_creator(target_org uuid)
returns boolean language sql stable security definer
set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.organizations o
    where o.id = target_org and o.created_by = auth.uid()
  );
$$;

drop policy if exists members_insert_admin_or_first_owner on public.organization_members;
create policy members_insert_admin_or_first_owner on public.organization_members
for insert to authenticated with check (
  public.has_org_role(organization_id, array['owner','admin'])
  or (user_id = auth.uid() and role = 'owner' and public.is_org_creator(organization_id))
);

-- Prevent assigning a work order to a technician from another organization.
create unique index if not exists technicians_org_id_id_uidx
  on public.technicians (organization_id, id);

alter table public.work_orders
  drop constraint if exists work_orders_assigned_technician_id_fkey;

alter table public.work_orders
  add constraint work_orders_assigned_technician_org_fkey
  foreign key (organization_id, assigned_technician_id)
  references public.technicians (organization_id, id)
  on delete restrict;

-- Security-definer helpers are only callable by signed-in app users.
revoke all on function public.is_org_member(uuid) from public;
revoke all on function public.has_org_role(uuid, text[]) from public;
revoke all on function public.is_org_creator(uuid) from public;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.has_org_role(uuid, text[]) to authenticated;
grant execute on function public.is_org_creator(uuid) to authenticated;
