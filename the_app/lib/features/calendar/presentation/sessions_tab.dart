import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/consultation_session.dart';
import '../providers/calendar_providers.dart';
import 'google_calendar_connection_card.dart';
import 'schedule_session_dialog.dart';

/// Consultation sessions for one enterprise. Everyone on the enterprise
/// (Admin, Owner, the consultant Trio) sees the list and can join Meet;
/// only Consultants ([canSchedule]) book sessions — on their own Google
/// Calendar — and cancel the ones they booked. RLS enforces the same.
class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key, required this.enterpriseId, required this.canSchedule});
  final String enterpriseId;
  final bool canSchedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(consultationSessionsProvider(enterpriseId));
    final isConnected = canSchedule && ref.watch(myGoogleConnectionProvider).value != null;

    return Scaffold(
      floatingActionButton: isConnected
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.video_call),
              label: const Text('Schedule'),
              onPressed: () async {
                final created = await showScheduleSessionDialog(context, enterpriseId);
                if (created) {
                  ref.invalidate(consultationSessionsProvider(enterpriseId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Session scheduled — the owner has been invited.')),
                    );
                  }
                }
              },
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(consultationSessionsProvider(enterpriseId)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            if (canSchedule) ...[
              const GoogleCalendarConnectionCard(),
              const SizedBox(height: 16),
            ],
            ...sessionsAsync.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (_, _) => [const Center(child: Text('Could not load sessions.'))],
              data: (sessions) => _buildSections(context, sessions),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, List<ConsultationSession> sessions) {
    if (sessions.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 32),
          child: Center(child: Text('No sessions scheduled yet.')),
        ),
      ];
    }
    final upcoming = sessions.where((s) => s.isUpcoming).toList();
    // Most recent first for history.
    final past = sessions.where((s) => !s.isUpcoming).toList().reversed.toList();
    final textTheme = Theme.of(context).textTheme;

    return [
      Text('Upcoming', style: textTheme.titleMedium),
      const SizedBox(height: 8),
      if (upcoming.isEmpty) const Text('Nothing upcoming.'),
      for (final s in upcoming) _SessionCard(session: s, canSchedule: canSchedule),
      if (past.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text('Past & cancelled', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final s in past) _SessionCard(session: s, canSchedule: canSchedule),
      ],
    ];
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.canSchedule});
  final ConsultationSession session;
  final bool canSchedule;

  String _when(BuildContext context) {
    final l = MaterialLocalizations.of(context);
    return '${l.formatMediumDate(session.startsAt)}, '
        '${l.formatTimeOfDay(TimeOfDay.fromDateTime(session.startsAt))}'
        ' – ${l.formatTimeOfDay(TimeOfDay.fromDateTime(session.endsAt))}';
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel session?'),
        content: const Text(
          'The event is removed from Google Calendar and the owner gets a cancellation email.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel session'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(consultationSessionRepositoryProvider).cancelSession(session.id);
      ref.invalidate(consultationSessionsProvider(session.enterpriseId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelled = session.status == SessionStatus.cancelled;
    final isMine = session.consultantId == ref.read(authRepositoryProvider).currentUser?.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          decoration: isCancelled ? TextDecoration.lineThrough : null,
                        ),
                  ),
                ),
                if (isCancelled) const Chip(label: Text('Cancelled')),
              ],
            ),
            const SizedBox(height: 4),
            Text(_when(context)),
            if (session.consultantName != null) Text('With ${session.consultantName}'),
            if (session.description != null) ...[
              const SizedBox(height: 4),
              Text(session.description!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (session.isUpcoming)
              Wrap(
                spacing: 8,
                children: [
                  if (session.meetLink != null)
                    FilledButton.icon(
                      icon: const Icon(Icons.videocam),
                      label: const Text('Join Meet'),
                      onPressed: () => launchUrl(
                        Uri.parse(session.meetLink!),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  if (canSchedule && isMine)
                    TextButton(
                      onPressed: () => _cancel(context, ref),
                      child: const Text('Cancel session'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
