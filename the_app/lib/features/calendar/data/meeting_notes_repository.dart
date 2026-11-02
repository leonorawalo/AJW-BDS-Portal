import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meeting_notes.dart';

/// Asks the meeting-notes Edge Function to look for a finished meeting's
/// Gemini notes and transcript (it also lists them in the Files tab).
class MeetingNotesRepository {
  MeetingNotesRepository(this._client);

  final SupabaseClient _client;

  Future<MeetingNotes> check(String sessionId) async {
    try {
      final res = await _client.functions.invoke('meeting-notes', body: {'session_id': sessionId});
      return MeetingNotes.fromMap(Map<String, dynamic>.from(res.data as Map));
    } on FunctionException catch (e) {
      final details = e.details;
      throw Exception((details is Map ? details['error'] as String? : null) ?? 'Request failed (${e.status})');
    }
  }
}
