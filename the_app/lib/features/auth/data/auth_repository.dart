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

  /// [roleName] must match a row in public.roles ('Administrator',
  /// 'Consultant', 'Enterprise Owner'). It's passed as sign-up metadata,
  /// which the `handle_new_user` Postgres trigger reads to populate
  /// public.users — see supabase/migrations/…_create_roles_and_users.sql.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String roleName,
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
  /// role_id / status / names live, and what the router needs to decide
  /// which home screen to redirect to.
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    final response = await _client
        .from('users')
        .select('*, roles(role_name)')
        .eq('id', userId)
        .maybeSingle();
    return response;
  }
}
