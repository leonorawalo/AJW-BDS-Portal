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

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.consultant:
        return 'Consultant';
      case UserRole.enterpriseOwner:
        return 'Enterprise Owner';
    }
  }
}

/// The ToR's "Trio" model: only meaningful when role is Consultant.
/// The MVP builds full task support for Legal only; Accounting and
/// Marketing exist here as real, selectable values so the distinction
/// is captured now, even though their task templates aren't built yet.
enum ConsultantSpecialization { legal, accounting, marketing }

ConsultantSpecialization? consultantSpecializationFromDb(String? value) {
  switch (value) {
    case 'Legal':
      return ConsultantSpecialization.legal;
    case 'Accounting':
      return ConsultantSpecialization.accounting;
    case 'Marketing':
      return ConsultantSpecialization.marketing;
    default:
      return null;
  }
}

extension ConsultantSpecializationX on ConsultantSpecialization {
  String get dbValue {
    switch (this) {
      case ConsultantSpecialization.legal:
        return 'Legal';
      case ConsultantSpecialization.accounting:
        return 'Accounting';
      case ConsultantSpecialization.marketing:
        return 'Marketing';
    }
  }

  String get label => dbValue;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.status,
    this.specialization,
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
      specialization: consultantSpecializationFromDb(map['specialization'] as String?),
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String status;
  final ConsultantSpecialization? specialization;

  bool get isSuspended => status == 'suspended';

  /// What the profile badge actually displays: "Consultant" alone if
  /// no specialization is set (or role isn't Consultant), otherwise
  /// e.g. "Legal Consultant".
  String get roleDisplayLabel {
    if (role == UserRole.consultant && specialization != null) {
      return '${specialization!.label} Consultant';
    }
    return role.label;
  }
}
