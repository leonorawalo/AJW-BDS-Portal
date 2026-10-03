import '../../enterprises/models/enterprise.dart';

/// Where an enterprise is on the programme's timeline, per the Terms of
/// Reference: incubated for 12 months; a going concern within 3 months of
/// establishment; bankable ("able to secure services from a bank") by the
/// end of month 6. Counted from enrolment.
class ProgrammeClock {
  ProgrammeClock(this.enterprise, {DateTime? now}) : now = now ?? DateTime.now();

  final Enterprise enterprise;
  final DateTime now;

  static const incubationMonths = 12;
  static const goingConcernMonths = 3;
  static const bankableMonths = 6;

  DateTime get start => enterprise.enrolledAt.toLocal();

  static DateTime _addMonths(DateTime d, int months) {
    final y = d.year + ((d.month - 1 + months) ~/ 12);
    final m = (d.month - 1 + months) % 12 + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, d.day > lastDay ? lastDay : d.day);
  }

  DateTime get goingConcernDue => _addMonths(start, goingConcernMonths);
  DateTime get bankableDue => _addMonths(start, bankableMonths);
  DateTime get incubationEnds => _addMonths(start, incubationMonths);

  /// 1-based month of the programme, capped at 12.
  int get month {
    var months = (now.year - start.year) * 12 + now.month - start.month;
    if (now.day < start.day) months -= 1;
    return (months + 1).clamp(1, incubationMonths);
  }

  bool get goingConcernAchieved => enterprise.goingConcernStatus == GoingConcernStatus.achieved;

  /// "Loan Ready" or "Graduated" in the lifecycle counts as bankable.
  bool get bankableAchieved =>
      enterprise.lifecycleStatus == LifecycleStatus.loanReady ||
      enterprise.lifecycleStatus == LifecycleStatus.graduated;

  /// Became a going concern within the ToR's 3 months.
  bool get goingConcernOnTime {
    final at = enterprise.goingConcernAchievedAt;
    return goingConcernAchieved && at != null && !at.toLocal().isAfter(goingConcernDue);
  }

  int daysUntil(DateTime d) => DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;

  /// One line for a card: what's next and when.
  String get headline {
    if (!goingConcernAchieved) {
      final d = daysUntil(goingConcernDue);
      return d >= 0 ? 'Going concern due in $d ${d == 1 ? 'day' : 'days'}' : 'Going concern overdue by ${-d} days';
    }
    if (!bankableAchieved) {
      final d = daysUntil(bankableDue);
      return d >= 0 ? 'Bankable due in $d ${d == 1 ? 'day' : 'days'}' : 'Bankable overdue by ${-d} days';
    }
    return 'Bankable';
  }

  bool get isOverdue =>
      (!goingConcernAchieved && daysUntil(goingConcernDue) < 0) ||
      (goingConcernAchieved && !bankableAchieved && daysUntil(bankableDue) < 0);
}
