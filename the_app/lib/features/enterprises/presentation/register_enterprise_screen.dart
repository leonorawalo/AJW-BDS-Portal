import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/enterprise_providers.dart';

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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _businessNameController,
                      decoration: const InputDecoration(labelText: 'Business name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: const InputDecoration(labelText: 'Owner name'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone number (optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email (optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _countyController,
                      decoration: const InputDecoration(labelText: 'County (optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _industryController,
                      decoration: const InputDecoration(labelText: 'Industry (optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: const InputDecoration(labelText: 'Registration number (optional)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _kraPinController,
                      decoration: const InputDecoration(labelText: 'KRA PIN (optional)'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
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