enum AvailabilityStatus { free, busy, notConnected, unknown }

/// One person's free/busy for a proposed slot, from calendar-sessions'
/// check_availability. Only busy/free is known: never event details.
class ParticipantAvailability {
  const ParticipantAvailability({required this.userId, required this.name, required this.status});

  factory ParticipantAvailability.fromMap(Map<String, dynamic> map) => ParticipantAvailability(
        userId: map['user_id'] as String,
        name: map['name'] as String,
        status: switch (map['status']) {
          'free' => AvailabilityStatus.free,
          'busy' => AvailabilityStatus.busy,
          'not_connected' => AvailabilityStatus.notConnected,
          _ => AvailabilityStatus.unknown,
        },
      );

  final String userId;
  final String name;
  final AvailabilityStatus status;
}
