import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import 'assessment_dashboard_tab.dart';
import 'documents_tab.dart';
import 'recommendations_tab.dart';
import 'tasks_tab.dart';

class OwnerWorkstreamScreen extends ConsumerWidget {
  const OwnerWorkstreamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return enterprisesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('Could not load your enterprise.'))),
      data: (enterprises) {
        if (enterprises.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My workstream'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ),
            body: const Center(child: Text('No enterprise linked to your account yet.')),
          );
        }

        final enterprise = enterprises.first;

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(enterprise.businessName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
              bottom: const TabBar(tabs: [
                Tab(text: 'Dashboard'),
                Tab(text: 'Tasks'),
                Tab(text: 'Recommendations'),
                Tab(text: 'Documents'),
              ]),
            ),
            body: TabBarView(children: [
              AssessmentDashboardTab(enterpriseId: enterprise.id, readOnly: true),
              // Owner can now also mark task status, not just create
              // tasks and comment.
              TasksTab(enterpriseId: enterprise.id, readOnly: false, canCreateTasks: true),
              RecommendationsTab(enterpriseId: enterprise.id, readOnly: true),
              DocumentsTab(enterpriseId: enterprise.id, readOnly: false),
            ]),
          ),
        );
      },
    );
  }
}