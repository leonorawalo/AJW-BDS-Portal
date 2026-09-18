import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_comment.dart';

class TaskCommentRepository {
  TaskCommentRepository(this._client);

  final SupabaseClient _client;

  Future<List<TaskComment>> fetchComments(String taskId) async {
    final rows = await _client
        .from('task_comments')
        .select('*, author:author_id(first_name, last_name)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return (rows as List).map((r) => TaskComment.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> addComment({
    required String taskId,
    required String authorId,
    required String commentText,
  }) async {
    await _client.from('task_comments').insert({
      'task_id': taskId,
      'author_id': authorId,
      'comment_text': commentText,
    });
  }
}