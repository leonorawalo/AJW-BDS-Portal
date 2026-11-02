import 'package:supabase_flutter/supabase_flutter.dart';

import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../models/inbox_message.dart';
import '../models/inbox_page.dart';

/// The connection works but hasn't been granted Gmail read access
/// (gmail.readonly), which is pending Google's approval.
class GmailReadNotGrantedException implements Exception {
  const GmailReadNotGrantedException();
}

/// An enterprise's emails from the user's own Gmail (gmail-inbox Edge
/// Function). The search is built on the server from the enterprise's
/// people; the app never sends a filter.
class InboxRepository {
  InboxRepository(this._client);

  final SupabaseClient _client;

  Future<InboxPage> list(String enterpriseId, {String? pageToken}) async {
    final data = await _invoke({'action': 'list', 'enterprise_id': enterpriseId, 'page_token': ?pageToken});
    return InboxPage(
      messages: [
        for (final m in (data['messages'] as List? ?? const [])) InboxMessage.fromMap(Map<String, dynamic>.from(m as Map)),
      ],
      nextPageToken: data['next_page_token'] as String?,
    );
  }

  Future<InboxMessage> get(String enterpriseId, String messageId) async =>
      InboxMessage.fromMap(await _invoke({'action': 'get', 'enterprise_id': enterpriseId, 'message_id': messageId}));

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('gmail-inbox', body: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (e.status == 412 && message == 'not_connected') throw const GoogleNotConnectedException();
      if (e.status == 412 && message == 'read_not_granted') throw const GmailReadNotGrantedException();
      throw Exception(message ?? 'Request failed (${e.status})');
    }
  }
}
