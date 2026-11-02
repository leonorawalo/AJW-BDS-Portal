/// Where a finished meeting's Gemini notes and transcript stand (see
/// supabase/functions/meeting-notes and migration 20261008100000).
enum MeetingNotesStatus { pending, ready, none, unavailable }

MeetingNotesStatus meetingNotesStatusFromDb(String? value) => switch (value) {
      'ready' => MeetingNotesStatus.ready,
      'none' => MeetingNotesStatus.none,
      'unavailable' => MeetingNotesStatus.unavailable,
      _ => MeetingNotesStatus.pending,
    };

class MeetingNotes {
  const MeetingNotes({required this.status, this.notesUrl, this.transcriptUrl});

  factory MeetingNotes.fromMap(Map<String, dynamic> map) => MeetingNotes(
        status: meetingNotesStatusFromDb(map['status'] as String?),
        notesUrl: map['notes_url'] as String?,
        transcriptUrl: map['transcript_url'] as String?,
      );

  final MeetingNotesStatus status;
  final String? notesUrl;
  final String? transcriptUrl;
}
