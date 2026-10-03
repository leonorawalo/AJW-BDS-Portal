import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../consultants/models/consultant_assignment.dart';
import '../../consultants/providers/consultant_assignment_providers.dart';
import '../models/enterprise_visit.dart';
import '../providers/visit_providers.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
String _day(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)} ${d.year}';

/// Visits to one enterprise. The Terms of Reference ask each consultant to
/// visit every business twice a month and to log each visit within 2 days;
/// the header shows this month against that, per consultant.
class VisitsTab extends ConsumerWidget {
  const VisitsTab({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(enterpriseVisitsProvider(enterpriseId));
    final assignments = ref.watch(activeAssignmentsForEnterpriseProvider(enterpriseId)).value ?? const [];
    final me = ref.watch(currentUserProfileProvider).value;
    final canLog = me?.role == UserRole.consultant && assignments.any((a) => a.consultantId == me!.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canLog
          ? FloatingActionButton.extended(
              onPressed: () => showLogVisitDialog(context, enterpriseId: enterpriseId),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Log a visit'),
            )
          : null,
      body: visitsAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load visits",
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(enterpriseVisitsProvider(enterpriseId)),
            child: const Text('Try again'),
          ),
        ),
        data: (visits) {
          final padding = PageBody.paddingFor(context);
          return ListView(
            padding: padding.copyWith(bottom: padding.bottom + (canLog ? 88 : 0)),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ThisMonth(visits: visits, assignments: assignments),
                    const SizedBox(height: Space.xl),
                    if (visits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xl),
                        child: EmptyState(
                          icon: Icons.where_to_vote_outlined,
                          title: 'No visits logged yet',
                          message: canLog
                              ? 'After each visit or call, log what happened within 2 days.'
                              : 'Visits appear here once the consultants log them.',
                        ),
                      )
                    else
                      ..._history(context, ref, visits, me),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _history(BuildContext context, WidgetRef ref, List<EnterpriseVisit> visits, UserProfile? me) {
    final text = Theme.of(context).textTheme;
    final out = <Widget>[];
    String? currentMonth;
    for (final v in visits) {
      final month = '${_months[v.visitedOn.month - 1]} ${v.visitedOn.year}';
      if (month != currentMonth) {
        if (currentMonth != null) out.add(const SizedBox(height: Space.lg));
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: Text(month, style: text.titleMedium),
        ));
        currentMonth = month;
      }
      out.add(_VisitCard(visit: v, mine: v.consultantId == me?.id, enterpriseId: enterpriseId));
      out.add(const SizedBox(height: Space.sm));
    }
    return out;
  }
}

/// "This month: 1 of 2 visits" for each consultant on the enterprise.
class _ThisMonth extends StatelessWidget {
  const _ThisMonth({required this.visits, required this.assignments});
  final List<EnterpriseVisit> visits;
  final List<ConsultantAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final thisMonth = visits.where((v) => v.visitedOn.year == now.year && v.visitedOn.month == now.month).toList();
    final late = thisMonth.where((v) => v.loggedLate).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${_months[now.month - 1]}: visits so far', style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft)),
            const SizedBox(height: 2),
            Text(
              'The Terms of Reference ask for ${VisitRules.perMonth} visits a month by each consultant, '
              'each logged within ${VisitRules.logWithinDays} days.',
              style: text.bodySmall,
            ),
            const SizedBox(height: Space.md),
            if (assignments.isEmpty)
              Text('No consultant is assigned yet.', style: text.bodyMedium)
            else
              for (final a in assignments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  child: _ConsultantProgress(
                    name: a.consultantName ?? 'Consultant',
                    discipline: a.specialization?.label,
                    count: thisMonth.where((v) => v.consultantId == a.consultantId).length,
                  ),
                ),
            if (late > 0) ...[
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: AppColors.errorRed),
                  const SizedBox(width: Space.xs),
                  Text('$late logged more than ${VisitRules.logWithinDays} days after the visit',
                      style: text.bodySmall?.copyWith(color: AppColors.errorRed)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsultantProgress extends StatelessWidget {
  const _ConsultantProgress({required this.name, required this.count, this.discipline});
  final String name;
  final String? discipline;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final met = count >= VisitRules.perMonth;
    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: name, style: text.bodyMedium?.copyWith(fontWeight: AppFonts.bodyStrong)),
              if (discipline != null) TextSpan(text: '  ·  $discipline', style: text.bodySmall),
            ]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (var i = 0; i < VisitRules.perMonth; i++)
          Padding(
            padding: const EdgeInsets.only(left: Space.xs),
            child: Icon(
              i < count ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: i < count ? AppColors.successGreen : AppColors.lightGray,
            ),
          ),
        const SizedBox(width: Space.sm),
        SizedBox(
          width: 64,
          child: Text(
            '$count of ${VisitRules.perMonth}',
            textAlign: TextAlign.right,
            style: text.labelMedium?.copyWith(color: met ? AppColors.successGreen : AppColors.charcoalSoft),
          ),
        ),
      ],
    );
  }
}

class _VisitCard extends ConsumerWidget {
  const _VisitCard({required this.visit, required this.mine, required this.enterpriseId});
  final EnterpriseVisit visit;
  final bool mine;
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final who = [
      visit.consultantName ?? 'Consultant',
      if (visit.specialization != null) visit.specialization!,
      visit.mode,
    ].join('  ·  ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                visit.mode == 'In person' ? Icons.storefront_outlined : Icons.call_outlined,
                color: AppColors.charcoalSoft,
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(_day(visit.visitedOn), style: text.titleSmall),
                      if (visit.loggedLate) const StatusChip('Logged late', tone: StatusTone.warning, icon: Icons.schedule),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(who, style: text.bodySmall),
                  const SizedBox(height: Space.sm),
                  Text(visit.outcome, style: text.bodyMedium),
                  if (visit.nextSteps != null) ...[
                    const SizedBox(height: Space.sm),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'Next steps: ', style: text.bodyMedium?.copyWith(fontWeight: AppFonts.bodyStrong)),
                      TextSpan(text: visit.nextSteps, style: text.bodyMedium),
                    ])),
                  ],
                ],
              ),
            ),
            if (mine)
              PopupMenuButton<String>(
                tooltip: 'Visit options',
                onSelected: (v) async {
                  if (v == 'edit') {
                    await showLogVisitDialog(context, enterpriseId: enterpriseId, editing: visit);
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Delete this visit?'),
                        content: Text('The visit on ${_day(visit.visitedOn)} will be removed from the log.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(visitRepositoryProvider).delete(visit.id);
                      ref.invalidate(enterpriseVisitsProvider(enterpriseId));
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit notes')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Log a new visit, or edit the notes of one ([editing]); the date of a
/// logged visit can't change (the database keeps it as the record).
Future<void> showLogVisitDialog(BuildContext context, {required String enterpriseId, EnterpriseVisit? editing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LogVisitDialog(enterpriseId: enterpriseId, editing: editing),
  );
}

class _LogVisitDialog extends ConsumerStatefulWidget {
  const _LogVisitDialog({required this.enterpriseId, this.editing});
  final String enterpriseId;
  final EnterpriseVisit? editing;

  @override
  ConsumerState<_LogVisitDialog> createState() => _LogVisitDialogState();
}

class _LogVisitDialogState extends ConsumerState<_LogVisitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _outcome = TextEditingController(text: widget.editing?.outcome);
  late final _nextSteps = TextEditingController(text: widget.editing?.nextSteps);
  late DateTime _date = widget.editing?.visitedOn ?? DateUtils.dateOnly(DateTime.now());
  late String _mode = widget.editing?.mode ?? 'In person';
  bool _saving = false;

  bool get _editing => widget.editing != null;

  @override
  void dispose() {
    _outcome.dispose();
    _nextSteps.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today.subtract(const Duration(days: 60)),
      lastDate: today,
      helpText: 'When was the visit?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(visitRepositoryProvider);
    try {
      if (_editing) {
        await repo.updateNotes(widget.editing!.id, outcome: _outcome.text.trim(), nextSteps: _nextSteps.text);
      } else {
        await repo.logVisit(
          enterpriseId: widget.enterpriseId,
          visitedOn: _date,
          mode: _mode,
          outcome: _outcome.text.trim(),
          nextSteps: _nextSteps.text,
        );
      }
      ref.invalidate(enterpriseVisitsProvider(widget.enterpriseId));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the visit: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final daysAgo = DateUtils.dateOnly(DateTime.now()).difference(_date).inDays;

    return AlertDialog(
      title: Text(_editing ? 'Edit visit notes' : 'Log a visit'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 480),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: _editing ? null : _pickDate,
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of the visit',
                      suffixIcon: _editing ? null : const Icon(Icons.edit_calendar_outlined),
                      enabled: !_editing,
                    ),
                    child: Text(_day(_date), style: text.bodyLarge),
                  ),
                ),
                if (!_editing && daysAgo > VisitRules.logWithinDays) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    'This is more than ${VisitRules.logWithinDays} days ago, so it will be marked as logged late.',
                    style: text.bodySmall?.copyWith(color: AppColors.errorRed),
                  ),
                ],
                const SizedBox(height: Space.lg),
                if (!_editing) ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'In person', label: Text('In person'), icon: Icon(Icons.storefront_outlined)),
                      ButtonSegment(value: 'Phone or online', label: Text('Phone / online'), icon: Icon(Icons.call_outlined)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: Space.lg),
                ],
                TextFormField(
                  controller: _outcome,
                  autofocus: !_editing,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'What happened',
                    hintText: 'e.g. Reviewed the cash book with the owner; KRA PIN application submitted.',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Describe the outcome of the visit' : null,
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _nextSteps,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Next steps (optional)', alignLabelWithHint: true),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const AjwLoader(dotSize: 6) : Text(_editing ? 'Save' : 'Log visit'),
        ),
      ],
    );
  }
}
