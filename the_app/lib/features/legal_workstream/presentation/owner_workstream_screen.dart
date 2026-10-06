import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell.dart';
import '../../calendar/presentation/sessions_tab.dart';
import '../../drive_files/presentation/files_tab.dart';
import '../../email/presentation/email_menu_button.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../../google_exports/presentation/export_menu_button.dart';
import 'assessment_dashboard_tab.dart';
import 'documents_tab.dart';
import 'recommendations_tab.dart';
import 'tasks_tab.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../visits/presentation/visits_tab.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

/// The Owner's home: their enterprise's workspace. Sections come from the
/// side menu (AppShell) and live in the URL (/owner?section=...). An owner
/// with more than one business (rare) gets the enterprise switcher, and the
/// chosen one is in the URL too (`&enterprise=<id>`).
class OwnerWorkstreamScreen extends ConsumerWidget {
  const OwnerWorkstreamScreen({super.key, this.section, this.enterpriseId});

  final String? section;
  final String? enterpriseId;

  static const sections = [
    ShellSection('dashboard', 'Dashboard', Icons.dashboard_outlined),
    ShellSection('tasks', 'Tasks', Icons.task_alt),
    ShellSection('visits', 'Visits', Icons.where_to_vote_outlined),
    ShellSection('recommendations', 'Recommendations', Icons.lightbulb_outline),
    ShellSection('documents', 'Documents', Icons.folder_outlined),
    ShellSection('files', 'Google files', Icons.drive_file_move_outline),
    ShellSection('sessions', 'Sessions', Icons.event_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return enterprisesAsync.when(
      loading: () => const AppShell(title: 'My workstream', body: AjwLoadingView()),
      error: (_, _) => const AppShell(title: 'My workstream', body: Center(child: Text('Could not load your enterprise.'))),
      data: (enterprises) {
        if (enterprises.isEmpty) {
          return const AppShell(
            title: 'My workstream',
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No enterprise is linked to your account yet.\n'
                  'Contact your AJW administrator to have your business linked.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final enterprise = enterprises.firstWhere((e) => e.id == enterpriseId, orElse: () => enterprises.first);
        final current = sections.any((s) => s.key == section) ? section! : 'dashboard';

        return AppShell(
          title: enterprise.businessName,
          enterprise: ShellEnterprise(
            id: enterprise.id,
            name: enterprise.businessName,
            sections: sections,
            currentSection: current,
            onSelectSection: (key) => context.go('/owner?enterprise=${enterprise.id}&section=$key'),
            onSwitchEnterprise:
                enterprises.length > 1 ? (id) => context.go('/owner?enterprise=$id&section=$current') : null,
          ),
          actions: [
            TourAnchor(id: TourAnchors.email, child: EmailMenuButton(enterpriseId: enterprise.id)),
            TourAnchor(id: TourAnchors.export, child: ExportMenuButton(enterpriseId: enterprise.id)),
          ],
          body: switch (current) {
            // Owner can mark task status as well as create tasks and comment.
            'tasks' => TasksTab(enterpriseId: enterprise.id, readOnly: false, canCreateTasks: true),
            'recommendations' => RecommendationsTab(enterpriseId: enterprise.id, readOnly: true),
            'documents' => DocumentsTab(enterpriseId: enterprise.id, readOnly: false),
            'files' => FilesTab(enterpriseId: enterprise.id),
            'visits' => VisitsTab(enterpriseId: enterprise.id),
            'sessions' => SessionsTab(enterpriseId: enterprise.id),
            _ => AssessmentDashboardTab(enterpriseId: enterprise.id, readOnly: true, showGreeting: true),
          },
        );
      },
    );
  }
}
