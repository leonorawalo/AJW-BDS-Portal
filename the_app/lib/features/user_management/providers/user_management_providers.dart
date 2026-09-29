import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/invite_repository.dart';
import '../data/user_admin_repository.dart';
import '../models/managed_user.dart';

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  return InviteRepository(ref.watch(supabaseClientProvider));
});

final userAdminRepositoryProvider = Provider<UserAdminRepository>((ref) {
  return UserAdminRepository(ref.watch(supabaseClientProvider));
});

final managedUsersProvider = FutureProvider.autoDispose<List<ManagedUser>>((ref) {
  return ref.watch(userAdminRepositoryProvider).fetchUsers();
});
