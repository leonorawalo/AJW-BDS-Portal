/// One score line: measure, 0–100 score, Strong/Developing/Weak band.
typedef ReportScore = ({String label, double score, String band});

/// One "what's driving the score" line: whether it's satisfied, the
/// criterion, and which ToR task satisfies it.
typedef ReportDriver = ({bool done, String label, String source});

/// The loan-readiness report's content, built once from the enterprise's
/// data (buildLoanReadinessReport) and rendered two ways: HTML for the
/// Google Doc, and a PDF generated on the device: so both always say the
/// same thing.
class LoanReadinessReport {
  const LoanReadinessReport({
    required this.enterpriseName,
    required this.exportedBy,
    required this.exportedAt,
    required this.enterpriseFacts,
    required this.scores,
    required this.kcbRequirements,
    required this.redFlags,
    required this.drivers,
    required this.financialFacts,
  });

  final String enterpriseName;
  final String exportedBy;
  final DateTime exportedAt;

  /// (label, value) rows: owner, industry, county, lifecycle, …
  final List<(String, String)> enterpriseFacts;
  final List<ReportScore> scores;

  /// (met, requirement)
  final List<(bool, String)> kcbRequirements;
  final List<String> redFlags;
  final List<ReportDriver> drivers;

  /// (label, value) rows: turnover, years in operation, loan purpose.
  final List<(String, String)> financialFacts;

  int get kcbMetCount => kcbRequirements.where((r) => r.$1).length;

  static const disclaimer = 'Scores are computed from completed ToR tasks and are not '
      'a prediction of loan approval.';
}
