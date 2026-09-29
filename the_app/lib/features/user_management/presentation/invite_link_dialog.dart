import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invite_request.dart';

/// Shows a set-password link for the Admin to pass on themselves — the
/// fallback when the invite email can't be sent, and handy in the field
/// where WhatsApp is how people actually talk.
Future<void> showInviteLinkDialog(
  BuildContext context, {
  required InviteRequest request,
  required String link,
}) {
  final message = 'Hi ${request.firstName}, you have been invited to the AJW BAGS Portal. '
      'Open this link to set your password: $link';

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Invite link for ${request.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anyone with this link can set the password for this account, so send it only to '
            'this person. It expires after a while; create a new one if needed.',
          ),
          const SizedBox(height: 12),
          SelectableText(link, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: message));
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Invite message copied.')),
              );
            }
          },
        ),
        FilledButton.icon(
          icon: const Icon(Icons.chat),
          label: const Text('WhatsApp'),
          onPressed: () {
            // wa.me wants the number in international format, digits only.
            final digits = (request.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
            final phone = digits.startsWith('0') ? '254${digits.substring(1)}' : digits;
            final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
            launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ],
    ),
  );
}
