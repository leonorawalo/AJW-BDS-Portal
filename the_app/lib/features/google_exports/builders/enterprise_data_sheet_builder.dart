import '../../calendar/models/consultation_session.dart';
import '../../legal_workstream/models/loan_readiness.dart';
import '../../legal_workstream/models/recommendation.dart';
import '../../legal_workstream/models/task.dart';
import '../models/enterprise_export_data.dart';
import '../models/sheet_tab.dart';
import 'export_formatting.dart';

/// The enterprise data workbook: loan readiness, tasks, recommendations
/// and sessions, one tab each. Tasks and sessions contain only what the
/// exporting user can see.
List<SheetTab> buildEnterpriseDataSheet(EnterpriseExportData d) {
  final i = d.inputs;

  final readiness = <List<Object?>>[
    ['Measure', 'Value'],
    ['Business Health (/100)', d.businessHealth],
    ['Credit Readiness (/100)', d.creditReadiness],
    for (final (met, label) in LoanReadiness.kcbRequirements(i)) ['KCB: $label', met ? 'Met' : 'Not yet'],
    for (final (done, label, _) in LoanReadiness.drivers(i)) [label, done ? 'Done' : 'Outstanding'],
    ['Annual turnover (KSh)', i.annualTurnover],
    ['Years in operation', i.yearsInOperation],
    ['Loan purpose', i.loanPurpose ?? ''],
  ];

  final tasks = <List<Object?>>[
    ['Title', 'Discipline', 'Status', 'Priority', 'Due date', 'Completed'],
    for (final t in d.tasks)
      [
        t.title,
        t.specialization ?? '',
        t.status.dbValue,
        t.priority.dbValue,
        exportDate(t.dueDate),
        exportDate(t.completedAt),
      ],
  ];

  final recommendations = <List<Object?>>[
    ['Recommendation', 'Status', 'Created'],
    for (final r in d.recommendations) [r.recommendationText, r.status.dbValue, exportDate(r.createdAt)],
  ];

  final sessions = <List<Object?>>[
    ['Title', 'Starts', 'Ends', 'Status', 'Organizer', 'Meet link'],
    for (final s in d.sessions)
      [
        s.title,
        exportDateTime(s.startsAt),
        exportDateTime(s.endsAt),
        s.status.dbValue,
        d.sessionPeople
            .where((p) => p.sessionId == s.id && p.isOrganizer)
            .map((p) => p.fullName)
            .join(', '),
        s.meetLink ?? '',
      ],
  ];

  return [
    SheetTab(name: 'Loan readiness', rows: readiness),
    SheetTab(name: 'Tasks', rows: tasks),
    SheetTab(name: 'Recommendations', rows: recommendations),
    SheetTab(name: 'Sessions', rows: sessions),
  ];
}
