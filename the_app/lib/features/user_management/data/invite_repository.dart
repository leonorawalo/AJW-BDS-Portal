import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invite_request.dart';
import '../models/invite_result.dart';

/// The invite email couldn't be sent (e.g. no email provider configured,
/// or its rate limit hit). The Admin can still share a link instead.
class InviteEmailFailedException implements Exception {
  const InviteEmailFailedException(this.detail);
  final String? detail;
}

/// Admin-only onboarding (Phase 9a) via the invite-user Edge Function.
class InviteRepository {
  InviteRepository(this._client);

  final SupabaseClient _client;

  /// Emails an invite. Throws [InviteEmailFailedException] if the email
  /// couldn't be sent — fall back to [createLink].
  Future<InviteResult> sendInvite(InviteRequest request) => _invoke(request.toJson('invite'));

  /// A set-password link for the Admin to share (copy / WhatsApp). Also
  /// works as a "resend" for someone who hasn't accepted yet.
  Future<InviteResult> createLink(InviteRequest request) => _invoke(request.toJson('link'));

  Future<InviteResult> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('invite-user', body: body);
      return InviteResult.fromMap(res.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (message == 'email_failed') {
        throw InviteEmailFailedException(details is Map ? details['detail'] as String? : null);
      }
      throw Exception(message ?? 'Invite failed (${e.status})');
    }
  }
}
