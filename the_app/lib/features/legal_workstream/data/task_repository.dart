import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loan_readiness.dart';
import '../models/task.dart';
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

  /// Bulk-creates a standard checklist (Legal or Accounting) as real
  /// task rows — identical in shape to a manually-created task, just
  /// created in one batch. Existing custom tasks aren't touched or
  /// duplicate-checked; re-running this would create a second copy of
  /// each — acceptable since callers only apply this once per
  /// specialization per enterprise (see assign_consultant_screen).
  Future<void> applyChecklist({
    required String enterpriseId,
    required String consultantId,
    required List<TaskTemplate> checklist,
  }) async {
    final rows = checklist
        .map((t) => {
              'enterprise_id': enterpriseId,
              'consultant_id': consultantId,
              'title': t.title,
              'description': t.description,
              'priority': t.priority.dbValue,
            })
        .toList();
    await _client.from('tasks').insert(rows);
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    // completed_at is handled by the tasks_completed_consistency trigger.
    await _client.from('tasks').update({'status': status.dbValue}).eq('id', taskId);
  }
}