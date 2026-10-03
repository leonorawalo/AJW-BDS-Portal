import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum DateWindow { any, last7, last30, custom }

/// What the user has chosen in a [FileFilterBar]. Pure data; [matches] does
/// the filtering so both file lists behave the same.
class FileFilters {
  const FileFilters({
    this.query = '',
    this.kind,
    this.uploaderId,
    this.window = DateWindow.any,
    this.range,
  });

  final String query;

  /// Category (Documents) or file type (Google files).
  final String? kind;
  final String? uploaderId;
  final DateWindow window;
  final DateTimeRange? range;

  bool get isActive => query.trim().isNotEmpty || kind != null || uploaderId != null || window != DateWindow.any;

  FileFilters copyWith({
    String? query,
    Object? kind = _keep,
    Object? uploaderId = _keep,
    DateWindow? window,
    Object? range = _keep,
  }) =>
      FileFilters(
        query: query ?? this.query,
        kind: identical(kind, _keep) ? this.kind : kind as String?,
        uploaderId: identical(uploaderId, _keep) ? this.uploaderId : uploaderId as String?,
        window: window ?? this.window,
        range: identical(range, _keep) ? this.range : range as DateTimeRange?,
      );

  static const _keep = Object();

  bool matches({required String name, String? kind, String? uploaderId, required DateTime at, DateTime? now}) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !name.toLowerCase().contains(q)) return false;
    if (this.kind != null && this.kind != kind) return false;
    if (this.uploaderId != null && this.uploaderId != uploaderId) return false;
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final day = DateUtils.dateOnly(at);
    switch (window) {
      case DateWindow.any:
        return true;
      case DateWindow.last7:
        return !day.isBefore(today.subtract(const Duration(days: 6)));
      case DateWindow.last30:
        return !day.isBefore(today.subtract(const Duration(days: 29)));
      case DateWindow.custom:
        final r = range;
        return r == null || (!day.isBefore(DateUtils.dateOnly(r.start)) && !day.isAfter(DateUtils.dateOnly(r.end)));
    }
  }
}

/// Search box + filters for a list of files: [kinds] (category or file type),
/// [uploaders] (id -> name), and a date window with a custom range.
class FileFilterBar extends StatefulWidget {
  const FileFilterBar({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.kindLabel,
    required this.kinds,
    required this.uploaders,
    this.searchHint = 'Search by file name',
  });

  final FileFilters filters;
  final ValueChanged<FileFilters> onChanged;
  final String kindLabel;
  final List<String> kinds;
  final Map<String, String> uploaders;
  final String searchHint;

  @override
  State<FileFilterBar> createState() => _FileFilterBarState();
}

class _FileFilterBarState extends State<FileFilterBar> {
  late final _search = TextEditingController(text: widget.filters.query);

  @override
  void didUpdateWidget(covariant FileFilterBar old) {
    super.didUpdateWidget(old);
    if (widget.filters.query != _search.text) _search.text = widget.filters.query;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _d(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: widget.filters.range,
      helpText: 'Uploaded between',
    );
    if (picked != null) widget.onChanged(widget.filters.copyWith(window: DateWindow.custom, range: picked));
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.filters;
    final narrow = MediaQuery.sizeOf(context).width < 600;

    Widget dropdown<T>({
      required String label,
      required T? value,
      required List<DropdownMenuItem<T?>> items,
      required ValueChanged<T?> onChanged,
    }) =>
        SizedBox(
          width: narrow ? double.infinity : 200,
          child: DropdownButtonFormField<T?>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: items,
            onChanged: onChanged,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      widget.onChanged(f.copyWith(query: ''));
                    },
                  ),
          ),
          onChanged: (q) => widget.onChanged(f.copyWith(query: q)),
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            dropdown<String>(
              label: widget.kindLabel,
              value: f.kind,
              items: [
                const DropdownMenuItem(value: null, child: Text('All')),
                for (final k in widget.kinds) DropdownMenuItem(value: k, child: Text(k)),
              ],
              onChanged: (k) => widget.onChanged(f.copyWith(kind: k)),
            ),
            dropdown<String>(
              label: 'Uploaded by',
              value: widget.uploaders.containsKey(f.uploaderId) ? f.uploaderId : null,
              items: [
                const DropdownMenuItem(value: null, child: Text('Anyone')),
                for (final e in widget.uploaders.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (u) => widget.onChanged(f.copyWith(uploaderId: u)),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (w, label) in [
              (DateWindow.any, 'All time'),
              (DateWindow.last7, 'Last 7 days'),
              (DateWindow.last30, 'Last 30 days'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: f.window == w,
                onSelected: (_) => widget.onChanged(f.copyWith(window: w, range: null)),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(f.window == DateWindow.custom && f.range != null
                  ? '${_d(f.range!.start)} – ${_d(f.range!.end)}'
                  : 'Custom range'),
              selected: f.window == DateWindow.custom,
              onSelected: (_) => _pickRange(),
            ),
            if (f.isActive)
              TextButton.icon(
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(foregroundColor: AppColors.charcoalSoft),
                onPressed: () {
                  _search.clear();
                  widget.onChanged(const FileFilters());
                },
              ),
          ],
        ),
      ],
    );
  }
}
