import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/features/enterprises/models/enterprise.dart';
import 'package:the_app/features/google_exports/builders/loan_readiness_report_builder.dart';
import 'package:the_app/features/google_exports/builders/loan_readiness_report_pdf.dart';
import 'package:the_app/features/google_exports/builders/portfolio_sheet_builder.dart';
import 'package:the_app/features/google_exports/models/enterprise_export_data.dart';
import 'package:the_app/features/google_exports/models/portfolio_row.dart';
import 'package:the_app/features/legal_workstream/models/loan_readiness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final enterprise = Enterprise(
    id: 'e1',
    businessName: 'Blue Farm <Ltd> – Nairobi',
    ownerName: 'Wanjiru Kamau',
    county: 'Nairobi',
    industry: 'Agriculture',
    registrationNumber: 'BN-123',
    lifecycleStatus: LifecycleStatusX.fromDb('Active'),
    goingConcernStatus: GoingConcernStatusX.fromDb('Not Yet'),
    enrolledAt: DateTime(2026, 8, 1),
    annualTurnover: 6200000,
    businessStartedDate: DateTime(2023, 1, 1),
    loanPurpose: 'Buy a “cold room” for produce',
  );

  EnterpriseExportData data({required Set<String> completed}) => EnterpriseExportData(
        enterprise: enterprise,
        inputs: LoanReadinessInputs.from(enterprise: enterprise, completedTaskTitles: completed),
        tasks: const [],
        recommendations: const [],
        sessions: const [],
        sessionPeople: const [],
        exportedBy: 'Test Consultant',
        exportedAt: DateTime(2026, 9, 28, 14, 30),
      );

  test('report content comes from the shared scoring (no duplicated logic)', () {
    final d = data(completed: {'Acquire KRA PIN', 'Confirm monthly KRA returns filed'});
    final report = buildLoanReadinessReport(d);

    expect(report.scores.first.score, LoanReadiness.businessHealthScore(d.inputs));
    expect(report.scores.last.score, LoanReadiness.creditReadinessScore(d.inputs));
    expect(report.kcbRequirements, LoanReadiness.kcbRequirements(d.inputs));
    expect(report.redFlags, LoanReadiness.redFlags(d.inputs));
    expect(report.kcbMetCount, LoanReadiness.kcbRequirementsMet(d.inputs).length);
  });

  test('HTML report escapes user-entered text', () {
    final html = renderLoanReadinessReportHtml(buildLoanReadinessReport(data(completed: {})));
    expect(html, contains('Blue Farm &lt;Ltd&gt;'));
    expect(html, isNot(contains('<Ltd>')));
    expect(html, contains('KCB MSME requirements'));
  });

  test('PDF renders (with logo and non-Latin-1 text) to a valid PDF', () async {
    final bytes = await renderLoanReadinessReportPdf(buildLoanReadinessReport(data(completed: {})));
    expect(bytes.length, greaterThan(2000));
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('portfolio sheet has one header row plus one row per enterprise', () {
    final tabs = buildPortfolioSheet([
      PortfolioRow(
        enterpriseName: 'Blue Farm',
        lifecycleStatus: 'Active',
        goingConcern: 'Not Yet',
        businessHealth: 55,
        creditReadiness: 25,
        kcbMet: 4,
        kcbTotal: 10,
        consultantsByDiscipline: const {'Legal': 'Milagros Nagoria'},
        openTasks: 3,
        completedTasks: 12,
        lastActivity: DateTime(2026, 9, 27),
      ),
    ]);
    final rows = tabs.single.rows;
    expect(rows, hasLength(2));
    expect(rows[0].length, rows[1].length);
    expect(rows[1], containsAllInOrder(['Blue Farm', 'Active', 'Not Yet', 55.0, 25.0, '4/10', 'Milagros Nagoria']));
  });
}
