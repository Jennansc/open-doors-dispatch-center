-- Tighten membership management so an admin cannot promote themselves or others to owner.
drop policy if exists members_insert_admin_or_first_owner on public.organization_members;
create policy members_insert_admin_or_first_owner on public.organization_members
for insert to authenticated with check (
  public.has_org_role(organization_id, array['owner'])
  or (
    public.has_org_role(organization_id, array['admin'])
    and role in ('dispatcher','technician','viewer')
  )
  or (user_id = auth.uid() and role = 'owner' and public.is_org_creator(organization_id))
);

drop policy if exists members_update_admin on public.organization_members;
drop policy if exists members_update_owner on public.organization_members;
create policy members_update_owner on public.organization_members
for update to authenticated
using (public.has_org_role(organization_id, array['owner']))
with check (public.has_org_role(organization_id, array['owner']));

drop policy if exists members_delete_admin on public.organization_members;
drop policy if exists members_delete_owner on public.organization_members;
create policy members_delete_owner on public.organization_members
for delete to authenticated
using (public.has_org_role(organization_id, array['owner']));
