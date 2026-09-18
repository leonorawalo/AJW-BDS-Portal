class Assessment {
  const Assessment({
    required this.id,
    required this.enterpriseId,
    required this.consultantId,
    required this.assessmentType,
    this.findings,
    this.complianceScore,
    required this.createdAt,
  });

  factory Assessment.fromMap(Map<String, dynamic> map) => Assessment(
        id: map['id'] as String,
        enterpriseId: map['enterprise_id'] as String,
        consultantId: map['consultant_id'] as String,
        assessmentType: map['assessment_type'] as String,
        findings: map['findings'] as String?,
        complianceScore: (map['compliance_score'] as num?)?.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  final String id;
  final String enterpriseId;
  final String consultantId;
  final String assessmentType;
  final String? findings;
  final double? complianceScore;
  final DateTime createdAt;
}
