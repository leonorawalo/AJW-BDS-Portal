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
    final token = widget.tokenHash;
    // Skip if a session already exists (e.g. the page was reloaded after
    // the token was used: tokens are single-use).
    if (token != null && ref.read(authRepositoryProvider).currentUser == null) {
      _verify(token);
    }
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
    } on AuthException {
      if (mounted) {
        setState(() => _error = _isRecovery
            ? 'This reset link has expired or was already used. Request a new one from the sign-in page.'
            : 'This invite link has expired or was already used. '
                'Ask your AJW administrator to send a new one.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the invite. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
    final signedIn = ref.watch(authRepositoryProvider).currentUser != null;

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
          else if (signedIn)
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
              'Open the invite link from your email to continue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }
}
