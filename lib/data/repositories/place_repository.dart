import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/geofence_event.dart';
import '../models/place.dart';

class PlaceRepository {
  PlaceRepository(this._client);

  final SupabaseClient _client;

  Future<List<Place>> fetchPlaces(String circleId) async {
    final rows = await _client.from('places').select().eq('circle_id', circleId);
    return rows.map<Place>(Place.fromJson).toList();
  }

  Future<Place> fetchPlace(String placeId) async {
    final row = await _client.from('places').select().eq('id', placeId).single();
    return Place.fromJson(row);
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

  /// Arrival/departure events are written server-side by the
  /// `evaluate_geofences_for_location` trigger (see
  /// `supabase/migrations/0003_geofencing.sql`), never by the client. This
  /// streams every event visible to the caller (RLS scopes it to circles
  /// they belong to) so the app can surface a notification as new rows
  /// arrive.
  Stream<List<GeofenceEvent>> watchGeofenceEvents() {
    return _client
        .from('geofence_events')
        .stream(primaryKey: ['id'])
        .order('occurred_at', ascending: true)
        .map((rows) => rows.map(GeofenceEvent.fromJson).toList());
  }
}
