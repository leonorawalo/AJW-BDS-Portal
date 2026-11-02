/// Someone the signed-in user may start a direct chat with (chat_contacts()):
/// people who share an enterprise with them, and Admins.
class ChatContact {
  const ChatContact({required this.userId, required this.fullName, required this.roleName});

  factory ChatContact.fromMap(Map<String, dynamic> map) => ChatContact(
        userId: map['user_id'] as String,
        fullName: map['full_name'] as String? ?? '',
        roleName: map['role_name'] as String? ?? '',
      );

  final String userId;
  final String fullName;
  final String roleName;

  String get roleLabel => roleName == 'Enterprise Owner' ? 'Owner' : roleName;
}
