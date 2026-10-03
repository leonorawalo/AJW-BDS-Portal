/// A BDS workshop (ToR: onboarding & induction workshops by the trio;
/// registration list to M&E within 5 days). Migration 20261003120000.
class Workshop {
  const Workshop({
    required this.id,
    required this.title,
    required this.kind,
    required this.heldOn,
    required this.createdBy,
    required this.attendeeCount,
    this.location,
    this.notes,
    this.registrationSentAt,
  });

  factory Workshop.fromMap(Map<String, dynamic> map) {
    final count = map['workshop_attendees'];
    return Workshop(
      id: map['id'] as String,
      title: map['title'] as String,
      kind: map['kind'] as String,
      heldOn: DateTime.parse(map['held_on'] as String),
      location: map['location'] as String?,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String,
      registrationSentAt:
          map['registration_sent_at'] == null ? null : DateTime.parse(map['registration_sent_at'] as String).toLocal(),
      attendeeCount: count is List && count.isNotEmpty ? (count.first['count'] as num).toInt() : 0,
    );
  }

  final String id;
  final String title;
  final String kind;
  final DateTime heldOn;
  final String? location;
  final String? notes;
  final String createdBy;
  final DateTime? registrationSentAt;
  final int attendeeCount;

  static const kinds = ['Onboarding & induction', 'BDS workshop', 'Other'];

  /// ToR: the registration list goes to M&E 5 days after the workshop.
  static const registrationDueDays = 5;
  DateTime get registrationDue => heldOn.add(const Duration(days: registrationDueDays));

  bool get registrationOverdue {
    if (registrationSentAt != null) return false;
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day).isAfter(registrationDue);
  }
}

class WorkshopAttendee {
  const WorkshopAttendee({required this.id, required this.fullName, this.phone, this.businessName});

  factory WorkshopAttendee.fromMap(Map<String, dynamic> map) => WorkshopAttendee(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String?,
        businessName: map['business_name'] as String?,
      );

  final String id;
  final String fullName;
  final String? phone;
  final String? businessName;
}
