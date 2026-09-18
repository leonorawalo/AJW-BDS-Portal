import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/assessment.dart';

class AssessmentRepository {
  AssessmentRepository(this._client);

  final SupabaseClient _client;

  Future<List<Assessment>> fetchAssessments(String enterpriseId) async {
    final rows = await _client
        .from('assessments')
        .select()
        .eq('enterprise_id', enterpriseId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Assessment.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> createAssessment({
    required String enterpriseId,
    required String consultantId,
    required String assessmentType,
    String? findings,
    double? complianceScore,
  }) async {
    await _client.from('assessments').insert({
      'enterprise_id': enterpriseId,
      'consultant_id': consultantId,
      'assessment_type': assessmentType,
      'findings': findings,
      'compliance_score': complianceScore,
    });
  }
}