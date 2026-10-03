import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/features/legal_workstream/models/loan_readiness.dart';
import 'package:the_app/features/legal_workstream/models/task_template.dart';
import 'package:the_app/shared/models/user_profile.dart';

/// The ToR checklists: keys are stored in tasks.tor_key (unique per
/// enterprise + discipline), and the loan-readiness score reads some titles
/// by exact text, so both must stay consistent.
void main() {
  final all = [for (final s in ConsultantSpecialization.values) ...torChecklistFor(s)];

  test('every discipline has its own non-empty checklist', () {
    for (final s in ConsultantSpecialization.values) {
      expect(torChecklistFor(s), isNotEmpty, reason: '$s');
    }
    expect(torChecklistFor(ConsultantSpecialization.marketing), same(standardMarketingChecklist));
  });

  test('keys are unique and fit tasks.tor_key (varchar 40)', () {
    final keys = all.map((t) => t.key).toList();
    expect(keys.toSet().length, keys.length);
    for (final k in keys) {
      expect(k.length, lessThanOrEqualTo(40));
    }
  });

  test('titles are unique within each discipline', () {
    for (final s in ConsultantSpecialization.values) {
      final titles = torChecklistFor(s).map((t) => t.title).toList();
      expect(titles.toSet().length, titles.length, reason: '$s');
    }
  });

  test('every title the loan-readiness score reads is a checklist title', () {
    final titles = all.map((t) => t.title).toSet();
    for (final scored in loanReadinessTaskTitles) {
      expect(titles, contains(scored));
    }
  });
}
