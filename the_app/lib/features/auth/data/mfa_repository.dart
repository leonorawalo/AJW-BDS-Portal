import 'package:supabase_flutter/supabase_flutter.dart';

/// Two-step verification (multi-factor authentication, MFA) with an
/// authenticator app (time-based one-time password, TOTP), through
/// Supabase Auth.
class MfaRepository {
  MfaRepository(this._client);

  final SupabaseClient _client;

  GoTrueMFAApi get _mfa => _client.auth.mfa;

  /// Whether this session still has to enter a code (the account has a
  /// verified factor but this sign-in hasn't used it yet).
  bool get needsCode {
    final aal = _mfa.getAuthenticatorAssuranceLevel();
    return aal.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
        aal.nextLevel == AuthenticatorAssuranceLevels.aal2;
  }

  Future<List<Factor>> verifiedFactors() async => (await _mfa.listFactors()).totp;

  /// Starts setting up an authenticator app. Any half-finished earlier
  /// attempt is removed first (Supabase refuses a second unverified one).
  Future<AuthMFAEnrollResponse> startEnrolment() async {
    final user = _client.auth.currentUser;
    for (final f in user?.factors ?? const <Factor>[]) {
      if (f.status == FactorStatus.unverified) await _mfa.unenroll(f.id);
    }
    return _mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'AJW BAGS Portal',
      friendlyName: 'Authenticator app ${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Checks a 6-digit code; on success the session is upgraded.
  Future<void> verify(String factorId, String code) async {
    await _mfa.challengeAndVerify(factorId: factorId, code: code.trim());
    await _client.auth.refreshSession();
  }
}
