import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../builders/export_formatting.dart';
import '../builders/portfolio_sheet_builder.dart';
import '../providers/google_export_providers.dart';
import 'google_export_flow.dart';

/// Admin enterprise list: "Export portfolio (Google Sheets)" — one row per
/// enterprise with scores, consultants, task counts and activity.
class PortfolioExportButton extends ConsumerWidget {
  const PortfolioExportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.table_chart_outlined),
      tooltip: 'Export portfolio (Google Sheets)',
      onPressed: () => runGoogleExport(
        context,
        ref,
        appName: 'Google Sheets',
        create: () async {
          final rows = await ref.read(portfolioRepositoryProvider).fetchPortfolio();
          return ref.read(googleExportRepositoryProvider).exportSheet(
                title: 'AJW BAGS portfolio (${exportDate(DateTime.now())})',
                tabs: buildPortfolioSheet(rows),
              );
        },
      ),
    );
  }
}
