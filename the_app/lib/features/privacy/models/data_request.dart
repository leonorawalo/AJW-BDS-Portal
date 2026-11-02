/// A request under the Kenya Data Protection Act, 2019 (migration
/// 20261008150000). The database sets the deadline: access 7 days,
/// correction and deletion 14 days.
enum DataRequestKind { access, correction, deletion }

enum DataRequestStatus { open, inProgress, completed, rejected }

extension DataRequestKindX on DataRequestKind {
  String get dbValue => name;

  String get label => switch (this) {
        DataRequestKind.access => 'Access (a copy of my data)',
        DataRequestKind.correction => 'Correction',
        DataRequestKind.deletion => 'Deletion',
      };

  /// The person's button for making this request.
  String get actionLabel => switch (this) {
        DataRequestKind.access => 'Ask for a copy of my data',
        DataRequestKind.correction => 'Ask for a correction',
        DataRequestKind.deletion => 'Request deletion of my data',
      };
}

extension DataRequestStatusX on DataRequestStatus {
  static DataRequestStatus fromDb(String v) => switch (v) {
        'in_progress' => DataRequestStatus.inProgress,
        'completed' => DataRequestStatus.completed,
        'rejected' => DataRequestStatus.rejected,
        _ => DataRequestStatus.open,
      };

  String get dbValue => switch (this) {
        DataRequestStatus.open => 'open',
        DataRequestStatus.inProgress => 'in_progress',
        DataRequestStatus.completed => 'completed',
        DataRequestStatus.rejected => 'rejected',
      };

  String get label => switch (this) {
        // Stored as 'open'; people read it as "we have your request".
        DataRequestStatus.open => 'Received',
        DataRequestStatus.inProgress => 'In progress',
        DataRequestStatus.completed => 'Completed',
        DataRequestStatus.rejected => 'Rejected',
      };

  bool get isClosed => this == DataRequestStatus.completed || this == DataRequestStatus.rejected;
}

class DataRequest {
  const DataRequest({
    required this.id,
    required this.userId,
    required this.kind,
    required this.details,
    required this.status,
    required this.createdAt,
    required this.dueAt,
    this.resolvedAt,
    this.resolutionNote,
    this.requesterName,
  });

  factory DataRequest.fromMap(Map<String, dynamic> map) {
    final user = map['requester'] as Map<String, dynamic>?;
    return DataRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      kind: DataRequestKind.values.byName(map['kind'] as String),
      details: map['details'] as String? ?? '',
      status: DataRequestStatusX.fromDb(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      dueAt: DateTime.parse(map['due_at'] as String).toLocal(),
      resolvedAt: map['resolved_at'] != null ? DateTime.parse(map['resolved_at'] as String).toLocal() : null,
      resolutionNote: map['resolution_note'] as String?,
      requesterName: user == null ? null : '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
    );
  }

  final String id;
  final String userId;
  final DataRequestKind kind;
  final String details;
  final DataRequestStatus status;
  final DateTime createdAt;
  final DateTime dueAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;

  /// Filled for Admins' list.
  final String? requesterName;

  bool get isOverdue => !status.isClosed && DateTime.now().isAfter(dueAt);
}
