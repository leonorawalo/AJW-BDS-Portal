import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/success_story.dart';

/// Success stories for the monthly report. RLS: Admins see all; a
/// consultant sees their assigned enterprises' stories.
class SuccessStoryRepository {
  SuccessStoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<SuccessStory>> fetchForMonth(DateTime month) async {
    final first = '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
    final rows = await _client
        .from('success_stories')
        .select()
        .eq('report_month', first)
        .order('created_at');
    return (rows as List).map((r) => SuccessStory.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> save(SuccessStory story) async {
    if (story.id == null) {
      await _client.from('success_stories').insert(story.toInsert());
    } else {
      await _client.from('success_stories').update(story.toInsert()).eq('id', story.id!);
    }
  }

  Future<void> delete(String id) => _client.from('success_stories').delete().eq('id', id);
}
