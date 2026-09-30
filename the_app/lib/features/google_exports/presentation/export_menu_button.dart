import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/progress_dialog.dart';
import '../builders/enterprise_data_sheet_builder.dart';
import '../builders/export_formatting.dart';
import '../builders/loan_readiness_report_builder.dart';
import '../builders/progress_deck_builder.dart';
import '../models/enterprise_export_data.dart';
import '../providers/google_export_providers.dart';
import 'google_export_flow.dart';
import 'pdf_export.dart' deferred as pdf_export;

enum _ExportKind { pdf, doc, sheet, slides }

/// App-bar "Export" menu for an enterprise. Available to every role; each
/// export contains only what that user can see.
/// - Loan-readiness report (PDF): generated on the device, no Google needed.
/// - Loan-readiness report / Enterprise data / Progress deck: created in the
///   user's own Google Drive (Docs / Sheets / Slides).
class ExportMenuButton extends ConsumerWidget {
  const ExportMenuButton({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ExportKind>(
      icon: const Icon(Icons.ios_share),
      tooltip: 'Export',
      onSelected: (kind) => kind == _ExportKind.pdf ? _exportPdf(context, ref) : _exportToGoogle(context, ref, kind),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _ExportKind.pdf,
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('Loan-readiness report'),
            subtitle: Text('PDF'),
          ),
        ),
        PopupMenuDivider(),
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

  /// Fresh data every time, not whatever was cached when the screen opened.
  Future<EnterpriseExportData> _loadData(WidgetRef ref) async {
    final provider = enterpriseExportDataProvider(enterpriseId);
    ref.invalidate(provider);
    // Keeps the auto-dispose provider alive while the export runs.
    final subscription = ref.listenManual(provider, (_, _) {});
    return ref.read(provider.future).whenComplete(subscription.close);
  }

  /// Web: downloads the file. Android: opens the share sheet (save to
  /// Files, send by WhatsApp/email, …).
  Future<void> _exportPdf(BuildContext context, WidgetRef ref) async {
    try {
      final (bytes, filename) = await withProgress(context, 'Preparing PDF…', () async {
        await pdf_export.loadLibrary();
        final data = await _loadData(ref);
        final report = buildLoanReadinessReport(data);
        final safeName = data.enterprise.businessName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
        return (
          await pdf_export.renderReportPdf(report),
          'Loan-readiness-report-$safeName-${exportDate(data.exportedAt)}.pdf',
        );
      }());
      await pdf_export.sharePdf(bytes, filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create PDF: $e')));
      }
    }
  }

  Future<void> _exportToGoogle(BuildContext context, WidgetRef ref, _ExportKind kind) {
    final repo = ref.read(googleExportRepositoryProvider);
    return runGoogleExport(
      context,
      ref,
      appName: switch (kind) {
        _ExportKind.sheet => 'Google Sheets',
        _ExportKind.slides => 'Google Slides',
        _ => 'Google Docs',
      },
      create: () async {
        final data = await _loadData(ref);
        final name = data.enterprise.businessName;
        final date = exportDate(data.exportedAt);
        return switch (kind) {
          _ExportKind.sheet => repo.exportSheet(
              title: '$name – Enterprise data ($date)',
              tabs: buildEnterpriseDataSheet(data),
            ),
          _ExportKind.slides => repo.exportSlides(
              title: '$name – Progress summary',
              subtitle: 'AJW BAGS Portal · $date',
              slides: buildProgressDeck(data),
            ),
          _ => repo.exportDoc(
              title: '$name – Loan-readiness report ($date)',
              html: renderLoanReadinessReportHtml(buildLoanReadinessReport(data)),
            ),
        };
      },
    );
  }
}
