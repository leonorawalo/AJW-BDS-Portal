enum AccountState { invited, active, suspended }

/// One row of the Admin Users screen, from admin_list_users(): the
/// public.users profile plus whether the invite was accepted (auth.users),
/// which the app can't otherwise read.
class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.roleName,
    required this.status,
    required this.accepted,
    required this.activeAssignments,
    this.phoneNumber,
    this.specialization,
    this.invitedAt,
    this.lastSignInAt,
  });

  factory ManagedUser.fromMap(Map<String, dynamic> map) {
    DateTime? date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
    return ManagedUser(
      id: map['id'] as String,
      firstName: map['first_name'] as String? ?? '',
      lastName: map['last_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phone_number'] as String?,
      roleName: map['role_name'] as String,
      specialization: map['specialization'] as String?,
      status: map['status'] as String,
      accepted: map['accepted'] as bool? ?? false,
      invitedAt: date(map['invited_at']),
      lastSignInAt: date(map['last_sign_in_at']),
      activeAssignments: map['active_assignments'] as int? ?? 0,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String roleName;
  final String? specialization;

  /// public.users.status: 'active' or 'suspended'.
  final String status;

  /// Has set up their account (email confirmed), i.e. accepted the invite.
  final bool accepted;
  final DateTime? invitedAt;
  final DateTime? lastSignInAt;
  final int activeAssignments;

  String get fullName => '$firstName $lastName'.trim();
  bool get isConsultant => roleName == 'Consultant';

  AccountState get state => status == 'suspended'
      ? AccountState.suspended
      : accepted
          ? AccountState.active
          : AccountState.invited;
}
