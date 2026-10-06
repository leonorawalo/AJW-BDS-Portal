import '../../enterprises/models/enterprise.dart';

/// Every ToR task title the scores below depend on. The dashboard asks the
/// server which of these are completed (completed_loan_readiness_tasks),
/// rather than reading tasks directly: consultants can only read their
/// own discipline's tasks, but the scores span all of them.
const loanReadinessTaskTitles = [
  // Legal
  'Complete business registration',
  'Acquire KRA PIN',
  'Acquire trading licenses',
  'Confirm monthly KRA returns filed',
  'Obtain KRA Tax Compliance Certificate',
  // Accounting
  'Open a business bank account',
  'Set up financial record-keeping system',
  'Produce monthly financial reports',
  'File monthly KRA returns with the owner',
  'Compile 6 months of bank statements',
  'Document available collateral for financing',
  'Check CRB status',
  'Obtain 3 years of audited accounts',
];

/// Everything the loan-readiness dashboard needs, resolved from live data:
/// ToR task completion (task_template.dart) plus the enterprise facts no
/// task captures (annual turnover, when the business started, loan
/// purpose). Titles here are matched exactly against the checklists; a
/// unit test keeps them in sync.
class LoanReadinessInputs {
  const LoanReadinessInputs({
    required this.isRegistered,
    required this.hasKraPin,
    required this.hasBusinessPermit,
    required this.hasBankAccount,
    required this.hasFinancialRecords,
    required this.filesKraReturns,
    required this.hasTaxCertificate,
    required this.hasMonthlyReports,
    required this.hasSixMonthsBankStatements,
    required this.hasCollateral,
    required this.crbChecked,
    required this.hasAuditedAccounts,
    required this.annualTurnover,
    required this.yearsInOperation,
    required this.loanPurpose,
  });

  factory LoanReadinessInputs.from({
    required Enterprise enterprise,
    required Set<String> completedTaskTitles,
  }) {
    bool done(String title) => completedTaskTitles.contains(title);
    return LoanReadinessInputs(
      // A registration number / KRA PIN recorded on the enterprise counts
      // the same as the matching Legal task marked done.
      isRegistered: enterprise.registrationNumber != null || done('Complete business registration'),
      hasKraPin: enterprise.kraPin != null || done('Acquire KRA PIN'),
      hasBusinessPermit: done('Acquire trading licenses'),
      hasBankAccount: done('Open a business bank account'),
      hasFinancialRecords: done('Set up financial record-keeping system'),
      // Legal confirms the returns; Accounting files them with the owner.
      // Either one being done means the returns are being filed.
      filesKraReturns: done('Confirm monthly KRA returns filed') || done('File monthly KRA returns with the owner'),
      hasTaxCertificate: done('Obtain KRA Tax Compliance Certificate'),
      hasMonthlyReports: done('Produce monthly financial reports'),
      hasSixMonthsBankStatements: done('Compile 6 months of bank statements'),
      hasCollateral: done('Document available collateral for financing'),
      crbChecked: done('Check CRB status'),
      hasAuditedAccounts: done('Obtain 3 years of audited accounts'),
      annualTurnover: enterprise.annualTurnover,
      yearsInOperation: enterprise.businessStartedDate == null
          ? null
          : DateTime.now().difference(enterprise.businessStartedDate!).inDays ~/ 365,
      loanPurpose: enterprise.loanPurpose,
    );
  }

  final bool isRegistered;
  final bool hasKraPin;
  final bool hasBusinessPermit;
  final bool hasBankAccount;
  final bool hasFinancialRecords;
  final bool filesKraReturns;
  final bool hasTaxCertificate;
  final bool hasMonthlyReports;
  final bool hasSixMonthsBankStatements;
  final bool hasCollateral;
  final bool crbChecked;
  final bool hasAuditedAccounts;
  final double? annualTurnover;
  final int? yearsInOperation;
  final String? loanPurpose;
}

/// The loan-readiness scores: a weighted checklist over completed ToR
/// tasks, not a financial-ratio model. Neither score nor its weights come
/// from the ToR (it only says "bankable by month 6"); they are this
/// portal's guide, weighed by what each factor proves (6 Oct 2026):
///
/// Business Health, "is this a formal, working business?" The going-
/// concern foundations, mostly due in the first 3 months:
///   registered 20 · records kept 20 · KRA PIN 15 · trading licences 15 ·
///   business bank account 15 · operating history up to 15.
///   Registration and records weigh most: without them nothing else can
///   be shown to a lender.
///
/// Credit Readiness, "what would a lender ask to see?" The bankable
/// evidence, mostly due by month 6:
///   6 months of bank statements 25 · collateral 20 · Tax Compliance
///   Certificate 15 · monthly financial reports 15 · CRB checked 15 ·
///   KRA returns filed 10.
///   Statements weigh most: they are the cash-flow proof every lender
///   asks for first; collateral next, for secured lending.
///
/// Audited accounts are not scored: they're only needed for loans above
/// KSh 5 million (a red flag covers that case).
class LoanReadiness {
  const LoanReadiness._();

  /// Operating history points: 2+ years 15, 1 year 10, under a year 5,
  /// unknown (no start date) 0.
  static double operatingHistoryPoints(int? years) => years == null
      ? 0
      : years >= 2
          ? 15
          : years >= 1
              ? 10
              : 5;

  static double businessHealthScore(LoanReadinessInputs i) {
    var score = 0.0;
    if (i.isRegistered) score += 20;
    if (i.hasFinancialRecords) score += 20;
    if (i.hasKraPin) score += 15;
    if (i.hasBusinessPermit) score += 15;
    if (i.hasBankAccount) score += 15;
    score += operatingHistoryPoints(i.yearsInOperation);
    return score;
  }

  static double creditReadinessScore(LoanReadinessInputs i) {
    var score = 0.0;
    if (i.hasSixMonthsBankStatements) score += 25;
    if (i.hasCollateral) score += 20;
    if (i.hasTaxCertificate) score += 15;
    if (i.hasMonthlyReports) score += 15;
    if (i.crbChecked) score += 15;
    if (i.filesKraReturns) score += 10;
    return score;
  }

  /// The published KCB MSME loan criteria this app can check. States how
  /// many are met today; never a prediction of approval (KCB decides with
  /// its own internal model).
  static List<(bool, String)> kcbRequirements(LoanReadinessInputs i) {
    return [
      (i.isRegistered, 'Registered business'),
      (i.yearsInOperation != null && i.yearsInOperation! >= 2, '2+ years operating'),
      (i.hasSixMonthsBankStatements, '6 months of bank statements'),
      (i.hasBusinessPermit, 'Valid business permit'),
      (i.hasTaxCertificate, 'Tax Compliance Certificate'),
      (i.crbChecked, 'CRB status checked'),
      (i.hasFinancialRecords, 'Financial records available'),
      (i.loanPurpose != null && i.loanPurpose!.trim().isNotEmpty, 'Loan purpose documented'),
      (i.hasCollateral, 'Security/collateral documented'),
    ];
  }

  static List<String> kcbRequirementsMet(LoanReadinessInputs i) =>
      [for (final (met, label) in kcbRequirements(i)) if (met) label];

  /// Each task-based factor: (done, label, which ToR task does it), in
  /// score order, Business Health first. "Why is my score X", for the
  /// dashboard and exports.
  static List<(bool, String, String)> drivers(LoanReadinessInputs i) {
    return [
      (i.isRegistered, 'Business registered', 'Task: Complete business registration'),
      (i.hasFinancialRecords, 'Financial records kept', 'Task: Set up financial record-keeping system'),
      (i.hasKraPin, 'KRA PIN', 'Task: Acquire KRA PIN'),
      (i.hasBusinessPermit, 'Trading licences', 'Task: Acquire trading licenses'),
      (i.hasBankAccount, 'Business bank account', 'Task: Open a business bank account'),
      (i.hasSixMonthsBankStatements, '6 months of bank statements', 'Task: Compile 6 months of bank statements'),
      (i.hasCollateral, 'Collateral documented', 'Task: Document available collateral for financing'),
      (i.hasTaxCertificate, 'Tax Compliance Certificate', 'Task: Obtain KRA Tax Compliance Certificate'),
      (i.hasMonthlyReports, 'Monthly financial reports', 'Task: Produce monthly financial reports'),
      (i.crbChecked, 'CRB status checked', 'Task: Check CRB status'),
      (i.filesKraReturns, 'Monthly KRA returns filed', 'Task: Confirm monthly KRA returns filed (Legal) or File monthly KRA returns with the owner (Accounting)'),
    ];
  }

  /// Strong / Developing / Weak, as the dashboard shows it.
  static String band(double score) => score >= 70
      ? 'Strong'
      : score >= 40
          ? 'Developing'
          : 'Weak';

  /// Risk flags for the consultant to review: information, never a
  /// pass/fail gate (CBK guidance: a credit score or flag is one input to
  /// an appraisal, not the sole basis for a lending decision).
  static List<String> redFlags(LoanReadinessInputs i) {
    return [
      if (!i.isRegistered) 'Business is not formally registered',
      if (!i.filesKraReturns) 'Monthly KRA returns not confirmed as filed',
      if (!i.hasSixMonthsBankStatements) 'Less than 6 months of consistent bank statements',
      if (!i.hasCollateral) 'No collateral currently documented',
      if (i.annualTurnover != null && i.annualTurnover! > 5000000 && !i.hasAuditedAccounts)
        "Turnover exceeds KSh 5M but no audited accounts (KCB asks for 3 years' books above this level)",
      if (i.yearsInOperation != null && i.yearsInOperation! < 2) 'Less than 2 years of operating history',
    ];
  }
}
