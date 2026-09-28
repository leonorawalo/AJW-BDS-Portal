import '../../enterprises/models/enterprise.dart';
import '../../legal_workstream/models/loan_readiness.dart';
import '../../legal_workstream/models/recommendation.dart';
import '../../legal_workstream/models/task.dart';
import '../models/deck_slide.dart';
import '../models/enterprise_export_data.dart';
import 'export_formatting.dart';

/// The progress summary deck (google-export adds the title slide first).
/// Task progress covers only the disciplines the exporting user can see.
List<DeckSlide> buildProgressDeck(EnterpriseExportData d) {
  final i = d.inputs;
  final kcb = LoanReadiness.kcbRequirements(i);
  final flags = LoanReadiness.redFlags(i);

  final byDiscipline = <String, List<WorkstreamTask>>{};
  for (final t in d.tasks) {
    byDiscipline.putIfAbsent(t.specialization ?? 'Other', () => []).add(t);
  }

  final openRecs = d.recommendations.where((r) => r.status == RecommendationStatus.open).toList();
  final upcoming = d.sessions.where((s) => s.isUpcoming).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return [
    DeckSlide(title: 'Scores', bullets: [
      'Business Health: ${exportScore(d.businessHealth)} (${LoanReadiness.band(d.businessHealth)})',
      'Credit Readiness: ${exportScore(d.creditReadiness)} (${LoanReadiness.band(d.creditReadiness)})',
      'Going Concern: ${d.enterprise.goingConcernStatus.dbValue}',
      flags.isEmpty ? 'No red flags' : 'Red flags: ${flags.join('; ')}',
    ]),
    DeckSlide(
      title: 'KCB requirements: ${kcb.where((r) => r.$1).length} of ${kcb.length} met',
      bullets: [for (final (met, label) in kcb) '${met ? '✓' : '✗'} $label'],
    ),
    DeckSlide(title: 'Task progress', bullets: [
      if (byDiscipline.isEmpty) 'No tasks yet.',
      for (final MapEntry(key: discipline, value: tasks) in byDiscipline.entries)
        '$discipline: ${tasks.where((t) => t.status == TaskStatus.completed).length} of '
            '${tasks.length} completed',
    ]),
    DeckSlide(title: 'Open recommendations', bullets: [
      if (openRecs.isEmpty) 'None open.',
      for (final r in openRecs.take(8)) r.recommendationText,
      if (openRecs.length > 8) '…and ${openRecs.length - 8} more',
    ]),
    DeckSlide(title: 'Upcoming sessions', bullets: [
      if (upcoming.isEmpty) 'Nothing scheduled.',
      for (final s in upcoming.take(6)) '${exportDateTime(s.startsAt)}: ${s.title}',
    ]),
  ];
}
