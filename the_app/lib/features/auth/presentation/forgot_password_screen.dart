import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../providers/auth_providers.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
          .sendPasswordResetEmail(_emailController.text.trim());
      setState(() => _emailSent = true);
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
      onBack: () => context.go('/login'),
      child: _emailSent ? _buildConfirmation(context) : _buildForm(context),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.brandRedTint,
            child: const Icon(Icons.mark_email_read_outlined, size: 30, color: AppColors.brandRed),
          ),
        ),
        const SizedBox(height: Space.xl),
        AuthHeading(
          title: 'Check your inbox',
          subtitle: 'We sent a reset link to ${_emailController.text.trim()}. It can take a minute to arrive.',
        ),
        const SizedBox(height: Space.xxl),
        FilledButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeading(
            title: 'Reset your password',
            subtitle: "Enter your email and we'll send you a link to choose a new one.",
          ),
          const SizedBox(height: Space.xxl),
          if (_errorMessage != null) ...[
            AuthErrorBanner(_errorMessage!),
            const SizedBox(height: Space.lg),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: Space.xl),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting ? const AjwLoader(dotSize: 7) : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }
}
