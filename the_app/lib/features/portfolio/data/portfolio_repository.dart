import 'package:supabase_flutter/supabase_flutter.dart';

import '../../legal_workstream/models/task.dart';
import '../models/monthly_report.dart';
import '../models/portfolio_kpis.dart';

/// Reads for the Terms of Reference measures. Everything goes through RLS,
/// so a consultant gets their own discipline's ToR tasks on their
/// enterprises and an Admin gets the whole programme.
class PortfolioRepository {
  PortfolioRepository(this._client);

  final SupabaseClient _client;

  Future<List<TorTaskStatus>> fetchTorTaskStatuses() async {
    final rows = await _client.from('tasks').select('enterprise_id, tor_key, status').not('tor_key', 'is', null);
    return [
      for (final r in rows as List)
        TorTaskStatus(
          enterpriseId: r['enterprise_id'] as String,
          torKey: r['tor_key'] as String,
          status: TaskStatusX.fromDb(r['status'] as String),
        ),
    ];
  }

  /// Tasks completed in [from, to) the caller can see.
  Future<List<ReportTask>> fetchCompleted(DateTime from, DateTime to) async {
    final rows = await _client
        .from('tasks')
        .select('enterprise_id, title, specialization, completed_at')
        .eq('status', 'Completed')
        .gte('completed_at', from.toUtc().toIso8601String())
        .lt('completed_at', to.toUtc().toIso8601String())
        .order('completed_at');
    return [
      for (final r in rows as List)
        ReportTask(
          enterpriseId: r['enterprise_id'] as String,
          title: r['title'] as String,
          specialization: r['specialization'] as String?,
          date: r['completed_at'] == null ? null : DateTime.parse(r['completed_at'] as String).toLocal(),
        ),
    ];
  }

  /// Open tasks due in [from, to): the next month's workplan.
  Future<List<ReportTask>> fetchDue(DateTime from, DateTime to) async {
    String d(DateTime x) => x.toIso8601String().split('T').first;
    final rows = await _client
        .from('tasks')
        .select('enterprise_id, title, specialization, due_date')
        .neq('status', 'Completed')
        .gte('due_date', d(from))
        .lt('due_date', d(to))
        .order('due_date');
    return [
      for (final r in rows as List)
        ReportTask(
          enterpriseId: r['enterprise_id'] as String,
          title: r['title'] as String,
          specialization: r['specialization'] as String?,
          date: r['due_date'] == null ? null : DateTime.parse(r['due_date'] as String),
        ),
    ];
  }
}
