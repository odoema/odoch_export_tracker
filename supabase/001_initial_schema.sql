-- Odoch Export Tracker: initial production schema
-- Run in the dedicated Odoch Export Tracker Supabase project only.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_name text,
  full_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.shipments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  commodity text not null check (length(trim(commodity)) between 1 and 120),
  quantity text,
  buyer_name text,
  origin_name text not null,
  destination_name text not null,
  origin_coords double precision[] not null check (array_length(origin_coords,1)=2),
  destination_coords double precision[] not null check (array_length(destination_coords,1)=2),
  reference text,
  tracking_token uuid unique,
  tracking_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shipment_events (
  id uuid primary key default gen_random_uuid(),
  shipment_id uuid not null references public.shipments(id) on delete cascade,
  step_index smallint not null check (step_index between 0 and 5),
  step_name text not null,
  occurred_at timestamptz not null default now(),
  created_by uuid not null default auth.uid() references auth.users(id),
  unique(shipment_id, step_index)
);

create index if not exists shipments_owner_created_idx on public.shipments(owner_id, created_at desc);
create index if not exists shipment_events_shipment_idx on public.shipment_events(shipment_id, step_index);

alter table public.profiles enable row level security;
alter table public.shipments enable row level security;
alter table public.shipment_events enable row level security;

drop policy if exists "profiles select own" on public.profiles;
create policy "profiles select own" on public.profiles for select to authenticated using (id = (select auth.uid()));
drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists "shipments select own" on public.shipments;
create policy "shipments select own" on public.shipments for select to authenticated using (owner_id = (select auth.uid()));
drop policy if exists "shipments insert own" on public.shipments;
create policy "shipments insert own" on public.shipments for insert to authenticated with check (owner_id = (select auth.uid()));
drop policy if exists "shipments update own" on public.shipments;
create policy "shipments update own" on public.shipments for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
drop policy if exists "shipments delete own" on public.shipments;
create policy "shipments delete own" on public.shipments for delete to authenticated using (owner_id = (select auth.uid()));

drop policy if exists "events select own shipment" on public.shipment_events;
create policy "events select own shipment" on public.shipment_events for select to authenticated using (exists (select 1 from public.shipments s where s.id = shipment_id and s.owner_id = (select auth.uid())));
drop policy if exists "events insert own shipment" on public.shipment_events;
create policy "events insert own shipment" on public.shipment_events for insert to authenticated with check (created_by = auth.uid() and exists (select 1 from public.shipments s where s.id = shipment_id and s.owner_id = (select auth.uid())));
drop policy if exists "events delete own shipment" on public.shipment_events;
create policy "events delete own shipment" on public.shipment_events for delete to authenticated using (exists (select 1 from public.shipments s where s.id = shipment_id and s.owner_id = (select auth.uid())));

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists shipments_set_updated_at on public.shipments;
create trigger shipments_set_updated_at before update on public.shipments for each row execute function public.set_updated_at();

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

create or replace function private.ensure_tracking_token(p_shipment_id uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_token uuid;
begin
  update public.shipments
    set tracking_token = coalesce(tracking_token, gen_random_uuid()), tracking_enabled = true
    where id = p_shipment_id and owner_id = (select auth.uid())
    returning tracking_token into v_token;
  if v_token is null then raise exception 'Shipment not found or access denied'; end if;
  return v_token;
end; $$;
revoke all on function private.ensure_tracking_token(uuid) from public, anon;
grant execute on function private.ensure_tracking_token(uuid) to authenticated;

create or replace function public.ensure_tracking_token(p_shipment_id uuid)
returns uuid language sql security invoker set search_path = '' as $$
  select private.ensure_tracking_token(p_shipment_id);
$$;
revoke all on function public.ensure_tracking_token(uuid) from public, anon;
grant execute on function public.ensure_tracking_token(uuid) to authenticated;

create or replace function private.public_track_shipment(p_tracking_token uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', s.id, 'commodity', s.commodity, 'quantity', s.quantity,
    'buyer_name', s.buyer_name, 'origin_name', s.origin_name,
    'destination_name', s.destination_name, 'origin_coords', s.origin_coords,
    'destination_coords', s.destination_coords, 'reference', s.reference,
    'created_at', s.created_at,
    'events', coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'step_index',e.step_index,'step_name',e.step_name,'occurred_at',e.occurred_at) order by e.step_index)
      from public.shipment_events e where e.shipment_id=s.id), '[]'::jsonb)
  )
  from public.shipments s
  where s.tracking_token = p_tracking_token and s.tracking_enabled = true
  limit 1;
$$;
revoke all on function private.public_track_shipment(uuid) from public;
grant execute on function private.public_track_shipment(uuid) to anon, authenticated;

create or replace function public.public_track_shipment(p_tracking_token uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select private.public_track_shipment(p_tracking_token);
$$;
revoke all on function public.public_track_shipment(uuid) from public;
grant execute on function public.public_track_shipment(uuid) to anon, authenticated;

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name',''))
  on conflict (id) do nothing;
  return new;
end; $$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function private.handle_new_user();

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.shipments to authenticated;
grant select, insert, delete on public.shipment_events to authenticated;
grant select, insert, update on public.profiles to authenticated;
