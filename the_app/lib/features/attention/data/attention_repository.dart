import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attention_spots.dart';

/// Red dots. Both calls are database functions scoped to the caller
/// (migration 20261005100000); the app never reads `attention_seen`.
class AttentionRepository {
  AttentionRepository(this._client);

  final SupabaseClient _client;

  Future<AttentionSpots> fetch() async {
    final rows = await _client.rpc('my_attention');
    return AttentionSpots.fromRows(rows as List<dynamic>);
  }

  /// The user has opened this place: clears its dot. [enterpriseId] null =
  /// a role-level page.
  Future<void> markSeen({String? enterpriseId, required String section}) =>
      _client.rpc('mark_seen', params: {'p_enterprise_id': enterpriseId, 'p_section': section});
}
