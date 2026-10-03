/// One logged visit to an enterprise (Terms of Reference: visit every
/// business twice a month, log each visit within 2 days). See migration
/// 20261003110000_enterprise_visits.sql.
class EnterpriseVisit {
  const EnterpriseVisit({
    required this.id,
    required this.enterpriseId,
    required this.consultantId,
    required this.visitedOn,
    required this.mode,
    required this.outcome,
    required this.loggedAt,
    required this.loggedLate,
    this.nextSteps,
    this.specialization,
    this.consultantName,
  });

  factory EnterpriseVisit.fromMap(Map<String, dynamic> map) {
    final user = map['users'] as Map<String, dynamic>?;
    return EnterpriseVisit(
      id: map['id'] as String,
      enterpriseId: map['enterprise_id'] as String,
      consultantId: map['consultant_id'] as String,
      visitedOn: DateTime.parse(map['visited_on'] as String),
      mode: map['mode'] as String,
      outcome: map['outcome'] as String,
      nextSteps: map['next_steps'] as String?,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      loggedLate: map['logged_late'] as bool? ?? false,
      specialization: map['specialization'] as String?,
      consultantName: user == null ? null : '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
    );
  }

  final String id;
  final String enterpriseId;
  final String consultantId;
  final DateTime visitedOn;

  /// 'In person' or 'Phone or online'.
  final String mode;
  final String outcome;
  final String? nextSteps;
  final DateTime loggedAt;

  /// Logged more than 2 days after the visit (computed by the database).
  final bool loggedLate;
  final String? specialization;
  final String? consultantName;
}

/// The ToR's visit rule, in one place.
class VisitRules {
  VisitRules._();
  static const perMonth = 2;
  static const logWithinDays = 2;
}
