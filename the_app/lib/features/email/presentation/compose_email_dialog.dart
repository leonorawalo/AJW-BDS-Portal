import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../../calendar/providers/calendar_providers.dart';
import '../../google_exports/data/google_export_repository.dart' show GoogleReconnectNeededException;
import '../../google_exports/presentation/google_export_flow.dart' show offerGoogleConnect;
import '../models/email_contact.dart';
import '../providers/email_providers.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/theme/app_theme.dart';

/// "Write email", sent from the user's own Gmail. Either about an
/// enterprise ([enterpriseId]: recipients picked from its contacts,
/// [preselectUserIds] ticked), or to fixed [directRecipients] (Admin
/// emailing a user from the Users screen).
Future<void> showComposeEmailDialog(
  BuildContext context,
  WidgetRef ref, {
  String? enterpriseId,
  Set<String> preselectUserIds = const {},
  List<EmailContact> directRecipients = const [],
  String subject = '',
}) async {
  // Check the Google connection first, so nobody writes a whole message
  // only to be told to connect.
  ref.invalidate(myGoogleConnectionProvider);
  final connection = await ref.read(myGoogleConnectionProvider.future).catchError((_) => null);
  if (!context.mounted) return;
  if (connection == null || !connection.canSendEmail) {
    await offerGoogleConnect(context, ref, reconnect: connection != null);
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _ComposeEmailDialog(
      enterpriseId: enterpriseId,
      preselectUserIds: preselectUserIds,
      directRecipients: directRecipients,
      subject: subject,
      fromEmail: connection.googleEmail,
    ),
  );
}

class _ComposeEmailDialog extends ConsumerStatefulWidget {
  const _ComposeEmailDialog({
    required this.enterpriseId,
    required this.preselectUserIds,
    required this.directRecipients,
    required this.subject,
    required this.fromEmail,
  });

  final String? enterpriseId;
  final Set<String> preselectUserIds;
  final List<EmailContact> directRecipients;
  final String subject;
  final String? fromEmail;

  @override
  ConsumerState<_ComposeEmailDialog> createState() => _ComposeEmailDialogState();
}

class _ComposeEmailDialogState extends ConsumerState<_ComposeEmailDialog> {
  late final _subjectController = TextEditingController(text: widget.subject);
  final _bodyController = TextEditingController();
  final _selected = <String>{};
  bool _preselected = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.directRecipients.map((c) => c.email));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _subjectController.text.trim().isEmpty) {
      setState(() => _error = 'Pick at least one recipient and add a subject.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(emailRepositoryProvider).send(
            enterpriseId: widget.enterpriseId,
            to: _selected.toList(),
            subject: _subjectController.text.trim(),
            body: _bodyController.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email sent from your Gmail. It is in your Sent folder.')),
      );
    } on GoogleNotConnectedException {
      setState(() => _error = 'Your Google account is not connected any more. Connect it and try again.');
    } on GoogleReconnectNeededException {
      setState(() => _error = 'Reconnect Google once (Sessions tab) to allow sending email, then try again.');
    } catch (e) {
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enterpriseId = widget.enterpriseId;
    final contactsAsync = enterpriseId == null
        ? AsyncValue.data(widget.directRecipients)
        : ref.watch(enterpriseEmailContactsProvider(enterpriseId));

    return AlertDialog(
      title: const Text('Write email'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.fromEmail != null)
                Text('From: ${widget.fromEmail} (your Gmail)', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Space.lg),
              Text('To', style: Theme.of(context).textTheme.labelLarge),
              contactsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(8),
                  child: AjwLoadingView(),
                ),
                error: (_, _) => const Text('Could not load contacts.'),
                data: (contacts) {
                  if (!_preselected) {
                    _preselected = true;
                    _selected.addAll(contacts
                        .where((c) => c.userId != null && widget.preselectUserIds.contains(c.userId))
                        .map((c) => c.email));
                  }
                  if (contacts.isEmpty) return const Text('There is nobody to email here yet.');
                  return Column(
                    children: [
                      for (final c in contacts)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _selected.contains(c.email),
                          title: Text(c.fullName),
                          subtitle: Text('${c.roleLabel} · ${c.email}'),
                          onChanged: (v) => setState(() => v == true ? _selected.add(c.email) : _selected.remove(c.email)),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              const SizedBox(height: Space.lg),
              TextField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                minLines: 5,
                maxLines: 12,
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.lg),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          icon: _sending
              ? const AjwLoader(dotSize: 6)
              : const Icon(Icons.send),
          label: const Text('Send via Gmail'),
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
