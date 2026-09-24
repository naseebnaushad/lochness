import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/circle.dart';
import '../models/circle_invite.dart';
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

  Future<List<Profile>> fetchMembers(String circleId) async {
    final rows = await _client
        .from('circle_members')
        .select('profiles(*)')
        .eq('circle_id', circleId);
    return rows.map<Profile>((row) => Profile.fromJson(row['profiles'])).toList();
  }

  Future<Circle> fetchCircle(String circleId) async {
    final row = await _client.from('circles').select().eq('id', circleId).single();
    return Circle.fromJson(row);
  }

  /// Creates a shareable invite code for [circleId]. The code is reusable by
  /// anyone it's shared with until it expires, is revoked, or (if [maxUses]
  /// is set) reaches its use cap.
  Future<CircleInvite> createInvite({
    required String circleId,
    required String createdBy,
    required InviteExpiry expiry,
    int? maxUses,
  }) async {
    final row = await _client
        .from('circle_invites')
        .insert({
          'circle_id': circleId,
          'created_by': createdBy,
          'expires_at': expiry.expiresAtFrom(DateTime.now())?.toIso8601String(),
          'max_uses': maxUses,
        })
        .select()
        .single();
    return CircleInvite.fromJson(row);
  }

  Future<List<CircleInvite>> fetchInvites(String circleId) async {
    final rows = await _client
        .from('circle_invites')
        .select()
        .eq('circle_id', circleId)
        .order('created_at', ascending: false);
    return rows.map<CircleInvite>(CircleInvite.fromJson).toList();
  }

  Future<void> revokeInvite(String inviteId) {
    return _client
        .from('circle_invites')
        .update({'revoked_at': DateTime.now().toIso8601String()}).eq('id', inviteId);
  }

  /// Redeems an invite code for the signed-in user via the `accept_circle_invite`
  /// Postgres function, which validates expiry/revocation server-side and
  /// adds the caller to `circle_members`. Returns the joined circle.
  Future<Circle> joinByCode(String code) async {
    final circleId = await _client.rpc<String>(
      'accept_circle_invite',
      params: {'invite_code': code.trim().toUpperCase()},
    );
    return fetchCircle(circleId);
  }
}
