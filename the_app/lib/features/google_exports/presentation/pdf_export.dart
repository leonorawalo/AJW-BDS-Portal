import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../builders/loan_readiness_report_pdf.dart';
import '../models/loan_readiness_report.dart';

// Loaded as a deferred library by ExportMenuButton, so the pdf and printing
// packages are only downloaded on web when someone actually exports a PDF.

Future<Uint8List> renderReportPdf(LoanReadinessReport report) => renderLoanReadinessReportPdf(report);

/// Web: downloads the file. Android: opens the share sheet.
Future<void> sharePdf(Uint8List bytes, String filename) => Printing.sharePdf(bytes: bytes, filename: filename);
