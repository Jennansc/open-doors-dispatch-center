-- Server-side appointment, technician shift, overlap, past-time, and fee rules.
-- The organization timezone makes date/time validation use local business time.
alter table public.organizations
  add column if not exists tz_name text not null default 'America/New_York';

create or replace function public.validate_work_order_schedule()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  tech public.technicians%rowtype;
  org_tz text;
  start_min integer;
  end_min integer;
  shift_start_min integer;
  shift_end_min integer;
  conflict_number bigint;
begin
  -- Keep the existing saved fee when appointment details have not changed.
  if tg_op = 'UPDATE'
     and old.appointment_date is not distinct from new.appointment_date
     and old.appointment_time is not distinct from new.appointment_time
     and old.appointment_duration_minutes is not distinct from new.appointment_duration_minutes then
    new.after_hours_fee := old.after_hours_fee;
  else
    if new.appointment_date is null or new.appointment_time is null then
      new.after_hours_fee := 0;
    else
      start_min := extract(epoch from new.appointment_time)::integer / 60;
      end_min := start_min + new.appointment_duration_minutes;
      new.after_hours_fee := case when end_min > 17 * 60 then 85 else 0 end;
    end if;
  end if;

  -- Completed work orders are historical records and may retain past appointments.
  if new.status = 'Completed' or new.appointment_date is null then
    return new;
  end if;

  select o.tz_name into org_tz
  from public.organizations o
  where o.id = new.organization_id;
  if org_tz is null then
    raise exception 'Organization timezone is missing';
  end if;

  if (new.appointment_date + new.appointment_time)
     <= (now() at time zone org_tz) then
    raise exception 'Appointment must be in the future in the organization timezone';
  end if;

  start_min := extract(epoch from new.appointment_time)::integer / 60;
  end_min := start_min + new.appointment_duration_minutes;

  if new.assigned_technician_id is not null then
    select * into tech
    from public.technicians
    where id = new.assigned_technician_id
      and organization_id = new.organization_id;

    if not found then
      raise exception 'Assigned technician does not belong to this organization';
    end if;
    if not tech.is_available and
       (tg_op = 'INSERT' or old.assigned_technician_id is distinct from new.assigned_technician_id) then
      raise exception 'Assigned technician is marked unavailable';
    end if;

    shift_start_min := extract(epoch from tech.shift_start)::integer / 60;
    shift_end_min := extract(epoch from tech.shift_end)::integer / 60;
    if start_min < shift_start_min or end_min > shift_end_min then
      raise exception 'Appointment must fit within the assigned technician shift';
    end if;
  end if;

  select w.work_order_number into conflict_number
  from public.work_orders w
  where w.organization_id = new.organization_id
    and w.id is distinct from new.id
    and w.status <> 'Completed'
    and w.appointment_date = new.appointment_date
    and w.appointment_time is not null
    and (
      w.assigned_technician_id is null
      or new.assigned_technician_id is null
      or w.assigned_technician_id = new.assigned_technician_id
    )
    and (extract(epoch from w.appointment_time)::integer / 60)
        < start_min + new.appointment_duration_minutes
    and start_min
        < (extract(epoch from w.appointment_time)::integer / 60)
          + w.appointment_duration_minutes
  limit 1;

  if conflict_number is not null then
    raise exception 'Appointment overlaps active work order WO-%', conflict_number;
  end if;

  return new;
end;
$$;

drop trigger if exists work_orders_validate_schedule on public.work_orders;
create trigger work_orders_validate_schedule
before insert or update on public.work_orders
for each row execute function public.validate_work_order_schedule();

revoke all on function public.validate_work_order_schedule() from public;
