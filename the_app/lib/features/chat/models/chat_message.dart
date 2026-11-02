/// One chat message. Attachments live in the private `chat-attachments`
/// bucket; the app opens them through short-lived signed links.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.attachmentPath,
    this.attachmentName,
    this.attachmentMime,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        senderId: map['sender_id'] as String,
        body: map['body'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        attachmentPath: map['attachment_path'] as String?,
        attachmentName: map['attachment_name'] as String?,
        attachmentMime: map['attachment_mime'] as String?,
      );

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? attachmentPath;
  final String? attachmentName;
  final String? attachmentMime;

  bool get isImage => attachmentMime?.startsWith('image/') ?? false;
}
