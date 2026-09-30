import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../enterprises/providers/enterprise_providers.dart';
import '../../user_management/providers/user_management_providers.dart';
import '../data/audit_repository.dart';
import '../models/audit_entry.dart';
import '../providers/audit_providers.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/ajw_loader.dart';

/// Admin: the audit log (Phase 9c), newest first, filterable by
/// enterprise, user (what they did or what happened to them) and date.
/// [initialEnterpriseId] pre-filters when opened from an enterprise.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key, this.initialEnterpriseId});
  final String? initialEnterpriseId;

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  late String? _enterpriseId = widget.initialEnterpriseId;
  String? _userId;
  DateTimeRange? _dates;

  final _entries = <AuditEntry>[];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  // Ignores a page that arrives after the filters changed.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _entries.clear();
        _hasMore = true;
      }
    });
    try {
      final page = await ref.read(auditRepositoryProvider).fetch(
            enterpriseId: _enterpriseId,
            userId: _userId,
            from: _dates?.start,
            to: _dates?.end,
            offset: _entries.length,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries.addAll(page);
        _hasMore = page.length == AuditRepository.pageSize;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _error = 'Could not load the audit log.');
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: now,
      initialDateRange: _dates,
    );
    if (picked != null) {
      setState(() => _dates = picked);
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enterprises = ref.watch(enterprisesListProvider).value ?? const [];
    final users = ref.watch(managedUsersProvider).value ?? const [];
    final localizations = MaterialLocalizations.of(context);
    final hasFilters = _enterpriseId != null || _userId != null || _dates != null;

    return AppShell(
      title: 'Audit log',
      globalKey: 'audit',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _enterpriseId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Enterprise', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All enterprises')),
                      for (final e in enterprises) DropdownMenuItem(value: e.id, child: Text(e.businessName)),
                    ],
                    onChanged: (v) {
                      setState(() => _enterpriseId = v);
                      _load(reset: true);
                    },
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _userId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'User', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All users')),
                      for (final u in users) DropdownMenuItem(value: u.id, child: Text(u.fullName)),
                    ],
                    onChanged: (v) {
                      setState(() => _userId = v);
                      _load(reset: true);
                    },
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(_dates == null
                      ? 'Any date'
                      : '${localizations.formatShortDate(_dates!.start)} – '
                          '${localizations.formatShortDate(_dates!.end)}'),
                  onPressed: _pickDates,
                ),
                if (hasFilters)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _enterpriseId = null;
                        _userId = null;
                        _dates = null;
                      });
                      _load(reset: true);
                    },
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_error != null && _entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: () => _load(reset: true), child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return _loading
          ? const AjwLoadingView()
          : const Center(child: Text('No events match these filters.'));
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _entries.length + 1,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == _entries.length) {
            if (!_hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('End of the log.')),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: _loading
                    ? const AjwLoader()
                    : OutlinedButton(onPressed: () => _load(reset: false), child: const Text('Load more')),
              ),
            );
          }
          return _AuditTile(entry: _entries[i]);
        },
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});
  final AuditEntry entry;

  static IconData _icon(String entityType) => switch (entityType) {
        'user' => Icons.person_outline,
        'enterprise' => Icons.business_outlined,
        'assignment' => Icons.assignment_ind_outlined,
        'task' => Icons.task_alt,
        'document' => Icons.description_outlined,
        'session' => Icons.event_outlined,
        _ => Icons.history,
      };

  @override
  Widget build(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    final when = '${l.formatMediumDate(entry.occurredAt)}, '
        '${l.formatTimeOfDay(TimeOfDay.fromDateTime(entry.occurredAt))}';
    final meta = [
      'by ${entry.actorName ?? 'System'}',
      when,
      if (entry.enterpriseName != null) entry.enterpriseName!,
    ].join(' · ');

    return ListTile(
      leading: Icon(_icon(entry.entityType)),
      title: Text(entry.summary),
      subtitle: Text(meta, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
