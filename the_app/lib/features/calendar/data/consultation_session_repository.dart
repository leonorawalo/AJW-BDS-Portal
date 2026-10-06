import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/consultation_session.dart';
import '../models/participant_availability.dart';
import '../models/session_invitee.dart';
import '../models/session_person.dart';

/// Thrown when the Edge Function reports the organizer has no working
/// Google connection, so the UI can offer "Connect Google Calendar"
/// instead of a raw error.
class GoogleNotConnectedException implements Exception {
  const GoogleNotConnectedException();
}

/// Thrown when someone is busy at the chosen time and the booking wasn't
/// forced: the server re-checks free/busy just before creating the event,
/// so this can happen even after the dialog's own check showed all clear.
class SessionClashException implements Exception {
  const SessionClashException(this.availability);
  final List<ParticipantAvailability> availability;
}

class ConsultationSessionRepository {
  ConsultationSessionRepository(this._client);

  final SupabaseClient _client;

  /// RLS returns only sessions the caller organised or was invited to
  /// (Admins see all).
  Future<List<ConsultationSession>> fetchSessions(String enterpriseId) async {
    final rows = await _client
        .from('consultation_sessions')
        .select()
        .eq('enterprise_id', enterpriseId)
        .order('starts_at', ascending: true);
    return (rows as List)
        .map((r) => ConsultationSession.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Organizer + participant names for the caller's visible sessions.
  Future<List<SessionPerson>> fetchSessionPeople(String enterpriseId) async {
    final rows = await _client.rpc('session_people', params: {'p_enterprise_id': enterpriseId}) as List;
    return rows.map((r) => SessionPerson.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<SessionInvitee>> fetchInviteeCandidates(String enterpriseId) async {
    final rows =
        await _client.rpc('session_invitee_candidates', params: {'p_enterprise_id': enterpriseId}) as List;
    return rows.map((r) => SessionInvitee.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Free/busy for the caller and each participant who has connected
  /// Google. Participants who haven't are reported as notConnected.
  Future<List<ParticipantAvailability>> checkAvailability({
    required String enterpriseId,
    required List<String> participantIds,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final data = await _invoke({
      'action': 'check_availability',
      'enterprise_id': enterpriseId,
      'participant_ids': participantIds,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
    });
    return _parseAvailability((data as Map)['availability']);
  }

  /// Creates the Google Calendar event (Meet link, participants invited by
  /// email) and the matching rows in one Edge Function call. [force] books
  /// even if someone is busy ("Book anyway").
  Future<void> scheduleSession({
    required String enterpriseId,
    required List<String> participantIds,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    String? description,
    bool force = false,
  }) =>
      _invoke({
        'action': 'create',
        'enterprise_id': enterpriseId,
        'participant_ids': participantIds,
        'title': title,
        'description': description,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt.toUtc().toIso8601String(),
        'force': force,
      });

  /// Deletes the Google event (attendees get a cancellation email) and
  /// marks the row Cancelled: kept, not deleted, for the session history.
  Future<void> cancelSession(String sessionId) =>
      _invoke({'action': 'cancel', 'session_id': sessionId});

  static List<ParticipantAvailability> _parseAvailability(Object? list) => (list as List)
      .map((a) => ParticipantAvailability.fromMap(a as Map<String, dynamic>))
      .toList();

  Future<dynamic> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('calendar-sessions', body: body);
      return res.data;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (e.status == 412 && message == 'not_connected') {
        throw const GoogleNotConnectedException();
      }
      if (e.status == 409 && message == 'clash' && details is Map) {
        throw SessionClashException(_parseAvailability(details['availability']));
      }
      throw Exception(message ?? 'Request failed (${e.status})');
    }
  }
}
