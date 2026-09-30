/// "Find emails in Gmail": opens Gmail's own search, pre-filtered. No Google
/// permission is involved; it's just a link into the user's Gmail.
///
/// Matches mail from or to any of [emails], or mentioning [phrase] (e.g. the
/// business name or a meeting title). [accountEmail] (the Google account
/// connected to the portal) picks the right account when the browser is
/// signed in to several.
Uri gmailSearchUri({List<String> emails = const [], String? phrase, String? accountEmail}) {
  final terms = <String>[
    for (final e in emails) ...['from:$e', 'to:$e'],
    if (phrase != null && phrase.trim().isNotEmpty) '"${phrase.trim().replaceAll('"', '')}"',
  ];
  // Gmail treats {a b c} as "a OR b OR c".
  final query = terms.isEmpty ? '' : '{${terms.join(' ')}}';
  final account = accountEmail == null ? '' : '?authuser=${Uri.encodeComponent(accountEmail)}';
  return Uri.parse('https://mail.google.com/mail/$account#search/${Uri.encodeComponent(query)}');
}
