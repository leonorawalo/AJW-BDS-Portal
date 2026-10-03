import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/features/enterprises/models/enterprise.dart';
import 'package:the_app/features/legal_workstream/models/task.dart';
import 'package:the_app/features/portfolio/models/portfolio_kpis.dart';
import 'package:the_app/features/portfolio/models/programme_clock.dart';
import 'package:the_app/features/visits/models/enterprise_visit.dart';
import 'package:the_app/shared/models/user_profile.dart';

/// The Terms of Reference timeline and portfolio measures.
void main() {
  Enterprise ent(String id, DateTime enrolled, {String gc = 'Not Yet', DateTime? gcAt, String life = 'Active'}) =>
      Enterprise(
        id: id,
        businessName: id,
        ownerName: 'o',
        lifecycleStatus: LifecycleStatusX.fromDb(life),
        goingConcernStatus: GoingConcernStatusX.fromDb(gc),
        goingConcernAchievedAt: gcAt,
        enrolledAt: enrolled,
      );

  group('ProgrammeClock', () {
    final now = DateTime(2026, 10, 15);

    test('month counts from enrolment and caps at 12', () {
      expect(ProgrammeClock(ent('a', DateTime(2026, 10, 1)), now: now).month, 1);
      expect(ProgrammeClock(ent('a', DateTime(2026, 8, 20)), now: now).month, 2);
      expect(ProgrammeClock(ent('a', DateTime(2026, 8, 15)), now: now).month, 3);
      expect(ProgrammeClock(ent('a', DateTime(2024, 1, 1)), now: now).month, 12);
    });

    test('milestones: going concern at 3 months, bankable at 6, month-end safe', () {
      final c = ProgrammeClock(ent('a', DateTime(2026, 11, 30)), now: now);
      expect(c.goingConcernDue, DateTime(2027, 2, 28));
      expect(c.bankableDue, DateTime(2027, 5, 30));
      expect(c.incubationEnds, DateTime(2027, 11, 30));
    });

    test('headline and overdue', () {
      final early = ProgrammeClock(ent('a', DateTime(2026, 10, 1)), now: now);
      expect(early.headline, startsWith('Going concern due in'));
      expect(early.isOverdue, isFalse);

      final late = ProgrammeClock(ent('a', DateTime(2026, 6, 1)), now: now);
      expect(late.headline, startsWith('Going concern overdue by'));
      expect(late.isOverdue, isTrue);

      final gc = ProgrammeClock(ent('a', DateTime(2026, 6, 1), gc: 'Achieved', gcAt: DateTime(2026, 8, 1)), now: now);
      expect(gc.goingConcernOnTime, isTrue);
      expect(gc.headline, startsWith('Bankable due in'));

      final done = ProgrammeClock(ent('a', DateTime(2026, 1, 1), gc: 'Achieved', life: 'Loan Ready'), now: now);
      expect(done.headline, 'Bankable');
      expect(done.isOverdue, isFalse);
    });
  });

  group('PortfolioKpis', () {
    final now = DateTime(2026, 10, 15);
    final enterprises = [
      ent('on-time', DateTime(2026, 5, 1), gc: 'Achieved', gcAt: DateTime(2026, 7, 1)),
      ent('late-gc', DateTime(2026, 5, 1), gc: 'Achieved', gcAt: DateTime(2026, 9, 1)),
      ent('not-yet', DateTime(2026, 6, 1)),
      ent('too-new', DateTime(2026, 9, 1)),
      ent('closed', DateTime(2026, 1, 1), gc: 'Achieved', gcAt: DateTime(2026, 3, 1), life: 'Inactive'),
    ];
    EnterpriseVisit v(bool late) => EnterpriseVisit(
          id: 'v',
          enterpriseId: 'not-yet',
          consultantId: 'c',
          visitedOn: now,
          mode: 'In person',
          outcome: 'x',
          loggedAt: now,
          loggedLate: late,
        );
    final k = PortfolioKpis(
      enterprises: enterprises,
      torTasks: const [
        TorTaskStatus(enterpriseId: 'on-time', torKey: 'L-2.1.2', status: TaskStatus.completed),
        TorTaskStatus(enterpriseId: 'late-gc', torKey: 'L-2.1.2', status: TaskStatus.inProgress),
        TorTaskStatus(enterpriseId: 'someone-else', torKey: 'L-2.1.2', status: TaskStatus.completed),
      ],
      monthVisits: [v(false), v(true)],
      disciplines: const [ConsultantSpecialization.legal],
      now: now,
    );

    test('going concern within 3 months is measured on enterprises past month 3', () {
      expect(k.dueForGoingConcern.map((e) => e.id), containsAll(['on-time', 'late-gc', 'not-yet', 'closed']));
      expect(k.dueForGoingConcern.map((e) => e.id), isNot(contains('too-new')));
      expect(k.goingConcernOnTime, 2); // on-time + closed (achieved within 3 months)
    });

    test('survival counts going concerns not inactive', () {
      expect(k.goingConcerns, 3);
      expect(k.survivingGoingConcerns, 2);
    });

    test('visits: 2 per business per discipline; late logs counted', () {
      expect(k.visitsExpected, 10);
      expect(k.visitsThisMonth, 2);
      expect(k.lateLogsThisMonth, 1);
    });

    test('targets count completed ToR items on enterprises in view only', () {
      final reg = k.targets.firstWhere((t) => t.template.key == 'L-2.1.2');
      expect(reg.target, 90);
      expect(reg.done, 1);
      expect(reg.outOf, 5);
      expect(reg.met, isFalse);
    });
  });
}
