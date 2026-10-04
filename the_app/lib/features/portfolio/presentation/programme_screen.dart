import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/portfolio_providers.dart';
import 'monthly_report_button.dart';
import 'portfolio_kpis_section.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

/// Admin: the whole programme against the Terms of Reference measures,
/// across all three disciplines, plus the monthly report.
class ProgrammeScreen extends ConsumerWidget {
  const ProgrammeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = PageBody.paddingFor(context);
    return AppShell(
      title: 'Programme',
      globalKey: 'programme',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(portfolioKpisProvider),
        child: ListView(
          padding: padding,
          children: const [
            PageBody(child: TourAnchor(id: TourAnchors.kpis, child: PortfolioKpisSection(trailing: TourAnchor(id: TourAnchors.monthlyReport, child: MonthlyReportButton())))),
          ],
        ),
      ),
    );
  }
}
