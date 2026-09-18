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
/// registers a token on sign-in, moves it to the new token on refresh,
/// removes it on sign-out. Has no return value — it exists purely for
/// its side effects, so it must be kept alive by being watched once
/// near the root of the widget tree (app.dart). No-op on web — see
/// [foregroundMessagesProvider].
final notificationSyncProvider = Provider<void>((ref) {
  if (kIsWeb) return;

  final fcmService = ref.watch(fcmServiceProvider);
  final tokenRepo = ref.watch(deviceTokenRepositoryProvider);

  String? registeredToken;

  Future<void> registerForUser(String userId) async {
    await fcmService.requestPermission();
    final token = await fcmService.getToken();
    if (token == null) return;
    registeredToken = token;
    await tokenRepo.registerToken(userId: userId, token: token);
  }

  final refreshSubscription = fcmService.onTokenRefresh.listen((newToken) {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;
    registeredToken = newToken;
    tokenRepo.registerToken(userId: profile.id, token: newToken);
  });

  ref.listen<AsyncValue<UserProfile?>>(
    currentUserProfileProvider,
    (previous, next) {
      final profile = next.value;
      if (profile != null) {
        registerForUser(profile.id);
      } else if (previous?.value != null && registeredToken != null) {
        tokenRepo.deleteToken(registeredToken!);
        registeredToken = null;
      }
    },
    fireImmediately: true,
  );

  ref.onDispose(refreshSubscription.cancel);
});
