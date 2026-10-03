import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../google_exports/presentation/google_export_flow.dart';
import '../../google_exports/providers/google_export_providers.dart';
import '../../visits/providers/visit_providers.dart';
import '../models/monthly_report.dart';
import '../providers/portfolio_providers.dart';

/// "Monthly report": the ToR's BDS Status Report, Activity Report and next
/// month's Workplan as one Google Doc, from portal data. The ToR wants them
/// by the 3rd of the following month, so last month is the default.
class MonthlyReportButton extends ConsumerWidget {
  const MonthlyReportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.summarize_outlined),
      label: const Text('Monthly report'),
      onPressed: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final thisMonth = DateTime(now.year, now.month);
    final month = await showDialog<DateTime>(
      context: context,
      builder: (d) => SimpleDialog(
        title: const Text('Which month?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(d, lastMonth),
            child: ListTile(
              title: Text(monthLabel(lastMonth)),
              subtitle: const Text('Due by the 3rd of this month'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(d, thisMonth),
            child: ListTile(title: Text(monthLabel(thisMonth)), subtitle: const Text('So far')),
          ),
        ],
      ),
    );
    if (month == null || !context.mounted) return;

    await runGoogleExport(
      context,
      ref,
      appName: 'Google Docs',
      create: () async {
        final profile = await ref.read(currentUserProfileProvider.future);
        final me = profile == null ? 'AJW' : '${profile.firstName} ${profile.lastName}'.trim();
        final next = DateTime(month.year, month.month + 1);
        final afterNext = DateTime(month.year, month.month + 2);
        ref.invalidate(portfolioKpisProvider);
        final kpis = await ref.read(portfolioKpisProvider.future);
        final portfolio = ref.read(programmeDataRepositoryProvider);
        var visits = await ref.read(visitRepositoryProvider).fetchBetween(month, next);
        var completed = await portfolio.fetchCompleted(month, next);
        var due = await portfolio.fetchDue(next, afterNext);
        // Only the enterprises in view (RLS already scopes, this keeps an
        // Admin's report tidy if a row slipped through).
        final ids = kpis.enterprises.map((e) => e.id).toSet();
        visits = visits.where((v) => ids.contains(v.enterpriseId)).toList();
        // A consultant's Activity Report is their own visits.
        if (profile?.role == UserRole.consultant) {
          visits = visits.where((v) => v.consultantId == profile!.id).toList();
        }
        completed = completed.where((t) => ids.contains(t.enterpriseId)).toList();
        due = due.where((t) => ids.contains(t.enterpriseId)).toList();

        final report = MonthlyReport(
          author: me,
          month: month,
          kpis: kpis,
          visits: visits,
          completed: completed,
          dueNextMonth: due,
        );
        return ref.read(googleExportRepositoryProvider).exportDoc(title: report.title, html: report.toHtml());
      },
    );
  }
}
