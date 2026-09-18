class TaskComment {
  const TaskComment({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.commentText,
    required this.createdAt,
    this.authorName,
  });

  factory TaskComment.fromMap(Map<String, dynamic> map) {
    final author = map['author'] as Map<String, dynamic>?;
    return TaskComment(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      authorId: map['author_id'] as String,
      commentText: map['comment_text'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      authorName: author != null ? '${author['first_name']} ${author['last_name']}' : null,
    );
  }

  final String id;
  final String taskId;
  final String authorId;
  final String commentText;
  final DateTime createdAt;
  final String? authorName;
}