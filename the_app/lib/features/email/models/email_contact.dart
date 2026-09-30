/// Someone the signed-in user can email about an enterprise, from the
/// enterprise_email_contacts() RPC: the Owner, active consultants, Admins,
/// and the enterprise's own contact address ([userId] null).
class EmailContact {
  const EmailContact({required this.fullName, required this.roleName, required this.email, this.userId});

  factory EmailContact.fromMap(Map<String, dynamic> map) => EmailContact(
        userId: map['user_id'] as String?,
        fullName: map['full_name'] as String? ?? '',
        roleName: map['role_name'] as String? ?? '',
        email: map['email'] as String,
      );

  final String? userId;
  final String fullName;
  final String roleName;
  final String email;

  String get roleLabel => roleName == 'Enterprise Owner' ? 'Owner' : roleName;
}
