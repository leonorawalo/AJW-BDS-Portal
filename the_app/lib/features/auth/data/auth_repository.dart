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

  /// [roleName] must match a row in public.roles ('Administrator',
  /// 'Consultant', 'Enterprise Owner'). [specialization] is only
  /// meaningful when roleName is 'Consultant' — 'Legal', 'Accounting',
  /// or 'Marketing', per the ToR's "Trio" model. Both are passed as
  /// sign-up metadata, which the `handle_new_user` Postgres trigger
  /// reads to populate public.users.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String roleName,
    String? specialization,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
        'role_name': roleName,
        'specialization': ?specialization,
      },
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() {
    return _client.auth.signOut();
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