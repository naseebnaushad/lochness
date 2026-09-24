import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place.dart';

class PlaceRepository {
  PlaceRepository(this._client);

  final SupabaseClient _client;

  Future<List<Place>> fetchPlaces(String circleId) async {
    final rows = await _client.from('places').select().eq('circle_id', circleId);
    return rows.map<Place>(Place.fromJson).toList();
  }

  Future<Place> createPlace({
    required String circleId,
    required String name,
    required double latitude,
    required double longitude,
    required int radiusM,
    required String createdBy,
  }) async {
    final row = await _client
        .from('places')
        .insert({
          'circle_id': circleId,
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'radius_m': radiusM,
          'created_by': createdBy,
        })
        .select()
        .single();
    return Place.fromJson(row);
  }

  Future<void> deletePlace(String placeId) {
    return _client.from('places').delete().eq('id', placeId);
  }

  Future<void> recordGeofenceEvent({
    required String placeId,
    required String userId,
    required String eventType,
  }) {
    return _client.from('geofence_events').insert({
      'place_id': placeId,
      'user_id': userId,
      'event_type': eventType,
    });
  }
}
