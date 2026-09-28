/// Someone on a session, as the caller is allowed to see them (from the
/// session_people() RPC): Admin and the organizer see every participant;
/// a participant sees only the organizer and themselves.
class SessionPerson {
  const SessionPerson({
    required this.sessionId,
    required this.userId,
    required this.fullName,
    required this.isOrganizer,
  });

  factory SessionPerson.fromMap(Map<String, dynamic> map) => SessionPerson(
        sessionId: map['session_id'] as String,
        userId: map['user_id'] as String,
        fullName: map['full_name'] as String,
        isOrganizer: map['is_organizer'] as bool,
      );

  final String sessionId;
  final String userId;
  final String fullName;
  final bool isOrganizer;
}
