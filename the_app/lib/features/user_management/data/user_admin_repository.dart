import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/managed_user.dart';

/// Admin-only user management (Phase 9b). Listing goes through the
/// admin_list_users() RPC; suspend/reactivate through the manage-users Edge
/// Function, because they also ban/unban the login, which needs the
/// service key.
class UserAdminRepository {
  UserAdminRepository(this._client);

  final SupabaseClient _client;

  Future<List<ManagedUser>> fetchUsers() async {
    final rows = await _client.rpc('admin_list_users') as List;
    return rows.map((r) => ManagedUser.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> suspend(String userId) => _manage('suspend', userId);
  Future<void> reactivate(String userId) => _manage('reactivate', userId);

  /// Removes their authenticator app (lost phone); they set it up again
  /// at next sign-in.
  Future<void> resetTwoStep(String userId) => _manage('reset_mfa', userId);

  /// Consultants only. The Users screen allows it only while they have no
  /// active assignments: their assignments and tasks carry the
  /// specialization they had when created.
  Future<void> updateSpecialization(String userId, String specialization) {
    return _client.from('users').update({'specialization': specialization}).eq('id', userId);
  }

  /// Carries out an approved deletion request (Kenya Data Protection Act,
  /// 2019): the person's personal data is deleted or anonymised and their
  /// account blocked, and [requestId] is marked completed. Returns whether
  /// a confirmation email went out from the Admin's own Gmail.
  Future<bool> eraseUserData(String userId, {String? requestId}) async {
    final res = await _manage('erase', userId, extra: {'request_id': ?requestId});
    return res is Map && res['emailed'] == true;
  }

  Future<dynamic> _manage(String action, String userId, {Map<String, Object> extra = const {}}) async {
    try {
      final res = await _client.functions.invoke('manage-users', body: {'action': action, 'user_id': userId, ...extra});
      return res.data;
    } on FunctionException catch (e) {
      final details = e.details;
      throw Exception(details is Map ? details['error'] ?? 'Request failed' : 'Request failed (${e.status})');
    }
  }
}
