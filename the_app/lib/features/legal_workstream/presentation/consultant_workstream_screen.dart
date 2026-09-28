import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/presentation/sessions_tab.dart';
import '../../google_exports/presentation/export_menu_button.dart';
import 'assessment_dashboard_tab.dart';
import 'documents_tab.dart';
import 'recommendations_tab.dart';
import 'tasks_tab.dart';

class ConsultantWorkstreamScreen extends ConsumerWidget {
  const ConsultantWorkstreamScreen({
    super.key,
    required this.enterpriseId,
    required this.enterpriseName,
  });

  final String enterpriseId;
  final String enterpriseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(enterpriseName),
          actions: [ExportMenuButton(enterpriseId: enterpriseId)],
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Tasks'),
            Tab(text: 'Recommendations'),
            Tab(text: 'Documents'),
            Tab(text: 'Sessions'),
          ]),
        ),
        body: TabBarView(children: [
          AssessmentDashboardTab(enterpriseId: enterpriseId, readOnly: false),
          TasksTab(enterpriseId: enterpriseId, readOnly: false),
          RecommendationsTab(enterpriseId: enterpriseId, readOnly: false),
          DocumentsTab(enterpriseId: enterpriseId, readOnly: false),
          SessionsTab(enterpriseId: enterpriseId),
        ]),
      ),
    );
  }
}