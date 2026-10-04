import 'package:supabase_flutter/supabase_flutter.dart';

/// Which guided tours this account has seen, and whether automatic tips
/// are off. Kept per ACCOUNT in the user's auth metadata (like
/// google_prompt_done), so moving from phone to laptop doesn't repeat them.
///
/// Metadata keys: `tours_seen` (list of tour ids), `tips_off` (bool).
class TourProgressRepository {
  TourProgressRepository(this._client);

  final SupabaseClient _client;

  /// Seen this app run but maybe not saved yet (per user id): stops a tour
  /// repeating while the metadata write is in flight, and is merged into
  /// every write so back-to-back tours can't overwrite each other.
  static final _seenThisRun = <String, Set<String>>{};

  Set<String> get _local => _seenThisRun.putIfAbsent(_client.auth.currentUser?.id ?? '', () => {});

  Map<String, dynamic> get _meta => _client.auth.currentUser?.userMetadata ?? const {};

  /// Signed in and past the set-password step: tours never show before
  /// that (sign-in, set-password and reset screens have no tours).
  bool get ready => _client.auth.currentUser != null && _meta['needs_password'] != true;

  bool get tipsOff => _meta['tips_off'] == true;

  bool hasSeen(String tourId) =>
      _local.contains(tourId) || ((_meta['tours_seen'] as List?)?.contains(tourId) ?? false);

  Future<void> markSeen(String tourId) async {
    _local.add(tourId);
    final seen = {...((_meta['tours_seen'] as List?)?.cast<String>() ?? const <String>[]), ..._local};
    await _client.auth.updateUser(UserAttributes(data: {'tours_seen': seen.toList()..sort()}));
  }

  Future<void> setTipsOff(bool off) => _client.auth.updateUser(UserAttributes(data: {'tips_off': off}));
}
