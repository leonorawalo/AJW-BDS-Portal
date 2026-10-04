import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../enterprises/models/enterprise.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../models/loan_readiness.dart';
import '../providers/legal_workstream_providers.dart';
import '../../../core/widgets/labeled_value.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/greeting_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../../portfolio/presentation/programme_clock_card.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

/// Loan-readiness dashboard — computed live from ToR task completion
/// (standardLegalChecklist / standardAccountingChecklist) plus the
/// handful of enterprise facts nothing else in the app captures
/// (annual turnover, when the business started, loan purpose). Nobody
/// fills in a separate assessment form: Business Health, Credit
/// Readiness, the KCB checklist, and red flags all update automatically
/// as the consultant completes real ToR tasks.
class AssessmentDashboardTab extends ConsumerWidget {
  const AssessmentDashboardTab({
    super.key,
    required this.enterpriseId,
    required this.readOnly,
    this.showGreeting = false,
  });

  final String enterpriseId;
  final bool readOnly;

  /// The Owner's home: greet them above their enterprise's scores.
  final bool showGreeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterpriseAsync = ref.watch(enterpriseDetailProvider(enterpriseId));
    final completedAsync = ref.watch(completedLoanReadinessTitlesProvider(enterpriseId));

    if (enterpriseAsync.isLoading || completedAsync.isLoading) {
      return const AjwLoadingView();
    }
    if (enterpriseAsync.hasError || completedAsync.hasError) {
      return const EmptyState(
        isError: true,
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load loan readiness",
        message: 'Check your connection and try again.',
      );
    }

    final enterprise = enterpriseAsync.value;
    if (enterprise == null) {
      return const Center(child: Text('Enterprise not found.'));
    }
    final completedTaskTitles = completedAsync.value ?? const <String>{};

    final inputs = LoanReadinessInputs.from(enterprise: enterprise, completedTaskTitles: completedTaskTitles);
    final businessHealth = LoanReadiness.businessHealthScore(inputs);
    final creditReadiness = LoanReadiness.creditReadinessScore(inputs);
    final kcbMet = LoanReadiness.kcbRequirementsMet(inputs);
    final flags = LoanReadiness.redFlags(inputs);

    final kcbTotal = LoanReadiness.kcbRequirements(inputs).length;
    final text = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final scores = [
          _ScoreCard(label: 'Business health', score: businessHealth, compact: !wide),
          _ScoreCard(label: 'Credit readiness', score: creditReadiness, compact: !wide),
          _KcbCard(met: kcbMet.length, total: kcbTotal),
        ];
        final facts = TourAnchor(id: TourAnchors.facts, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              title: 'Business facts',
              subtitle: readOnly
                  ? 'Kept up to date by your consultant.'
                  : 'Not part of any task. Set them once, and update them when you learn more.',
            ),
            _EditableFacts(enterprise: enterprise, readOnly: readOnly),
          ],
        ));
        final drivers = TourAnchor(id: TourAnchors.drivers, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(
              title: "What's driving these scores",
              subtitle: 'Updates by itself as tasks are completed. Nothing to fill in here.',
            ),
            _DerivedFromTasksList(inputs: inputs),
          ],
        ));

        return ListView(
          padding: PageBody.paddingFor(context),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showGreeting) GreetingHeader(summary: enterprise.businessName),
                  TourAnchor(id: TourAnchors.clock, child: ProgrammeClockCard(enterprise: enterprise)),
                  const SizedBox(height: Space.xl),
                  Text('Loan readiness', style: text.titleLarge),
                  const SizedBox(height: Space.md),
                  if (wide)
                    TourAnchor(id: TourAnchors.scores, child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < scores.length; i++) ...[
                            if (i > 0) const SizedBox(width: Space.lg),
                            Expanded(child: scores[i]),
                          ],
                        ],
                      ),
                    ))
                  else ...[
                    TourAnchor(id: TourAnchors.scores, child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: scores[0]),
                          const SizedBox(width: Space.md),
                          Expanded(child: scores[1]),
                        ],
                      ),
                    )),
                    const SizedBox(height: Space.md),
                    scores[2],
                  ],
                  const SizedBox(height: Space.lg),
                  _RedFlagsList(flags: flags),
                  const SizedBox(height: Space.xxl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: drivers),
                        const SizedBox(width: Space.xl),
                        Expanded(child: facts),
                      ],
                    )
                  else ...[
                    drivers,
                    const SizedBox(height: Space.xxl),
                    facts,
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleLarge),
          const SizedBox(height: 2),
          Text(subtitle, style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Score out of 100 as a ring, with its band (Strong / Developing / Weak).
/// The colour never carries meaning alone: the band is also written out,
/// with an icon.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.label, required this.score, this.compact = false});

  final String label;
  final double score;

  /// Ring above the band instead of beside it (two cards across a phone).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String bandLabel, StatusTone tone) = switch (score) {
      >= 70 => (AppColors.successGreen, Icons.check_circle, 'Strong', StatusTone.success),
      >= 40 => (AppColors.pendingAmber, Icons.trending_up, 'Developing', StatusTone.warning),
      _ => (AppColors.errorRed, Icons.error_outline, 'Weak', StatusTone.danger),
    };
    final text = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft)),
            const SizedBox(height: Space.md),
            Builder(
              builder: (context) {
                final ring = SizedBox(
                  width: 72,
                  height: 72,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: score / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CustomPaint(
                      painter: _RingPainter(value: value, color: color),
                      child: Center(child: Text(score.toStringAsFixed(0), style: text.headlineMedium)),
                    ),
                  ),
                );
                final band = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(bandLabel, tone: tone, icon: icon),
                    const SizedBox(height: Space.xs),
                    Text('out of 100', style: text.bodySmall),
                  ],
                );
                // Side by side when there's room; stacked in a narrow card
                // (two cards across a phone).
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [ring, const SizedBox(height: Space.md), band],
                  );
                }
                return Row(children: [ring, const SizedBox(width: Space.lg), Expanded(child: band)]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.surfaceSunken;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, 6.2832, false, track);
    if (value > 0) canvas.drawArc(rect, -1.5708, 6.2832 * value.clamp(0.0, 1.0), false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

class _KcbCard extends StatelessWidget {
  const _KcbCard({required this.met, required this.total});

  final int met;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : met / total;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KCB MSME checklist', style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft)),
            const SizedBox(height: Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$met', style: text.displaySmall),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4),
                  child: Text('of $total met', style: text.bodyMedium?.copyWith(color: AppColors.charcoalSoft)),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceSunken,
                  valueColor: const AlwaysStoppedAnimation(AppColors.brandRed),
                ),
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
    final text = Theme.of(context).textTheme;
    if (flags.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, color: AppColors.successGreen, size: 22),
              const SizedBox(width: Space.md),
              Text('No red flags right now.', style: text.bodyMedium),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFFFF6F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: Color(0xFFF6D4CF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: AppColors.errorRed, size: 20),
                const SizedBox(width: Space.sm),
                Text(
                  '${flags.length} red ${flags.length == 1 ? 'flag' : 'flags'} to resolve',
                  style: text.titleMedium?.copyWith(color: AppColors.errorRed),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            for (final flag in flags)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: CircleAvatar(radius: 3, backgroundColor: AppColors.errorRed),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(child: Text(flag, style: text.bodyMedium)),
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
    final rows = LoanReadiness.drivers(inputs);
    final text = Theme.of(context).textTheme;

    // Read-only status rows, not checkboxes: the colour says done or not,
    // and nothing here looks tappable. Completing the named task in Tasks
    // is what turns a row green.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Space.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            decoration: BoxDecoration(
              color: rows[i].$1 ? AppColors.successGreen.withValues(alpha: 0.10) : AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].$2, style: text.bodyMedium?.copyWith(fontWeight: AppFonts.bodyStrong)),
                      const SizedBox(height: 2),
                      Text(rows[i].$3, style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(
                  rows[i].$1 ? 'Done' : 'Not yet',
                  style: text.labelMedium?.copyWith(
                    color: rows[i].$1 ? AppColors.successGreen : AppColors.charcoalSoft,
                    fontWeight: AppFonts.bodyStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EditableFacts extends ConsumerStatefulWidget {
  const _EditableFacts({required this.enterprise, required this.readOnly});

  final Enterprise enterprise;
  final bool readOnly;

  @override
  ConsumerState<_EditableFacts> createState() => _EditableFactsState();
}

class _EditableFactsState extends ConsumerState<_EditableFacts> {
  late TextEditingController _turnoverController;
  late TextEditingController _loanPurposeController;
  DateTime? _businessStartedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _turnoverController =
        TextEditingController(text: widget.enterprise.annualTurnover?.toStringAsFixed(0) ?? '');
    _loanPurposeController = TextEditingController(text: widget.enterprise.loanPurpose ?? '');
    _businessStartedDate = widget.enterprise.businessStartedDate;
  }

  @override
  void didUpdateWidget(covariant _EditableFacts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enterprise.id != widget.enterprise.id ||
        oldWidget.enterprise.annualTurnover != widget.enterprise.annualTurnover) {
      _turnoverController.text = widget.enterprise.annualTurnover?.toStringAsFixed(0) ?? '';
    }
    if (oldWidget.enterprise.id != widget.enterprise.id ||
        oldWidget.enterprise.loanPurpose != widget.enterprise.loanPurpose) {
      _loanPurposeController.text = widget.enterprise.loanPurpose ?? '';
    }
    if (oldWidget.enterprise.id != widget.enterprise.id ||
        oldWidget.enterprise.businessStartedDate != widget.enterprise.businessStartedDate) {
      _businessStartedDate = widget.enterprise.businessStartedDate;
    }
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
    final rawTurnover = _turnoverController.text.trim().replaceAll(',', '');
    final turnover = rawTurnover.isEmpty ? null : double.tryParse(rawTurnover);
    // An unparseable entry must not silently clear the saved turnover.
    if (rawTurnover.isNotEmpty && turnover == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annual turnover must be a number.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final rawPurpose = _loanPurposeController.text.trim();
      final loanPurpose = rawPurpose.isEmpty ? null : rawPurpose;

      await ref.read(enterpriseRepositoryProvider).updateFinancialFacts(
            enterpriseId: widget.enterprise.id,
            annualTurnover: turnover,
            businessStartedDate: _businessStartedDate,
            loanPurpose: loanPurpose,
          );
      ref.invalidate(enterpriseDetailProvider(widget.enterprise.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Financial facts updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save financial facts: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _date(DateTime? d) => d == null ? 'Not set' : '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _money(double? v) {
    if (v == null) return 'Not set';
    final digits = v.toStringAsFixed(0);
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return 'KSh $out';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) {
      final e = widget.enterprise;
      final rows = [
        ('Business started', _date(e.businessStartedDate)),
        ('Approximate annual turnover', _money(e.annualTurnover)),
        ('Loan purpose', (e.loanPurpose ?? '').isEmpty ? 'Not set' : e.loanPurpose!),
      ];
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(indent: Space.lg, endIndent: Space.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                  child: LabeledValue(label: rows[i].$1, value: rows[i].$2),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: !widget.readOnly,
              title: LabeledValue(
                label: 'Business started',
                value: _date(_businessStartedDate),
              ),
              trailing: widget.readOnly ? null : const Icon(Icons.edit_calendar_outlined),
              onTap: widget.readOnly ? null : _pickDate,
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: _turnoverController,
              enabled: !widget.readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Approximate annual turnover (KSh)'),
              onSubmitted: (_) => _save(),
              onEditingComplete: _save,
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _loanPurposeController,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: 'Loan purpose (if known)'),
              onSubmitted: (_) => _save(),
              onEditingComplete: _save,
            ),
            if (_isSaving) ...[
              const SizedBox(height: Space.md),
              const Center(child: AjwLoader(dotSize: 7, semanticsLabel: 'Saving')),
            ],
          ],
        ),
      ),
    );
  }
}
