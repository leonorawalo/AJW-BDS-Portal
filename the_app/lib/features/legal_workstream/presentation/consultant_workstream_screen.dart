import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(enterpriseName),
          bottom: const TabBar(tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Tasks'),
            Tab(text: 'Recommendations'),
            Tab(text: 'Documents'),
          ]),
        ),
        body: TabBarView(children: [
          AssessmentDashboardTab(enterpriseId: enterpriseId, readOnly: false),
          TasksTab(enterpriseId: enterpriseId, readOnly: false),
          RecommendationsTab(enterpriseId: enterpriseId, readOnly: false),
          DocumentsTab(enterpriseId: enterpriseId, readOnly: false),
        ]),
      ),
    );
  }
}