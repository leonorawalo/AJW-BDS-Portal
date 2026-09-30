import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/progress_dialog.dart';
import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../../calendar/providers/calendar_providers.dart';
import '../../google_exports/data/google_export_repository.dart' show GoogleReconnectNeededException;
import '../../google_exports/presentation/google_export_flow.dart' show offerGoogleConnect;
import '../data/enterprise_file_repository.dart';
import '../models/enterprise_file.dart';
import '../providers/drive_files_providers.dart';
import '../../../core/widgets/ajw_loader.dart';

/// B2: the enterprise's working Google files. Anyone on the enterprise
/// (Admin, Owner, consultants) can create a Doc / Sheet / Slides; it's
/// created in their own Drive and shared as editor with the Owner and
/// active consultants, and listed here for everyone to find.
class FilesTab extends ConsumerWidget {
  const FilesTab({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(enterpriseFilesProvider(enterpriseId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New file'),
        onPressed: () async {
          final kind = await showModalBottomSheet<GoogleFileKind>(
            context: context,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final kind in GoogleFileKind.values)
                    ListTile(
                      leading: Icon(_icon(kind)),
                      title: Text('New ${kind.label}'),
                      onTap: () => Navigator.pop(sheetContext, kind),
                    ),
                ],
              ),
            ),
          );
          if (kind != null && context.mounted) await _create(context, ref, kind);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(enterpriseFilesProvider(enterpriseId)),
        child: filesAsync.when(
          loading: () => const AjwLoadingView(),
          error: (_, _) => ListView(children: const [
            Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Could not load files.'))),
          ]),
          data: (files) => files.isEmpty
              ? ListView(children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No Google files yet.\nUse "New file" to create a Doc, Sheet or Slides '
                        'shared with everyone working on this enterprise.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _FileCard(file: files[i]),
                ),
        ),
      ),
    );
  }

  static IconData _icon(GoogleFileKind kind) => switch (kind) {
        GoogleFileKind.doc => Icons.description_outlined,
        GoogleFileKind.sheet => Icons.table_chart_outlined,
        GoogleFileKind.slides => Icons.slideshow_outlined,
      };

  Future<void> _create(BuildContext context, WidgetRef ref, GoogleFileKind kind) async {
    // Google connection with drive.file first, so nobody names a file only
    // to be told to connect.
    ref.invalidate(myGoogleConnectionProvider);
    final connection = await ref.read(myGoogleConnectionProvider.future).catchError((_) => null);
    if (!context.mounted) return;
    if (connection == null || !connection.canExport) {
      await offerGoogleConnect(context, ref, reconnect: connection != null);
      return;
    }

    final title = await _askTitle(context, kind);
    if (title == null || !context.mounted) return;

    try {
      final (file, share) = await withProgress(
        context,
        'Creating ${kind.label}…',
        ref.read(enterpriseFileRepositoryProvider).create(enterpriseId: enterpriseId, kind: kind, title: title),
      );
      ref.invalidate(enterpriseFilesProvider(enterpriseId));
      await launchUrl(Uri.parse(file.webUrl), mode: LaunchMode.externalApplication);
      if (context.mounted) _reportSharing(context, share);
    } on GoogleNotConnectedException {
      if (context.mounted) await offerGoogleConnect(context, ref, reconnect: false);
    } on GoogleReconnectNeededException {
      if (context.mounted) await offerGoogleConnect(context, ref, reconnect: true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create the file: $e')));
      }
    }
  }

  Future<String?> _askTitle(BuildContext context, GoogleFileKind kind) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('New ${kind.label}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(dialogContext, v);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

void _reportSharing(BuildContext context, ShareResult share) {
  final message = share.notShared.isEmpty
      ? (share.sharedWith.isEmpty
          ? 'Created. Nobody else is on this enterprise yet to share it with.'
          : 'Shared with ${share.sharedWith.length} ${share.sharedWith.length == 1 ? 'person' : 'people'} on this enterprise.')
      : "Couldn't share with ${share.notShared.join(', ')} (no Google account). "
          'Share from Google directly if needed.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

enum _FileAction { open, pdf, share, remove }

class _FileCard extends ConsumerWidget {
  const _FileCard({required this.file});
  final EnterpriseFile file;

  Future<void> _run(BuildContext context, WidgetRef ref, _FileAction action) async {
    final repo = ref.read(enterpriseFileRepositoryProvider);
    switch (action) {
      case _FileAction.open:
        await launchUrl(Uri.parse(file.webUrl), mode: LaunchMode.externalApplication);
      case _FileAction.pdf:
        await launchUrl(file.pdfUrl, mode: LaunchMode.externalApplication);
      case _FileAction.share:
        try {
          final share = await withProgress(context, 'Updating sharing…', repo.updateSharing(file.id));
          ref.invalidate(enterpriseFilesProvider(file.enterpriseId));
          if (context.mounted) _reportSharing(context, share);
        } on GoogleNotConnectedException {
          if (context.mounted) await offerGoogleConnect(context, ref, reconnect: false);
        } on GoogleReconnectNeededException {
          if (context.mounted) await offerGoogleConnect(context, ref, reconnect: true);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
          }
        }
      case _FileAction.remove:
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Remove from the list?'),
            content: const Text(
              "It disappears from this enterprise's Files list. The Google file itself stays in its "
              "creator's Drive, and people it was shared with keep access.",
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
            ],
          ),
        );
        if (ok != true) return;
        await repo.removeFromList(file.id);
        ref.invalidate(enterpriseFilesProvider(file.enterpriseId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.read(authRepositoryProvider).currentUser?.id;
    final isAdmin = ref.watch(currentUserProfileProvider).value?.role == UserRole.administrator;
    final isCreator = file.createdBy == myId;
    final l = MaterialLocalizations.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(FilesTab._icon(file.kind)),
        title: Text(file.title),
        subtitle: Text(
          '${file.kind.label} · ${isCreator ? 'you' : file.creatorName ?? 'a team member'} · '
          '${l.formatMediumDate(file.createdAt)}',
        ),
        onTap: () => _run(context, ref, _FileAction.open),
        trailing: PopupMenuButton<_FileAction>(
          onSelected: (a) => _run(context, ref, a),
          itemBuilder: (_) => [
            const PopupMenuItem(value: _FileAction.open, child: Text('Open in Google')),
            const PopupMenuItem(value: _FileAction.pdf, child: Text('Download as PDF')),
            if (isCreator)
              const PopupMenuItem(value: _FileAction.share, child: Text('Update sharing (new team members)')),
            if (isCreator || isAdmin)
              const PopupMenuItem(value: _FileAction.remove, child: Text('Remove from list')),
          ],
        ),
      ),
    );
  }
}
