import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../providers/auth_providers.dart';
import 'auth_layout.dart';
import 'password_field.dart';

/// First sign-in for an invited user (Phase 9a). Reached two ways:
/// - from the invite email / an Admin-shared link:
///   /set-password?token_hash=…&type=invite|magiclink: the token is
///   exchanged for a session here, then the user picks a password;
/// - by the router, for any signed-in user still flagged needs_password.
/// Once the password is saved the flag clears and the router sends them to
/// their role's home.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key, this.tokenHash, this.type});

  final String? tokenHash;
  final String? type;

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _verifying = false;

  /// Arrived from a "Forgot password" email rather than an invite.
  bool get _isRecovery => widget.type == 'recovery';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Always exchange the link's token, even if someone is signed in on
    // this device: the reset (or invite) must apply to the link's account.
    // The repository makes sure a token is exchanged only once.
    final token = widget.tokenHash;
    if (token != null) _verify(token);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _verify(String token) async {
    setState(() => _verifying = true);
    try {
      await ref.read(authRepositoryProvider).verifyInviteToken(tokenHash: token, type: widget.type ?? 'invite');
      // Drop the used token from the address, so a reload doesn't try it
      // again (the needs_password flag keeps the form available).
      if (mounted) context.go('/set-password?type=${widget.type ?? 'invite'}');
    } on AuthException catch (e) {
      final used = e.code == 'otp_expired' ||
          e.message.toLowerCase().contains('expired') ||
          e.message.toLowerCase().contains('invalid');
      if (mounted) {
        setState(() => _error = !used
            ? e.message
            : _isRecovery
                ? 'This reset link has expired or was already used. Only the newest reset email works: '
                    'request a new link below.'
                : 'This invite link has expired or was already used. '
                    'Ask your AJW administrator to send a new one.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the invite. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// The form is only offered for the account a link (or an invite) is
  /// for: after this screen's token exchange worked, or, with no token in
  /// the address (a reload, or the router holding an invited user here),
  /// when the signed-in account is flagged as needing a password. Never
  /// for whoever simply happens to be signed in.
  bool get _canSetPassword {
    final auth = ref.read(authRepositoryProvider);
    if (auth.currentUser == null) return false;
    final token = widget.tokenHash;
    return token != null ? auth.tokenExchanged(token) : auth.needsPassword;
  }

  Future<void> _requestNewLink() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/forgot-password');
  }

  Future<void> _save() async {
    if (!_canSetPassword || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).setPassword(_passwordController.text);
      // A reset link keeps the router on this page (see app_router); move on
      // to the role home now that the new password is saved.
      if (_isRecovery && mounted) context.go('/');
      // No navigation here: the router sees needs_password cleared and
      // sends the user to their role home.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save your password. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateChangesProvider);
    final canSetPassword = _canSetPassword;

    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(
            title: _isRecovery ? 'Choose a new password' : 'Welcome to BAGS',
            subtitle: _isRecovery
                ? 'Pick something you haven\'t used here before.'
                : 'Choose a password to finish setting up your account.',
          ),
          const SizedBox(height: Space.xxl),
          if (_error != null) ...[
            AuthErrorBanner(_error!),
            const SizedBox(height: Space.lg),
          ],
          if (_verifying)
            const AjwLoadingView()
          else if (canSetPassword)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    controller: _passwordController,
                    label: 'New password',
                    showRules: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: Space.lg),
                  PasswordField(
                    controller: _confirmController,
                    label: 'Confirm password',
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saving ? null : _save(),
                    validator: (v) => v != _passwordController.text ? "The two passwords don't match." : null,
                  ),
                  const SizedBox(height: Space.xl),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving ? const AjwLoader(dotSize: 7) : const Text('Save password'),
                  ),
                ],
              ),
            )
          else if (_error == null)
            Text(
              _isRecovery
                  ? 'Open the newest reset link from your email to continue.'
                  : 'Open the invite link from your email to continue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else if (_isRecovery)
            OutlinedButton(onPressed: _requestNewLink, child: const Text('Request a new reset link')),
        ],
      ),
    );
  }
}
