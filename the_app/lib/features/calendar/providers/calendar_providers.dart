import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/consultation_session_repository.dart';
import '../data/google_connection_repository.dart';
import '../models/consultation_session.dart';
import '../models/google_connection.dart';
import '../models/session_invitee.dart';
import '../models/session_person.dart';

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

/// Re-fetches with the sessions list, so names stay in step with it.
final sessionPeopleProvider =
    FutureProvider.autoDispose.family<List<SessionPerson>, String>((ref, enterpriseId) async {
  await ref.watch(consultationSessionsProvider(enterpriseId).future);
  return ref.watch(consultationSessionRepositoryProvider).fetchSessionPeople(enterpriseId);
});

final sessionInviteeCandidatesProvider =
    FutureProvider.autoDispose.family<List<SessionInvitee>, String>((ref, enterpriseId) {
  return ref.watch(consultationSessionRepositoryProvider).fetchInviteeCandidates(enterpriseId);
});
