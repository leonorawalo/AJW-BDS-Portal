/// Who the Admin is inviting (see supabase/functions/invite-user).
/// [roleName] is 'Enterprise Owner', 'Consultant' or 'Administrator';
/// [specialization] is required for Consultants; [enterpriseId] links an
/// Owner to their enterprise as soon as the account exists.
class InviteRequest {
  const InviteRequest({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roleName,
    this.specialization,
    this.enterpriseId,
    this.phoneNumber,
  });

  /// An enterprise's Owner, from the enterprise record (which keeps the
  /// owner's name as one field and the contact email/phone).
  factory InviteRequest.forOwner({
    required String email,
    required String ownerName,
    required String enterpriseId,
    String? phoneNumber,
  }) {
    final parts = ownerName.trim().split(RegExp(r'\s+'));
    return InviteRequest(
      email: email,
      firstName: parts.first,
      lastName: parts.skip(1).join(' '),
      roleName: 'Enterprise Owner',
      enterpriseId: enterpriseId,
      phoneNumber: phoneNumber,
    );
  }

  final String email;
  final String firstName;
  final String lastName;
  final String roleName;
  final String? specialization;
  final String? enterpriseId;

  /// Only used to pre-fill a WhatsApp share of the invite link.
  final String? phoneNumber;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson(String action) => {
        'action': action,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role_name': roleName,
        'specialization': specialization,
        'enterprise_id': enterpriseId,
      };
}
