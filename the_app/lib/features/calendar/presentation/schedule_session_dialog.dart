import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/consultation_session_repository.dart';
import '../models/participant_availability.dart';
import '../models/session_invitee.dart';
import '../providers/calendar_providers.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/theme/app_theme.dart';

/// Books a meeting on the caller's own Google Calendar and invites the
/// chosen participants. Who can be picked comes from
/// session_invitee_candidates() (the invite rules live in the database).
/// Returns true when a session was created.
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
  final _participantIds = <String>{};
  DateTime? _date;
  TimeOfDay? _time;
  int _durationMinutes = 60;
  bool _isSaving = false;
  String? _error;

  List<ParticipantAvailability>? _availability;
  bool _checkingAvailability = false;
  // Ignores results from an older check that finishes after a newer one.
  int _availabilityRequest = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime? get _startsAt => _date == null || _time == null
      ? null
      : DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);

  DateTime get _endsAt => _startsAt!.add(Duration(minutes: _durationMinutes));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _checkAvailability();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0));
    if (picked != null) {
      setState(() => _time = picked);
      _checkAvailability();
    }
  }

  /// Runs whenever the time or the participants change. Advisory only:
  /// the server checks again when booking.
  Future<void> _checkAvailability() async {
    final startsAt = _startsAt;
    final request = ++_availabilityRequest;
    if (startsAt == null || _participantIds.isEmpty) {
      setState(() => _availability = null);
      return;
    }
    setState(() => _checkingAvailability = true);
    try {
      final result = await ref
          .read(consultationSessionRepositoryProvider)
          .checkAvailability(
            enterpriseId: widget.enterpriseId,
            participantIds: _participantIds.toList(),
            startsAt: startsAt,
            endsAt: _endsAt,
          );
      if (mounted && request == _availabilityRequest) setState(() => _availability = result);
    } catch (_) {
      // Not being able to check shouldn't block booking.
      if (mounted && request == _availabilityRequest) setState(() => _availability = null);
    } finally {
      if (mounted && request == _availabilityRequest) setState(() => _checkingAvailability = false);
    }
  }

  Future<bool> _confirmBookAnyway(List<ParticipantAvailability> availability) async {
    final busy = availability.where((a) => a.status == AvailabilityStatus.busy).map((a) => a.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Calendar clash'),
        content: Text('Busy at this time: ${busy.join(', ')}.\n\nBook the meeting anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Pick another time')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Book anyway')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final startsAt = _startsAt;
    if (title.isEmpty || startsAt == null) {
      setState(() => _error = 'Title, date and time are required.');
      return;
    }
    if (_participantIds.isEmpty) {
      setState(() => _error = 'Pick at least one participant.');
      return;
    }
    if (startsAt.isBefore(DateTime.now())) {
      setState(() => _error = 'Pick a time in the future.');
      return;
    }

    var force = false;
    final known = _availability;
    if (known != null && known.any((a) => a.status == AvailabilityStatus.busy)) {
      if (!await _confirmBookAnyway(known)) return;
      force = true;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final repo = ref.read(consultationSessionRepositoryProvider);
      Future<void> book(bool force) => repo.scheduleSession(
        enterpriseId: widget.enterpriseId,
        participantIds: _participantIds.toList(),
        title: title,
        startsAt: startsAt,
        endsAt: _endsAt,
        description: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        force: force,
      );
      try {
        await book(force);
      } on SessionClashException catch (clash) {
        // Someone's calendar changed since the dialog last checked.
        if (!mounted) return;
        setState(() => _availability = clash.availability);
        if (!await _confirmBookAnyway(clash.availability)) return;
        await book(true);
      }
      if (mounted) Navigator.pop(context, true);
    } on GoogleNotConnectedException {
      ref.invalidate(myGoogleConnectionProvider);
      setState(
        () => _error =
            'Your Google Calendar is not connected (or access expired). '
            'Connect it from the Sessions tab and try again.',
      );
    } catch (e) {
      setState(() => _error = 'Could not schedule: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final candidatesAsync = ref.watch(sessionInviteeCandidatesProvider(widget.enterpriseId));

    return AlertDialog(
      title: const Text('Schedule meeting'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: Space.lg),
              Text('Participants', style: Theme.of(context).textTheme.labelLarge),
              candidatesAsync.when(
                loading: () => const Padding(padding: EdgeInsets.all(8), child: AjwLoadingView()),
                error: (_, _) => const Text('Could not load who you can invite.'),
                data: (candidates) => _ParticipantPicker(
                  candidates: candidates,
                  selected: _participantIds,
                  onChanged: (id, checked) {
                    setState(() => checked ? _participantIds.add(id) : _participantIds.remove(id));
                    _checkAvailability();
                  },
                ),
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(_date == null ? 'Date' : localizations.formatMediumDate(_date!)),
                      onPressed: _pickDate,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(_time == null ? 'Time' : localizations.formatTimeOfDay(_time!)),
                      onPressed: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                decoration: const InputDecoration(labelText: 'Duration'),
                items: [for (final m in _durations) DropdownMenuItem(value: m, child: Text('$m minutes'))],
                onChanged: (m) {
                  setState(() => _durationMinutes = m ?? _durationMinutes);
                  _checkAvailability();
                },
              ),
              if (_checkingAvailability)
                const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator())
              else if (_availability != null) ...[
                const SizedBox(height: Space.lg),
                _AvailabilitySummary(availability: _availability!),
              ],
              const SizedBox(height: Space.lg),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Agenda / notes (optional)'),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.lg),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving ? const AjwLoader(dotSize: 6) : const Text('Schedule'),
        ),
      ],
    );
  }
}

class _ParticipantPicker extends StatelessWidget {
  const _ParticipantPicker({required this.candidates, required this.selected, required this.onChanged});

  final List<SessionInvitee> candidates;
  final Set<String> selected;
  final void Function(String userId, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('There is nobody you can invite on this enterprise yet.'),
      );
    }
    return Column(
      children: [
        for (final c in candidates)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selected.contains(c.userId),
            title: Text(c.fullName),
            subtitle: Text(c.roleLabel),
            onChanged: (checked) => onChanged(c.userId, checked ?? false),
          ),
      ],
    );
  }
}

class _AvailabilitySummary extends StatelessWidget {
  const _AvailabilitySummary({required this.availability});
  final List<ParticipantAvailability> availability;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy = availability.where((a) => a.status == AvailabilityStatus.busy).toList();

    (IconData, Color, String) line(ParticipantAvailability a) => switch (a.status) {
      AvailabilityStatus.free => (Icons.check_circle, Colors.green, '${a.name}: free'),
      AvailabilityStatus.busy => (Icons.warning_amber, colors.error, '${a.name}: busy at this time'),
      AvailabilityStatus.notConnected => (
        Icons.mail_outline,
        colors.onSurfaceVariant,
        '${a.name}: hasn\'t connected Google, will be invited by email',
      ),
      AvailabilityStatus.unknown => (
        Icons.help_outline,
        colors.onSurfaceVariant,
        '${a.name}: availability unknown (may need to reconnect Google)',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          busy.isEmpty ? 'No clashes found' : 'Calendar clash',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: busy.isEmpty ? null : colors.error),
        ),
        const SizedBox(height: 4),
        for (final a in availability)
          Builder(
            builder: (context) {
              final (icon, color, text) = line(a);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
