import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../calendar/providers/calendar_providers.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../data/gmail_links.dart';
import '../models/email_contact.dart';
import '../providers/email_providers.dart';
import 'compose_email_dialog.dart';

enum _EmailAction { write, find }

/// App-bar Email menu on an enterprise (every role): write an email from
/// your own Gmail to the people on this enterprise, or open Gmail searched
/// for mail with them / about the business.
class EmailMenuButton extends ConsumerWidget {
  const EmailMenuButton({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_EmailAction>(
      icon: const Icon(Icons.mail_outline),
      tooltip: 'Email',
      onSelected: (action) async {
        if (action == _EmailAction.write) {
          await showComposeEmailDialog(context, ref, enterpriseId: enterpriseId);
          return;
        }
        final contacts = await ref.read(enterpriseEmailContactsProvider(enterpriseId).future).catchError((_) => <EmailContact>[]);
        final enterprise = await ref.read(enterpriseDetailProvider(enterpriseId).future).catchError((_) => null);
        final connection = await ref.read(myGoogleConnectionProvider.future).catchError((_) => null);
        await launchUrl(
          gmailSearchUri(
            // Admins are in every enterprise's contacts; searching for them
            // would match unrelated mail, so only the enterprise's own people.
            emails: [for (final c in contacts) if (c.roleName != 'Administrator') c.email],
            phrase: enterprise?.businessName,
            accountEmail: connection?.googleEmail,
          ),
          mode: LaunchMode.externalApplication,
        );
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _EmailAction.write,
          child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Write email'), subtitle: Text('From your Gmail')),
        ),
        PopupMenuItem(
          value: _EmailAction.find,
          child: ListTile(leading: Icon(Icons.search), title: Text('Find emails in Gmail')),
        ),
      ],
    );
  }
}
