import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../../visits/providers/visit_providers.dart';
import '../data/portfolio_repository.dart';
import '../models/portfolio_kpis.dart';

final programmeDataRepositoryProvider = Provider<PortfolioRepository>((ref) {
  return PortfolioRepository(ref.watch(supabaseClientProvider));
});

/// The ToR measures for whatever the signed-in user can see: a
/// consultant's portfolio in their discipline, or (Admin) the whole
/// programme across all three.
final portfolioKpisProvider = FutureProvider.autoDispose<PortfolioKpis>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  final enterprises = await ref.watch(enterprisesListProvider.future);
  final now = DateTime.now();
  final results = await Future.wait([
    ref.watch(programmeDataRepositoryProvider).fetchTorTaskStatuses(),
    ref.watch(visitRepositoryProvider).fetchSince(DateTime(now.year, now.month)),
  ]);
  final torTasks = results[0] as List<TorTaskStatus>;
  var visits = results[1] as List;

  final List<ConsultantSpecialization> disciplines;
  if (profile?.role == UserRole.consultant) {
    disciplines = [if (profile!.specialization != null) profile.specialization!];
    // A consultant's measures are their own visits.
    visits = visits.where((v) => v.consultantId == profile.id).toList();
  } else {
    disciplines = ConsultantSpecialization.values;
  }
  return PortfolioKpis(
    enterprises: enterprises,
    torTasks: torTasks,
    monthVisits: visits.cast(),
    disciplines: disciplines,
    now: now,
  );
});
