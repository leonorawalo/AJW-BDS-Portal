import '../../enterprises/models/enterprise.dart';
import '../../legal_workstream/models/loan_readiness.dart';
import '../models/enterprise_export_data.dart';
import 'export_formatting.dart';

/// The loan-readiness report as HTML. google-export uploads it with
/// conversion to a Google Doc, which turns headings, lists and tables
/// into native Docs formatting.
String buildLoanReadinessReportHtml(EnterpriseExportData d) {
  final e = d.enterprise;
  final i = d.inputs;
  final kcb = LoanReadiness.kcbRequirements(i);
  final flags = LoanReadiness.redFlags(i);
  final metCount = kcb.where((r) => r.$1).length;

  final b = StringBuffer()
    ..write('<html><head><meta charset="utf-8"></head><body>')
    ..write('<h1>Loan-readiness report: ${esc(e.businessName)}</h1>')
    ..write('<p><i>Exported ${esc(exportDateTime(d.exportedAt))} by ${esc(d.exportedBy)} '
        'from the AJW BAGS Portal. Scores are computed from completed ToR tasks '
        'and are not a prediction of loan approval.</i></p>')
    ..write('<h2>Enterprise</h2><table border="1" cellpadding="4">')
    ..write(_row('Owner', e.ownerName))
    ..write(_row('Industry', e.industry))
    ..write(_row('County', e.county))
    ..write(_row('Lifecycle status', e.lifecycleStatus.label))
    ..write(_row('Going Concern', e.goingConcernStatus.dbValue))
    ..write(_row('Enrolled', exportDate(e.enrolledAt)))
    ..write('</table>')
    ..write('<h2>Scores</h2><table border="1" cellpadding="4">')
    ..write('<tr><th>Measure</th><th>Score</th><th>Band</th></tr>')
    ..write(_scoreRow('Business Health', d.businessHealth))
    ..write(_scoreRow('Credit Readiness', d.creditReadiness))
    ..write('</table>')
    ..write('<h2>KCB MSME requirements: $metCount of ${kcb.length} met</h2>')
    ..write('<table border="1" cellpadding="4"><tr><th>Requirement</th><th>Status</th></tr>');
  for (final (met, label) in kcb) {
    b.write('<tr><td>${esc(label)}</td><td>${met ? 'Met' : 'Not yet'}</td></tr>');
  }
  b
    ..write('</table>')
    ..write('<h2>Red flags</h2>');
  if (flags.isEmpty) {
    b.write('<p>No red flags right now.</p>');
  } else {
    b.write('<ul>');
    for (final f in flags) {
      b.write('<li>${esc(f)}</li>');
    }
    b.write('</ul>');
  }
  b
    ..write("<h2>What's driving the score</h2>")
    ..write('<table border="1" cellpadding="4">'
        '<tr><th>Criterion</th><th>Status</th><th>Satisfied by</th></tr>');
  for (final (done, label, source) in LoanReadiness.drivers(i)) {
    b.write('<tr><td>${esc(label)}</td><td>${done ? 'Done' : 'Outstanding'}</td>'
        '<td>${esc(source)}</td></tr>');
  }
  b
    ..write('</table>')
    ..write('<h2>Financial facts</h2><table border="1" cellpadding="4">')
    ..write(_row('Annual turnover', exportMoney(i.annualTurnover)))
    ..write(_row('Years in operation', i.yearsInOperation?.toString() ?? 'Not recorded'))
    ..write(_row('Loan purpose', i.loanPurpose ?? 'Not recorded'))
    ..write('</table></body></html>');
  return b.toString();
}

String _row(String label, String? value) => '<tr><td><b>${esc(label)}</b></td>'
    '<td>${esc(value == null || value.isEmpty ? '—' : value)}</td></tr>';

String _scoreRow(String label, double score) =>
    '<tr><td>$label</td><td>${exportScore(score)}</td><td>${LoanReadiness.band(score)}</td></tr>';
