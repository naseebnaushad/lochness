# Lochness

Share your location with family or friends, for a duration or forever.

## Stack

- **Flutter** (Riverpod for state, go_router for navigation)
- **Supabase**: Postgres (with Row Level Security) + Auth + Realtime for live
  location sync
- **flutter_map** (OpenStreetMap tiles) so you don't need a Google Maps API
  key to get started
- **geolocator** for position streaming, **flutter_local_notifications** for
  arrival/departure and "sharing active" alerts

## Project layout

```
lib/
  core/          app-wide config, theme, router, riverpod providers
  data/
    models/      plain Dart models mirroring the Supabase schema
    repositories/  one repository per table/feature, wraps supabase_flutter calls
  services/      location tracking, geofencing, local notifications
  features/
    auth/        sign in / sign up
    circles/     create & list sharing groups ("Family", "Road trip")
    sharing/     duration picker + start/stop a location share
    map/         live map of everyone sharing with you
    home/        bottom-nav shell
supabase/
  migrations/0001_init.sql   full schema + RLS policies
```

## Getting started

This repo was hand-scaffolded (no Flutter SDK in the environment that
created it), so the platform folders (`android/`, `ios/`, `web/`, etc.)
haven't been generated yet. To bootstrap locally:

```bash
flutter create . --project-name lochness --org com.lochness
flutter pub get
```

Set up Supabase:

1. Create a project at [supabase.com](https://supabase.com).
2. Run `supabase/migrations/0001_init.sql` in the SQL editor (or via
   `supabase db push` if you use the Supabase CLI).
3. Enable email/password auth under Authentication settings (or swap in
   whatever provider you prefer — the `AuthRepository` only needs updating
   in one place).

Run the app with your Supabase credentials:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-KEY
```

### Platform permissions

You'll need to add location (and background location, for always-share) and
notification permissions once the platform folders exist:

- **Android**: `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`,
  `POST_NOTIFICATIONS` in `AndroidManifest.xml`.
- **iOS**: `NSLocationWhenInUseUsageDescription`,
  `NSLocationAlwaysAndWhenInUseUsageDescription`, and the "Location updates"
  background mode in `Info.plist`.

## Current scope (MVP)

- Email/password auth
- Create circles and share a location with one
- Start a share for 15 min / 1 hr / 8 hr / until turned off / forever
- Live map of everyone currently sharing with you (Supabase Realtime)
- Geofencing scaffolding (`Place` model, `GeofenceService`) for arrival/
  departure notifications — wire it into a periodic check or a Supabase Edge
  Function on `live_locations` writes to fully activate

## Not yet built

- Invite flow (currently `CircleRepository.inviteMember` takes a raw user
  id — needs an invite-link/QR flow so people don't need to know each
  other's UUIDs)
- True background tracking when the app is killed (see the note in
  `LocationTrackingService` — plug in platform foreground services or a
  package such as `flutter_background_geolocation` for this)
- Location history/breadcrumb trail
- Ghost mode / per-viewer precision controls
