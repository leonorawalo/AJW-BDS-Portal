/// One enterprise's line in the Admin portfolio export (Phase 8).
class PortfolioRow {
  const PortfolioRow({
    required this.enterpriseName,
    required this.lifecycleStatus,
    required this.goingConcern,
    required this.businessHealth,
    required this.creditReadiness,
    required this.kcbMet,
    required this.kcbTotal,
    required this.consultantsByDiscipline,
    required this.openTasks,
    required this.completedTasks,
    this.nextSession,
    this.lastActivity,
  });

  final String enterpriseName;
  final String lifecycleStatus;
  final String goingConcern;
  final double businessHealth;
  final double creditReadiness;
  final int kcbMet;
  final int kcbTotal;

  /// 'Legal' / 'Accounting' / 'Marketing' -> active consultant's name.
  final Map<String, String> consultantsByDiscipline;
  final int openTasks;
  final int completedTasks;
  final DateTime? nextSession;

  /// Latest change anywhere on the enterprise: its record, tasks, task
  /// comments, recommendations, documents or sessions.
  final DateTime? lastActivity;
}
