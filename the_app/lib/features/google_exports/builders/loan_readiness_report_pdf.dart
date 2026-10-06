import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/loan_readiness_report.dart';
import 'export_formatting.dart';

/// Renders the loan-readiness report as a PDF, entirely on the device: no
/// Google connection needed (Owners typically won't have one). Same
/// content as the Google Doc: both come from buildLoanReadinessReport().
///
/// Uses the PDF standard Helvetica font (nothing to bundle or download),
/// which only covers Latin-1, so text passes through [_pdfSafe].
Future<Uint8List> renderLoanReadinessReportPdf(LoanReadinessReport r) async {
  final logo = await _loadLogo();
  const charcoal = PdfColor.fromInt(0xFF333333);
  const muted = PdfColor.fromInt(0xFF777777);
  const green = PdfColor.fromInt(0xFF2E7D32);
  const red = PdfColor.fromInt(0xFFC62828);

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(_pdfSafe(text), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
        headers: headers.map(_pdfSafe).toList(),
        data: [for (final row in rows) row.map(_pdfSafe).toList()],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEEEEE)),
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
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: charcoal, width: 1))),
        child: pw.Row(
          children: [
            if (logo != null) pw.Image(logo, height: 28),
            if (logo != null) pw.SizedBox(width: 10),
            pw.Text('AJW BAGS Portal', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Spacer(),
            pw.Text('Loan-readiness report', style: const pw.TextStyle(fontSize: 9, color: muted)),
          ],
        ),
      ),
      footer: (context) => pw.Row(
        children: [
          pw.Text(
            _pdfSafe('Generated ${exportDateTime(r.exportedAt)} by ${r.exportedBy}'),
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
          pw.Spacer(),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: muted)),
        ],
      ),
      build: (context) => [
        pw.SizedBox(height: 8),
        pw.Text(_pdfSafe(r.enterpriseName), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(LoanReadinessReport.disclaimer, style: const pw.TextStyle(fontSize: 8, color: muted)),
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
                      pw.Text(_pdfSafe(s.label), style: const pw.TextStyle(fontSize: 9, color: muted)),
                      pw.Text(exportScore(s.score), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text(s.band, style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        heading('KCB MSME requirements: ${r.kcbMetCount} of ${r.kcbRequirements.length} met'),
        table(['Requirement', 'Status'], [
          for (final (met, label) in r.kcbRequirements) [label, met ? 'Met' : 'Not yet'],
        ]),
        heading('Red flags'),
        if (r.redFlags.isEmpty)
          pw.Text('No red flags right now.', style: const pw.TextStyle(fontSize: 9, color: green))
        else
          for (final f in r.redFlags)
            pw.Bullet(text: _pdfSafe(f), style: const pw.TextStyle(fontSize: 9, color: red)),
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
