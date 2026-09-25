import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../calendar/presentation/sessions_tab.dart';
import '../../legal_workstream/presentation/assessment_dashboard_tab.dart';
import '../../legal_workstream/presentation/documents_tab.dart';
import '../../legal_workstream/presentation/recommendations_tab.dart';
import '../../legal_workstream/presentation/tasks_tab.dart';
import '../providers/enterprise_providers.dart';
import 'enterprise_details_tab.dart';

/// The Admin's home for a single enterprise. Loan-readiness Dashboard
/// leads — per the program's actual purpose (tracking enterprises
/// toward loan readiness) — followed by Tasks, Recommendations,
/// Documents, and finally Details (business info/lifecycle/consultants,
/// what used to be the entire screen before this became one tab of it).
class EnterpriseWorkspaceScreen extends ConsumerWidget {
  const EnterpriseWorkspaceScreen({super.key, required this.enterpriseId});

  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterpriseAsync = ref.watch(enterpriseDetailProvider(enterpriseId));

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(enterpriseAsync.value?.businessName ?? 'Enterprise'),
          leading: BackButton(onPressed: () => context.go('/admin')),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_alt),
              tooltip: 'Assign consultant',
              onPressed: () => context.push('/admin/enterprises/$enterpriseId/assign-consultant'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Tasks'),
              Tab(text: 'Recommendations'),
              Tab(text: 'Documents'),
              Tab(text: 'Sessions'),
              Tab(text: 'Details'),
            ],
          ),
        ),
        body: enterpriseAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Could not load this enterprise.')),
          data: (enterprise) {
            if (enterprise == null) {
              return const Center(child: Text('Enterprise not found.'));
            }
            return TabBarView(
              children: [
                AssessmentDashboardTab(enterpriseId: enterpriseId, readOnly: false),
                // Admin can view and create/assign tasks, but not mark
                // them complete/change status — that's Owner/Consultant
                // only.
                TasksTab(enterpriseId: enterpriseId, readOnly: true, canCreateTasks: true),
                RecommendationsTab(enterpriseId: enterpriseId, readOnly: false),
                DocumentsTab(enterpriseId: enterpriseId, readOnly: false),
                SessionsTab(enterpriseId: enterpriseId, canSchedule: false),
                EnterpriseDetailsTab(enterprise: enterprise),
              ],
            );
          },
        ),
      ),
    );
  }
}
