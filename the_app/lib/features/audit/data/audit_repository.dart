import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';

/// Reads the audit log (Admins only, enforced by RLS). Newest first,
/// paged.
class AuditRepository {
  AuditRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 100;

  /// [userId] matches both what the user did (actor) and what happened to
  /// them (subject). [to] is inclusive of that whole day.
  Future<List<AuditEntry>> fetch({
    String? enterpriseId,
    String? userId,
    DateTime? from,
    DateTime? to,
    int offset = 0,
  }) async {
    var query = _client.from('audit_log').select(
          'id, occurred_at, action, entity_type, summary, '
          'actor:actor_id(first_name, last_name), enterprise:enterprise_id(business_name)',
        );
    if (enterpriseId != null) query = query.eq('enterprise_id', enterpriseId);
    if (userId != null) query = query.or('actor_id.eq.$userId,subject_user_id.eq.$userId');
    if (from != null) query = query.gte('occurred_at', DateTime(from.year, from.month, from.day).toUtc().toIso8601String());
    if (to != null) {
      query = query.lt('occurred_at', DateTime(to.year, to.month, to.day + 1).toUtc().toIso8601String());
    }
    final rows = await query.order('occurred_at', ascending: false).range(offset, offset + pageSize - 1);
    return (rows as List).map((r) => AuditEntry.fromMap(r as Map<String, dynamic>)).toList();
  }
}
