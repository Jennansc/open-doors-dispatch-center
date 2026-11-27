-- Backend hardening: prevent bypassing audited deletion and protect system-owned fields.
-- Apply after 007_server_side_schedule_and_fee_rules.sql.

-- Work orders must be deleted only through delete_work_order_with_reason(),
-- which writes the deleted snapshot and reason before removing the row.
drop policy if exists work_orders_delete_admin on public.work_orders;
revoke delete on public.work_orders from public, anon, authenticated;

-- Organization deletion cascades all tenant records. Keep it unavailable through
-- the browser API until a dedicated, reasoned organization-deletion workflow exists.
drop policy if exists organizations_delete_owner on public.organizations;
revoke delete on public.organizations from public, anon, authenticated;

-- Audit history is append-only through database triggers and the deletion RPC.
-- Remove any inherited/direct API mutation privileges; SELECT remains granted.
revoke insert, update, delete on public.work_order_audit from public, anon, authenticated;
drop policy if exists audit_insert_member on public.work_order_audit;

-- The database, not a client payload, owns the work-order sequence number.
alter table public.work_orders
  alter column work_order_number set generated always;

create or replace function public.guard_work_order_system_fields()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if old.organization_id is distinct from new.organization_id then
    raise exception 'A work order cannot be moved to another organization'
      using errcode = '23514';
  end if;

  if old.work_order_number is distinct from new.work_order_number then
    raise exception 'Work order number is system-managed'
      using errcode = '23514';
  end if;

  if old.created_by is distinct from new.created_by then
    raise exception 'Work order creator is immutable'
      using errcode = '23514';
  end if;

  if old.created_at is distinct from new.created_at then
    raise exception 'Work order creation timestamp is immutable'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists work_orders_guard_system_fields on public.work_orders;
create trigger work_orders_guard_system_fields
before update on public.work_orders
for each row execute function public.guard_work_order_system_fields();

revoke all on function public.guard_work_order_system_fields() from public, anon, authenticated;
