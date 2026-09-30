import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/enterprise_providers.dart';

import '../../google_exports/presentation/portfolio_export_button.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import 'enterprise_grid.dart';

class EnterpriseListScreen extends ConsumerWidget {
  const EnterpriseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return AppShell(
      title: 'Enterprises',
      globalKey: 'enterprises',
      actions: const [PortfolioExportButton()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/enterprises/new'),
        icon: const Icon(Icons.add),
        label: const Text('Register enterprise'),
      ),
      body: enterprisesAsync.when(
        loading: () => const AjwLoadingView(),
        error: (error, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load enterprises",
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(enterprisesListProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (enterprises) => EnterpriseGrid(
          enterprises: enterprises,
          bottomPadding: 72,
          onRefresh: () async => ref.invalidate(enterprisesListProvider),
          onOpen: (e) => context.go('/admin/enterprises/${e.id}'),
          emptyState: const EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No enterprises yet',
            message: 'Register the first enterprise to start tracking its journey to going concern and loan readiness.',
          ),
        ),
      ),
    );
  }
}
