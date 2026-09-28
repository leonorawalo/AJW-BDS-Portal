import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/assessment_repository.dart';
import '../data/document_repository.dart';
import '../data/recommendation_repository.dart';
import '../data/task_comment_repository.dart';
import '../data/task_repository.dart';
import '../models/assessment.dart';
import '../models/document.dart';
import '../models/recommendation.dart';
import '../models/task.dart';
import '../models/task_comment.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.watch(supabaseClientProvider));
});
final taskCommentRepositoryProvider = Provider<TaskCommentRepository>((ref) {
  return TaskCommentRepository(ref.watch(supabaseClientProvider));
});
final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  return AssessmentRepository(ref.watch(supabaseClientProvider));
});
final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  return RecommendationRepository(ref.watch(supabaseClientProvider));
});
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(ref.watch(supabaseClientProvider));
});

final tasksProvider =
    FutureProvider.autoDispose.family<List<WorkstreamTask>, String>((ref, enterpriseId) {
  return ref.watch(taskRepositoryProvider).fetchTasks(enterpriseId);
});

/// Re-fetches whenever tasksProvider is invalidated (e.g. a status change),
/// so the dashboard stays live without extra invalidate calls.
final completedLoanReadinessTitlesProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, enterpriseId) async {
  await ref.watch(tasksProvider(enterpriseId).future);
  return ref.watch(taskRepositoryProvider).fetchCompletedLoanReadinessTitles(enterpriseId);
});

final taskProvider =
    FutureProvider.autoDispose.family<WorkstreamTask, String>((ref, taskId) {
  return ref.watch(taskRepositoryProvider).fetchTask(taskId);
});

final taskCommentsProvider =
    FutureProvider.autoDispose.family<List<TaskComment>, String>((ref, taskId) {
  return ref.watch(taskCommentRepositoryProvider).fetchComments(taskId);
});

final assessmentsProvider =
    FutureProvider.autoDispose.family<List<Assessment>, String>((ref, enterpriseId) {
  return ref.watch(assessmentRepositoryProvider).fetchAssessments(enterpriseId);
});

final recommendationsProvider =
    FutureProvider.autoDispose.family<List<Recommendation>, String>((ref, enterpriseId) {
  return ref.watch(recommendationRepositoryProvider).fetchRecommendations(enterpriseId);
});

final documentsProvider =
    FutureProvider.autoDispose.family<List<WorkstreamDocument>, String>((ref, enterpriseId) {
  return ref.watch(documentRepositoryProvider).fetchDocuments(enterpriseId);
});

final taskDocumentsProvider =
    FutureProvider.autoDispose.family<List<WorkstreamDocument>, String>((ref, taskId) {
  return ref.watch(documentRepositoryProvider).fetchDocumentsForTask(taskId);
});