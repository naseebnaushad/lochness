import 'package:geolocator/geolocator.dart';

import '../data/models/live_location.dart';
import '../data/models/place.dart';
import '../data/repositories/place_repository.dart';
import 'notification_service.dart';

/// Evaluates a user's live location against a set of saved [Place]s and
/// records/announces arrival & departure transitions. Intended to be driven
/// either client-side (for the app's own owner) or from a Supabase Edge
/// Function on `live_locations` writes for other circle members.
class GeofenceService {
  GeofenceService(this._placeRepository, this._notificationService);

  final PlaceRepository _placeRepository;
  final NotificationService _notificationService;

  final Map<String, bool> _insideByPlaceId = {};

  Future<void> evaluate({
    required LiveLocation location,
    required List<Place> places,
    required String personDisplayName,
  }) async {
    for (final place in places) {
      final distanceM = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        place.latitude,
        place.longitude,
      );
      final isInside = distanceM <= place.radiusM;
      final wasInside = _insideByPlaceId[place.id] ?? false;

      if (isInside == wasInside) continue;
      _insideByPlaceId[place.id] = isInside;

      final eventType = isInside ? 'arrival' : 'departure';
      await _placeRepository.recordGeofenceEvent(
        placeId: place.id,
        userId: location.userId,
        eventType: eventType,
      );
      await _notificationService.showGeofenceNotification(
        personName: personDisplayName,
        placeName: place.name,
        isArrival: isInside,
      );
    }
  }
}
