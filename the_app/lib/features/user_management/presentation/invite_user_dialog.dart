import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/invite_request.dart';
import 'invite_flow.dart';

/// Admin: invite a Consultant (with specialization) or another
/// Administrator. Owners are invited from their enterprise instead, so
/// they're linked to it.
Future<void> showInviteUserDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _InviteUserDialog());
}

class _InviteUserDialog extends ConsumerStatefulWidget {
  const _InviteUserDialog();

  @override
  ConsumerState<_InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends ConsumerState<_InviteUserDialog> {
  static const _roles = ['Consultant', 'Administrator'];
  static const _specializations = ['Legal', 'Accounting', 'Marketing'];

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _role = 'Consultant';
  String? _specialization;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  InviteRequest? _request() {
    if (!_formKey.currentState!.validate()) return null;
    return InviteRequest(
      email: _emailController.text.trim(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      roleName: _role,
      specialization: _role == 'Consultant' ? _specialization : null,
      phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );
  }

  /// "an Administrator", "a Legal Consultant" — the same wording the invite
  /// email uses.
  static String _asWhat(InviteRequest r) {
    if (r.roleName == 'Consultant' && r.specialization != null) return 'a ${r.specialization} Consultant';
    return RegExp('^[AEIOU]').hasMatch(r.roleName) ? 'an ${r.roleName}' : 'a ${r.roleName}';
  }

  /// Last look before anything is sent, so a wrong role or specialization
  /// is caught here rather than fixed afterwards.
  Future<bool> _confirm(InviteRequest r, {required bool asLink}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(asLink ? 'Create an invite link?' : 'Send this invite?'),
        content: Text.rich(
          TextSpan(children: [
            TextSpan(text: asLink ? 'Create a set-password link for ' : 'Invite '),
            TextSpan(text: r.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: ' (${r.email}) as '),
            TextSpan(text: _asWhat(r), style: const TextStyle(fontWeight: FontWeight.w600)),
            const TextSpan(text: '?'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(asLink ? 'Create link' : 'Send'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _submit({required bool asLink}) async {
    final request = _request();
    if (request == null) return;
    if (!await _confirm(request, asLink: asLink) || !mounted) return;
    final done = asLink ? await shareInviteLink(context, ref, request) : await runInvite(context, ref, request);
    if (done && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    String? required(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;

    return AlertDialog(
      title: const Text('Invite a user'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 440),
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [for (final r in _roles) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (r) => setState(() => _role = r ?? _role),
              ),
              if (_role == 'Consultant') ...[
                const SizedBox(height: Space.lg),
                DropdownButtonFormField<String>(
                  initialValue: _specialization,
                  decoration: const InputDecoration(labelText: 'Specialization'),
                  items: [for (final s in _specializations) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (s) => setState(() => _specialization = s),
                  validator: (v) => v == null ? 'Pick a specialization' : null,
                ),
              ],
              const SizedBox(height: Space.xl),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: required,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last name'),
                validator: required,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional, for WhatsApp)'),
              ),
            ],
          ),
        ),
      ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => _submit(asLink: true), child: const Text('Get link instead')),
        FilledButton(onPressed: () => _submit(asLink: false), child: const Text('Send invite')),
      ],
    );
  }
}
