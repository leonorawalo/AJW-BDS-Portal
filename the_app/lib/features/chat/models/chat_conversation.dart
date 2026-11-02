/// One chat the signed-in user is in, from my_chats() (migration
/// 20261008140000): an enterprise's group chat or a direct chat.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.isEnterprise,
    required this.title,
    this.enterpriseId,
    this.otherUserId,
    this.lastMessage,
    this.lastMessageAt,
    this.unread = 0,
  });

  factory ChatConversation.fromMap(Map<String, dynamic> map) => ChatConversation(
        id: map['conversation_id'] as String,
        isEnterprise: map['kind'] == 'enterprise',
        title: (map['title'] as String?)?.trim().isNotEmpty == true ? map['title'] as String : 'Chat',
        enterpriseId: map['enterprise_id'] as String?,
        otherUserId: map['other_user_id'] as String?,
        lastMessage: map['last_message'] as String?,
        lastMessageAt:
            map['last_message_at'] != null ? DateTime.parse(map['last_message_at'] as String).toLocal() : null,
        unread: (map['unread'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final bool isEnterprise;

  /// The business name, or the other person's name.
  final String title;
  final String? enterpriseId;
  final String? otherUserId;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  /// Messages from others since the user last opened it.
  final int unread;
}
