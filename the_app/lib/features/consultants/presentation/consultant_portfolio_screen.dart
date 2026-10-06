import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../enterprises/providers/enterprise_providers.dart';

import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../enterprises/presentation/enterprise_grid.dart';
import '../../portfolio/presentation/monthly_report_button.dart';
import '../../portfolio/presentation/portfolio_kpis_section.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

/// Reuses enterprisesListProvider: the *same* query Admin's screen uses.
/// What comes back differs per role purely because of RLS
/// ("enterprises_select_assigned_consultant"), not because of any
/// client-side filtering here. A Consultant querying "all enterprises"
/// only ever receives the ones actually assigned to them.
class ConsultantPortfolioScreen extends ConsumerWidget {
  const ConsultantPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return AppShell(
      title: 'My portfolio',
      globalKey: 'portfolio',
      body: enterprisesAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load your portfolio",
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(enterprisesListProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (enterprises) => EnterpriseGrid(
          enterprises: enterprises,
          header: enterprises.isEmpty ? null : const TourAnchor(id: TourAnchors.kpis, child: PortfolioKpisSection(trailing: TourAnchor(id: TourAnchors.monthlyReport, child: MonthlyReportButton()))),
          onRefresh: () async => ref.invalidate(enterprisesListProvider),
          onOpen: (e) => context.go(
            '/consultant/enterprises/${e.id}?name=${Uri.encodeComponent(e.businessName)}',
          ),
          emptyState: const EmptyState(
            icon: Icons.work_outline,
            title: 'No enterprises assigned yet',
            message: 'When an administrator assigns you to an enterprise, it will appear here.',
          ),
        ),
      ),
    );
  }
}
