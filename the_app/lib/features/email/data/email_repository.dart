import 'package:supabase_flutter/supabase_flutter.dart';

import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../../google_exports/data/google_export_repository.dart' show GoogleReconnectNeededException;
import '../models/email_contact.dart';

/// "Write email": sent from the user's own Gmail by the gmail-send Edge
/// Function (gmail.send — send only, no mailbox access).
class EmailRepository {
  EmailRepository(this._client);

  final SupabaseClient _client;

  Future<List<EmailContact>> fetchContacts(String enterpriseId) async {
    final rows =
        await _client.rpc('enterprise_email_contacts', params: {'p_enterprise_id': enterpriseId}) as List;
    return rows.map((r) => EmailContact.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Recipients are re-checked on the server against the same contact list
  /// (Admins may also email any portal user).
  Future<void> send({
    String? enterpriseId,
    required List<String> to,
    required String subject,
    required String body,
  }) async {
    try {
      await _client.functions.invoke('gmail-send', body: {
        'enterprise_id': enterpriseId,
        'to': to,
        'subject': subject,
        'body': body,
      });
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (e.status == 412 && message == 'not_connected') throw const GoogleNotConnectedException();
      if (e.status == 412 && message == 'reconnect_needed') throw const GoogleReconnectNeededException();
      throw Exception(message ?? 'Sending failed (${e.status})');
    }
  }
}
