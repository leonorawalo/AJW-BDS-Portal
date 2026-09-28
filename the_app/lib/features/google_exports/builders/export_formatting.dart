import 'dart:convert';

/// Shared formatting for the export builders, so the Doc, Sheet and
/// Slides versions of the same data read identically.
String exportDate(DateTime? d) => d == null
    ? ''
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String exportDateTime(DateTime d) =>
    '${exportDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String exportMoney(double? v) {
  if (v == null) return 'Not recorded';
  final digits = v.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return 'KSh $grouped';
}

String exportScore(double score) => '${score.toStringAsFixed(0)}/100';

/// Escapes user-entered text for the Doc's HTML.
String esc(String? s) => const HtmlEscape().convert(s ?? '');
