import 'dart:convert';
import 'dart:typed_data';

import 'workshop.dart';

/// A workshop's registration list as an Excel-ready CSV (the ToR asks for
/// "an excel copy"): UTF-8 with a byte-order mark so Excel shows names
/// with accents correctly, CRLF line ends, and every field quoted.
class RegistrationList {
  const RegistrationList(this.workshop, this.attendees);

  final Workshop workshop;
  final List<WorkshopAttendee> attendees;

  static const header = ['#', 'Full name', 'Phone', 'Business', 'Workshop', 'Type', 'Date', 'Location'];

  String get fileName {
    final title = workshop.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    return 'Registration list - ${title.isEmpty ? 'Workshop' : title} - ${_isoDay(workshop.heldOn)}.csv';
  }

  String toCsv() {
    final rows = [
      header,
      for (var i = 0; i < attendees.length; i++)
        [
          '${i + 1}',
          attendees[i].fullName,
          attendees[i].phone ?? '',
          attendees[i].businessName ?? '',
          workshop.title,
          workshop.kind,
          _isoDay(workshop.heldOn),
          workshop.location ?? '',
        ],
    ];
    return rows.map((r) => r.map(_cell).join(',')).join('\r\n');
  }

  Uint8List toBytes() => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(toCsv())]);

  /// Quoted, with quotes doubled. A value Excel would run as a formula
  /// (starting with = + - @) is kept as text with a leading apostrophe,
  /// so a typed name can never execute in the M&E team's spreadsheet.
  /// Plain numbers such as "+254 712 345 678" are left alone: they can't run.
  static String _cell(String value) {
    var v = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
    final plainNumber = RegExp(r'^[+-]?[0-9 ()]+$').hasMatch(v);
    if (v.isNotEmpty && '=+-@'.contains(v[0]) && !plainNumber) v = "'$v";
    return '"${v.replaceAll('"', '""')}"';
  }

  static String _isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
