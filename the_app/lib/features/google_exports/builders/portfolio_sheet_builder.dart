import '../models/portfolio_row.dart';
import '../models/sheet_tab.dart';
import 'export_formatting.dart';

const _disciplines = ['Legal', 'Accounting', 'Marketing'];

/// The Admin portfolio as a single-tab Google Sheet, one row per enterprise.
List<SheetTab> buildPortfolioSheet(List<PortfolioRow> rows) {
  return [
    SheetTab(name: 'Portfolio', rows: [
      [
        'Enterprise',
        'Lifecycle status',
        'Going Concern',
        'Business Health (/100)',
        'Credit Readiness (/100)',
        'KCB requirements met',
        for (final d in _disciplines) '$d consultant',
        'Open tasks',
        'Completed tasks',
        'Next session',
        'Last activity',
      ],
      for (final r in rows)
        [
          r.enterpriseName,
          r.lifecycleStatus,
          r.goingConcern,
          r.businessHealth,
          r.creditReadiness,
          '${r.kcbMet}/${r.kcbTotal}',
          for (final d in _disciplines) r.consultantsByDiscipline[d] ?? '',
          r.openTasks,
          r.completedTasks,
          r.nextSession == null ? '' : exportDateTime(r.nextSession!),
          exportDate(r.lastActivity),
        ],
    ]),
  ];
}
