import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/widgets/file_filter_bar.dart';

void main() {
  final now = DateTime(2026, 10, 15, 14);
  bool m(FileFilters f, {String name = 'KRA PIN certificate.pdf', String? kind = 'KRA PIN', String? by = 'u1', DateTime? at}) =>
      f.matches(name: name, kind: kind, uploaderId: by, at: at ?? now, now: now);

  test('no filters match everything and are not active', () {
    const f = FileFilters();
    expect(f.isActive, isFalse);
    expect(m(f, at: DateTime(2020)), isTrue);
  });

  test('search is case-insensitive on the name', () {
    expect(m(const FileFilters(query: 'kra')), isTrue);
    expect(m(const FileFilters(query: 'tenancy')), isFalse);
  });

  test('kind and uploader', () {
    expect(m(const FileFilters(kind: 'KRA PIN')), isTrue);
    expect(m(const FileFilters(kind: 'Contract')), isFalse);
    expect(m(const FileFilters(uploaderId: 'u2')), isFalse);
  });

  test('last 7 days includes today and 6 days back, not 7', () {
    const f = FileFilters(window: DateWindow.last7);
    expect(m(f, at: DateTime(2026, 10, 9, 8)), isTrue);
    expect(m(f, at: DateTime(2026, 10, 8, 23)), isFalse);
  });

  test('last 30 days', () {
    const f = FileFilters(window: DateWindow.last30);
    expect(m(f, at: DateTime(2026, 9, 16)), isTrue);
    expect(m(f, at: DateTime(2026, 9, 15)), isFalse);
  });

  test('custom range is inclusive of both days', () {
    final f = FileFilters(window: DateWindow.custom, range: DateTimeRange(start: DateTime(2026, 10, 1), end: DateTime(2026, 10, 5)));
    expect(m(f, at: DateTime(2026, 10, 1)), isTrue);
    expect(m(f, at: DateTime(2026, 10, 5, 23, 59)), isTrue);
    expect(m(f, at: DateTime(2026, 10, 6)), isFalse);
  });

  test('copyWith can clear a filter back to null', () {
    const f = FileFilters(kind: 'KRA PIN', uploaderId: 'u1');
    final cleared = f.copyWith(kind: null);
    expect(cleared.kind, isNull);
    expect(cleared.uploaderId, 'u1');
  });
}
