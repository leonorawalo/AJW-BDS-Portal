import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../enterprises/models/enterprise.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../../legal_workstream/models/task_template.dart';
import '../../legal_workstream/providers/legal_workstream_providers.dart';
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
  String? _selectedEnterpriseId;
  String? _errorMessage;

  // One independent selection/submitting-state pair per specialization —
  // the ToR "Trio" model means up to three assignments can happen in one
  // visit to this screen, each unrelated to the others.
  final Map<ConsultantSpecialization, String?> _selectedConsultantId = {
    for (final s in ConsultantSpecialization.values) s: null,
  };
  final Map<ConsultantSpecialization, bool> _isSubmitting = {
    for (final s in ConsultantSpecialization.values) s: false,
  };

  @override
  void initState() {
    super.initState();
    _selectedEnterpriseId = widget.preselectedEnterpriseId;
  }

  Future<void> _assign(ConsultantSpecialization specialization) async {
    final consultantId = _selectedConsultantId[specialization];
    final enterpriseId = _selectedEnterpriseId;
    if (consultantId == null || enterpriseId == null) return;

    setState(() {
      _isSubmitting[specialization] = true;
      _errorMessage = null;
    });

    try {
      final currentUserId = ref.read(authRepositoryProvider).currentUser!.id;
      await ref.read(consultantAssignmentRepositoryProvider).assign(
            consultantId: consultantId,
            enterpriseId: enterpriseId,
            assignedByUserId: currentUserId,
          );

      // The assignment itself has now succeeded. Everything below is a
      // best-effort side effect (auto-applying that specialization's
      // standard checklist) and must never be allowed to make a
      // successful assignment read back as a failure — this is
      // deliberately isolated in its own try/catch rather than sharing
      // the outer one.
      final checklist = switch (specialization) {
        ConsultantSpecialization.legal => standardLegalChecklist,
        ConsultantSpecialization.accounting => standardAccountingChecklist,
        ConsultantSpecialization.marketing => null,
      };
      if (checklist != null) {
        try {
          final existingTasks = await ref.read(taskRepositoryProvider).fetchTasks(enterpriseId);
          // Scoped to THIS specialization's tasks — Legal's checklist
          // already being applied must never block Accounting's from
          // auto-applying too (and vice versa).
          final alreadyApplied = existingTasks.any((t) => t.specialization == specialization.dbValue);
          if (!alreadyApplied) {
            await ref.read(taskRepositoryProvider).applyChecklist(
                  enterpriseId: enterpriseId,
                  consultantId: consultantId,
                  checklist: checklist,
                );
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Auto-applying the standard checklist failed: $e');
        }
      }

      ref.invalidate(assignmentsListProvider);
      ref.invalidate(enterprisesListProvider);
      ref.invalidate(activeAssignmentsForEnterpriseProvider(enterpriseId));

      if (mounted) {
        setState(() => _selectedConsultantId[specialization] = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${specialization.label} consultant assigned.')),
        );
      }
    } catch (e) {
      setState(
        () => _errorMessage = 'Could not assign the ${specialization.label} consultant. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting[specialization] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consultantsAsync = ref.watch(consultantsListProvider);
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign consultants'),
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
                      error: (_, _) => const Text('Could not load enterprise name.'),
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
                      error: (_, _) => const Text('Could not load enterprises.'),
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
                  const SizedBox(height: 24),

                  consultantsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Could not load consultants.'),
                    data: (consultants) {
                      if (consultants.isEmpty) {
                        return const Text(
                          'No Consultant accounts exist yet. Register one before assigning.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final specialization in ConsultantSpecialization.values) ...[
                            _SpecializationAssignmentCard(
                              specialization: specialization,
                              enterpriseId: _selectedEnterpriseId,
                              consultants: consultants
                                  .where(
                                    (c) =>
                                        consultantSpecializationFromDb(c['specialization'] as String?) ==
                                        specialization,
                                  )
                                  .toList(),
                              selectedConsultantId: _selectedConsultantId[specialization],
                              isSubmitting: _isSubmitting[specialization] ?? false,
                              enabled: _selectedEnterpriseId != null,
                              onChanged: (id) => setState(() => _selectedConsultantId[specialization] = id),
                              onAssign: () => _assign(specialization),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
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

/// One specialization's slot: who's currently assigned (if anyone), and
/// a picker scoped to just that specialization's consultants — so
/// picking a Legal consultant never means scrolling past Accounting and
/// Marketing names first.
class _SpecializationAssignmentCard extends ConsumerWidget {
  const _SpecializationAssignmentCard({
    required this.specialization,
    required this.consultants,
    required this.selectedConsultantId,
    required this.isSubmitting,
    required this.enabled,
    required this.onChanged,
    required this.onAssign,
    this.enterpriseId,
  });

  final ConsultantSpecialization specialization;
  final List<Map<String, dynamic>> consultants;
  final String? selectedConsultantId;
  final bool isSubmitting;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAssign;

  /// When set, shows who's currently filling this specialization slot.
  final String? enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentlyAssignedName = enterpriseId == null
        ? null
        : ref.watch(activeAssignmentsForEnterpriseProvider(enterpriseId!)).value?.where(
              (a) => a.specialization == specialization,
            );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${specialization.label} consultant', style: Theme.of(context).textTheme.titleSmall),
            if (currentlyAssignedName != null)
              Text(
                currentlyAssignedName.isEmpty
                    ? 'Currently: Unassigned'
                    : 'Currently: ${currentlyAssignedName.first.consultantName ?? 'Unassigned'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            if (consultants.isEmpty)
              Text(
                'No ${specialization.label} consultants registered yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedConsultantId,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      isExpanded: true,
                      items: consultants
                          .map((c) => DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(
                                  '${c['first_name']} ${c['last_name']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: enabled ? onChanged : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (enabled && selectedConsultantId != null && !isSubmitting) ? onAssign : null,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Assign'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
