import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_providers.dart';

/// First sign-in for an invited user (Phase 9a). Reached two ways:
/// - from the invite email / an Admin-shared link:
///   /set-password?token_hash=…&type=invite|magiclink — the token is
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
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final token = widget.tokenHash;
    // Skip if a session already exists (e.g. the page was reloaded after
    // the token was used — tokens are single-use).
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
        setState(() => _error = 'This invite link has expired or was already used. '
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset('assets/images/ajw_logo.webp', height: 64, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 16),
                  Text('Welcome to the AJW BAGS Portal', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Choose a password to finish setting up your account.'),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_verifying)
                    const Center(child: CircularProgressIndicator())
                  else if (signedIn)
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'New password'),
                            validator: (v) =>
                                v == null || v.length < 8 ? 'Use at least 8 characters' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Confirm password'),
                            validator: (v) =>
                                v != _passwordController.text ? 'Passwords do not match' : null,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save password'),
                          ),
                        ],
                      ),
                    )
                  else if (_error == null)
                    const Text('Open the invite link from your email to continue.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
