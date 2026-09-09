import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/consultant_assignment_repository.dart';
import '../models/consultant_assignment.dart';

final consultantAssignmentRepositoryProvider = Provider<ConsultantAssignmentRepository>((ref) {
  return ConsultantAssignmentRepository(ref.watch(supabaseClientProvider));
});

final consultantsListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(consultantAssignmentRepositoryProvider).fetchConsultants();
});

final assignmentsListProvider = FutureProvider.autoDispose<List<ConsultantAssignment>>((ref) {
  return ref.watch(consultantAssignmentRepositoryProvider).fetchAll();
});