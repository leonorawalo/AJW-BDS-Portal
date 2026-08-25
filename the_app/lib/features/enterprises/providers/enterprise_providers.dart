import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/enterprise_repository.dart';
import '../models/enterprise.dart';

final enterpriseRepositoryProvider = Provider<EnterpriseRepository>((ref) {
  return EnterpriseRepository(ref.watch(supabaseClientProvider));
});

/// Admin's full enterprise list. RLS scopes what actually comes back —
/// an Owner hitting this same provider would only ever get their own
/// enterprise, even though the query itself asks for everything.
final enterprisesListProvider = FutureProvider.autoDispose<List<Enterprise>>((ref) {
  return ref.watch(enterpriseRepositoryProvider).fetchAll();
});

final enterpriseDetailProvider =
    FutureProvider.autoDispose.family<Enterprise?, String>((ref, enterpriseId) {
  return ref.watch(enterpriseRepositoryProvider).fetchById(enterpriseId);
});