-- Explicit API grants for the authenticated Supabase role.
-- RLS policies remain the row-level security boundary.

grant usage on schema public to authenticated;

grant select, insert, update, delete on public.organizations to authenticated;
grant select, insert, update, delete on public.organization_members to authenticated;
grant select, insert, update, delete on public.technicians to authenticated;
grant select, insert, update, delete on public.work_orders to authenticated;

-- Audit writes are performed only by SECURITY DEFINER triggers/RPCs.
grant select on public.work_order_audit to authenticated;
drop policy if exists audit_insert_member on public.work_order_audit;

grant usage, select on all sequences in schema public to authenticated;

-- Anonymous users receive no table privileges; authentication is required.
revoke all on public.organizations from anon;
revoke all on public.organization_members from anon;
revoke all on public.technicians from anon;
revoke all on public.work_orders from anon;
revoke all on public.work_order_audit from anon;
