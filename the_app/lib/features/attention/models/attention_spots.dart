/// Where the signed-in user has something new to look at (red dots).
/// Built from `my_attention()` rows: (enterprise id or null, section).
///
/// Sections match the shell's keys: an enterprise's ShellSection keys
/// ('tasks', 'sessions', ...) plus 'new' (a newly assigned enterprise),
/// and role-level page keys ('users', 'workshops') with no enterprise.
class AttentionSpots {
  const AttentionSpots(this._spots);

  static const none = AttentionSpots({});

  factory AttentionSpots.fromRows(List<dynamic> rows) => AttentionSpots({
    for (final r in rows.cast<Map<String, dynamic>>()) _key(r['enterprise_id'] as String?, r['section'] as String),
  });

  final Set<String> _spots;

  static String _key(String? enterpriseId, String section) => '${enterpriseId ?? ''}|$section';

  bool get isEmpty => _spots.isEmpty;

  /// A role-level page, e.g. 'users'.
  bool page(String key) => _spots.contains(_key(null, key));

  /// One section of one enterprise, e.g. its Tasks.
  bool section(String enterpriseId, String key) => _spots.contains(_key(enterpriseId, key));

  /// Anything at all inside this enterprise (its card in a list).
  bool enterprise(String enterpriseId) => _spots.any((s) => s.startsWith('$enterpriseId|'));

  /// Anything inside any enterprise (the consultant's "My portfolio").
  bool get anyEnterprise => _spots.any((s) => !s.startsWith('|'));
}
