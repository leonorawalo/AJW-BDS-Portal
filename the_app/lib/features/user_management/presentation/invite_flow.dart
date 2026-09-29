import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/progress_dialog.dart';
import '../data/invite_repository.dart';
import '../models/invite_request.dart';
import '../models/invite_result.dart';
import '../providers/user_management_providers.dart';
import 'invite_link_dialog.dart';

/// Emails an invite; if email isn't possible, offers a shareable link
/// instead (copy / WhatsApp). Returns true when an account was invited or
/// linked, so callers can refresh.
Future<bool> runInvite(BuildContext context, WidgetRef ref, InviteRequest request) async {
  try {
    final result = await withProgress(
      context,
      'Sending invite…',
      ref.read(inviteRepositoryProvider).sendInvite(request),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.status == InviteStatus.linkedExisting
            ? '${request.email} already had an Owner account; it is now linked.'
            : 'Invite sent to ${request.email}.'),
      ));
    }
    return true;
  } on InviteEmailFailedException {
    if (!context.mounted) return false;
    final shareInstead = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Couldn't send the invite email"),
        content: Text(
          'You can share a set-password link with ${request.fullName} yourself instead '
          '(copy it, or send it by WhatsApp).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Get link')),
        ],
      ),
    );
    if (shareInstead != true || !context.mounted) return false;
    return shareInviteLink(context, ref, request);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not invite: $e')));
    }
    return false;
  }
}

/// Creates a set-password link and shows the share dialog. Also the way
/// to "resend" to someone who hasn't accepted yet, without relying on email.
Future<bool> shareInviteLink(BuildContext context, WidgetRef ref, InviteRequest request) async {
  try {
    final result = await withProgress(
      context,
      'Creating invite link…',
      ref.read(inviteRepositoryProvider).createLink(request),
    );
    if (!context.mounted) return true;
    if (result.link == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${request.email} already had an Owner account; it is now linked.')),
      );
      return true;
    }
    await showInviteLinkDialog(context, request: request, link: result.link!);
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create link: $e')));
    }
    return false;
  }
}
