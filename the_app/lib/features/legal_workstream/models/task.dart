enum TaskPriority { low, medium, high }

extension TaskPriorityX on TaskPriority {
  static TaskPriority fromDb(String v) => TaskPriority.values.firstWhere(
        (p) => p.dbValue == v,
        orElse: () => TaskPriority.medium,
      );
  String get dbValue => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
      };
}

enum TaskStatus { pending, inProgress, completed, overdue }

extension TaskStatusX on TaskStatus {
  static TaskStatus fromDb(String v) => switch (v) {
        'In Progress' => TaskStatus.inProgress,
        'Completed' => TaskStatus.completed,
        'Overdue' => TaskStatus.overdue,
        _ => TaskStatus.pending,
      };
  String get dbValue => switch (this) {
        TaskStatus.pending => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed => 'Completed',
        TaskStatus.overdue => 'Overdue',
      };
}

class WorkstreamTask {
  const WorkstreamTask({
    required this.id,
    required this.enterpriseId,
    required this.consultantId,
    required this.title,
    this.description,
    required this.priority,
    this.dueDate,
    required this.status,
    this.completedAt,
    this.specialization,
    this.torKey,
  });

  factory WorkstreamTask.fromMap(Map<String, dynamic> map) => WorkstreamTask(
        id: map['id'] as String,
        enterpriseId: map['enterprise_id'] as String,
        consultantId: map['consultant_id'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        priority: TaskPriorityX.fromDb(map['priority'] as String),
        dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
        status: TaskStatusX.fromDb(map['status'] as String),
        completedAt:
            map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String) : null,
        specialization: map['specialization'] as String?,
        torKey: map['tor_key'] as String?,
      );

  final String id;
  final String enterpriseId;
  final String consultantId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime? dueDate;
  final TaskStatus status;
  final DateTime? completedAt;

  /// 'Legal' / 'Accounting' / 'Marketing' — derived server-side from the
  /// assigned consultant's profile (see set_task_specialization trigger).
  /// Plain string, not the shared ConsultantSpecialization enum — this
  /// model doesn't otherwise depend on shared/models/user_profile.dart
  /// and a display label is all this needs.
  final String? specialization;

  /// Set for a Terms of Reference checklist item (task_template.dart);
  /// null for a custom task.
  final String? torKey;

  bool get isTor => torKey != null;
}