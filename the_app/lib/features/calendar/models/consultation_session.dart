import 'meeting_notes.dart';

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

/// A meeting booked on its organizer's Google Calendar: the organizer can
/// be an Admin, Consultant or Owner (see supabase/functions/calendar-sessions).
/// Who's on it comes separately from session_people(). Rows are only ever
/// created/cancelled through that Edge Function, never inserted directly
/// from the app, because the Google event and the row must stay paired.
class ConsultationSession {
  const ConsultationSession({
    required this.id,
    required this.enterpriseId,
    required this.organizerId,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    this.description,
    this.meetLink,
    this.calendarHtmlLink,
    this.notes = const MeetingNotes(status: MeetingNotesStatus.pending),
  });

  factory ConsultationSession.fromMap(Map<String, dynamic> map) {
    return ConsultationSession(
      id: map['id'] as String,
      enterpriseId: map['enterprise_id'] as String,
      organizerId: map['organizer_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(map['ends_at'] as String).toLocal(),
      status: SessionStatusX.fromDb(map['status'] as String),
      meetLink: map['meet_link'] as String?,
      calendarHtmlLink: map['calendar_html_link'] as String?,
      notes: MeetingNotes(
        status: meetingNotesStatusFromDb(map['notes_status'] as String?),
        notesUrl: map['notes_doc_url'] as String?,
        transcriptUrl: map['transcript_doc_url'] as String?,
      ),
    );
  }

  final String id;
  final String enterpriseId;
  final String organizerId;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final SessionStatus status;
  final String? meetLink;
  final String? calendarHtmlLink;

  /// Gemini notes / transcript, once the meeting is over.
  final MeetingNotes notes;

  bool get hasEnded => status == SessionStatus.scheduled && !endsAt.isAfter(DateTime.now());

  bool get isUpcoming => status == SessionStatus.scheduled && endsAt.isAfter(DateTime.now());
}
