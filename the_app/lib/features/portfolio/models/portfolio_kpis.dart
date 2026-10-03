import '../../../shared/models/user_profile.dart';
import '../../enterprises/models/enterprise.dart';
import '../../legal_workstream/models/task.dart';
import '../../legal_workstream/models/task_template.dart';
import '../../visits/models/enterprise_visit.dart';
import 'programme_clock.dart';

/// A ToR task item's status on one enterprise, as read for the portfolio.
class TorTaskStatus {
  const TorTaskStatus({required this.enterpriseId, required this.torKey, required this.status});
  final String enterpriseId;
  final String torKey;
  final TaskStatus status;
}

/// One ToR deliverable with a portfolio target ("Register businesses:
/// 90% of portfolio") against what's done.
class TargetProgress {
  const TargetProgress({
    required this.template,
    required this.discipline,
    required this.done,
    required this.outOf,
  });
  final TaskTemplate template;
  final ConsultantSpecialization discipline;
  final int done;
  final int outOf;

  int get target => template.targetPercent!;
  double get percent => outOf == 0 ? 0 : done * 100 / outOf;
  bool get met => outOf > 0 && percent >= target;
}

/// The Terms of Reference measures for a set of enterprises (a consultant's
/// portfolio, or the whole programme for an Admin). Pure: built from data
/// the caller can already read, so it's the same numbers RLS allows.
class PortfolioKpis {
  PortfolioKpis({
    required this.enterprises,
    required this.torTasks,
    required this.monthVisits,
    required this.disciplines,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final List<Enterprise> enterprises;
  final List<TorTaskStatus> torTasks;

  /// Visits this calendar month.
  final List<EnterpriseVisit> monthVisits;

  /// Which disciplines' targets to show (a consultant: theirs; Admin: all).
  final List<ConsultantSpecialization> disciplines;
  final DateTime now;

  /// ToR: "Minimum of 30 clients in portfolio".
  static const minimumPortfolio = 30;

  /// ToR: "Create new going concerns from 50% of the startup businesses
  /// within 3 months" and "Maintain a 50% business survival rate".
  static const goingConcernTargetPercent = 50;

  int get portfolioSize => enterprises.length;

  /// Enterprises at least 3 months in, i.e. whose going-concern deadline
  /// has passed: the ones the 50% target is measured on.
  List<Enterprise> get dueForGoingConcern =>
      enterprises.where((e) => !ProgrammeClock(e, now: now).goingConcernDue.isAfter(now)).toList();

  int get goingConcernOnTime => dueForGoingConcern.where((e) => ProgrammeClock(e, now: now).goingConcernOnTime).length;

  int get goingConcerns => enterprises.where((e) => e.goingConcernStatus == GoingConcernStatus.achieved).length;

  /// Going concerns still operating (not inactive).
  int get survivingGoingConcerns => enterprises
      .where((e) => e.goingConcernStatus == GoingConcernStatus.achieved && e.lifecycleStatus != LifecycleStatus.inactive)
      .length;

  int get bankable => enterprises.where((e) => ProgrammeClock(e, now: now).bankableAchieved).length;

  int get overdueMilestones => enterprises.where((e) => ProgrammeClock(e, now: now).isOverdue).length;

  /// ToR: visit each business twice a month. Expected = 2 per enterprise
  /// per consultant discipline being measured.
  int get visitsExpected => portfolioSize * 2 * disciplines.length;
  int get visitsThisMonth => monthVisits.length;
  int get lateLogsThisMonth => monthVisits.where((v) => v.loggedLate).length;

  /// Every ToR item with a target, per discipline, against completion on
  /// the enterprises in view.
  List<TargetProgress> get targets {
    final completed = <String, Set<String>>{};
    for (final t in torTasks) {
      if (t.status == TaskStatus.completed) {
        completed.putIfAbsent(t.torKey, () => <String>{}).add(t.enterpriseId);
      }
    }
    final ids = enterprises.map((e) => e.id).toSet();
    return [
      for (final d in disciplines)
        for (final item in torChecklistFor(d))
          if (item.targetPercent != null)
            TargetProgress(
              template: item,
              discipline: d,
              done: (completed[item.key] ?? const <String>{}).intersection(ids).length,
              outOf: enterprises.length,
            ),
    ];
  }
}
