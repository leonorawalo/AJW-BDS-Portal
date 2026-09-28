import 'package:supabase_flutter/supabase_flutter.dart';

import '../../enterprises/models/enterprise.dart';
import '../../legal_workstream/models/loan_readiness.dart';
import '../models/portfolio_row.dart';

/// Builds the Admin portfolio: one row per enterprise. Admin-only in the
/// UI; RLS lets Admins read every table used here. A non-admin calling it
/// would simply get only the rows RLS lets them see.
class PortfolioRepository {
  PortfolioRepository(this._client);

  final SupabaseClient _client;

  Future<List<PortfolioRow>> fetchPortfolio() async {
    final (enterprises, tasks, assignments, sessions, recommendations, documents, comments) = await (
      _client.from('enterprises').select().order('business_name'),
      _client.from('tasks').select('enterprise_id, title, status, updated_at'),
      _client
          .from('consultant_assignments')
          .select('enterprise_id, specialization, consultant:consultant_id(first_name, last_name)')
          .eq('assignment_status', 'active'),
      _client.from('consultation_sessions').select('enterprise_id, starts_at, status, created_at'),
      _client.from('recommendations').select('enterprise_id, created_at'),
      _client.from('documents').select('enterprise_id, uploaded_at'),
      _client.from('task_comments').select('created_at, task:task_id(enterprise_id)'),
    ).wait;

    Map<String, List<Map<String, dynamic>>> byEnterprise(List rows, [String Function(Map<String, dynamic>)? key]) {
      final out = <String, List<Map<String, dynamic>>>{};
      for (final r in rows.cast<Map<String, dynamic>>()) {
        final id = key != null ? key(r) : r['enterprise_id'] as String?;
        if (id != null) out.putIfAbsent(id, () => []).add(r);
      }
      return out;
    }

    final tasksBy = byEnterprise(tasks);
    final assignmentsBy = byEnterprise(assignments);
    final sessionsBy = byEnterprise(sessions);
    final recsBy = byEnterprise(recommendations);
    final docsBy = byEnterprise(documents);
    final commentsBy = byEnterprise(comments, (r) => (r['task'] as Map<String, dynamic>?)?['enterprise_id'] as String? ?? '');

    DateTime? parse(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
    DateTime? latest(Iterable<DateTime?> dates) {
      DateTime? max;
      for (final d in dates) {
        if (d != null && (max == null || d.isAfter(max))) max = d;
      }
      return max;
    }

    final now = DateTime.now();
    return [
      for (final row in enterprises.cast<Map<String, dynamic>>())
        () {
          final e = Enterprise.fromMap(row);
          final eTasks = tasksBy[e.id] ?? const [];
          final completed = eTasks.where((t) => t['status'] == 'Completed');
          // Admins can read every task, so this is the same set the
          // completion-only RPC returns to consultants.
          final inputs = LoanReadinessInputs.from(
            enterprise: e,
            completedTaskTitles: {for (final t in completed) t['title'] as String},
          );
          final kcb = LoanReadiness.kcbRequirements(inputs);
          final eSessions = sessionsBy[e.id] ?? const [];
          final upcoming = eSessions
              .where((s) => s['status'] == 'Scheduled')
              .map((s) => parse(s['starts_at'])!)
              .where((d) => d.isAfter(now))
              .toList()
            ..sort();

          return PortfolioRow(
            enterpriseName: e.businessName,
            lifecycleStatus: e.lifecycleStatus.label,
            goingConcern: e.goingConcernStatus.dbValue,
            businessHealth: LoanReadiness.businessHealthScore(inputs),
            creditReadiness: LoanReadiness.creditReadinessScore(inputs),
            kcbMet: kcb.where((r) => r.$1).length,
            kcbTotal: kcb.length,
            consultantsByDiscipline: {
              for (final a in assignmentsBy[e.id] ?? const <Map<String, dynamic>>[])
                if (a['specialization'] != null && a['consultant'] != null)
                  a['specialization'] as String:
                      '${a['consultant']['first_name']} ${a['consultant']['last_name']}'.trim(),
            },
            openTasks: eTasks.length - completed.length,
            completedTasks: completed.length,
            nextSession: upcoming.isEmpty ? null : upcoming.first,
            lastActivity: latest([
              parse(row['updated_at']),
              for (final t in eTasks) parse(t['updated_at']),
              for (final s in eSessions) parse(s['created_at']),
              for (final r in recsBy[e.id] ?? const <Map<String, dynamic>>[]) parse(r['created_at']),
              for (final d in docsBy[e.id] ?? const <Map<String, dynamic>>[]) parse(d['uploaded_at']),
              for (final c in commentsBy[e.id] ?? const <Map<String, dynamic>>[]) parse(c['created_at']),
            ]),
          );
        }(),
    ];
  }
}
