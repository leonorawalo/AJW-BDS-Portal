import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers/removes the current device's FCM token in
/// `public.device_tokens`. A token belongs to ONE user at a time (unique on
/// fcm_token): signing in claims it for the new user, and signing out
/// releases it (while the session still exists, so RLS allows the delete).
/// send-push reads this table with the service role key to know which
/// devices to push to.
class DeviceTokenRepository {
  DeviceTokenRepository(this._client);

  final SupabaseClient _client;

  String get _platform {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// Assigns this device's token to the signed-in user, taking it over
  /// from whoever used the device before (see claim_device_token()).
  Future<void> claimToken(String token) {
    return _client.rpc('claim_device_token', params: {'p_token': token, 'p_platform': _platform});
  }

  /// Must run BEFORE signing out: afterwards there's no session and RLS
  /// silently blocks the delete (the original Phase 6 bug).
  Future<void> releaseToken(String token) {
    return _client.from('device_tokens').delete().eq('fcm_token', token);
  }
}
