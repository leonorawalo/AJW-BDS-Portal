import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../../calendar/providers/calendar_providers.dart';
import '../builders/enterprise_data_sheet_builder.dart';
import '../builders/export_formatting.dart';
import '../builders/loan_readiness_report_builder.dart';
import '../builders/progress_deck_builder.dart';
import '../data/google_export_repository.dart';
import '../models/exported_file.dart';
import '../providers/google_export_providers.dart';

enum _ExportKind { doc, sheet, slides }

/// App-bar "Export" menu for an enterprise: loan-readiness report (Docs),
/// enterprise data (Sheets), progress deck (Slides) — created in the
/// user's own Google Drive. Available to every role; each export contains
/// only what that user can see.
class ExportMenuButton extends ConsumerWidget {
  const ExportMenuButton({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ExportKind>(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Export to Google',
      onSelected: (kind) => _export(context, ref, kind),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ExportKind.doc,
          child: ListTile(
            leading: Icon(Icons.description_outlined),
            title: Text('Loan-readiness report'),
            subtitle: Text('Google Docs'),
          ),
        ),
        PopupMenuItem(
          value: _ExportKind.sheet,
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text('Enterprise data'),
            subtitle: Text('Google Sheets'),
          ),
        ),
        PopupMenuItem(
          value: _ExportKind.slides,
          child: ListTile(
            leading: Icon(Icons.slideshow_outlined),
            title: Text('Progress deck'),
            subtitle: Text('Google Slides'),
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, _ExportKind kind) async {
    // May have just come back from the Connect/Reconnect page.
    ref.invalidate(myGoogleConnectionProvider);
    final connection = await ref.read(myGoogleConnectionProvider.future).catchError((_) => null);
    if (!context.mounted) return;
    if (connection == null || !connection.canExport) {
      await _offerConnect(context, ref, reconnect: connection != null);
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Creating in your Google Drive…')),
          ],
        ),
      ),
    );

    try {
      final file = await _create(ref, kind);
      navigator.pop();
      if (context.mounted) await _showCreated(context, kind, file);
    } on GoogleNotConnectedException {
      navigator.pop();
      ref.invalidate(myGoogleConnectionProvider);
      if (context.mounted) await _offerConnect(context, ref, reconnect: false);
    } on GoogleReconnectNeededException {
      navigator.pop();
      ref.invalidate(myGoogleConnectionProvider);
      if (context.mounted) await _offerConnect(context, ref, reconnect: true);
    } catch (e) {
      navigator.pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<ExportedFile> _create(WidgetRef ref, _ExportKind kind) async {
    // Fresh data every time, not whatever was cached when the screen opened.
    final provider = enterpriseExportDataProvider(enterpriseId);
    ref.invalidate(provider);
    // Keeps the auto-dispose provider alive while the export runs.
    final subscription = ref.listenManual(provider, (_, _) {});
    final data = await ref.read(provider.future).whenComplete(subscription.close);
    final repo = ref.read(googleExportRepositoryProvider);
    final name = data.enterprise.businessName;
    final date = exportDate(data.exportedAt);

    return switch (kind) {
      _ExportKind.doc => repo.exportDoc(
          title: '$name – Loan-readiness report ($date)',
          html: buildLoanReadinessReportHtml(data),
        ),
      _ExportKind.sheet => repo.exportSheet(
          title: '$name – Enterprise data ($date)',
          tabs: buildEnterpriseDataSheet(data),
        ),
      _ExportKind.slides => repo.exportSlides(
          title: '$name – Progress summary',
          subtitle: 'AJW BAGS Portal · $date',
          slides: buildProgressDeck(data),
        ),
    };
  }

  Future<void> _showCreated(BuildContext context, _ExportKind kind, ExportedFile file) {
    final app = switch (kind) {
      _ExportKind.doc => 'Google Docs',
      _ExportKind.sheet => 'Google Sheets',
      _ExportKind.slides => 'Google Slides',
    };
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Export created'),
        content: const Text('Saved to the "AJW BAGS Portal" folder in your Google Drive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text('Open in $app'),
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
  Future<void> _offerConnect(BuildContext context, WidgetRef ref, {required bool reconnect}) {
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
}
