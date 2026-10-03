import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/visit_repository.dart';
import '../models/enterprise_visit.dart';

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  return VisitRepository(ref.watch(supabaseClientProvider));
});

final enterpriseVisitsProvider =
    FutureProvider.autoDispose.family<List<EnterpriseVisit>, String>((ref, enterpriseId) {
  return ref.watch(visitRepositoryProvider).fetchForEnterprise(enterpriseId);
});
