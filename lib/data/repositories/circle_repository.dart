import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import '../models/profile.dart';

class CircleRepository {
  CircleRepository(this._client);

  final SupabaseClient _client;

  Future<List<Circle>> fetchMyCircles(String userId) async {
    final rows = await _client
        .from('circles')
        .select('*, circle_members!inner(user_id)')
        .eq('circle_members.user_id', userId);
    return rows.map<Circle>(Circle.fromJson).toList();
  }

  Future<Circle> createCircle({required String name, required String ownerId}) async {
    final row = await _client
        .from('circles')
        .insert({'name': name, 'owner_id': ownerId})
        .select()
        .single();
    final circle = Circle.fromJson(row);
    await _client.from('circle_members').insert({
      'circle_id': circle.id,
      'user_id': ownerId,
      'role': 'owner',
    });
    return circle;
  }

  Future<void> inviteMember({required String circleId, required String userId}) {
    return _client.from('circle_members').insert({
      'circle_id': circleId,
      'user_id': userId,
      'role': 'member',
    });
  }

  Future<List<Profile>> fetchMembers(String circleId) async {
    final rows = await _client
        .from('circle_members')
        .select('profiles(*)')
        .eq('circle_id', circleId);
    return rows.map<Profile>((row) => Profile.fromJson(row['profiles'])).toList();
  }
}
