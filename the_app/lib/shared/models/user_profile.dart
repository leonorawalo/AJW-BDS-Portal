enum UserRole { administrator, consultant, enterpriseOwner }

UserRole userRoleFromName(String roleName) {
  switch (roleName) {
    case 'Administrator':
      return UserRole.administrator;
    case 'Consultant':
      return UserRole.consultant;
    case 'Enterprise Owner':
      return UserRole.enterpriseOwner;
    default:
      throw ArgumentError('Unknown role_name: $roleName');
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // `roles` comes through as a nested map from the `roles(role_name)`
    // join in AuthRepository.fetchUserProfile.
    final roleName = (map['roles'] as Map<String, dynamic>)['role_name'] as String;
    return UserProfile(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      email: map['email'] as String,
      role: userRoleFromName(roleName),
      status: map['status'] as String,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String status;

  bool get isSuspended => status == 'suspended';
}
