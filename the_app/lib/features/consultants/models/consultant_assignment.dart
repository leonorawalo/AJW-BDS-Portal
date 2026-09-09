enum AssignmentStatus { active, ended }

extension AssignmentStatusX on AssignmentStatus {
  static AssignmentStatus fromDb(String value) {
    return value == 'ended' ? AssignmentStatus.ended : AssignmentStatus.active;
  }

  String get dbValue => this == AssignmentStatus.ended ? 'ended' : 'active';
}

class ConsultantAssignment {
  const ConsultantAssignment({
    required this.id,
    required this.consultantId,
    required this.enterpriseId,
    required this.assignedDate,
    required this.assignedBy,
    required this.status,
    this.consultantName,
    this.enterpriseName,
  });

  factory ConsultantAssignment.fromMap(Map<String, dynamic> map) {
    // consultant/enterprise are only present when the repository joins
    // them in (Admin's assignment list) — null otherwise.
    final consultant = map['consultant'] as Map<String, dynamic>?;
    final enterprise = map['enterprise'] as Map<String, dynamic>?;

    return ConsultantAssignment(
      id: map['id'] as String,
      consultantId: map['consultant_id'] as String,
      enterpriseId: map['enterprise_id'] as String,
      assignedDate: DateTime.parse(map['assigned_date'] as String),
      assignedBy: map['assigned_by'] as String,
      status: AssignmentStatusX.fromDb(map['assignment_status'] as String),
      consultantName:
          consultant != null ? '${consultant['first_name']} ${consultant['last_name']}' : null,
      enterpriseName: enterprise?['business_name'] as String?,
    );
  }

  final String id;
  final String consultantId;
  final String enterpriseId;
  final DateTime assignedDate;
  final String assignedBy;
  final AssignmentStatus status;
  final String? consultantName;
  final String? enterpriseName;
}