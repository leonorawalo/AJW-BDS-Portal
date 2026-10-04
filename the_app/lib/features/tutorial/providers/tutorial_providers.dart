import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/tour_progress_repository.dart';

final tourProgressRepositoryProvider = Provider<TourProgressRepository>((ref) {
  return TourProgressRepository(ref.watch(supabaseClientProvider));
});
