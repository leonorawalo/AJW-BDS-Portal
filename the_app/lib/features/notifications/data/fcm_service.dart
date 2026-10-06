import 'package:firebase_messaging/firebase_messaging.dart';

/// Thin wrapper around FirebaseMessaging: same "keep every raw SDK call
/// in one place" pattern as AuthRepository wraps Supabase Auth.
class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Android 13+ requires this to be requested explicitly before a
  /// notification tray entry will actually show. No-op / auto-granted
  /// on older Android and other platforms.
  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  /// Null if permission hasn't been granted, or (rarely) the platform
  /// couldn't produce one yet.
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  /// Fires when the platform rotates the token (app reinstall, token
  /// expiry, etc.): device_tokens must be kept in sync or pushes to
  /// the stale token silently fail.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Messages that arrive while the app is in the foreground don't show
  /// a system tray notification on their own: the caller decides how
  /// to surface them (e.g. a SnackBar).
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;
}
