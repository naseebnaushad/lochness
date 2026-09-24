/// Firebase config, passed via --dart-define at build/run time, e.g.:
///
///   flutter run \
///     --dart-define=FIREBASE_API_KEY=... \
///     --dart-define=FIREBASE_APP_ID=... \
///     --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///     --dart-define=FIREBASE_PROJECT_ID=...
///
/// These come from a Firebase project's "Add app" config (Android/iOS), not
/// from `flutterfire configure` — we pass them programmatically instead of
/// committing `google-services.json` / `GoogleService-Info.plist`, matching
/// how android/ios/ are already gitignored and generated locally.
///
/// When these aren't set, push notifications are simply skipped — Realtime-
/// based in-app notifications (GeofenceNotificationListener) don't need them.
class FirebaseEnv {
  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  static const String appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '',
  );

  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );

  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;
}
