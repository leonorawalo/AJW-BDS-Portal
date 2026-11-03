import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../enterprises/models/enterprise.dart';
import '../../enterprises/models/loan_purpose.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../models/loan_readiness.dart';
import '../providers/legal_workstream_providers.dart';
import '../../../core/widgets/labeled_value.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/greeting_header.dart';
import '../../../core/widgets/dashboard_card.dart';
import '../../portfolio/presentation/programme_clock_card.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';
import '../../../core/lender.dart';
import '../../../core/user_message.dart';

/// Loan-readiness dashboard: computed live from ToR task completion
/// (standardLegalChecklist / standardAccountingChecklist) plus the
/// handful of enterprise facts nothing else in the app captures
/// (annual turnover, when the business started, loan purpose). Nobody
/// fills in a separate assessment form: Business Health, Credit
/// Readiness, the bank lending checklist, and red flags all update automatically
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
    final bankMet = LoanReadiness.bankRequirementsMet(inputs);
    final flags = LoanReadiness.redFlags(inputs);

    final bankTotal = LoanReadiness.bankRequirements(inputs).length;
    final palette = ref.watch(dashboardPaletteProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final scores = [
          _ScoreCard(
            label: 'Business health',
            score: businessHealth,
            compact: !wide,
            accent: palette.accentAt(0),
            deep: palette.deep,
            entranceIndex: 1,
          ),
          _ScoreCard(
            label: 'Credit readiness',
            score: creditReadiness,
            compact: !wide,
            accent: palette.accentAt(1),
            deep: palette.deep,
            entranceIndex: 2,
          ),
          _BankChecklistCard(
            met: bankMet.length,
            total: bankTotal,
            accent: palette.accentAt(2),
            deep: palette.deep,
            entranceIndex: 3,
          ),
        ];
        final facts = TourAnchor(id: TourAnchors.facts, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              accent: palette.accent,
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
            _SectionHeader(
              accent: palette.accent,
              title: "What's driving these scores",
              subtitle: 'Updates by itself as tasks are completed. Nothing to fill in here.',
            ),
            _DerivedFromTasksList(inputs: inputs, accent: palette.accent, deep: palette.deep),
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
                  AccentHeading('Loan readiness', accent: palette.accent),
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
                  Entrance(index: 4, child: _RedFlagsList(flags: flags, accent: palette.accent)),
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
  const _SectionHeader({required this.title, required this.subtitle, required this.accent});
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: AccentHeading(title, subtitle: subtitle, accent: accent),
    );
  }
}

/// Score out of 100 as a ring in the role's colour, with its band
/// (Strong / Developing / Weak) written out with an icon, so the band never
/// depends on colour.
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.accent,
    required this.deep,
    this.compact = false,
    this.entranceIndex = 0,
  });

  final String label;
  final double score;
  final Color accent;
  final Color deep;
  final int entranceIndex;

  /// Ring above the band instead of beside it (two cards across a phone).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String bandLabel) = switch (score) {
      >= 70 => (Icons.check_circle, 'Strong'),
      >= 40 => (Icons.trending_up, 'Developing'),
      _ => (Icons.error_outline, 'Weak'),
    };
    final text = Theme.of(context).textTheme;
    final still = reduceMotion(context);

    final ring = SizedBox(
      width: 76,
      height: 76,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: score / 100),
        duration: still ? Duration.zero : const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _RingPainter(value: value, color: accent),
          child: Center(
            child: Text(
              (value * 100).round().toString(),
              style: text.headlineMedium?.copyWith(color: deep, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
    final band = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: deep),
              const SizedBox(width: 4),
              Text(bandLabel, style: text.labelMedium?.copyWith(color: deep, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        Text('out of 100', style: text.bodySmall),
      ],
    );

    return DashboardCard(
      accent: accent,
      entranceIndex: entranceIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft)),
          const SizedBox(height: Space.md),
          // Side by side when there's room; stacked in a narrow card (two
          // cards across a phone).
          if (compact) ...[ring, const SizedBox(height: Space.md), band]
          else Row(children: [ring, const SizedBox(width: Space.lg), Expanded(child: band)]),
        ],
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
    const stroke = 8.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color.withValues(alpha: 0.14);
    canvas.drawArc(rect, 0, 6.2832, false, track);
    if (value <= 0) return;
    final sweep = 6.2832 * value.clamp(0.0, 1.0);
    // The arc deepens along its length: lighter at the start, full colour
    // at the tip.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep < 0.01 ? 0.01 : sweep,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-1.5708),
      ).createShader(rect);
    canvas.drawArc(rect, -1.5708, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

class _BankChecklistCard extends StatelessWidget {
  const _BankChecklistCard({
    required this.met,
    required this.total,
    required this.accent,
    required this.deep,
    this.entranceIndex = 0,
  });

  final int met;
  final int total;
  final Color accent;
  final Color deep;
  final int entranceIndex;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ratio = total == 0 ? 0.0 : met / total;
    return DashboardCard(
      accent: accent,
      entranceIndex: entranceIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Lender.checklist, style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft)),
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUp(met, style: text.displaySmall?.copyWith(color: deep, fontWeight: FontWeight.w700)),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text('of $total met', style: text.bodyMedium?.copyWith(color: AppColors.charcoalSoft)),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          AccentBar(value: ratio, accent: accent),
        ],
      ),
    );
  }
}

class _RedFlagsList extends StatelessWidget {
  const _RedFlagsList({required this.flags, required this.accent});

  final List<String> flags;

  /// Only for the all-clear state; red flags themselves stay red.
  final Color accent;

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
              Icon(Icons.verified_outlined, color: accent, size: 22),
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

/// Lists what's already satisfied vs still outstanding, and: for the
/// outstanding, task-derived ones: which ToR task completing it would
/// satisfy, so "why is my score X" is never a mystery.
class _DerivedFromTasksList extends StatelessWidget {
  const _DerivedFromTasksList({required this.inputs, required this.accent, required this.deep});

  final LoanReadinessInputs inputs;
  final Color accent;
  final Color deep;

  @override
  Widget build(BuildContext context) {
    final rows = LoanReadiness.drivers(inputs);
    final text = Theme.of(context).textTheme;

    // Read-only status rows, not checkboxes: nothing here looks tappable.
    // Done rows are washed in the role's colour with a tick; completing the
    // named task in Tasks is what turns a row done.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: Space.sm),
          Entrance(
            index: 5 + i,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
              decoration: BoxDecoration(
                color: rows[i].$1 ? accent.withValues(alpha: 0.10) : AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: rows[i].$1 ? accent.withValues(alpha: 0.35) : AppColors.hairline),
              ),
              child: Row(
                children: [
                  Icon(
                    rows[i].$1 ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20,
                    color: rows[i].$1 ? accent : AppColors.notDoneMark,
                  ),
                  const SizedBox(width: Space.md),
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
                      color: rows[i].$1 ? deep : AppColors.charcoalSoft,
                      fontWeight: AppFonts.bodyStrong,
                    ),
                  ),
                ],
              ),
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
  String? _purposeChoice;
  DateTime? _businessStartedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _turnoverController =
        TextEditingController(text: widget.enterprise.annualTurnover?.toStringAsFixed(0) ?? '');
    _setPurpose(widget.enterprise.loanPurpose);
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
      _loanPurposeController.dispose();
      _setPurpose(widget.enterprise.loanPurpose);
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

  /// Dropdown choice plus, for "Other", the owner's own words.
  void _setPurpose(String? stored) {
    _purposeChoice = loanPurposeChoice(stored);
    _loanPurposeController = TextEditingController(text: _purposeChoice == loanPurposeOther ? stored!.trim() : '');
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
      final otherText = _loanPurposeController.text.trim();
      final loanPurpose = _purposeChoice == loanPurposeOther
          ? (otherText.isEmpty ? null : otherText)
          : _purposeChoice;

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
          SnackBar(content: Text('Could not save financial facts: ${userMessage(e)}')),
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
            DropdownButtonFormField<String>(
              // Rebuilt when the saved value changes (another enterprise, a save).
              key: ValueKey('${widget.enterprise.id}|${widget.enterprise.loanPurpose}'),
              initialValue: _purposeChoice,
              decoration: const InputDecoration(
                labelText: 'Loan purpose',
                helperText: 'What a loan would pay for. Banks ask for this specifically.',
              ),
              items: [
                for (final p in [...loanPurposes, loanPurposeOther]) DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: widget.readOnly
                  ? null
                  : (value) {
                      setState(() => _purposeChoice = value);
                      // "Other" saves once its description is typed.
                      if (value != loanPurposeOther) _save();
                    },
            ),
            if (_purposeChoice == loanPurposeOther) ...[
              const SizedBox(height: Space.md),
              TextField(
                controller: _loanPurposeController,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(labelText: 'Describe the loan purpose'),
                onSubmitted: (_) => _save(),
                onEditingComplete: _save,
              ),
            ],
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
