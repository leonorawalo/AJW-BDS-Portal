import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/device_token_repository.dart';
import '../data/fcm_service.dart';

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepository(ref.watch(supabaseClientProvider));
});

/// Messages that arrive while the app is open — a screen can watch this
/// to surface them (e.g. app.dart shows a SnackBar). Empty on web: no
/// Firebase Web app is registered yet, so FirebaseMessaging isn't
/// available there.
final foregroundMessagesProvider = StreamProvider<RemoteMessage>((ref) {
  if (kIsWeb) return const Stream.empty();
  return ref.watch(fcmServiceProvider).onForegroundMessage;
});

/// Keeps `device_tokens` in sync with who's signed in on this device:
/// claims the token for the user on sign-in (taking it over from any
/// previous user of the device), follows token refreshes, and releases it
/// just BEFORE sign-out while the session can still delete it. Has no
/// return value — it exists purely for its side effects, so it must be
/// kept alive by being watched once near the root of the widget tree
/// (app.dart). No-op on web — see [foregroundMessagesProvider].
final notificationSyncProvider = Provider<void>((ref) {
  if (kIsWeb) return;

  final fcmService = ref.watch(fcmServiceProvider);
  final tokenRepo = ref.watch(deviceTokenRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  String? registeredToken;

  Future<void> claimForCurrentUser() async {
    await fcmService.requestPermission();
    final token = await fcmService.getToken();
    if (token == null) return;
    registeredToken = token;
    await tokenRepo.claimToken(token);
  }

  Future<void> releaseBeforeSignOut() async {
    final token = registeredToken;
    if (token == null) return;
    await tokenRepo.releaseToken(token);
    registeredToken = null;
  }

  authRepo.addBeforeSignOut(releaseBeforeSignOut);

  final refreshSubscription = fcmService.onTokenRefresh.listen((newToken) {
    if (ref.read(currentUserProfileProvider).value == null) return;
    final oldToken = registeredToken;
    registeredToken = newToken;
    tokenRepo.claimToken(newToken);
    if (oldToken != null && oldToken != newToken) tokenRepo.releaseToken(oldToken);
  });

  ref.listen<AsyncValue<UserProfile?>>(
    currentUserProfileProvider,
    (previous, next) {
      if (next.value != null) claimForCurrentUser();
    },
    fireImmediately: true,
  );

  ref.onDispose(() {
    refreshSubscription.cancel();
    authRepo.removeBeforeSignOut(releaseBeforeSignOut);
  });
});
