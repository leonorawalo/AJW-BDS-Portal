import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/app_colors.dart';
import '../models/loan_readiness_report.dart';
import 'document_brand.dart';
import 'export_formatting.dart';
import '../../../core/lender.dart';

/// Renders the loan-readiness report as a PDF, entirely on the device: no
/// Google connection needed (Owners typically won't have one). Same
/// content as the Google Doc: both come from buildLoanReadinessReport().
///
/// Uses the PDF standard Helvetica font (nothing to bundle or download),
/// which only covers Latin-1, so text passes through [_pdfSafe].
Future<Uint8List> renderLoanReadinessReportPdf(LoanReadinessReport r) async {
  final logo = await _loadLogo();
  // The shared document template's colours (document_brand.dart).
  final brand = PdfColor.fromInt(AppColors.brandRed.toARGB32());
  final brandTint = PdfColor.fromInt(AppColors.brandRedTint.toARGB32());
  final charcoal = PdfColor.fromInt(AppColors.charcoal.toARGB32());
  final muted = PdfColor.fromInt(AppColors.charcoalSoft.toARGB32());
  final green = PdfColor.fromInt(AppColors.successGreen.toARGB32());
  final red = PdfColor.fromInt(AppColors.errorRed.toARGB32());
  final footerLine = DocumentBrand.footerText(
    documentType: LoanReadinessReport.documentType,
    enterpriseName: r.enterpriseName,
    generatedAt: r.exportedAt,
  );

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(_pdfSafe(text), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: brand)),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
        headers: headers.map(_pdfSafe).toList(),
        data: [for (final row in rows) row.map(_pdfSafe).toList()],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: pw.BoxDecoration(color: brandTint),
        cellAlignment: pw.Alignment.centerLeft,
        border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCCCCCC), width: 0.5),
      );

  pw.Widget factsTable(List<(String, String)> rows) => pw.Table(
        border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCCCCCC), width: 0.5),
        columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(2)},
        children: [
          for (final (label, value) in rows)
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(_pdfSafe(label), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(_pdfSafe(value), style: const pw.TextStyle(fontSize: 9)),
              ),
            ]),
        ],
      );

  final doc = pw.Document(title: 'Loan-readiness report: ${_pdfSafe(r.enterpriseName)}', author: 'AJW BAGS Portal');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 4),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: brand, width: 1.5))),
        child: pw.Row(
          children: [
            if (logo != null) pw.Image(logo, height: 30),
            if (logo != null) pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(DocumentBrand.organisation, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: brand)),
                pw.Text(DocumentBrand.portalName, style: pw.TextStyle(fontSize: 7, color: muted)),
              ],
            ),
            pw.Spacer(),
            pw.Text(LoanReadinessReport.documentType, style: pw.TextStyle(fontSize: 9, color: charcoal)),
          ],
        ),
      ),
      footer: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: muted, width: 0.5))),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(_pdfSafe(footerLine), style: pw.TextStyle(fontSize: 8, color: muted)),
            ),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: muted)),
          ],
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 8),
        pw.Text(_pdfSafe(r.enterpriseName), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: charcoal)),
        pw.SizedBox(height: 2),
        pw.Text(_pdfSafe('Prepared by ${r.exportedBy}, ${exportDateTime(r.exportedAt)}'),
            style: pw.TextStyle(fontSize: 9, color: muted)),
        pw.SizedBox(height: 4),
        pw.Text(LoanReadinessReport.disclaimer, style: pw.TextStyle(fontSize: 8, color: muted)),
        heading('Enterprise'),
        factsTable(r.enterpriseFacts),
        heading('Scores'),
        pw.Row(
          children: [
            for (final s in r.scores)
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFCCCCCC)),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(_pdfSafe(s.label), style: pw.TextStyle(fontSize: 9, color: muted)),
                      pw.Text(exportScore(s.score), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text(s.band, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        heading('${Lender.requirements}: ${r.bankMetCount} of ${r.bankRequirements.length} met'),
        table(['Requirement', 'Status'], [
          for (final (met, label) in r.bankRequirements) [label, met ? 'Met' : 'Not yet'],
        ]),
        heading('Red flags'),
        if (r.redFlags.isEmpty)
          pw.Text('No red flags right now.', style: pw.TextStyle(fontSize: 9, color: green))
        else
          for (final f in r.redFlags)
            pw.Bullet(text: _pdfSafe(f), style: pw.TextStyle(fontSize: 9, color: red)),
        heading("What's driving the score"),
        table(['Criterion', 'Status', 'Satisfied by'], [
          for (final d in r.drivers) [d.label, d.done ? 'Done' : 'Outstanding', d.source],
        ]),
        heading('Financial facts'),
        factsTable(r.financialFacts),
      ],
    ),
  );
  return doc.save();
}

/// The logo asset is WebP, which the pdf package can't embed; Flutter's
/// own codec decodes it (web and Android alike) and it's re-encoded as PNG.
Future<pw.ImageProvider?> _loadLogo() async {
  try {
    final data = await rootBundle.load('assets/images/ajw_logo.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return null;
    return pw.MemoryImage(png.buffer.asUint8List());
  } catch (_) {
    // The "AJW BAGS Portal" text still brands the page; a logo problem
    // shouldn't stop the report.
    return null;
  }
}

/// Helvetica in PDFs covers Latin-1 only; map common typographic
/// characters to ASCII and replace anything else rather than failing.
String _pdfSafe(String s) {
  const replacements = {
    '–': '-', '—': '-', '‘': "'", '’': "'",
    '“': '"', '”': '"', '…': '...', '•': '-',
  };
  final out = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    out.write(replacements[ch] ?? (rune <= 0xFF ? ch : '?'));
  }
  return out.toString();
}
