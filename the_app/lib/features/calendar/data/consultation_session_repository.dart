import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/consultation_session.dart';

/// Thrown when the Edge Function reports the consultant has no working
/// Google connection, so the UI can offer "Connect Google Calendar"
/// instead of a raw error.
class GoogleNotConnectedException implements Exception {
  const GoogleNotConnectedException();
}

class ConsultationSessionRepository {
  ConsultationSessionRepository(this._client);

  final SupabaseClient _client;

  Future<List<ConsultationSession>> fetchSessions(String enterpriseId) async {
    final rows = await _client
        .from('consultation_sessions')
        .select('*, consultant:consultant_id(first_name, last_name)')
        .eq('enterprise_id', enterpriseId)
        .order('starts_at', ascending: true);
    return (rows as List)
        .map((r) => ConsultationSession.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Creates the Google Calendar event (with Meet link, Owner invited)
  /// and the matching row in one Edge Function call.
  Future<void> scheduleSession({
    required String enterpriseId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
  }) =>
      _invoke({
        'action': 'create',
        'enterprise_id': enterpriseId,
        'title': title,
        'description': description,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
      });

  /// Deletes the Google event (attendees get a cancellation email) and
  /// marks the row Cancelled — kept, not deleted, for the session history.
  Future<void> cancelSession(String sessionId) =>
      _invoke({'action': 'cancel', 'session_id': sessionId});

  Future<void> _invoke(Map<String, dynamic> body) async {
    try {
      await _client.functions.invoke('calendar-sessions', body: body);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (e.status == 412 && message == 'not_connected') {
        throw const GoogleNotConnectedException();
      }
      throw Exception(message ?? 'Request failed (${e.status})');
    }
  }
}
