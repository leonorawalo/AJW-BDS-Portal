import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_readiness.dart';
import '../models/task.dart';
import '../../../shared/models/user_profile.dart';
import '../models/task_template.dart';

class TaskRepository {
  TaskRepository(this._client);

  final SupabaseClient _client;

  Future<List<WorkstreamTask>> fetchTasks(String enterpriseId) async {
    final rows = await _client
        .from('tasks')
        .select()
        .eq('enterprise_id', enterpriseId)
        .order('due_date', ascending: true);
    return (rows as List).map((r) => WorkstreamTask.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Which score-relevant ToR tasks are completed on the enterprise,
  /// across every discipline — including tasks the caller can't read.
  Future<Set<String>> fetchCompletedLoanReadinessTitles(String enterpriseId) async {
    final rows = await _client.rpc('completed_loan_readiness_tasks', params: {
      'p_enterprise_id': enterpriseId,
      'p_titles': loanReadinessTaskTitles,
    }) as List;
    return rows.map((r) => r as String).toSet();
  }

  Future<WorkstreamTask> fetchTask(String taskId) async {
    final row = await _client.from('tasks').select().eq('id', taskId).single();
    return WorkstreamTask.fromMap(row);
  }

  Future<void> createTask({
    required String enterpriseId,
    required String consultantId,
    required String title,
    String? description,
    required TaskPriority priority,
    DateTime? dueDate,
  }) async {
    await _client.from('tasks').insert({
      'enterprise_id': enterpriseId,
      'consultant_id': consultantId,
      'title': title,
      'description': description,
      'priority': priority.dbValue,
      'due_date': dueDate?.toIso8601String(),
    });
  }

  /// Adds whatever is missing of [specialization]'s ToR checklist to the
  /// enterprise, for the consultant currently assigned to that discipline
  /// (ensure_tor_tasks, migration 20261003100000). Safe to call any number
  /// of times: each item exists at most once. Returns how many were added
  /// (0 when nobody holds that discipline yet).
  ///
  /// Due dates follow the ToR clock from enrolment: going-concern items at
  /// 3 months, bankable items at 6. For an enterprise enrolled long ago the
  /// date would already have passed, so those get two weeks from today.
  Future<int> ensureTorTasks({
    required String enterpriseId,
    required ConsultantSpecialization specialization,
    required DateTime enrolledAt,
  }) async {
    final soonest = DateTime.now().add(const Duration(days: 14));
    String dueFor(TorPhase phase) {
      final byToR = enrolledAt.add(Duration(days: phase.dueAfterDays));
      final due = byToR.isBefore(soonest) ? soonest : byToR;
      return due.toIso8601String().split('T').first;
    }

    final items = [
      for (final t in torChecklistFor(specialization))
        {
          'tor_key': t.key,
          'title': t.title,
          'description': t.description,
          'priority': t.priority.dbValue,
          'due_date': dueFor(t.phase),
        },
    ];
    final added = await _client.rpc('ensure_tor_tasks', params: {
      'p_enterprise_id': enterpriseId,
      'p_specialization': specialization.dbValue,
      'p_items': items,
    });
    return (added as num?)?.toInt() ?? 0;
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    // completed_at is handled by the tasks_completed_consistency trigger.
    await _client.from('tasks').update({'status': status.dbValue}).eq('id', taskId);
  }
}