import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/live_location.dart';
import '../models/location_share.dart';

class LocationRepository {
  LocationRepository(this._client);

  final SupabaseClient _client;

  /// Starts (or replaces) a share of the current user's location with
  /// [circleId] for the given [duration]. Passing [ShareDuration.forever]
  /// or [ShareDuration.untilTurnedOff] stores a null expiry.
  Future<LocationShare> startShare({
    required String sharerId,
    required String circleId,
    required ShareDuration duration,
  }) async {
    final now = DateTime.now();
    final row = await _client
        .from('location_shares')
        .insert({
          'sharer_id': sharerId,
          'circle_id': circleId,
          'started_at': now.toIso8601String(),
          'expires_at': duration.expiresAtFrom(now)?.toIso8601String(),
        })
        .select()
        .single();
    return LocationShare.fromJson(row);
  }

  Future<void> stopShare(String shareId) {
    return _client
        .from('location_shares')
        .update({'stopped_at': DateTime.now().toIso8601String()}).eq('id', shareId);
  }

  Future<List<LocationShare>> fetchActiveShares(String sharerId) async {
    final rows = await _client
        .from('active_location_shares')
        .select()
        .eq('sharer_id', sharerId);
    return rows.map<LocationShare>(LocationShare.fromJson).toList();
  }

  /// Upserts the caller's own current position. Called on every location
  /// tracking tick while at least one active share exists.
  Future<void> pushLocation(LiveLocation location) {
    return _client.from('live_locations').upsert(location.toUpsertJson());
  }

  /// Streams live locations visible to the current user (RLS restricts rows
  /// to people who have an active share with a circle the caller belongs to).
  Stream<List<LiveLocation>> watchVisibleLocations() {
    return _client
        .from('live_locations')
        .stream(primaryKey: ['user_id'])
        .map((rows) => rows.map(LiveLocation.fromJson).toList());
  }
}
