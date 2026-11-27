-- Automatic append-only work-order history and reasoned deletion.
create or replace function public.audit_work_order_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  event_name text;
begin
  if tg_op = 'INSERT' then
    event_name := 'created';
    insert into public.work_order_audit
      (organization_id, work_order_id, work_order_number, event_type, actor_user_id, after_state)
    values
      (new.organization_id, new.id, new.work_order_number, event_name, auth.uid(), to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from new.status then
      event_name := 'status_changed';
    elsif old.assigned_technician_id is distinct from new.assigned_technician_id then
      event_name := 'assignment_changed';
    else
      event_name := 'updated';
    end if;
    insert into public.work_order_audit
      (organization_id, work_order_id, work_order_number, event_type, actor_user_id, before_state, after_state)
    values
      (new.organization_id, new.id, new.work_order_number, event_name, auth.uid(), to_jsonb(old), to_jsonb(new));
    return new;
  end if;
  return null;
end;
$$;

drop trigger if exists work_orders_audit_insert_update on public.work_orders;
create trigger work_orders_audit_insert_update
after insert or update on public.work_orders
for each row execute function public.audit_work_order_change();

create or replace function public.delete_work_order_with_reason(target_work_order uuid, delete_reason text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  item public.work_orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if delete_reason is null or length(trim(delete_reason)) not between 1 and 1000 then
    raise exception 'A deletion reason of 1–1000 characters is required';
  end if;

  select * into item from public.work_orders where id = target_work_order;
  if not found then
    raise exception 'Work order not found';
  end if;
  if not public.has_org_role(item.organization_id, array['owner','admin','dispatcher']) then
    raise exception 'Insufficient permission to delete this work order';
  end if;

  insert into public.work_order_audit
    (organization_id, work_order_id, work_order_number, event_type, actor_user_id, reason, before_state)
  values
    (item.organization_id, item.id, item.work_order_number, 'deleted', auth.uid(), trim(delete_reason), to_jsonb(item));

  delete from public.work_orders where id = item.id;
end;
$$;

revoke all on function public.delete_work_order_with_reason(uuid, text) from public;
grant execute on function public.delete_work_order_with_reason(uuid, text) to authenticated;
revoke all on function public.audit_work_order_change() from public;
