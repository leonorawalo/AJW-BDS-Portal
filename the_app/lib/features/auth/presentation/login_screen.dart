import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../providers/auth_providers.dart';
import 'auth_layout.dart';
import 'password_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authErrorSub;

  @override
  void initState() {
    super.initState();
    // A failed Google sign-in comes back as a redirect carrying the error,
    // not as an exception from signInWithGoogle(). On Android it arrives on
    // the auth stream; on web the page reloads with it in the URL.
    _authErrorSub = ref
        .read(authRepositoryProvider)
        .authStateChanges
        .listen(
          (_) {},
          onError: (Object e) {
            if (mounted) setState(() => _errorMessage = _googleErrorMessage(e.toString()));
          },
        );
    final urlError = Uri.base.queryParameters['error_description'];
    if (urlError != null) _errorMessage = _googleErrorMessage(urlError);
  }

  /// The handle_new_user trigger rejects Google sign-ins with no matching
  /// account, which Supabase reports as a generic database error.
  static String _googleErrorMessage(String raw) {
    if (raw.contains('Database error saving new user')) {
      return 'No AJW account uses that Google email. Sign in with your email '
          'and password, or ask an administrator for an account.';
    }
    return 'Google sign-in failed. Please try again.';
  }

  @override
  void dispose() {
    _authErrorSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _errorMessage = null);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // Browser opens; the session (or an error) comes back via the
      // auth stream, and routerProvider's redirect takes it from there.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t open Google sign-in. Check your connection and try again.')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _emailController.text.trim(), password: _passwordController.text);
      // No manual navigation here: routerProvider's redirect picks up
      // the auth state change and sends the user to their role home.
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      playIntro: true,
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeading(title: 'Welcome back', subtitle: 'Sign in to your BAGS workspace.'),
              const SizedBox(height: Space.xxl),
              if (_errorMessage != null) ...[AuthErrorBanner(_errorMessage!), const SizedBox(height: Space.lg)],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (value) {
                  if (value == null || !value.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: Space.lg),
              PasswordField(
                controller: _passwordController,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isSubmitting ? null : _submit(),
                validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: Space.sm),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting ? const AjwLoader(dotSize: 7) : const Text('Sign in'),
              ),
              const SizedBox(height: Space.lg),
              const _OrDivider(),
              const SizedBox(height: Space.lg),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _signInWithGoogle,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: Space.xl),
              Text(
                'New to the portal? Your AJW administrator will send you an invite.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Text('or', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.charcoalSoft)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
