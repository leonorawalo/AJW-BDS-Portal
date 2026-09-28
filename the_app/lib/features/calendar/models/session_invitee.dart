/// Someone the caller may invite to a meeting on an enterprise, from the
/// session_invitee_candidates() RPC — which is where the invite rules live
/// (Admin -> Owner/consultants, Consultant -> Owner, Owner ->
/// consultants/Admins).
class SessionInvitee {
  const SessionInvitee({required this.userId, required this.fullName, required this.roleName});

  factory SessionInvitee.fromMap(Map<String, dynamic> map) => SessionInvitee(
        userId: map['user_id'] as String,
        fullName: map['full_name'] as String,
        roleName: map['role_name'] as String,
      );

  final String userId;
  final String fullName;
  final String roleName;

  /// "Owner" reads better than "Enterprise Owner" in a checkbox list.
  String get roleLabel => roleName == 'Enterprise Owner' ? 'Owner' : roleName;
}
