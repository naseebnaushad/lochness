import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../data/models/live_location.dart';
import '../data/repositories/location_repository.dart';

/// Streams device position updates and pushes them to Supabase while at
/// least one location share is active. Keeps updates cheap when the device
/// is stationary by using a distance filter rather than a fixed timer.
///
/// NOTE: for real background tracking (app killed / screen off for hours),
/// wire this into a platform foreground service (Android) or background
/// location updates (iOS), or a dedicated package such as
/// `flutter_background_geolocation`. This class covers foreground + short
/// background tracking out of the box.
class LocationTrackingService {
  LocationTrackingService(this._locationRepository);

  final LocationRepository _locationRepository;

  StreamSubscription<Position>? _subscription;
  String? _userId;

  bool get isTracking => _subscription != null;

  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> start(String userId) async {
    if (_subscription != null) return;
    _userId = userId;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25, // meters - avoids spamming updates while stationary
    );

    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      _locationRepository.pushLocation(
        LiveLocation(
          userId: userId,
          latitude: position.latitude,
          longitude: position.longitude,
          recordedAt: DateTime.now(),
          accuracyM: position.accuracy,
          headingDeg: position.heading,
          speedMS: position.speed,
        ),
      );
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _userId = null;
  }
}
