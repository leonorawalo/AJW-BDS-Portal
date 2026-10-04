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
import '../../visits/presentation/visits_tab.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

/// A consultant's workspace for one assigned enterprise. Sections come from
/// the side menu (AppShell) and live in the URL (?section=…).
class ConsultantWorkstreamScreen extends ConsumerWidget {
  const ConsultantWorkstreamScreen({
    super.key,
    required this.enterpriseId,
    required this.enterpriseName,
    this.section,
  });

  final String enterpriseId;

  /// From the portfolio link; shown until the enterprise record loads.
  final String enterpriseName;
  final String? section;

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
    final name = ref.watch(enterpriseDetailProvider(enterpriseId)).value?.businessName ?? enterpriseName;
    final current = sections.any((s) => s.key == section) ? section! : 'dashboard';

    return AppShell(
      title: name,
      enterprise: ShellEnterprise(
        id: enterpriseId,
        name: name,
        sections: sections,
        currentSection: current,
        onSelectSection: (key) => context.go('/consultant/enterprises/$enterpriseId?section=$key'),
        onSwitchEnterprise: (id) => context.go('/consultant/enterprises/$id?section=$current'),
      ),
      actions: [
        TourAnchor(id: TourAnchors.email, child: EmailMenuButton(enterpriseId: enterpriseId)),
        TourAnchor(id: TourAnchors.export, child: ExportMenuButton(enterpriseId: enterpriseId)),
      ],
      body: switch (current) {
        'tasks' => TasksTab(enterpriseId: enterpriseId, readOnly: false),
        'recommendations' => RecommendationsTab(enterpriseId: enterpriseId, readOnly: false),
        'documents' => DocumentsTab(enterpriseId: enterpriseId, readOnly: false),
        'files' => FilesTab(enterpriseId: enterpriseId),
        'visits' => VisitsTab(enterpriseId: enterpriseId),
        'sessions' => SessionsTab(enterpriseId: enterpriseId),
        _ => AssessmentDashboardTab(enterpriseId: enterpriseId, readOnly: false),
      },
    );
  }
}
