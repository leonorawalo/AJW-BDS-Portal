import '../../../shared/models/user_profile.dart';
import '../../enterprises/models/enterprise.dart';
import '../../google_exports/builders/export_formatting.dart';
import '../../visits/models/enterprise_visit.dart';
import 'portfolio_kpis.dart';
import 'programme_clock.dart';

/// A task completed in the report month, or due next month.
class ReportTask {
  const ReportTask({required this.enterpriseId, required this.title, this.specialization, this.date});
  final String enterpriseId;
  final String title;
  final String? specialization;
  final DateTime? date;
}

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
String monthLabel(DateTime m) => '${_monthNames[m.month - 1]} ${m.year}';
String _d(DateTime d) => '${d.day} ${_monthNames[d.month - 1].substring(0, 3)} ${d.year}';

/// The monthly reports the Terms of Reference ask for by the 3rd of the
/// following month (BDS Status Report, BDS Officer Activity Report and the
/// next month's Workplan), built from portal data as one document.
class MonthlyReport {
  MonthlyReport({
    required this.author,
    required this.month,
    required this.kpis,
    required this.visits,
    required this.completed,
    required this.dueNextMonth,
  });

  final String author;

  /// First day of the report month.
  final DateTime month;
  final PortfolioKpis kpis;

  /// Visits in the report month.
  final List<EnterpriseVisit> visits;

  /// ToR and custom tasks completed in the report month.
  final List<ReportTask> completed;

  /// Open tasks due next month: the workplan.
  final List<ReportTask> dueNextMonth;

  String get title => 'BDS monthly report: $author, ${monthLabel(month)}';

  Map<String, Enterprise> get _byId => {for (final e in kpis.enterprises) e.id: e};

  String toHtml() {
    final k = kpis;
    final b = StringBuffer();
    final names = _byId;
    String name(String id) => esc(names[id]?.businessName ?? 'Enterprise');
    final next = DateTime(month.year, month.month + 1);

    b.writeln('<h1>${esc(title)}</h1>');
    b.writeln('<p>Generated from the AJW BAGS Portal on ${_d(DateTime.now())}. '
        'Measures are as at that date; activity is for ${monthLabel(month)}.</p>');

    // ---- 1. BDS Status Report ----
    b.writeln('<h2>1. BDS status</h2>');
    final due = k.dueForGoingConcern.length;
    b.writeln('<table border="1" cellpadding="6"><tr><th>Measure</th><th>Now</th><th>ToR target</th></tr>');
    b.writeln('<tr><td>Clients in portfolio</td><td>${k.portfolioSize}</td><td>At least ${PortfolioKpis.minimumPortfolio}</td></tr>');
    b.writeln('<tr><td>Going concern within 3 months</td><td>'
        '${due == 0 ? 'None past month 3 yet' : '${k.goingConcernOnTime} of $due (${(k.goingConcernOnTime * 100 / due).round()}%)'}'
        '</td><td>${PortfolioKpis.goingConcernTargetPercent}%</td></tr>');
    b.writeln('<tr><td>Going concerns still trading</td><td>${k.survivingGoingConcerns} of ${k.goingConcerns}</td>'
        '<td>${PortfolioKpis.goingConcernTargetPercent}% survival</td></tr>');
    b.writeln('<tr><td>Bankable (loan ready or graduated)</td><td>${k.bankable}</td><td>By month 6</td></tr>');
    b.writeln('<tr><td>Visits in ${monthLabel(month)}</td><td>${visits.length}</td>'
        '<td>2 per business per month</td></tr>');
    b.writeln('<tr><td>Visits logged late (over 2 days)</td><td>${visits.where((v) => v.loggedLate).length}</td><td>0</td></tr>');
    b.writeln('</table>');

    if (k.targets.isNotEmpty) {
      b.writeln('<h3>Deliverable targets</h3>');
      b.writeln('<table border="1" cellpadding="6"><tr><th>ToR deliverable</th><th>Discipline</th><th>Done</th><th>Target</th></tr>');
      for (final t in k.targets) {
        b.writeln('<tr><td>${esc(t.template.title)}</td><td>${esc(t.discipline.label)}</td>'
            '<td>${t.done} of ${t.outOf} (${t.percent.round()}%)</td><td>${t.target}%</td></tr>');
      }
      b.writeln('</table>');
    }

    b.writeln('<h3>Enterprises</h3>');
    b.writeln('<table border="1" cellpadding="6"><tr><th>Enterprise</th><th>Programme month</th><th>Going concern</th><th>Next milestone</th></tr>');
    for (final e in k.enterprises) {
      final c = ProgrammeClock(e);
      b.writeln('<tr><td>${esc(e.businessName)}</td><td>${c.month} of 12</td>'
          '<td>${c.goingConcernAchieved ? 'Yes' : 'Not yet'}</td><td>${esc(c.headline)}</td></tr>');
    }
    b.writeln('</table>');

    // ---- 2. BDS Officer Activity Report ----
    b.writeln('<h2>2. Activity in ${monthLabel(month)}</h2>');
    b.writeln('<h3>Visits</h3>');
    if (visits.isEmpty) {
      b.writeln('<p>No visits logged.</p>');
    } else {
      b.writeln('<table border="1" cellpadding="6"><tr><th>Date</th><th>Enterprise</th><th>By</th><th>Outcome</th><th>Next steps</th></tr>');
      for (final v in [...visits]..sort((a, z) => a.visitedOn.compareTo(z.visitedOn))) {
        b.writeln('<tr><td>${_d(v.visitedOn)}${v.loggedLate ? ' (logged late)' : ''}</td><td>${name(v.enterpriseId)}</td>'
            '<td>${esc(v.consultantName)}${v.specialization != null ? ', ${esc(v.specialization)}' : ''}</td>'
            '<td>${esc(v.outcome)}</td><td>${esc(v.nextSteps)}</td></tr>');
      }
      b.writeln('</table>');
    }
    b.writeln('<h3>Tasks completed</h3>');
    if (completed.isEmpty) {
      b.writeln('<p>None this month.</p>');
    } else {
      b.writeln('<ul>');
      for (final t in completed) {
        b.writeln('<li>${name(t.enterpriseId)}: ${esc(t.title)}'
            '${t.specialization != null ? ' (${esc(t.specialization)})' : ''}'
            '${t.date != null ? ', ${_d(t.date!)}' : ''}</li>');
      }
      b.writeln('</ul>');
    }

    // ---- 3. Workplan ----
    b.writeln('<h2>3. Workplan for ${monthLabel(next)}</h2>');
    b.writeln('<p>Two visits to each business, plus the tasks below (due next month) and the next steps agreed at visits.</p>');
    if (dueNextMonth.isEmpty) {
      b.writeln('<p>No tasks due next month.</p>');
    } else {
      b.writeln('<ul>');
      for (final t in dueNextMonth) {
        b.writeln('<li>${name(t.enterpriseId)}: ${esc(t.title)}${t.date != null ? ' (due ${_d(t.date!)})' : ''}</li>');
      }
      b.writeln('</ul>');
    }
    final steps = visits.where((v) => (v.nextSteps ?? '').trim().isNotEmpty).toList();
    if (steps.isNotEmpty) {
      b.writeln('<h3>Next steps from visits</h3><ul>');
      for (final v in steps) {
        b.writeln('<li>${name(v.enterpriseId)}: ${esc(v.nextSteps)}</li>');
      }
      b.writeln('</ul>');
    }

    b.writeln('<h2>4. Success stories</h2>');
    b.writeln('<p>(Add this month\'s success stories here.)</p>');
    return b.toString();
  }
}
