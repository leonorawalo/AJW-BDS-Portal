enum RecommendationStatus { open, actioned, dismissed }

extension RecommendationStatusX on RecommendationStatus {
  static RecommendationStatus fromDb(String v) => switch (v) {
        'Actioned' => RecommendationStatus.actioned,
        'Dismissed' => RecommendationStatus.dismissed,
        _ => RecommendationStatus.open,
      };
  String get dbValue => switch (this) {
        RecommendationStatus.open => 'Open',
        RecommendationStatus.actioned => 'Actioned',
        RecommendationStatus.dismissed => 'Dismissed',
      };
}

class Recommendation {
  const Recommendation({
    required this.id,
    required this.enterpriseId,
    required this.consultantId,
    required this.recommendationText,
    required this.status,
    required this.createdAt,
  });

  factory Recommendation.fromMap(Map<String, dynamic> map) => Recommendation(
        id: map['id'] as String,
        enterpriseId: map['enterprise_id'] as String,
        consultantId: map['consultant_id'] as String,
        recommendationText: map['recommendation'] as String,
        status: RecommendationStatusX.fromDb(map['status'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  final String id;
  final String enterpriseId;
  final String consultantId;
  final String recommendationText;
  final RecommendationStatus status;
  final DateTime createdAt;
}