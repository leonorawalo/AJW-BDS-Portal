import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/consultation_session_repository.dart';
import '../data/google_connection_repository.dart';
import '../models/consultation_session.dart';
import '../models/google_connection.dart';

final googleConnectionRepositoryProvider = Provider<GoogleConnectionRepository>((ref) {
  return GoogleConnectionRepository(ref.watch(supabaseClientProvider));
});

final consultationSessionRepositoryProvider = Provider<ConsultationSessionRepository>((ref) {
  return ConsultationSessionRepository(ref.watch(supabaseClientProvider));
});

final myGoogleConnectionProvider = FutureProvider.autoDispose<GoogleConnection?>((ref) {
  return ref.watch(googleConnectionRepositoryProvider).fetchMyConnection();
});

final consultationSessionsProvider =
    FutureProvider.autoDispose.family<List<ConsultationSession>, String>((ref, enterpriseId) {
  return ref.watch(consultationSessionRepositoryProvider).fetchSessions(enterpriseId);
});
