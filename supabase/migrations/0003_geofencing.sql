-- Server-side geofence detection: fires whenever a live_locations row is
-- written, so arrivals/departures are detected from whoever's phone is
-- actually moving, without trusting any client to self-report "I arrived".

-- Tracks whether a user was last known to be inside each place, so the
-- trigger below can detect *transitions* rather than re-firing on every
-- location ping. Internal bookkeeping only: RLS is enabled with no
-- policies, so it's invisible to anon/authenticated roles and only the
-- security-definer trigger function (below) can touch it.
create table public.geofence_state (
  place_id uuid not null references public.places (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  is_inside boolean not null,
  updated_at timestamptz not null default now(),
  primary key (place_id, user_id)
);

alter table public.geofence_state enable row level security;

create or replace function public.haversine_distance_m(
  lat1 double precision, lon1 double precision,
  lat2 double precision, lon2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lon2 - lon1) / 2), 2)
  ));
$$;

-- Runs after every live_locations write for the moving user, checks every
-- place in a circle they're actively sharing to, and records an
-- arrival/departure row in geofence_events on each state transition. The
-- very first observation of a place only ever records "arrival" (never a
-- spurious departure) since there's no prior state to compare against.
create or replace function public.evaluate_geofences_for_location()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  place record;
  distance_m double precision;
  now_inside boolean;
  was_inside boolean;
begin
  for place in
    select p.*
    from public.places p
    join public.active_location_shares s on s.circle_id = p.circle_id
    where s.sharer_id = new.user_id
  loop
    distance_m := public.haversine_distance_m(new.latitude, new.longitude, place.latitude, place.longitude);
    now_inside := distance_m <= place.radius_m;

    select gs.is_inside into was_inside
    from public.geofence_state gs
    where gs.place_id = place.id and gs.user_id = new.user_id;

    if was_inside is null then
      insert into public.geofence_state (place_id, user_id, is_inside, updated_at)
      values (place.id, new.user_id, now_inside, now());

      if now_inside then
        insert into public.geofence_events (place_id, user_id, event_type)
        values (place.id, new.user_id, 'arrival');
      end if;
    elsif now_inside <> was_inside then
      update public.geofence_state
      set is_inside = now_inside, updated_at = now()
      where place_id = place.id and user_id = new.user_id;

      insert into public.geofence_events (place_id, user_id, event_type)
      values (place.id, new.user_id, case when now_inside then 'arrival' else 'departure' end);
    end if;
  end loop;

  return new;
end;
$$;

create trigger live_locations_geofence_trigger
  after insert or update on public.live_locations
  for each row execute function public.evaluate_geofences_for_location();

-- Realtime delivery: the app subscribes to `geofence_events` (and already
-- relies on `live_locations` streaming for the map) to show notifications
-- as they happen. Supabase only streams tables explicitly added to this
-- publication, and neither table was added when they were first created,
-- so add both here. Wrapped in a DO block so re-running this migration
-- (or a project where a table was already added via the dashboard) doesn't
-- error.
do $$
begin
  alter publication supabase_realtime add table public.live_locations;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.geofence_events;
exception
  when duplicate_object then null;
end $$;
