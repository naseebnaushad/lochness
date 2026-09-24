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
  services/      location tracking, geofence notification listener, local notifications
  features/
    auth/        sign in / sign up
    circles/     create & list sharing groups, invite flow, manage members
    sharing/     duration picker + start/stop a location share
    map/         live map of everyone sharing with you
    places/      geofenced places per circle (add/list/delete)
    home/        bottom-nav shell
supabase/
  migrations/
    0001_init.sql             core schema + RLS policies
    0002_circle_invites.sql   invite codes + accept_circle_invite() RPC
    0003_geofencing.sql       server-side arrival/departure detection
    0004_push_notifications.sql  device_push_tokens + push trigger (pg_net)
  functions/
    send-geofence-push/      Edge Function: sends the FCM push for a geofence event
```

## Getting started

Platform folders (`android/`, `ios/`, `linux/`, `web/`, etc.) are
gitignored and generated locally, not committed. `flutter analyze`,
`flutter test`, and a `flutter build linux --debug` have all been run
against this scaffold and pass. To bootstrap on your machine:

```bash
flutter create . --project-name lochness --org com.lochness
flutter pub get
```

Set up Supabase:

1. Create a project at [supabase.com](https://supabase.com).
2. Run the migrations in `supabase/migrations/`, in order, in the SQL
   editor (or via `supabase db push` if you use the Supabase CLI).
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
- If you set up push notifications (see below), also add the "Push
  Notifications" and "Background Modes → Remote notifications" capabilities
  in Xcode, and link an APNs key in the Firebase console.

## Current scope (MVP)

- Email/password auth
- Create circles, view members, and invite people by shareable code
  (see **Invite flow** below)
- Start a share for 15 min / 1 hr / 8 hr / until turned off / forever
- Live map of everyone currently sharing with you (Supabase Realtime)
- Geofenced places per circle with arrival/departure notifications
  (see **Geofencing** below), optionally delivered by push even when the
  recipient's app is fully killed (see **Push notifications** below)

## Invite flow

Circle membership never requires knowing someone else's user id:

1. From a circle's detail screen (`/circles/:id`), tap **Invite** and pick
   an expiry (7 days / 30 days / never). This inserts a row into
   `circle_invites` with a server-generated 8-character code (via
   `generate_invite_code()` in `0002_circle_invites.sql`) and opens the
   platform share sheet (`share_plus`) with the code pre-filled into a
   message.
2. The recipient opens **Circles → the code icon in the app bar** (`/join`),
   types the code, and taps Join.
3. The client calls the `accept_circle_invite(invite_code)` Postgres
   function (`CircleRepository.joinByCode`), which runs as `security
   definer` so it can validate the code (not revoked, not expired, under
   its use cap) and insert the `circle_members` row itself — the invitee
   never needs direct insert access to that table.
4. A code is reusable by anyone it's shared with until the owner or
   creator revokes it (trash icon on the invite tile) or it expires.

This intentionally ships without OS-level deep linking (no
`lochness://invite/CODE` intent filter) — copy/paste or share-sheet text
covers the "share with family" case without needing to commit and
maintain `android/`/`ios/` platform config. Add a `app_links` (or
`uni_links`) integration later if tapping a link should jump straight to
the join screen.

## Geofencing

Arrival/departure detection runs **server-side**, not on the traveler's
device, so it doesn't depend on that specific phone's app staying open or
doing extra work:

1. From a circle's detail screen, tap the pin icon in the app bar to open
   **Places**, then **Add current location** while standing at the spot
   you want to name (e.g. home, school). Pick a name and a notify radius
   (50–500 m).
2. Every time anyone's `live_locations` row is written (see
   `LocationTrackingService`), the `evaluate_geofences_for_location`
   Postgres trigger (`0003_geofencing.sql`) checks that user's new position
   against every place in circles they're actively sharing to. Distance
   uses a plain haversine calculation — no PostGIS extension required.
3. A `geofence_state` table (server-only; RLS enabled with zero policies,
   so it's invisible over the API) tracks whether each user was last known
   to be inside each place, so the trigger only fires on true transitions,
   not on every location ping. The very first ping for a place only ever
   records an arrival (never a spurious departure) since there's no prior
   state yet.
4. Transitions are inserted into `geofence_events`, which only the trigger
   (running `security definer`) can write — there is deliberately no
   client-facing insert policy, so nobody can fake someone else's arrival.
5. Every signed-in device with the app's authenticated area open
   subscribes to `geofence_events` via Supabase Realtime
   (`GeofenceNotificationListener`, kept alive by `HomeShell`) and raises a
   local notification ("Mom arrived Home") for anyone else's transition in
   a shared circle.

**Limitation:** step 5 only reaches a device that has an open Realtime
connection — foreground or backgrounded, not fully killed. See **Push
notifications** below for the killed-app path.

## Push notifications

Reaching a fully-killed app needs real push delivery (FCM/APNs), not
Realtime. This is wired up, but — unlike everything above — it needs a real
Firebase project, which isn't something that can be created or verified in
a sandboxed dev environment, so you'll need to do the one-time setup
yourself:

1. **Create a Firebase project** (console.firebase.google.com) and add an
   Android app and/or iOS app to it. You don't need `google-services.json` /
   `GoogleService-Info.plist` — `FirebaseOptions` are passed programmatically
   via `--dart-define` (see `lib/core/config/firebase_env.dart`), the same
   pattern already used for Supabase credentials:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... \
     --dart-define=FIREBASE_API_KEY=... \
     --dart-define=FIREBASE_APP_ID=... \
     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
     --dart-define=FIREBASE_PROJECT_ID=...
   ```
   (Values come from the app's config snippet in Firebase console settings.)
   When these aren't set, push is simply skipped and everything else — 
   including in-app geofence alerts — still works.
2. Run migration `0004_push_notifications.sql`. It adds `device_push_tokens`
   (RLS: users manage only their own row) and a trigger on `geofence_events`
   that calls the Edge Function below via `pg_net` — but only once you've
   stored its URL and a service-role key in Supabase Vault (see the
   migration's comments), so it's a safe no-op until then.
3. **Deploy the Edge Function**: `supabase functions deploy send-geofence-push`.
   Generate a service account key in Firebase console (Project settings →
   Service accounts → Generate new private key) and set its fields as
   function secrets:
   ```bash
   supabase secrets set FCM_PROJECT_ID=... FCM_CLIENT_EMAIL=... \
     FCM_PRIVATE_KEY="$(jq -r .private_key service-account.json)"
   ```
   Then run the two `vault.create_secret(...)` calls from the migration's
   comments with your function's URL and a service-role key.
4. On the client, `PushNotificationService` (started from
   `pushRegistrationProvider`, watched by `HomeShell`) requests notification
   permission, gets an FCM token, and upserts it into `device_push_tokens`
   whenever someone is signed in with Firebase configured; the token is
   removed again on sign-out.
5. The Edge Function looks up the other members of the geofence event's
   circle, fetches their tokens, and sends an FCM v1 "notification" message
   to each — which the OS displays directly even if the app isn't running,
   with no extra background-handler code needed.

## Not yet built

- OS-level deep linking for invite codes (see **Invite flow** above)
- True background tracking when the app is killed (see the note in
  `LocationTrackingService` — plug in platform foreground services or a
  package such as `flutter_background_geolocation` for this)
- Location history/breadcrumb trail
- Ghost mode / per-viewer precision controls
