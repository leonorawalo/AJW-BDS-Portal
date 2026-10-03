import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/enterprise_providers.dart';
import '../../user_management/models/invite_request.dart';
import '../../user_management/presentation/invite_flow.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_layout.dart' show AuthErrorBanner;

class RegisterEnterpriseScreen extends ConsumerStatefulWidget {
  const RegisterEnterpriseScreen({super.key});

  @override
  ConsumerState<RegisterEnterpriseScreen> createState() => _RegisterEnterpriseScreenState();
}

class _RegisterEnterpriseScreenState extends ConsumerState<RegisterEnterpriseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _countyController = TextEditingController();
  final _industryController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _kraPinController = TextEditingController();
  bool _inviteOwner = true;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _countyController.dispose();
    _industryController.dispose();
    _registrationNumberController.dispose();
    _kraPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final enterprise = await ref.read(enterpriseRepositoryProvider).create(
            businessName: _businessNameController.text.trim(),
            ownerName: _ownerNameController.text.trim(),
            phoneNumber: _emptyToNull(_phoneController.text),
            email: _emptyToNull(_emailController.text),
            county: _emptyToNull(_countyController.text),
            industry: _emptyToNull(_industryController.text),
            registrationNumber: _emptyToNull(_registrationNumberController.text),
            kraPin: _emptyToNull(_kraPinController.text),
          );

      // Refresh the list so the new enterprise shows up immediately when
      // we navigate back to it.
      ref.invalidate(enterprisesListProvider);

      final email = _emptyToNull(_emailController.text);
      if (_inviteOwner && email != null && mounted) {
        await runInvite(
          context,
          ref,
          InviteRequest.forOwner(
            email: email,
            ownerName: enterprise.ownerName,
            enterpriseId: enterprise.id,
            phoneNumber: enterprise.phoneNumber,
          ),
        );
      }

      if (mounted) {
        context.go('/admin/enterprises/${enterprise.id}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not register enterprise. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register enterprise'),
        leading: BackButton(onPressed: () => context.go('/admin')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      AuthErrorBanner(_errorMessage!),
                      const SizedBox(height: Space.lg),
                    ],
                    const _Group('The business'),
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(labelText: 'Business name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: Space.xl),
                    const _Group('The owner'),
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: const InputDecoration(labelText: 'Owner name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone number (optional)'),
                    ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "Owner's email (optional)"),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_emailController.text.trim().isNotEmpty)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _inviteOwner,
                        onChanged: (v) => setState(() => _inviteOwner = v ?? true),
                        title: const Text('Invite the owner to the portal'),
                        subtitle: const Text(
                          'Emails them a link to set a password; their account is linked to this enterprise.',
                        ),
                      ),
                    const SizedBox(height: Space.xl),
                    const _Group('Location and registration (optional)'),
                    TextFormField(
                      controller: _countyController,
                      decoration: const InputDecoration(labelText: 'County (optional)'),
                    ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _industryController,
                      decoration: const InputDecoration(labelText: 'Industry (optional)'),
                    ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: const InputDecoration(labelText: 'Registration number (optional)'),
                    ),
                    const SizedBox(height: Space.lg),
                    TextFormField(
                      controller: _kraPinController,
                      decoration: const InputDecoration(labelText: 'KRA PIN (optional)'),
                    ),
                    const SizedBox(height: Space.xxl),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const AjwLoader(dotSize: 6)
                          : const Text('Register enterprise'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/// A small heading over a group of fields.
class _Group extends StatelessWidget {
  const _Group(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
