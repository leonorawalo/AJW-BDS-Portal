import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers/removes the current device's FCM token in
/// `public.device_tokens`, keyed by (user_id, fcm_token). A future
/// Edge Function reads this table with the service role key to know
/// which devices to push to — never read back by the app itself.
class DeviceTokenRepository {
  DeviceTokenRepository(this._client);

  final SupabaseClient _client;

  String get _platform {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  Future<void> registerToken({required String userId, required String token}) {
    return _client.from('device_tokens').upsert(
      {'user_id': userId, 'fcm_token': token, 'platform': _platform},
      onConflict: 'user_id,fcm_token',
    );
  }

  /// Best-effort — called on sign-out so a stale token isn't pushed to
  /// after the user who owned it has left the device.
  Future<void> deleteToken(String token) {
    return _client.from('device_tokens').delete().eq('fcm_token', token);
  }
}
