import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/repositories/push_token_repository.dart';

/// Registers this device for FCM push and keeps `device_push_tokens` in sync,
/// so the `send-geofence-push` Edge Function (supabase/functions/) can reach
/// it even when the app is fully killed. Only used when Firebase is
/// configured (see [FirebaseEnv.isConfigured]) — otherwise geofence alerts
/// still work in-app via GeofenceNotificationListener/Realtime.
class PushNotificationService {
  PushNotificationService({required PushTokenRepository pushTokenRepository})
      : _pushTokenRepository = pushTokenRepository;

  final PushTokenRepository _pushTokenRepository;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentToken;

  Future<void> registerForUser(String userId) async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await messaging.getToken();
    if (token != null) {
      _currentToken = token;
      await _pushTokenRepository.upsertToken(
        userId: userId,
        token: token,
        platform: _platformName,
      );
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _pushTokenRepository.upsertToken(
        userId: userId,
        token: newToken,
        platform: _platformName,
      );
    });
  }

  Future<void> unregister() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    final token = _currentToken;
    _currentToken = null;
    if (token != null) {
      await _pushTokenRepository.deleteToken(token);
    }
  }

  String get _platformName => Platform.isIOS ? 'ios' : 'android';
}
