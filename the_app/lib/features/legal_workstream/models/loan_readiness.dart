import '../../enterprises/models/enterprise.dart';
import 'task.dart';

bool _isTaskComplete(List<WorkstreamTask> tasks, String title) {
  for (final t in tasks) {
    if (t.title == title && t.status == TaskStatus.completed) return true;
  }
  return false;
}

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
    required List<WorkstreamTask> tasks,
  }) {
    return LoanReadinessInputs(
      // registration_number / kraPin (set by Admin at enterprise
      // registration, or already known) are treated as equally valid
      // evidence alongside the matching Legal task being marked done —
      // whichever happened first.
      isRegistered:
          enterprise.registrationNumber != null || _isTaskComplete(tasks, 'Complete business registration'),
      hasKraPin: enterprise.kraPin != null || _isTaskComplete(tasks, 'Acquire KRA PIN'),
      filesKraReturns: _isTaskComplete(tasks, 'Confirm monthly KRA returns filed'),
      hasBusinessPermit: _isTaskComplete(tasks, 'Acquire trading licenses'),
      hasFinancialRecords: _isTaskComplete(tasks, 'Set up financial record-keeping system'),
      hasSixMonthsBankStatements: _isTaskComplete(tasks, 'Compile 6 months of bank statements'),
      hasAuditedAccounts: _isTaskComplete(tasks, 'Obtain 3 years of audited accounts'),
      hasCollateral: _isTaskComplete(tasks, 'Document available collateral for financing'),
      crbChecked: _isTaskComplete(tasks, 'Check CRB status'),
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
  static List<String> kcbRequirementsMet(LoanReadinessInputs i) {
    return [
      if (i.isRegistered) 'Registered business',
      if (i.yearsInOperation != null && i.yearsInOperation! >= 2) '2+ years operating',
      if (i.annualTurnover != null && i.annualTurnover! >= 500000) 'KSh 500K+ annual turnover',
      if (i.hasSixMonthsBankStatements) '6 months of bank statements',
      if (i.hasBusinessPermit) 'Valid business permit',
      if (i.taxCompliant) 'Tax Compliance Certificate',
      if (i.crbChecked) 'CRB status checked',
      if (i.hasFinancialRecords) 'Financial records available',
      if (i.loanPurpose != null && i.loanPurpose!.trim().isNotEmpty) 'Loan purpose documented',
      if (i.hasCollateral) 'Security/collateral documented',
    ];
  }

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
