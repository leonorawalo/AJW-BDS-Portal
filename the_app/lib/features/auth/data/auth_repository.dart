import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth. Keeps every raw Supabase call in one
/// place so the rest of the app never touches `Supabase.instance` directly.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign-in only — no Calendar scope, and no Google token is kept.
  /// Calendar access is a separate, per-consultant connection made through
  /// the google-oauth Edge Function (Sessions tab).
  ///
  /// Only works for an existing account: Supabase links the Google
  /// identity to the account with the same (confirmed) email, and the
  /// handle_new_user trigger refuses to create a brand-new user from a
  /// Google sign-in, since there'd be no way to pick a role.
  ///
  /// Opens the browser and returns immediately; the session arrives later
  /// via [authStateChanges] (deep link on Android, page reload on web).
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : 'ajwbags://login-callback',
    );
  }

  /// Exchanges the one-time token from an invite (or an Admin-shared
  /// set-password link) for a session. The links point at the app's own
  /// /set-password page rather than Supabase's default redirect, because
  /// this app uses the PKCE flow, which can't pick up a session from that
  /// redirect. See supabase/functions/invite-user.
  Future<void> verifyInviteToken({required String tokenHash, required String type}) {
    return _client.auth.verifyOTP(
      tokenHash: tokenHash,
      type: type == 'magiclink' ? OtpType.magiclink : OtpType.invite,
    );
  }

  /// Invited users carry needs_password in their metadata until they've
  /// chosen a password; the router keeps them on /set-password until then.
  bool get needsPassword => _client.auth.currentUser?.userMetadata?['needs_password'] == true;

  /// Set once the user has answered the first-run "Connect your Google
  /// suite" prompt (Connect or Later), so it's only ever shown once.
  bool get googlePromptDone => _client.auth.currentUser?.userMetadata?['google_prompt_done'] == true;

  Future<void> markGooglePromptDone() async {
    await _client.auth.updateUser(UserAttributes(data: {'google_prompt_done': true}));
  }

  /// The Google account this user signs in with ("Continue with Google"),
  /// or null if they never have.
  String? get googleSignInEmail {
    final identities = _client.auth.currentUser?.identities ?? const <UserIdentity>[];
    for (final identity in identities) {
      if (identity.provider == 'google') return identity.identityData?['email'] as String?;
    }
    return null;
  }

  /// The connected Google email the user chose to keep even though it
  /// differs from the one they sign in with.
  String? get keptGoogleConnectionEmail =>
      _client.auth.currentUser?.userMetadata?['google_connection_kept'] as String?;

  Future<void> keepGoogleConnection(String connectedEmail) async {
    await _client.auth.updateUser(UserAttributes(data: {'google_connection_kept': connectedEmail}));
  }

  Future<void> setPassword(String password) {
    return _client.auth.updateUser(
      UserAttributes(password: password, data: {'needs_password': false}),
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  final _beforeSignOut = <Future<void> Function()>[];

  /// Work that must happen while the session still exists, e.g. releasing
  /// this device's push token (RLS needs the user's JWT to delete it).
  void addBeforeSignOut(Future<void> Function() hook) => _beforeSignOut.add(hook);
  void removeBeforeSignOut(Future<void> Function() hook) => _beforeSignOut.remove(hook);

  Future<void> signOut() async {
    for (final hook in List.of(_beforeSignOut)) {
      // Best effort: an offline device must still be able to sign out.
      // (If the release fails, the next sign-in's claim fixes ownership.)
      try {
        await hook().timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await _client.auth.signOut();
  }

  /// Fetches the row from public.users (not auth.users) — this is where
  /// role_id / status / names / specialization live, and what the
  /// router needs to decide which home screen to redirect to.
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    final response = await _client
        .from('users')
        .select('*, roles(role_name)')
        .eq('id', userId)
        .maybeSingle();
    return response;
  }
}