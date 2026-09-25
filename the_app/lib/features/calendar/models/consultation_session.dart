enum SessionStatus { scheduled, cancelled }

extension SessionStatusX on SessionStatus {
  static SessionStatus fromDb(String v) => switch (v) {
        'Cancelled' => SessionStatus.cancelled,
        _ => SessionStatus.scheduled,
      };
  String get dbValue => switch (this) {
        SessionStatus.scheduled => 'Scheduled',
        SessionStatus.cancelled => 'Cancelled',
      };
}

/// A consultation session booked on a Consultant's Google Calendar
/// (see supabase/functions/calendar-sessions). Rows are only ever
/// created/cancelled through that Edge Function, never inserted directly
/// from the app, because the Google event and the row must stay paired.
class ConsultationSession {
  const ConsultationSession({
    required this.id,
    required this.enterpriseId,
    required this.consultantId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.description,
    this.meetLink,
    this.calendarHtmlLink,
    this.consultantName,
  });

  factory ConsultationSession.fromMap(Map<String, dynamic> map) {
    final consultant = map['consultant'] as Map<String, dynamic>?;
    return ConsultationSession(
      id: map['id'] as String,
      enterpriseId: map['enterprise_id'] as String,
      consultantId: map['consultant_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(map['ends_at'] as String).toLocal(),
      status: SessionStatusX.fromDb(map['status'] as String),
      meetLink: map['meet_link'] as String?,
      calendarHtmlLink: map['calendar_html_link'] as String?,
      consultantName:
          consultant != null ? '${consultant['first_name']} ${consultant['last_name']}' : null,
    );
  }

  final String id;
  final String enterpriseId;
  final String consultantId;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final SessionStatus status;
  final String? meetLink;
  final String? calendarHtmlLink;
  final String? consultantName;

  bool get isUpcoming => status == SessionStatus.scheduled && endsAt.isAfter(DateTime.now());
}
