import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/app_version.dart';
import '../../../core/legal/legal_documents.dart';
import '../../../core/web/cookie_settings.dart';
import '../models/consent_record.dart';
import '../models/data_request.dart';
import '../../user_management/providers/user_management_providers.dart';
import '../providers/privacy_providers.dart';
import '../../../core/user_message.dart';
import '../../../core/phone_number.dart';
import '../../auth/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// "Settings and privacy": the person's rights under the Kenya Data
/// Protection Act, 2019 (download a copy of their data, ask for a
/// correction or deletion, follow their requests), their email choice,
/// the legal pages, credits, and AJW's contact details.
class MyDataScreen extends ConsumerWidget {
  const MyDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final requests = ref.watch(myDataRequestsProvider);
    Widget section(String title, List<Widget> children) => Card(
          margin: const EdgeInsets.only(bottom: Space.lg),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title, style: text.titleMedium), const SizedBox(height: Space.xs), ...children],
            ),
          ),
        );
    return AppShell(
      title: 'Settings and privacy',
      globalKey: 'privacy',
      body: ListView(
        padding: PageBody.paddingFor(context),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Under the Kenya Data Protection Act, 2019 you can see the information the portal holds about you, '
                  'ask for it to be corrected, or ask for it to be deleted.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: Space.lg),
                section('Your contact details', [
                  Text(
                    'Your phone number is optional. AJW administrators and the people you work with in the '
                    'programme can see it, so they can call you.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: Space.sm),
                  const _PhoneNumberTile(),
                ]),
                section('Download my data', [
                  Text(
                    'A file (JSON, a standard format other systems can read) with your profile and everything '
                    'linked to you: enterprises you own, tasks, comments, uploads, meetings, messages, consents and requests.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: Space.md),
                  const _DownloadButton(),
                ]),
                section('Requests about your data', [
                  Text(
                    'An AJW administrator answers within 7 days for a copy of your data, and within 14 days for a '
                    'correction or deletion. If a request is refused, you are told why.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final kind in DataRequestKind.values)
                        OutlinedButton(
                          onPressed: () => _request(context, ref, kind),
                          child: Text(kind.actionLabel),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.md),
                  Text('My requests', style: text.titleSmall),
                  const SizedBox(height: Space.sm),
                  ...requests.when(
                    loading: () => [const AjwLoadingView()],
                    error: (_, _) => [const Text("Couldn't load your requests.")],
                    data: (list) => list.isEmpty
                        ? [Text('None yet.', style: text.bodySmall)]
                        : [for (final r in list) DataRequestTile(request: r)],
                  ),
                ]),
                section('Email preferences', const [_ProgrammeEmailsSwitch()]),
                section('Legal', [
                  for (final doc in LegalDocuments.all)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(doc.title),
                      subtitle: identical(doc, LegalDocuments.aboutAndContact)
                          ? null
                          : Text('Version ${doc.version} · updated ${_date(context, doc.lastUpdated)}'),
                      trailing: const Icon(Icons.open_in_new, size: 18, semanticLabel: 'Opens in your browser'),
                      onTap: () => launchUrl(Uri.parse(doc.url), mode: LaunchMode.externalApplication),
                    ),
                  if (cookieSettingsAvailable)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.cookie_outlined),
                      title: Text('Cookie settings'),
                      onTap: openCookieSettings,
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copyright_outlined),
                    title: const Text('Credits and licences'),
                    subtitle: const Text('Fonts and open-source software the portal uses'),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'AJW BAGS Portal',
                      applicationVersion: appVersionName,
                      applicationLegalese: '© ${BusinessDetails.tradingName}',
                    ),
                  ),
                ]),
                section('About and contact', const [_BusinessDetailsTable()]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(BuildContext context, String iso) =>
      MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(iso));

  Future<void> _request(BuildContext context, WidgetRef ref, DataRequestKind kind) async {
    final details = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(kind.actionLabel),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (kind == DataRequestKind.deletion) ...[
                const Text(
                  'An administrator will delete or anonymise your personal data and close your account. Programme '
                  "records others rely on (for example an enterprise's tasks and documents) are kept without your "
                  'name, as the Privacy Policy explains. You will get a confirmation.',
                ),
                const SizedBox(height: Space.md),
              ],
              TextField(
                controller: details,
                minLines: 3,
                maxLines: 6,
                maxLength: 4000,
                decoration: InputDecoration(
                  labelText: 'Details',
                  helperText: switch (kind) {
                    DataRequestKind.correction => 'What is wrong, and what it should say.',
                    DataRequestKind.deletion => 'What you would like deleted (or "my whole account").',
                    DataRequestKind.access => 'Anything specific you would like (optional).',
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Send request')),
        ],
      ),
    );
    if (sent != true) return;
    try {
      await ref.read(privacyRepositoryProvider).createRequest(kind, details.text);
      ref.invalidate(myDataRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to AJW.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the request. Check your connection and try again.')),
        );
      }
    }
  }
}

/// Optional programme emails (news, updates, reminders). Off unless the
/// person turns it on; every change is kept in the consent history.
/// Account and security emails are always sent.
/// Shows the person's own phone number with Add / Change / Remove.
class _PhoneNumberTile extends ConsumerWidget {
  const _PhoneNumberTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(currentUserProfileProvider).value?.phoneNumber;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.phone_outlined),
      title: Text(phone == null ? 'No phone number added' : PhoneNumber.display(phone)),
      trailing: Wrap(
        spacing: Space.xs,
        children: [
          if (phone != null)
            TextButton(
              onPressed: () => _save(context, ref, null),
              child: const Text('Remove'),
            ),
          OutlinedButton(
            onPressed: () => _edit(context, ref, phone),
            child: Text(phone == null ? 'Add' : 'Change'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, String? current) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PhoneNumberDialog(initial: current == null ? '' : PhoneNumber.display(current)),
    );
    if (result == null || !context.mounted) return;
    await _save(context, ref, result);
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String? phone) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).updateMyPhoneNumber(phone);
      ref.invalidate(currentUserProfileProvider);
      messenger.showSnackBar(SnackBar(content: Text(phone == null ? 'Phone number removed.' : 'Phone number saved.')));
    } on PostgrestException catch (e) {
      // 23505: users.phone_number is unique.
      messenger.showSnackBar(SnackBar(
        content: Text(e.code == '23505'
            ? 'That number is already on another account. Check it, or ask an AJW administrator.'
            : 'Could not save your phone number. Try again.'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not save your phone number. Try again.')));
    }
  }
}

class _PhoneNumberDialog extends StatefulWidget {
  const _PhoneNumberDialog({required this.initial});
  final String initial;

  @override
  State<_PhoneNumberDialog> createState() => _PhoneNumberDialogState();
}

class _PhoneNumberDialogState extends State<_PhoneNumberDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalised = PhoneNumber.normalise(_controller.text);
    if (normalised == null) {
      setState(() => _error = 'Enter a number like 0712 345 678 or +254 712 345 678.');
      return;
    }
    Navigator.pop(context, normalised);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your phone number'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        decoration: InputDecoration(
          labelText: 'Phone number',
          hintText: '0712 345 678',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ProgrammeEmailsSwitch extends ConsumerStatefulWidget {
  const _ProgrammeEmailsSwitch();

  @override
  ConsumerState<_ProgrammeEmailsSwitch> createState() => _ProgrammeEmailsSwitchState();
}

class _ProgrammeEmailsSwitchState extends ConsumerState<_ProgrammeEmailsSwitch> {
  bool _saving = false;

  Future<void> _set(bool on) async {
    setState(() => _saving = true);
    try {
      await ref.read(privacyRepositoryProvider).recordAnswers({ConsentPurpose.programmeEmails: on}, fromSettings: true);
      ref.invalidate(consentStatusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your choice. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(consentStatusProvider);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Programme news and updates by email'),
      subtitle: const Text(
        'Optional. Emails about your account, security, meetings you are invited to and messages people send you '
        'are always delivered.',
      ),
      value: status.value?.programmeEmails ?? false,
      onChanged: _saving || !status.hasValue ? null : _set,
    );
  }
}

/// AJW Africa's details (legal/business.json).
class _BusinessDetailsTable extends StatelessWidget {
  const _BusinessDetailsTable();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const rows = <(String, String)>[
      ('Registered name', BusinessDetails.registeredName),
      ('Physical address', BusinessDetails.physicalAddress),
      ('Email', BusinessDetails.email),
      ('Phone', BusinessDetails.phone),
      ('Data protection contact', BusinessDetails.dataProtectionContact),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelMedium?.copyWith(color: AppColors.charcoalSoft)),
                SelectableText(value, style: text.bodyMedium),
              ],
            ),
          ),
      ],
    );
  }
}

class _DownloadButton extends ConsumerStatefulWidget {
  const _DownloadButton();

  @override
  ConsumerState<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<_DownloadButton> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(privacyRepositoryProvider).exportMyData();
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await FilePicker.saveFile(
        fileName: 'ajw-bags-portal-my-data-$date.json',
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Save my data',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export: ${userMessage(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        icon: _busy ? const AjwLoader(dotSize: 5) : const Icon(Icons.download),
        label: const Text('Download my data'),
        onPressed: _busy ? null : _download,
      );
}

/// One request with its status and deadline (shared with the Admin list).
class DataRequestTile extends StatelessWidget {
  const DataRequestTile({super.key, required this.request, this.trailing, this.onTap});
  final DataRequest request;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final r = request;
    final due = r.status.isClosed
        ? '${r.status.label}${r.resolvedAt != null ? ' ${l.formatMediumDate(r.resolvedAt!)}' : ''}'
        : '${r.isOverdue ? 'OVERDUE: was due' : 'Due'} ${l.formatMediumDate(r.dueAt)}';
    return Card(
      margin: const EdgeInsets.only(bottom: Space.sm),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          r.status.isClosed ? Icons.check_circle_outline : (r.isOverdue ? Icons.error_outline : Icons.schedule),
          color: r.status.isClosed
              ? AppColors.successGreen
              : (r.isOverdue ? AppColors.errorRed : AppColors.charcoalSoft),
        ),
        title: Text([if (r.requesterName != null) r.requesterName!, r.kind.label].join(' · ')),
        subtitle: Text(
          [
            if (r.details.isNotEmpty) r.details,
            '${r.status.label} · $due',
            if (r.resolutionNote?.isNotEmpty == true) 'AJW: ${r.resolutionNote}',
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: trailing,
      ),
    );
  }
}

/// Admin: every request, oldest deadline first, and the retention
/// settings.
class DataRequestsAdminScreen extends ConsumerWidget {
  const DataRequestsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final requests = ref.watch(allDataRequestsProvider);
    return AppShell(
      title: 'Data requests',
      globalKey: 'data-requests',
      body: ListView(
        padding: PageBody.paddingFor(context),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Requests under the Kenya Data Protection Act, 2019. Deadlines: access 7 days, correction and '
                  'deletion 14 days from the request.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: Space.md),
                ...requests.when(
                  loading: () => [const AjwLoadingView()],
                  error: (_, _) => [
                    const EmptyState(isError: true, icon: Icons.cloud_off_outlined, title: "Couldn't load requests"),
                  ],
                  data: (list) {
                    final sorted = [...list]..sort((a, b) {
                        if (a.status.isClosed != b.status.isClosed) return a.status.isClosed ? 1 : -1;
                        return a.dueAt.compareTo(b.dueAt);
                      });
                    return sorted.isEmpty
                        ? [Text('No requests.', style: text.bodyMedium)]
                        : [
                            for (final r in sorted)
                              DataRequestTile(
                                request: r,
                                onTap: r.status.isClosed ? null : () => _resolve(context, ref, r),
                                trailing: r.status.isClosed ? null : const Icon(Icons.chevron_right),
                              ),
                          ];
                  },
                ),
                const SizedBox(height: Space.xl),
                const _RetentionCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref, DataRequest r) async {
    final note = TextEditingController(text: r.resolutionNote ?? '');
    String? refuseError;
    // Refusing needs a reason the person can read (the database insists
    // too). For a deletion, "Carry out deletion" does the deleting.
    final status = await showDialog<Object>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setDialogState) {
          return AlertDialog(
            title: Text('${r.kind.label} request'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320, maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (r.details.isNotEmpty) Text(r.details),
                  const SizedBox(height: Space.md),
                  TextField(
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Note to the person',
                      helperText: 'What was done. Required when you refuse: say why.',
                      errorText: refuseError,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (note.text.trim().isEmpty) {
                    setDialogState(() => refuseError = 'Give a reason for refusing.');
                    return;
                  }
                  Navigator.pop(d, DataRequestStatus.rejected);
                },
                child: const Text('Refuse'),
              ),
              TextButton(onPressed: () => Navigator.pop(d, DataRequestStatus.inProgress), child: const Text('In progress')),
              if (r.kind == DataRequestKind.deletion)
                FilledButton(onPressed: () => Navigator.pop(d, _eraseAction), child: const Text('Carry out deletion'))
              else
                FilledButton(onPressed: () => Navigator.pop(d, DataRequestStatus.completed), child: const Text('Completed')),
            ],
          );
        },
      ),
    );
    if (status == null || !context.mounted) return;
    if (identical(status, _eraseAction)) return _erase(context, ref, r);
    try {
      await ref.read(privacyRepositoryProvider).updateRequest(r.id, status as DataRequestStatus, note: note.text.trim());
      ref.invalidate(allDataRequestsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Try again.')));
      }
    }
  }

  static const _eraseAction = 'erase';

  /// Deletes or anonymises the person's personal data (manage-users), then
  /// says whether they were emailed a confirmation.
  Future<void> _erase(BuildContext context, WidgetRef ref, DataRequest r) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete ${r.requesterName ?? 'this person'}\'s data?'),
        content: const Text(
          'Their name, email, contact details, chat messages and attachments, Google connection and devices are '
          'deleted, their account is closed for good, and the audit log shows them as "a deleted user". '
          'Programme records others rely on (tasks, documents, visit notes) are kept without their name. '
          'This cannot be undone.\n\n'
          'If your Google account is connected, a confirmation is emailed to them from your Gmail.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete their data')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      final emailed = await ref.read(userAdminRepositoryProvider).eraseUserData(r.userId, requestId: r.id);
      ref.invalidate(allDataRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(emailed
              ? 'Their data was deleted and they were emailed a confirmation.'
              : 'Their data was deleted. No confirmation email was sent (connect Google to send one): '
                  'please tell them another way.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage(e))),
        );
      }
    }
  }
}

class _RetentionCard extends ConsumerWidget {
  const _RetentionCard();

  static const _choices = <int?>[null, 90, 180, 365, 730, 1825];

  static String _label(int? days) => switch (days) {
        null => 'Keep until deleted',
        365 => '1 year',
        730 => '2 years',
        1825 => '5 years',
        _ => '$days days',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(retentionSettingsProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('How long data is kept', style: text.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              'Older data is deleted only when you press "Delete old data now". The audit log is always kept.',
              style: text.bodySmall,
            ),
            const SizedBox(height: Space.md),
            ...settings.when(
              loading: () => [const AjwLoadingView()],
              error: (_, _) => [const Text("Couldn't load the settings.")],
              data: (list) => [
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: DropdownButtonFormField<int?>(
                      initialValue: _choices.contains(s.keepDays) ? s.keepDays : null,
                      decoration: InputDecoration(labelText: s.label),
                      items: [for (final c in _choices) DropdownMenuItem(value: c, child: Text(_label(c)))],
                      onChanged: (v) async {
                        await ref.read(privacyRepositoryProvider).setRetention(s.key, v);
                        ref.invalidate(retentionSettingsProvider);
                      },
                    ),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Delete old data now'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('Delete old data?'),
                      content: const Text('Everything older than the periods above is deleted for good.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    final result = await ref.read(privacyRepositoryProvider).applyRetention();
                    final total = result.values.fold<int>(0, (a, b) => a + ((b as num?)?.toInt() ?? 0));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $total old items.')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete: ${userMessage(e)}')));
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
