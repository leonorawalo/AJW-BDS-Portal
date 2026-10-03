import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/workshop_repository.dart';
import '../models/workshop.dart';

final workshopRepositoryProvider = Provider<WorkshopRepository>((ref) {
  return WorkshopRepository(ref.watch(supabaseClientProvider));
});

final workshopsProvider = FutureProvider.autoDispose<List<Workshop>>((ref) {
  return ref.watch(workshopRepositoryProvider).fetchAll();
});

final workshopProvider = FutureProvider.autoDispose.family<Workshop?, String>((ref, id) {
  return ref.watch(workshopRepositoryProvider).fetchOne(id);
});

final workshopAttendeesProvider = FutureProvider.autoDispose.family<List<WorkshopAttendee>, String>((ref, id) {
  return ref.watch(workshopRepositoryProvider).fetchAttendees(id);
});
