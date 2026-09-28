import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../calendar/providers/calendar_providers.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../../legal_workstream/models/loan_readiness.dart';
import '../../legal_workstream/providers/legal_workstream_providers.dart';
import '../data/google_export_repository.dart';
import '../data/portfolio_repository.dart';
import '../models/enterprise_export_data.dart';

final googleExportRepositoryProvider = Provider<GoogleExportRepository>((ref) {
  return GoogleExportRepository(ref.watch(supabaseClientProvider));
});

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository(ref.watch(supabaseClientProvider));
});

/// Gathers an enterprise export from the same providers the screens use,
/// so an export holds exactly what the user can see in the app.
final enterpriseExportDataProvider =
    FutureProvider.autoDispose.family<EnterpriseExportData, String>((ref, enterpriseId) async {
  final enterprise = await ref.watch(enterpriseDetailProvider(enterpriseId).future);
  if (enterprise == null) throw StateError('Enterprise not found');

  final (completedTitles, tasks, recommendations, sessions, people, profile) = await (
    ref.watch(completedLoanReadinessTitlesProvider(enterpriseId).future),
    ref.watch(tasksProvider(enterpriseId).future),
    ref.watch(recommendationsProvider(enterpriseId).future),
    ref.watch(consultationSessionsProvider(enterpriseId).future),
    ref.watch(sessionPeopleProvider(enterpriseId).future),
    ref.watch(currentUserProfileProvider.future),
  ).wait;

  return EnterpriseExportData(
    enterprise: enterprise,
    inputs: LoanReadinessInputs.from(enterprise: enterprise, completedTaskTitles: completedTitles),
    tasks: tasks,
    recommendations: recommendations,
    sessions: sessions,
    sessionPeople: people,
    exportedBy: profile == null ? 'AJW BAGS Portal' : '${profile.firstName} ${profile.lastName}',
    exportedAt: DateTime.now(),
  );
});
