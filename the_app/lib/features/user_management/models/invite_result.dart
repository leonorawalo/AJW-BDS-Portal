enum InviteStatus { sent, linkedExisting, link }

/// What invite-user did: emailed an invite, linked an existing Owner
/// account, or returned a set-password [link] for the Admin to share.
class InviteResult {
  const InviteResult({required this.status, required this.userId, this.link});

  factory InviteResult.fromMap(Map<String, dynamic> map) => InviteResult(
        status: switch (map['status']) {
          'linked_existing' => InviteStatus.linkedExisting,
          'link' => InviteStatus.link,
          _ => InviteStatus.sent,
        },
        userId: map['user_id'] as String,
        link: map['link'] as String?,
      );

  final InviteStatus status;
  final String userId;
  final String? link;
}
