-- Open Doors Dispatch Center cloud persistence (v1 snapshot backend)
-- Run this migration in the Supabase SQL Editor for the Open-Doors-HVAC-Test project.
-- The app stores training-simulator state as one user-owned JSON document.
-- Do not store real customer/health/payment data in this training environment.

create table if not exists public.dispatch_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint dispatch_state_is_object check (jsonb_typeof(state) = 'object')
);

alter table public.dispatch_state enable row level security;

revoke all on public.dispatch_state from anon;
grant select, insert, update, delete on public.dispatch_state to authenticated;

drop policy if exists "Users can read their own dispatch state" on public.dispatch_state;
create policy "Users can read their own dispatch state"
  on public.dispatch_state for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own dispatch state" on public.dispatch_state;
create policy "Users can create their own dispatch state"
  on public.dispatch_state for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own dispatch state" on public.dispatch_state;
create policy "Users can update their own dispatch state"
  on public.dispatch_state for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own dispatch state" on public.dispatch_state;
create policy "Users can delete their own dispatch state"
  on public.dispatch_state for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.dispatch_state is
  'Private, user-scoped JSON snapshot for the Open Doors HVAC dispatch training simulator.';

