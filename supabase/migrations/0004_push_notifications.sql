-- Push notifications for geofence events, so an arrival/departure alert can
-- reach a device even when the app is fully killed (not just backgrounded
-- with an open Realtime connection).
--
-- This migration only wires up the *trigger*. The actual push send is done
-- by the `send-geofence-push` Edge Function (supabase/functions/), and the
-- trigger below no-ops until you've deployed that function and configured
-- the two Vault secrets it needs — see the "Push notifications" section of
-- the README for the full setup.

create table public.device_push_tokens (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  updated_at timestamptz not null default now()
);

alter table public.device_push_tokens enable row level security;

create policy "Users manage their own push tokens"
  on public.device_push_tokens
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create extension if not exists pg_net with schema extensions;

-- After deploying the Edge Function, run once in the SQL editor:
--   select vault.create_secret('https://YOUR-PROJECT.functions.supabase.co/send-geofence-push', 'edge_function_url');
--   select vault.create_secret('YOUR-SERVICE-ROLE-KEY', 'edge_function_service_role_key');
create or replace function public.notify_push_on_geofence_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  function_url text;
  service_key text;
begin
  select decrypted_secret into function_url from vault.decrypted_secrets where name = 'edge_function_url';
  select decrypted_secret into service_key from vault.decrypted_secrets where name = 'edge_function_service_role_key';

  -- Push infra not configured yet: Realtime-based in-app notifications
  -- (GeofenceNotificationListener) still work without this.
  if function_url is null or service_key is null then
    return new;
  end if;

  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := jsonb_build_object('record', row_to_json(new))
  );

  return new;
end;
$$;

create trigger geofence_events_push_trigger
  after insert on public.geofence_events
  for each row execute function public.notify_push_on_geofence_event();
