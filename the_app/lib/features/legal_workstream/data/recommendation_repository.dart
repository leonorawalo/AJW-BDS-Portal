import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recommendation.dart';

class RecommendationRepository {
  RecommendationRepository(this._client);

  final SupabaseClient _client;

  Future<List<Recommendation>> fetchRecommendations(String enterpriseId) async {
    final rows = await _client
        .from('recommendations')
        .select()
        .eq('enterprise_id', enterpriseId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Recommendation.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> createRecommendation({
    required String enterpriseId,
    required String consultantId,
    required String recommendationText,
  }) async {
    await _client.from('recommendations').insert({
      'enterprise_id': enterpriseId,
      'consultant_id': consultantId,
      'recommendation': recommendationText,
    });
  }

  Future<void> updateStatus(String id, RecommendationStatus status) async {
    await _client.from('recommendations').update({'status': status.dbValue}).eq('id', id);
  }
}