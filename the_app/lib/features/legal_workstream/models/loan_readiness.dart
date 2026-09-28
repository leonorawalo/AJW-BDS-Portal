import '../../enterprises/models/enterprise.dart';

/// Every ToR task title the scores below depend on. The dashboard asks the
/// server which of these are completed (completed_loan_readiness_tasks),
/// rather than reading tasks directly — consultants can only read their
/// own discipline's tasks, but the scores span all of them.
const loanReadinessTaskTitles = [
  'Complete business registration',
  'Acquire KRA PIN',
  'Confirm monthly KRA returns filed',
  'Acquire trading licenses',
  'Set up financial record-keeping system',
  'Compile 6 months of bank statements',
  'Obtain 3 years of audited accounts',
  'Document available collateral for financing',
  'Check CRB status',
];

/// Everything the loan-readiness dashboard needs, resolved from live
/// data — ToR task completion (see standardLegalChecklist /
/// standardAccountingChecklist in task_template.dart) plus the handful
/// of enterprise facts nothing else captures (annual turnover, when
/// the business started, loan purpose). Titles here are matched
/// exactly against those checklists — keep them in sync if either
/// changes.
class LoanReadinessInputs {
  const LoanReadinessInputs({
    required this.isRegistered,
    required this.hasKraPin,
    required this.filesKraReturns,
    required this.hasBusinessPermit,
    required this.hasFinancialRecords,
    required this.hasSixMonthsBankStatements,
    required this.hasAuditedAccounts,
    required this.hasCollateral,
    required this.crbChecked,
    required this.annualTurnover,
    required this.yearsInOperation,
    required this.loanPurpose,
  });

  factory LoanReadinessInputs.from({
    required Enterprise enterprise,
    required Set<String> completedTaskTitles,
  }) {
    return LoanReadinessInputs(
      // registration_number / kraPin (set by Admin at enterprise
      // registration, or already known) are treated as equally valid
      // evidence alongside the matching Legal task being marked done —
      // whichever happened first.
      isRegistered:
          enterprise.registrationNumber != null || completedTaskTitles.contains('Complete business registration'),
      hasKraPin: enterprise.kraPin != null || completedTaskTitles.contains('Acquire KRA PIN'),
      filesKraReturns: completedTaskTitles.contains('Confirm monthly KRA returns filed'),
      hasBusinessPermit: completedTaskTitles.contains('Acquire trading licenses'),
      hasFinancialRecords: completedTaskTitles.contains('Set up financial record-keeping system'),
      hasSixMonthsBankStatements: completedTaskTitles.contains('Compile 6 months of bank statements'),
      hasAuditedAccounts: completedTaskTitles.contains('Obtain 3 years of audited accounts'),
      hasCollateral: completedTaskTitles.contains('Document available collateral for financing'),
      crbChecked: completedTaskTitles.contains('Check CRB status'),
      annualTurnover: enterprise.annualTurnover,
      yearsInOperation: enterprise.businessStartedDate == null
          ? null
          : DateTime.now().difference(enterprise.businessStartedDate!).inDays ~/ 365,
      loanPurpose: enterprise.loanPurpose,
    );
  }

  final bool isRegistered;
  final bool hasKraPin;
  final bool filesKraReturns;
  final bool hasBusinessPermit;
  final bool hasFinancialRecords;
  final bool hasSixMonthsBankStatements;
  final bool hasAuditedAccounts;
  final bool hasCollateral;
  final bool crbChecked;
  final double? annualTurnover;
  final int? yearsInOperation;
  final String? loanPurpose;

  bool get taxCompliant => hasKraPin && filesKraReturns;
}

/// Pure scoring functions over [LoanReadinessInputs] — deliberately
/// simple (weighted checklist, not a full financial-ratio engine), per
/// this project's scope for the feature.
class LoanReadiness {
  const LoanReadiness._();

  /// "How organized/formalized is this business" — independent of
  /// whether it's seeking financing right now.
  static double businessHealthScore(LoanReadinessInputs i) {
    var score = 0.0;
    if (i.isRegistered) score += 25;
    if (i.taxCompliant) score += 25;
    if (i.yearsInOperation != null) {
      score += i.yearsInOperation! >= 2
          ? 25
          : i.yearsInOperation! >= 1
              ? 15
              : 5;
    }
    if (i.hasFinancialRecords) score += 25;
    return score;
  }

  /// The specific factors a lender checks — bank statement history,
  /// turnover threshold, collateral, audited accounts.
  static double creditReadinessScore(LoanReadinessInputs i) {
    var score = 0.0;
    if (i.hasSixMonthsBankStatements) score += 25;
    if (i.annualTurnover != null && i.annualTurnover! >= 500000) score += 25;
    if (i.hasCollateral) score += 25;
    if (i.hasAuditedAccounts) score += 25;
    return score;
  }

  /// The publicly-documented KCB MSME Loan Offer criteria this app can
  /// actually evaluate. States how many are met today — never a
  /// prediction of loan approval (KCB's own decision uses an internal
  /// scoring model this app has no access to).
  static List<(bool, String)> kcbRequirements(LoanReadinessInputs i) {
    return [
      (i.isRegistered, 'Registered business'),
      (i.yearsInOperation != null && i.yearsInOperation! >= 2, '2+ years operating'),
      (i.annualTurnover != null && i.annualTurnover! >= 500000, 'KSh 500K+ annual turnover'),
      (i.hasSixMonthsBankStatements, '6 months of bank statements'),
      (i.hasBusinessPermit, 'Valid business permit'),
      (i.taxCompliant, 'Tax Compliance Certificate'),
      (i.crbChecked, 'CRB status checked'),
      (i.hasFinancialRecords, 'Financial records available'),
      (i.loanPurpose != null && i.loanPurpose!.trim().isNotEmpty, 'Loan purpose documented'),
      (i.hasCollateral, 'Security/collateral documented'),
    ];
  }

  static List<String> kcbRequirementsMet(LoanReadinessInputs i) =>
      [for (final (met, label) in kcbRequirements(i)) if (met) label];

  /// Each task-derived criterion: (satisfied, label, which ToR task
  /// satisfies it) — "why is my score X", for the dashboard and exports.
  static List<(bool, String, String)> drivers(LoanReadinessInputs i) {
    return [
      (i.isRegistered, 'Business registered', 'Task: Complete business registration'),
      (i.taxCompliant, 'Tax compliant', 'Tasks: Acquire KRA PIN + Confirm monthly KRA returns filed'),
      (i.hasBusinessPermit, 'Valid business permit', 'Task: Acquire trading licenses'),
      (i.hasFinancialRecords, 'Financial record-keeping', 'Task: Set up financial record-keeping system'),
      (i.hasSixMonthsBankStatements, '6 months of bank statements', 'Task: Compile 6 months of bank statements'),
      (i.hasAuditedAccounts, 'Audited accounts (3 yrs)', 'Task: Obtain 3 years of audited accounts'),
      (i.hasCollateral, 'Collateral documented', 'Task: Document available collateral for financing'),
      (i.crbChecked, 'CRB status checked', 'Task: Check CRB status'),
    ];
  }

  /// Strong / Developing / Weak, as the dashboard shows it.
  static String band(double score) => score >= 70
      ? 'Strong'
      : score >= 40
          ? 'Developing'
          : 'Weak';

  /// Risk flags for the consultant to review — informational, never a
  /// pass/fail gate (mirrors CBK guidance that a credit score/flag
  /// should be one input to appraisal, not the sole basis for a
  /// lending decision).
  static List<String> redFlags(LoanReadinessInputs i) {
    return [
      if (!i.isRegistered) 'Business is not formally registered',
      if (!i.taxCompliant) 'Not tax compliant',
      if (!i.hasSixMonthsBankStatements) 'Less than 6 months of consistent bank statements',
      if (!i.hasCollateral) 'No collateral currently documented',
      if (i.annualTurnover != null && i.annualTurnover! > 5000000 && !i.hasAuditedAccounts)
        "Turnover exceeds KSh 5M but no audited accounts (KCB requires 3 years' books above this threshold)",
      if (i.yearsInOperation != null && i.yearsInOperation! < 2) 'Less than 2 years of operating history',
    ];
  }
}
