/// One email in an enterprise's inbox, read from the signed-in user's own
/// Gmail by the gmail-inbox Edge Function. [body] and [gmailUrl] are only
/// filled when a single message is opened.
class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.threadId,
    required this.from,
    required this.to,
    required this.subject,
    this.date,
    this.snippet = '',
    this.unread = false,
    this.body,
    this.gmailUrl,
  });

  factory InboxMessage.fromMap(Map<String, dynamic> map) => InboxMessage(
        id: map['id'] as String,
        threadId: map['thread_id'] as String? ?? '',
        from: map['from'] as String? ?? '',
        to: map['to'] as String? ?? '',
        subject: map['subject'] as String? ?? '',
        date: map['date'] != null ? DateTime.parse(map['date'] as String).toLocal() : null,
        snippet: map['snippet'] as String? ?? '',
        unread: map['unread'] as bool? ?? false,
        body: map['body'] as String?,
        gmailUrl: map['gmail_url'] as String?,
      );

  final String id;
  final String threadId;
  final String from;
  final String to;
  final String subject;
  final DateTime? date;
  final String snippet;
  final bool unread;
  final String? body;
  final String? gmailUrl;

  /// "Jane Doe" from `Jane Doe <jane@example.com>`.
  String get fromName {
    final i = from.indexOf('<');
    final name = (i > 0 ? from.substring(0, i) : from).replaceAll('"', '').trim();
    return name.isEmpty ? from : name;
  }

  /// The sender's address, lower-case.
  String get fromEmail {
    final m = RegExp(r'<([^>]+)>').firstMatch(from);
    return (m?.group(1) ?? from).trim().toLowerCase();
  }
}
