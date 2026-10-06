import '../../enterprises/models/enterprise.dart';
import '../../legal_workstream/models/loan_readiness.dart';
import '../models/enterprise_export_data.dart';
import '../models/loan_readiness_report.dart';
import 'export_formatting.dart';

/// The report's content: the single definition shared by the Google Doc
/// (renderLoanReadinessReportHtml) and the PDF (loan_readiness_report_pdf.dart).
LoanReadinessReport buildLoanReadinessReport(EnterpriseExportData d) {
  final e = d.enterprise;
  final i = d.inputs;
  String orDash(String? v) => v == null || v.trim().isEmpty ? '-' : v;

  return LoanReadinessReport(
    enterpriseName: e.businessName,
    exportedBy: d.exportedBy,
    exportedAt: d.exportedAt,
    enterpriseFacts: [
      ('Owner', orDash(e.ownerName)),
      ('Industry', orDash(e.industry)),
      ('County', orDash(e.county)),
      ('Lifecycle status', e.lifecycleStatus.label),
      ('Going Concern', e.goingConcernStatus.dbValue),
      ('Enrolled', exportDate(e.enrolledAt)),
    ],
    scores: [
      (label: 'Business Health', score: d.businessHealth, band: LoanReadiness.band(d.businessHealth)),
      (label: 'Credit Readiness', score: d.creditReadiness, band: LoanReadiness.band(d.creditReadiness)),
    ],
    kcbRequirements: LoanReadiness.kcbRequirements(i),
    redFlags: LoanReadiness.redFlags(i),
    drivers: [
      for (final (done, label, source) in LoanReadiness.drivers(i)) (done: done, label: label, source: source),
    ],
    financialFacts: [
      ('Annual turnover', exportMoney(i.annualTurnover)),
      ('Years in operation', i.yearsInOperation?.toString() ?? 'Not recorded'),
      ('Loan purpose', orDash(i.loanPurpose)),
    ],
  );
}

/// The report as HTML. google-export uploads it with conversion to a
/// Google Doc, which turns headings, lists and tables into native Docs
/// formatting.
String renderLoanReadinessReportHtml(LoanReadinessReport r) {
  final b = StringBuffer()
    ..write('<html><head><meta charset="utf-8"></head><body>')
    ..write('<h1>Loan-readiness report: ${esc(r.enterpriseName)}</h1>')
    ..write('<p><i>Exported ${esc(exportDateTime(r.exportedAt))} by ${esc(r.exportedBy)} '
        'from the AJW BAGS Portal. ${LoanReadinessReport.disclaimer}</i></p>')
    ..write('<h2>Enterprise</h2>')
    ..write(_factsTable(r.enterpriseFacts))
    ..write('<h2>Scores</h2><table border="1" cellpadding="4">')
    ..write('<tr><th>Measure</th><th>Score</th><th>Band</th></tr>');
  for (final s in r.scores) {
    b.write('<tr><td>${esc(s.label)}</td><td>${exportScore(s.score)}</td><td>${esc(s.band)}</td></tr>');
  }
  b
    ..write('</table>')
    ..write('<h2>KCB MSME requirements: ${r.kcbMetCount} of ${r.kcbRequirements.length} met</h2>')
    ..write('<table border="1" cellpadding="4"><tr><th>Requirement</th><th>Status</th></tr>');
  for (final (met, label) in r.kcbRequirements) {
    b.write('<tr><td>${esc(label)}</td><td>${met ? 'Met' : 'Not yet'}</td></tr>');
  }
  b
    ..write('</table>')
    ..write('<h2>Red flags</h2>');
  if (r.redFlags.isEmpty) {
    b.write('<p>No red flags right now.</p>');
  } else {
    b.write('<ul>');
    for (final f in r.redFlags) {
      b.write('<li>${esc(f)}</li>');
    }
    b.write('</ul>');
  }
  b
    ..write("<h2>What's driving the score</h2>")
    ..write('<table border="1" cellpadding="4">'
        '<tr><th>Criterion</th><th>Status</th><th>Satisfied by</th></tr>');
  for (final d in r.drivers) {
    b.write('<tr><td>${esc(d.label)}</td><td>${d.done ? 'Done' : 'Outstanding'}</td>'
        '<td>${esc(d.source)}</td></tr>');
  }
  b
    ..write('</table>')
    ..write('<h2>Financial facts</h2>')
    ..write(_factsTable(r.financialFacts))
    ..write('</body></html>');
  return b.toString();
}

String _factsTable(List<(String, String)> rows) {
  final b = StringBuffer('<table border="1" cellpadding="4">');
  for (final (label, value) in rows) {
    b.write('<tr><td><b>${esc(label)}</b></td><td>${esc(value)}</td></tr>');
  }
  return (b..write('</table>')).toString();
}
