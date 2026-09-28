import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../../calendar/providers/calendar_providers.dart';
import '../data/google_export_repository.dart';
import '../models/exported_file.dart';

/// The shared flow behind every Google export button: make sure the user
/// has a Google connection with drive.file (offer Connect/Reconnect if
/// not), show progress, then an "Export created / Open in …" dialog.
/// [appName] is e.g. 'Google Sheets'.
Future<void> runGoogleExport(
  BuildContext context,
  WidgetRef ref, {
  required String appName,
  required Future<ExportedFile> Function() create,
}) async {
  // May have just come back from the Connect/Reconnect page.
  ref.invalidate(myGoogleConnectionProvider);
  final connection = await ref.read(myGoogleConnectionProvider.future).catchError((_) => null);
  if (!context.mounted) return;
  if (connection == null || !connection.canExport) {
    await offerGoogleConnect(context, ref, reconnect: connection != null);
    return;
  }

  try {
    final file = await withProgress(context, 'Creating in your Google Drive…', create());
    if (context.mounted) await _showCreated(context, appName, file);
  } on GoogleNotConnectedException {
    ref.invalidate(myGoogleConnectionProvider);
    if (context.mounted) await offerGoogleConnect(context, ref, reconnect: false);
  } on GoogleReconnectNeededException {
    ref.invalidate(myGoogleConnectionProvider);
    if (context.mounted) await offerGoogleConnect(context, ref, reconnect: true);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

/// Shows a blocking progress dialog while [work] runs; always closes it.
Future<T> withProgress<T>(BuildContext context, String message, Future<T> work) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
  try {
    return await work;
  } finally {
    navigator.pop();
  }
}

Future<void> _showCreated(BuildContext context, String appName, ExportedFile file) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Export created'),
      content: const Text('Saved to the "AJW BAGS Portal" folder in your Google Drive.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text('Open in $appName'),
          onPressed: () {
            Navigator.pop(dialogContext);
            launchUrl(Uri.parse(file.url), mode: LaunchMode.externalApplication);
          },
        ),
      ],
    ),
  );
}

/// Same consent flow as the Sessions tab's Connect card; running it again
/// when already connected replaces the token with one that has drive.file.
Future<void> offerGoogleConnect(BuildContext context, WidgetRef ref, {required bool reconnect}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(reconnect ? 'Reconnect Google' : 'Connect Google'),
      content: Text(
        reconnect
            ? 'Your Google connection predates exports. Reconnect once to allow the '
                'app to create files in your Drive (it can only see files it creates).'
            : 'Connect your Google account to export to Docs, Sheets and Slides. '
                'Files are created in your own Drive, and the app can only see files it creates.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Not now')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              final url = await ref.read(googleConnectionRepositoryProvider).startConnect();
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not start Google sign-in: $e')),
                );
              }
            }
          },
          child: Text(reconnect ? 'Reconnect' : 'Connect'),
        ),
      ],
    ),
  );
}
