import 'dart:async';

import '../data/models/geofence_event.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/place_repository.dart';
import 'notification_service.dart';

/// Watches `geofence_events` (written server-side by the
/// `evaluate_geofences_for_location` Postgres trigger — see
/// supabase/migrations/0003_geofencing.sql) and raises a local notification
/// for every *new* arrival/departure by someone else in a shared circle.
///
/// This only reaches devices with the app open (foreground or backgrounded
/// with an active Realtime connection) since it relies on Supabase Realtime
/// rather than push. Waking a fully-killed app requires a push service
/// (FCM/APNs) wired through a Supabase Edge Function — see the README.
class GeofenceNotificationListener {
  GeofenceNotificationListener({
    required PlaceRepository placeRepository,
    required AuthRepository authRepository,
    required NotificationService notificationService,
    required String currentUserId,
  })  : _placeRepository = placeRepository,
        _authRepository = authRepository,
        _notificationService = notificationService,
        _currentUserId = currentUserId;

  final PlaceRepository _placeRepository;
  final AuthRepository _authRepository;
  final NotificationService _notificationService;
  final String _currentUserId;

  StreamSubscription<List<GeofenceEvent>>? _subscription;
  final Set<String> _seenEventIds = {};
  bool _hasBootstrapped = false;

  final Map<String, String> _placeNameCache = {};
  final Map<String, String> _displayNameCache = {};

  void start() {
    if (_subscription != null) return;
    _subscription = _placeRepository.watchGeofenceEvents().listen(_handleEvents);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _handleEvents(List<GeofenceEvent> events) async {
    if (!_hasBootstrapped) {
      // Don't fire notifications for history that predates this listener.
      _seenEventIds.addAll(events.map((e) => e.id));
      _hasBootstrapped = true;
      return;
    }

    for (final event in events) {
      if (_seenEventIds.contains(event.id)) continue;
      _seenEventIds.add(event.id);

      if (event.userId == _currentUserId) continue; // don't notify people about themselves

      final placeName = await _placeName(event.placeId);
      final personName = await _displayName(event.userId);
      if (placeName == null || personName == null) continue;

      await _notificationService.showGeofenceNotification(
        personName: personName,
        placeName: placeName,
        isArrival: event.isArrival,
      );
    }
  }

  Future<String?> _placeName(String placeId) async {
    final cached = _placeNameCache[placeId];
    if (cached != null) return cached;
    try {
      final place = await _placeRepository.fetchPlace(placeId);
      _placeNameCache[placeId] = place.name;
      return place.name;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _displayName(String userId) async {
    final cached = _displayNameCache[userId];
    if (cached != null) return cached;
    try {
      final profile = await _authRepository.fetchProfile(userId);
      _displayNameCache[userId] = profile.displayName;
      return profile.displayName;
    } catch (_) {
      return null;
    }
  }
}
