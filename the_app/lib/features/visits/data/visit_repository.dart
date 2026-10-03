import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enterprise_visit.dart';

/// The visit log. RLS decides who sees and writes what (see the migration):
/// only the consultant who made a visit can log or edit it.
class VisitRepository {
  VisitRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, users!enterprise_visits_consultant_id_fkey(first_name, last_name)';

  Future<List<EnterpriseVisit>> fetchForEnterprise(String enterpriseId) async {
    final rows = await _client
        .from('enterprise_visits')
        .select(_select)
        .eq('enterprise_id', enterpriseId)
        .order('visited_on', ascending: false)
        .order('logged_at', ascending: false);
    return (rows as List).map((r) => EnterpriseVisit.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Every visit the caller can see on or after [since] (RLS scopes it:
  /// a consultant gets their enterprises', an Admin everyone's).
  Future<List<EnterpriseVisit>> fetchSince(DateTime since) async {
    final rows = await _client
        .from('enterprise_visits')
        .select(_select)
        .gte('visited_on', _date(since))
        .order('visited_on', ascending: false);
    return (rows as List).map((r) => EnterpriseVisit.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Visits on dates in [from, to).
  Future<List<EnterpriseVisit>> fetchBetween(DateTime from, DateTime to) async {
    final rows = await _client
        .from('enterprise_visits')
        .select(_select)
        .gte('visited_on', _date(from))
        .lt('visited_on', _date(to))
        .order('visited_on');
    return (rows as List).map((r) => EnterpriseVisit.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> logVisit({
    required String enterpriseId,
    required DateTime visitedOn,
    required String mode,
    required String outcome,
    String? nextSteps,
  }) async {
    await _client.from('enterprise_visits').insert({
      'enterprise_id': enterpriseId,
      'visited_on': _date(visitedOn),
      'mode': mode,
      'outcome': outcome,
      'next_steps': (nextSteps ?? '').trim().isEmpty ? null : nextSteps!.trim(),
    });
  }

  Future<void> updateNotes(String visitId, {required String outcome, String? nextSteps}) async {
    await _client.from('enterprise_visits').update({
      'outcome': outcome,
      'next_steps': (nextSteps ?? '').trim().isEmpty ? null : nextSteps!.trim(),
    }).eq('id', visitId);
  }

  Future<void> delete(String visitId) async {
    await _client.from('enterprise_visits').delete().eq('id', visitId);
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
