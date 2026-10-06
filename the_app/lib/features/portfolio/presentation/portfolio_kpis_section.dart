import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../shared/models/user_profile.dart';
import '../models/portfolio_kpis.dart';
import '../providers/portfolio_providers.dart';

/// The Terms of Reference measures, as cards plus a target list. Used on a
/// consultant's portfolio (their discipline) and the Admin's Programme page
/// (all three).
class PortfolioKpisSection extends ConsumerWidget {
  const PortfolioKpisSection({super.key, this.showTargets = true, this.trailing});

  final bool showTargets;

  /// e.g. the "Monthly report" button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(portfolioKpisProvider);
    return kpisAsync.when(
      loading: () => const Padding(padding: EdgeInsets.all(Space.xl), child: Center(child: AjwLoader())),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Text("Couldn't load the programme measures.", style: Theme.of(context).textTheme.bodySmall),
      ),
      data: (k) => _Body(kpis: k, showTargets: showTargets, trailing: trailing),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.kpis, required this.showTargets, this.trailing});
  final PortfolioKpis kpis;
  final bool showTargets;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final k = kpis;
    final due = k.dueForGoingConcern.length;
    final gcPct = due == 0 ? null : (k.goingConcernOnTime * 100 / due);
    final survivalPct = k.goingConcerns == 0 ? null : (k.survivingGoingConcerns * 100 / k.goingConcerns);

    final cards = [
      _Metric(
        label: 'Portfolio',
        value: '${k.portfolioSize}',
        detail: 'ToR minimum ${PortfolioKpis.minimumPortfolio} clients',
        good: k.portfolioSize >= PortfolioKpis.minimumPortfolio,
      ),
      _Metric(
        label: 'Going concern within 3 months',
        value: gcPct == null ? '–' : '${gcPct.round()}%',
        detail: due == 0
            ? 'No enterprise past month 3 yet'
            : '${k.goingConcernOnTime} of $due on time · target ${PortfolioKpis.goingConcernTargetPercent}%',
        good: gcPct != null && gcPct >= PortfolioKpis.goingConcernTargetPercent,
      ),
      _Metric(
        label: 'Going concern survival',
        value: survivalPct == null ? '–' : '${survivalPct.round()}%',
        detail: '${k.survivingGoingConcerns} of ${k.goingConcerns} still trading · target ${PortfolioKpis.goingConcernTargetPercent}%',
        good: survivalPct != null && survivalPct >= PortfolioKpis.goingConcernTargetPercent,
      ),
      _Metric(
        label: 'Visits this month',
        value: '${k.visitsThisMonth} of ${k.visitsExpected}',
        detail: k.lateLogsThisMonth == 0
            ? 'Twice a month per business'
            : '${k.lateLogsThisMonth} logged late (over 2 days)',
        good: k.visitsExpected > 0 && k.visitsThisMonth >= k.visitsExpected,
        warn: k.lateLogsThisMonth > 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Terms of Reference measures', style: text.titleLarge)),
            ?trailing,
          ],
        ),
        const SizedBox(height: Space.md),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
            const gap = Space.md;
            final width = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final card in cards) SizedBox(width: width, child: card)],
            );
          },
        ),
        if (showTargets && k.targets.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          _Targets(targets: k.targets, showDiscipline: k.disciplines.length > 1, overdue: k.overdueMilestones),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.detail, required this.good, this.warn = false});
  final String label;
  final String value;
  final String detail;
  final bool good;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft))),
                if (good)
                  const Icon(Icons.check_circle, size: 18, color: AppColors.successGreen)
                else if (warn)
                  const Icon(Icons.schedule, size: 18, color: AppColors.errorRed),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(value, style: text.headlineMedium),
            const SizedBox(height: Space.xs),
            Text(detail, style: text.bodySmall?.copyWith(color: warn ? AppColors.errorRed : null)),
          ],
        ),
      ),
    );
  }
}

class _Targets extends StatelessWidget {
  const _Targets({required this.targets, required this.showDiscipline, required this.overdue});
  final List<TargetProgress> targets;
  final bool showDiscipline;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deliverable targets', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Each ToR deliverable sets a target share of the portfolio, for example "90% of businesses '
                    'registered". The bar fills as businesses complete that task; the dark mark on it is where '
                    'the target sits, so the bar has met it once it reaches the mark.'
                    '${overdue > 0 ? ' $overdue ${overdue == 1 ? 'enterprise is' : 'enterprises are'} past a milestone.' : ''}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            for (final t in targets)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: t.template.title, style: text.bodyMedium),
                              if (showDiscipline) TextSpan(text: '  ·  ${t.discipline.label}', style: text.bodySmall),
                            ]),
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Text(
                          t.met ? 'Target met' : 'Target: ${t.target}%',
                          style: text.labelMedium?.copyWith(
                            color: t.met ? AppColors.successGreen : AppColors.charcoalSoft,
                            fontWeight: t.met ? AppFonts.bodyStrong : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: (t.percent / 100).clamp(0, 1),
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceSunken,
                            valueColor: AlwaysStoppedAnimation(t.met ? AppColors.successGreen : AppColors.brandRed),
                          ),
                        ),
                        // Where the target sits on the bar (not a control).
                        FractionallySizedBox(
                          widthFactor: (t.target / 100).clamp(0.0, 1.0),
                          alignment: Alignment.centerLeft,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(width: 2, height: 14, color: AppColors.charcoal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${t.done} of ${t.outOf} ${t.outOf == 1 ? 'business' : 'businesses'} done (${t.percent.round()}%)',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
  }
}
