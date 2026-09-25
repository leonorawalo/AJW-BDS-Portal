import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consultation_session_repository.dart';
import '../providers/calendar_providers.dart';

/// Books a session on the Consultant's Google Calendar. Returns true when
/// a session was created.
Future<bool> showScheduleSessionDialog(BuildContext context, String enterpriseId) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => _ScheduleSessionDialog(enterpriseId: enterpriseId),
  );
  return created ?? false;
}

class _ScheduleSessionDialog extends ConsumerStatefulWidget {
  const _ScheduleSessionDialog({required this.enterpriseId});
  final String enterpriseId;

  @override
  ConsumerState<_ScheduleSessionDialog> createState() => _ScheduleSessionDialogState();
}

class _ScheduleSessionDialogState extends ConsumerState<_ScheduleSessionDialog> {
  static const _durations = [30, 45, 60, 90, 120];

  final _titleController = TextEditingController(text: 'Consultation session');
  final _notesController = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  int _durationMinutes = 60;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _date == null || _time == null) {
      setState(() => _error = 'Title, date and time are required.');
      return;
    }
    final startsAt = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    if (startsAt.isBefore(DateTime.now())) {
      setState(() => _error = 'Pick a time in the future.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(consultationSessionRepositoryProvider).scheduleSession(
            enterpriseId: widget.enterpriseId,
            title: title,
            startsAt: startsAt,
            endsAt: startsAt.add(Duration(minutes: _durationMinutes)),
            description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on GoogleNotConnectedException {
      ref.invalidate(myGoogleConnectionProvider);
      setState(() => _error = 'Your Google Calendar is not connected (or access expired). '
          'Connect it from the Sessions tab and try again.');
    } catch (e) {
      setState(() => _error = 'Could not schedule: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    return AlertDialog(
      title: const Text('Schedule session'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_date == null ? 'Date' : localizations.formatMediumDate(_date!)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text(_time == null ? 'Time' : localizations.formatTimeOfDay(_time!)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              decoration: const InputDecoration(labelText: 'Duration'),
              items: [
                for (final m in _durations) DropdownMenuItem(value: m, child: Text('$m minutes')),
              ],
              onChanged: (m) => setState(() => _durationMinutes = m ?? _durationMinutes),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Agenda / notes (optional)'),
              maxLines: 3,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Schedule'),
        ),
      ],
    );
  }
}
