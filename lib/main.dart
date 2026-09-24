import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/firebase_env.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.isConfigured) {
    debugPrint(
      'SUPABASE_URL / SUPABASE_ANON_KEY are not set. Pass them with '
      '--dart-define when running or building the app.',
    );
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Registers the plugin's platform channel once at startup; the
  // NotificationService instances created later via Riverpod share the same
  // underlying platform binding, so they don't need to re-initialize.
  await NotificationService().init();

  if (FirebaseEnv.isConfigured) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: FirebaseEnv.apiKey,
        appId: FirebaseEnv.appId,
        messagingSenderId: FirebaseEnv.messagingSenderId,
        projectId: FirebaseEnv.projectId,
      ),
    );
  } else {
    debugPrint(
      'FIREBASE_* dart-defines are not set; push notifications for a fully '
      'killed app are disabled. In-app geofence alerts (Realtime-based) '
      'still work without this.',
    );
  }

  runApp(const ProviderScope(child: LochnessApp()));
}
