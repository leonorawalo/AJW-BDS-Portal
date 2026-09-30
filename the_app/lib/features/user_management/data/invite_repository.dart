import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invite_request.dart';
import '../models/invite_result.dart';

/// The invite email couldn't be sent (e.g. no email provider configured,
/// or its rate limit hit). The Admin can still share a link instead.
class InviteEmailFailedException implements Exception {
  const InviteEmailFailedException(this.detail);
  final String? detail;
}

/// Any other invite failure, with a message fit to show the Admin as-is
/// (no "Exception:" prefix, no raw status codes).
class InviteFailedException implements Exception {
  const InviteFailedException(this.message);
  final String message;

  @override
  String toString() => message;
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

  /// Status 0 means no response reached the browser at all (network blip,
  /// or the function cold-starting past the browser's patience). The
  /// request may still have been processed, so the single automatic retry
  /// is flagged: the function then won't email someone it invited in the
  /// last two minutes, which keeps a retry from sending a second invite.
  Future<InviteResult> _invoke(Map<String, dynamic> body) async {
    try {
      return await _invokeOnce(body);
    } on FunctionsFetchException {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        return await _invokeOnce({...body, 'retry': true});
      } on FunctionsFetchException {
        throw const InviteFailedException(
          "Couldn't reach the server. Check your internet connection and try again.",
        );
      }
    }
  }

  Future<InviteResult> _invokeOnce(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('invite-user', body: body);
      return InviteResult.fromMap(res.data as Map<String, dynamic>);
    } on FunctionsFetchException {
      rethrow;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (message == 'email_failed') {
        throw InviteEmailFailedException(details is Map ? details['detail'] as String? : null);
      }
      throw InviteFailedException(message ?? 'The invite could not be completed. Please try again.');
    }
  }
}
