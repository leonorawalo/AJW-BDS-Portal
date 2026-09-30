import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell.dart';
import '../../calendar/presentation/sessions_tab.dart';
import '../../drive_files/presentation/files_tab.dart';
import '../../email/presentation/email_menu_button.dart';
import '../../google_exports/presentation/export_menu_button.dart';
import '../../legal_workstream/presentation/assessment_dashboard_tab.dart';
import '../../legal_workstream/presentation/documents_tab.dart';
import '../../legal_workstream/presentation/recommendations_tab.dart';
import '../../legal_workstream/presentation/tasks_tab.dart';
import '../providers/enterprise_providers.dart';
import 'enterprise_details_tab.dart';
import '../../../core/widgets/ajw_loader.dart';

/// The Admin's home for a single enterprise. The loan-readiness Dashboard
/// leads (the programme's purpose), then Tasks, Recommendations,
/// Documents, Files, Sessions and Details. The side menu (AppShell) picks
/// the [section], which lives in the URL (?section=…) so Back, refresh and
/// bookmarks work.
class EnterpriseWorkspaceScreen extends ConsumerWidget {
  const EnterpriseWorkspaceScreen({super.key, required this.enterpriseId, this.section});

  final String enterpriseId;
  final String? section;

  static const sections = [
    ShellSection('dashboard', 'Dashboard', Icons.dashboard_outlined),
    ShellSection('tasks', 'Tasks', Icons.task_alt),
    ShellSection('recommendations', 'Recommendations', Icons.lightbulb_outline),
    ShellSection('documents', 'Documents', Icons.folder_outlined),
    ShellSection('files', 'Google files', Icons.drive_file_move_outline),
    ShellSection('sessions', 'Sessions', Icons.event_outlined),
    ShellSection('details', 'Details', Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterpriseAsync = ref.watch(enterpriseDetailProvider(enterpriseId));
    final current = sections.any((s) => s.key == section) ? section! : 'dashboard';

    return AppShell(
      title: 'Enterprise',
      enterprise: ShellEnterprise(
        id: enterpriseId,
        name: enterpriseAsync.value?.businessName ?? 'Enterprise',
        sections: sections,
        currentSection: current,
        onSelectSection: (key) => context.go('/admin/enterprises/$enterpriseId?section=$key'),
        onSwitchEnterprise: (id) => context.go('/admin/enterprises/$id?section=$current'),
      ),
      actions: [
        EmailMenuButton(enterpriseId: enterpriseId),
        ExportMenuButton(enterpriseId: enterpriseId),
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Audit log for this enterprise',
          onPressed: () => context.push('/admin/audit?enterprise=$enterpriseId'),
        ),
        IconButton(
          icon: const Icon(Icons.person_add_alt),
          tooltip: 'Assign consultant',
          onPressed: () => context.push('/admin/enterprises/$enterpriseId/assign-consultant'),
        ),
      ],
      body: enterpriseAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => const Center(child: Text('Could not load this enterprise.')),
        data: (enterprise) {
          if (enterprise == null) return const Center(child: Text('Enterprise not found.'));
          return switch (current) {
            // Admin can view and create/assign tasks, but not change their
            // status — that's Owner/Consultant only.
            'tasks' => TasksTab(enterpriseId: enterpriseId, readOnly: true, canCreateTasks: true),
            'recommendations' => RecommendationsTab(enterpriseId: enterpriseId, readOnly: false),
            'documents' => DocumentsTab(enterpriseId: enterpriseId, readOnly: false),
            'files' => FilesTab(enterpriseId: enterpriseId),
            'sessions' => SessionsTab(enterpriseId: enterpriseId),
            'details' => EnterpriseDetailsTab(enterprise: enterprise),
            _ => AssessmentDashboardTab(enterpriseId: enterpriseId, readOnly: false),
          };
        },
      ),
    );
  }
}
