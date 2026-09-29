/// One row of public.audit_log (Phase 9c). Written only by database
/// triggers; Admins can read it.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.occurredAt,
    required this.action,
    required this.entityType,
    required this.summary,
    this.actorName,
    this.enterpriseName,
  });

  factory AuditEntry.fromMap(Map<String, dynamic> map) {
    final actor = map['actor'] as Map<String, dynamic>?;
    final enterprise = map['enterprise'] as Map<String, dynamic>?;
    return AuditEntry(
      id: map['id'] as int,
      occurredAt: DateTime.parse(map['occurred_at'] as String).toLocal(),
      action: map['action'] as String,
      entityType: map['entity_type'] as String,
      summary: map['summary'] as String,
      actorName: actor == null ? null : '${actor['first_name']} ${actor['last_name']}'.trim(),
      enterpriseName: enterprise?['business_name'] as String?,
    );
  }

  final int id;
  final DateTime occurredAt;

  /// e.g. 'task.status_changed', 'user.suspended'.
  final String action;

  /// 'user' | 'enterprise' | 'assignment' | 'task' | 'document' | 'session'
  final String entityType;
  final String summary;

  /// Null for server-side changes (e.g. an invite created by the
  /// invite-user function), shown as "System".
  final String? actorName;
  final String? enterpriseName;
}
