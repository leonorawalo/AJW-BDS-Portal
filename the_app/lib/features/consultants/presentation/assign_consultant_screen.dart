import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import '../../enterprises/models/enterprise.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../providers/consultant_assignment_providers.dart';

class AssignConsultantScreen extends ConsumerStatefulWidget {
  const AssignConsultantScreen({super.key, this.preselectedEnterpriseId});

  /// When launched from an enterprise's detail screen, that enterprise
  /// is locked in rather than shown as an editable dropdown — assigning
  /// a consultant "to nothing in particular" isn't a real use case.
  final String? preselectedEnterpriseId;

  @override
  ConsumerState<AssignConsultantScreen> createState() => _AssignConsultantScreenState();
}

class _AssignConsultantScreenState extends ConsumerState<AssignConsultantScreen> {
  String? _selectedConsultantId;
  String? _selectedEnterpriseId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedEnterpriseId = widget.preselectedEnterpriseId;
  }

  Future<void> _submit() async {
    if (_selectedConsultantId == null || _selectedEnterpriseId == null) {
      setState(() => _errorMessage = 'Pick both a consultant and an enterprise.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = ref.read(authRepositoryProvider).currentUser!.id;
      await ref.read(consultantAssignmentRepositoryProvider).assign(
            consultantId: _selectedConsultantId!,
            enterpriseId: _selectedEnterpriseId!,
            assignedByUserId: currentUserId,
          );

      ref.invalidate(assignmentsListProvider);
      ref.invalidate(enterprisesListProvider);

      if (mounted) context.go('/admin');
    } catch (e) {
      setState(() => _errorMessage = 'Could not create the assignment. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consultantsAsync = ref.watch(consultantsListProvider);
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign consultant'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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

                  // Enterprise: locked text if preselected, dropdown otherwise.
                  if (widget.preselectedEnterpriseId != null)
                    enterprisesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load enterprise name.'),
                      data: (enterprises) {
                        final match = enterprises.firstWhere(
                          (e) => e.id == widget.preselectedEnterpriseId,
                          orElse: () => enterprises.first,
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enterprise'),
                          subtitle: Text(match.businessName),
                        );
                      },
                    )
                  else
                    enterprisesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load enterprises.'),
                      data: (enterprises) => DropdownButtonFormField<String>(
                        initialValue: _selectedEnterpriseId,
                        decoration: const InputDecoration(labelText: 'Enterprise'),
                        items: enterprises
                            .map((Enterprise e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.businessName),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedEnterpriseId = value),
                      ),
                    ),
                  const SizedBox(height: 16),

                  consultantsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Could not load consultants.'),
                    data: (consultants) {
                      if (consultants.isEmpty) {
                        return const Text(
                          'No Consultant accounts exist yet. Register one before assigning.',
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedConsultantId,
                        decoration: const InputDecoration(labelText: 'Consultant'),
                        items: consultants
                            .map((c) => DropdownMenuItem(
                                  value: c['id'] as String,
                                  child: Text('${c['first_name']} ${c['last_name']}'),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedConsultantId = value),
                      );
                    },
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
                        : const Text('Assign'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}