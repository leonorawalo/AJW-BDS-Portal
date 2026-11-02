/// One success story for the monthly programme report, in six guided
/// parts (migration 20261008110000). Each part has a prompt so writers
/// cover the same ground every time.
class SuccessStory {
  const SuccessStory({
    this.id,
    required this.enterpriseId,
    required this.reportMonth,
    this.beforeStory = '',
    this.whatWeDid = '',
    this.results = '',
    this.humanImpact = '',
    this.ownerQuote = '',
    this.whatsNext = '',
    this.involvesMinor = false,
    this.guardianConsent = false,
  });

  factory SuccessStory.fromMap(Map<String, dynamic> map) => SuccessStory(
        id: map['id'] as String,
        enterpriseId: map['enterprise_id'] as String,
        reportMonth: DateTime.parse(map['report_month'] as String),
        beforeStory: map['before_story'] as String? ?? '',
        whatWeDid: map['what_we_did'] as String? ?? '',
        results: map['results'] as String? ?? '',
        humanImpact: map['human_impact'] as String? ?? '',
        ownerQuote: map['owner_quote'] as String? ?? '',
        whatsNext: map['whats_next'] as String? ?? '',
        involvesMinor: map['involves_minor'] as bool? ?? false,
        guardianConsent: map['guardian_consent'] as bool? ?? false,
      );

  /// Null until saved.
  final String? id;
  final String enterpriseId;

  /// First day of the report month.
  final DateTime reportMonth;
  final String beforeStory;
  final String whatWeDid;
  final String results;
  final String humanImpact;
  final String ownerQuote;
  final String whatsNext;

  /// The story names, quotes or shows someone under 18. Saving it then
  /// needs [guardianConsent]: a parent or guardian agreed (Kenya Data
  /// Protection Act, 2019, section 33; the database checks it too).
  final bool involvesMinor;
  final bool guardianConsent;

  Map<String, dynamic> toInsert() => {
        'enterprise_id': enterpriseId,
        'report_month':
            '${reportMonth.year}-${reportMonth.month.toString().padLeft(2, '0')}-01',
        'before_story': beforeStory.trim(),
        'what_we_did': whatWeDid.trim(),
        'results': results.trim(),
        'human_impact': humanImpact.trim(),
        'owner_quote': ownerQuote.trim(),
        'whats_next': whatsNext.trim(),
        'involves_minor': involvesMinor,
        'guardian_consent': involvesMinor && guardianConsent,
      };

  /// The six parts in report order: (heading, prompt shown while writing,
  /// text).
  List<(String, String, String)> get parts => [
        for (final (i, p) in storyPrompts.indexed) (p.$1, p.$2, _values[i]),
      ];

  List<String> get _values => [beforeStory, whatWeDid, results, humanImpact, ownerQuote, whatsNext];
}

/// (heading, helper text) for each part, in order.
const storyPrompts = <(String, String)>[
  ('Before', 'The business and the challenge it faced when it joined the programme.'),
  ('What we did', 'The specific support given, by whom, and when (for example "registered with the Registrar in March").'),
  (
    'Results',
    'Measurable change: revenue, jobs created, customers, compliance achieved, loan readiness. Use numbers where you can.',
  ),
  ('Human impact', 'Who benefited and how many people: the owner, staff, families, the community.'),
  ('In their words', 'A short quote from the business owner, in their own words.'),
  ('What\'s next', 'The next milestone for the business.'),
];
