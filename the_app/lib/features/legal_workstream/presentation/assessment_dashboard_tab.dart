import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../enterprises/models/enterprise.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../models/loan_readiness.dart';
import '../providers/legal_workstream_providers.dart';

/// Loan-readiness dashboard — computed live from ToR task completion
/// (standardLegalChecklist / standardAccountingChecklist) plus the
/// handful of enterprise facts nothing else in the app captures
/// (annual turnover, when the business started, loan purpose). Nobody
/// fills in a separate assessment form: Business Health, Credit
/// Readiness, the KCB checklist, and red flags all update automatically
/// as the consultant completes real ToR tasks.
class AssessmentDashboardTab extends ConsumerWidget {
  const AssessmentDashboardTab({super.key, required this.enterpriseId, required this.readOnly});

  final String enterpriseId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterpriseAsync = ref.watch(enterpriseDetailProvider(enterpriseId));
    final tasksAsync = ref.watch(tasksProvider(enterpriseId));

    if (enterpriseAsync.isLoading || tasksAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (enterpriseAsync.hasError || tasksAsync.hasError) {
      return const Center(child: Text('Could not load loan-readiness data.'));
    }

    final enterprise = enterpriseAsync.value;
    if (enterprise == null) {
      return const Center(child: Text('Enterprise not found.'));
    }
    final tasks = tasksAsync.value ?? const [];

    final inputs = LoanReadinessInputs.from(enterprise: enterprise, tasks: tasks);
    final businessHealth = LoanReadiness.businessHealthScore(inputs);
    final creditReadiness = LoanReadiness.creditReadinessScore(inputs);
    final kcbMet = LoanReadiness.kcbRequirementsMet(inputs);
    final flags = LoanReadiness.redFlags(inputs);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ScoreBadge(label: 'Business Health', score: businessHealth)),
            const SizedBox(width: 12),
            Expanded(child: _ScoreBadge(label: 'Credit Readiness', score: creditReadiness)),
          ],
        ),
        const SizedBox(height: 12),
        _KcbProgress(met: kcbMet.length),
        const SizedBox(height: 12),
        _RedFlagsList(flags: flags),
        const SizedBox(height: 24),
        Text('Facts nothing else tracks', style: Theme.of(context).textTheme.titleMedium),
        Text(
          "These three aren't in any task — set them once, update when you learn better.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _EditableFacts(enterprise: enterprise, readOnly: readOnly),
        const SizedBox(height: 24),
        Text('What\'s driving this score', style: Theme.of(context).textTheme.titleMedium),
        Text(
          'Automatic — updates itself as ToR tasks are completed in the Tasks tab. '
          'Nothing here to fill in.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        _DerivedFromTasksList(inputs: inputs),
      ],
    );
  }
}

/// Score + status band (Strong/Developing/Weak) — the color never
/// carries meaning alone, it's always paired with the icon and label.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.label, required this.score});

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String band) = switch (score) {
      >= 70 => (AppColors.successGreen, Icons.check_circle, 'Strong'),
      >= 40 => (AppColors.pendingAmber, Icons.warning_amber, 'Developing'),
      _ => (AppColors.errorRed, Icons.error, 'Weak'),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text('${score.toStringAsFixed(0)}/100', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            Text(band, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _KcbProgress extends StatelessWidget {
  const _KcbProgress({required this.met});

  final int met;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KCB MSME readiness: $met/10', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: met / 10,
                minHeight: 8,
                backgroundColor: AppColors.lightGray.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(AppColors.charcoal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedFlagsList extends StatelessWidget {
  const _RedFlagsList({required this.flags});

  final List<String> flags;

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.successGreen, size: 20),
          SizedBox(width: 8),
          Text('No red flags right now.'),
        ],
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.errorRed.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Red flags', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final flag in flags)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(flag)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lists what's already satisfied vs still outstanding, and — for the
/// outstanding, task-derived ones — which ToR task completing it would
/// satisfy, so "why is my score X" is never a mystery.
class _DerivedFromTasksList extends StatelessWidget {
  const _DerivedFromTasksList({required this.inputs});

  final LoanReadinessInputs inputs;

  @override
  Widget build(BuildContext context) {
    final rows = <(bool, String, String)>[
      (inputs.isRegistered, 'Business registered', 'Task: Complete business registration'),
      (inputs.taxCompliant, 'Tax compliant', 'Tasks: Acquire KRA PIN + Confirm monthly KRA returns filed'),
      (inputs.hasBusinessPermit, 'Valid business permit', 'Task: Acquire trading licenses'),
      (inputs.hasFinancialRecords, 'Financial record-keeping', 'Task: Set up financial record-keeping system'),
      (
        inputs.hasSixMonthsBankStatements,
        '6 months of bank statements',
        'Task: Compile 6 months of bank statements',
      ),
      (inputs.hasAuditedAccounts, 'Audited accounts (3 yrs)', 'Task: Obtain 3 years of audited accounts'),
      (
        inputs.hasCollateral,
        'Collateral documented',
        'Task: Document available collateral for financing',
      ),
      (inputs.crbChecked, 'CRB status checked', 'Task: Check CRB status'),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (done, label, source) in rows)
            ListTile(
              dense: true,
              leading: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? AppColors.successGreen : AppColors.lightGray,
              ),
              title: Text(label),
              subtitle: done ? null : Text(source, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// The three facts (turnover, business-started date, loan purpose)
/// nothing else in the schema captures — small inline editors right
/// where their effect on the score is visible.
class _EditableFacts extends ConsumerStatefulWidget {
  const _EditableFacts({required this.enterprise, required this.readOnly});

  final Enterprise enterprise;
  final bool readOnly;

  @override
  ConsumerState<_EditableFacts> createState() => _EditableFactsState();
}

class _EditableFactsState extends ConsumerState<_EditableFacts> {
  late final _turnoverController =
      TextEditingController(text: widget.enterprise.annualTurnover?.toStringAsFixed(0) ?? '');
  late final _loanPurposeController = TextEditingController(text: widget.enterprise.loanPurpose ?? '');
  DateTime? _businessStartedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _businessStartedDate = widget.enterprise.businessStartedDate;
  }

  @override
  void dispose() {
    _turnoverController.dispose();
    _loanPurposeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _businessStartedDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _businessStartedDate = picked);
      await _save();
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(enterpriseRepositoryProvider).updateFinancialFacts(
            enterpriseId: widget.enterprise.id,
            annualTurnover: double.tryParse(_turnoverController.text.trim()),
            businessStartedDate: _businessStartedDate,
            loanPurpose: _loanPurposeController.text.trim().isEmpty
                ? null
                : _loanPurposeController.text.trim(),
          );
      ref.invalidate(enterpriseDetailProvider(widget.enterprise.id));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !widget.readOnly,
              title: const Text('Business started'),
              subtitle: Text(_businessStartedDate?.toLocal().toString().split(' ').first ?? 'Not set'),
              trailing: widget.readOnly ? null : const Icon(Icons.calendar_today),
              onTap: widget.readOnly ? null : _pickDate,
            ),
            TextField(
              controller: _turnoverController,
              enabled: !widget.readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Approximate annual turnover (KSh)'),
              onSubmitted: (_) => _save(),
              onEditingComplete: _save,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _loanPurposeController,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: 'Loan purpose (if known)'),
              onSubmitted: (_) => _save(),
              onEditingComplete: _save,
            ),
            if (_isSaving) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
