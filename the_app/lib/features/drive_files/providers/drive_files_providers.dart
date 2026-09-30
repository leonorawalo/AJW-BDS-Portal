import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/enterprise_file_repository.dart';
import '../models/enterprise_file.dart';

final enterpriseFileRepositoryProvider = Provider<EnterpriseFileRepository>((ref) {
  return EnterpriseFileRepository(ref.watch(supabaseClientProvider));
});

final enterpriseFilesProvider =
    FutureProvider.autoDispose.family<List<EnterpriseFile>, String>((ref, enterpriseId) {
  return ref.watch(enterpriseFileRepositoryProvider).fetchFiles(enterpriseId);
});
