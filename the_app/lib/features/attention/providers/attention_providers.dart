import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/attention_repository.dart';
import '../models/attention_spots.dart';

final attentionRepositoryProvider = Provider<AttentionRepository>((ref) {
  return AttentionRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's red dots. Re-read after every [markSeen] (i.e. on
/// each navigation) and every few minutes while the app is open. A dot is
/// a nicety: if the call fails, show none rather than an error.
final attentionProvider = FutureProvider<AttentionSpots>((ref) async {
  // Start over on sign-in / sign-out.
  ref.watch(authStateChangesProvider);
  final timer = Timer(const Duration(minutes: 3), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  if (ref.read(supabaseClientProvider).auth.currentUser == null) return AttentionSpots.none;
  try {
    return await ref.read(attentionRepositoryProvider).fetch();
  } catch (e) {
    if (kDebugMode) debugPrint('Red dots unavailable: $e');
    return AttentionSpots.none;
  }
});

/// Records that the user opened a place, then refreshes the dots.
Future<void> markSeen(WidgetRef ref, {String? enterpriseId, required String section}) async {
  try {
    await ref.read(attentionRepositoryProvider).markSeen(enterpriseId: enterpriseId, section: section);
  } catch (e) {
    if (kDebugMode) debugPrint('mark_seen failed: $e');
    return;
  }
  ref.invalidate(attentionProvider);
}
