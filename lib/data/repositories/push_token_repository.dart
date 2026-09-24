import 'package:supabase_flutter/supabase_flutter.dart';

class PushTokenRepository {
  PushTokenRepository(this._client);

  final SupabaseClient _client;

  Future<void> upsertToken({
    required String userId,
    required String token,
    required String platform,
  }) {
    return _client.from('device_push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  Future<void> deleteToken(String token) {
    return _client.from('device_push_tokens').delete().eq('token', token);
  }
}
