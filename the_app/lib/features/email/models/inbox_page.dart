import 'inbox_message.dart';

/// One page of an enterprise's inbox; [nextPageToken] fetches the next.
class InboxPage {
  const InboxPage({required this.messages, this.nextPageToken});
  final List<InboxMessage> messages;
  final String? nextPageToken;
}
