import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/user_profile.dart';
import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// Raw Supabase auth events (signed in / signed out / token refreshed).
/// The router listens to this (via goRouterRefreshStreamProvider below) to
/// know when to re-evaluate redirects.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The signed-in user's profile row (name, role, status) — null when
/// signed out. This is what every role-based redirect and role-gated
/// widget should read, never the raw Supabase User.
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Re-run whenever auth state changes.
  ref.watch(authStateChangesProvider);

  final repo = ref.watch(authRepositoryProvider);
  final user = repo.currentUser;
  if (user == null) return null;

  final map = await repo.fetchUserProfile(user.id);
  if (map == null) return null;
  return UserProfile.fromMap(map);
});
