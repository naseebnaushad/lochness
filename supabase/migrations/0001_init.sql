-- Lochness location-sharing schema
-- Run via `supabase db push` or paste into the Supabase SQL editor.

create extension if not exists "uuid-ossp";

-- One row per authenticated user, mirrors auth.users
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- A "circle" is a named group of people (e.g. "Family", "Weekend hike")
create table public.circles (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.circle_members (
  circle_id uuid not null references public.circles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

-- An active/expired grant: "I am sharing my location with this circle until X"
create table public.location_shares (
  id uuid primary key default uuid_generate_v4(),
  sharer_id uuid not null references public.profiles (id) on delete cascade,
  circle_id uuid not null references public.circles (id) on delete cascade,
  started_at timestamptz not null default now(),
  -- null expires_at means "share forever" (until explicitly stopped)
  expires_at timestamptz,
  stopped_at timestamptz,
  created_at timestamptz not null default now()
);

-- Latest known position per user. Overwritten on every ping (not a history
-- table) to keep it cheap; add a separate breadcrumbs table if a trail view
-- is wanted later.
create table public.live_locations (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m double precision,
  heading double precision,
  speed_m_s double precision,
  recorded_at timestamptz not null default now()
);

-- Saved places for geofencing (e.g. "Home", "Mom's house")
create table public.places (
  id uuid primary key default uuid_generate_v4(),
  circle_id uuid not null references public.circles (id) on delete cascade,
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  radius_m integer not null default 150,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Arrival/departure events, used to drive push notifications
create table public.geofence_events (
  id uuid primary key default uuid_generate_v4(),
  place_id uuid not null references public.places (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  event_type text not null check (event_type in ('arrival', 'departure')),
  occurred_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_members enable row level security;
alter table public.location_shares enable row level security;
alter table public.live_locations enable row level security;
alter table public.places enable row level security;
alter table public.geofence_events enable row level security;

create or replace function public.is_circle_member(target_circle_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.circle_members
    where circle_id = target_circle_id and user_id = auth.uid()
  );
$$;

-- profiles: readable by anyone in a shared circle, writable only by self
create policy "profiles are readable by circle-mates" on public.profiles
  for select using (
    id = auth.uid()
    or exists (
      select 1 from public.circle_members m1
      join public.circle_members m2 on m1.circle_id = m2.circle_id
      where m1.user_id = auth.uid() and m2.user_id = profiles.id
    )
  );

create policy "users manage their own profile" on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

-- circles: members can read, only the owner can update/delete
create policy "members read their circles" on public.circles
  for select using (public.is_circle_member(id));

create policy "owner manages circle" on public.circles
  for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy "authenticated users create circles" on public.circles
  for insert with check (owner_id = auth.uid());

-- circle_members: members can see the roster, owner manages membership
create policy "members read roster" on public.circle_members
  for select using (public.is_circle_member(circle_id));

create policy "owner manages members" on public.circle_members
  for all using (
    exists (select 1 from public.circles c where c.id = circle_id and c.owner_id = auth.uid())
  );

-- location_shares: circle members can see shares in their circles,
-- users manage their own shares
create policy "members read circle shares" on public.location_shares
  for select using (public.is_circle_member(circle_id));

create policy "users manage their own shares" on public.location_shares
  for all using (sharer_id = auth.uid()) with check (sharer_id = auth.uid());

-- live_locations: visible only to people the user has an active share with
create policy "active-share circle-mates read location" on public.live_locations
  for select using (
    user_id = auth.uid()
    or exists (
      select 1 from public.location_shares s
      join public.circle_members m on m.circle_id = s.circle_id
      where s.sharer_id = live_locations.user_id
        and m.user_id = auth.uid()
        and s.stopped_at is null
        and (s.expires_at is null or s.expires_at > now())
    )
  );

create policy "users write their own location" on public.live_locations
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- places: circle members read, any member can create, creator/owner can delete
create policy "members read places" on public.places
  for select using (public.is_circle_member(circle_id));

create policy "members create places" on public.places
  for insert with check (public.is_circle_member(circle_id));

create policy "creator manages place" on public.places
  for update using (created_by = auth.uid());

create policy "creator deletes place" on public.places
  for delete using (created_by = auth.uid());

-- geofence_events: circle members of the place can read; written by the
-- backend function/service role that evaluates geofences
create policy "circle members read geofence events" on public.geofence_events
  for select using (
    exists (
      select 1 from public.places p
      where p.id = place_id and public.is_circle_member(p.circle_id)
    )
  );

-- Convenience view: only currently-active shares (not expired/stopped)
create view public.active_location_shares as
  select * from public.location_shares
  where stopped_at is null and (expires_at is null or expires_at > now());
