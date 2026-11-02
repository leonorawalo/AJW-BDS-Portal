import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/consultation_session.dart';
import '../models/meeting_notes.dart';
import '../models/session_person.dart';
import '../providers/calendar_providers.dart';
import 'google_calendar_connection_card.dart';
import 'schedule_session_dialog.dart';
import '../../email/data/gmail_links.dart';
import '../../email/presentation/compose_email_dialog.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';
import '../../../core/user_message.dart';

/// Meetings on one enterprise. Admins, Consultants and Owners can all
/// connect their own Google Calendar and schedule meetings (who they can
/// invite comes from session_invitee_candidates()). Each person sees only
/// the meetings they organised or were invited to; Admins see all. Only
/// the organizer (or an Admin) can cancel. RLS enforces the same.
class SessionsTab extends ConsumerWidget {
  const SessionsTab({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(consultationSessionsProvider(enterpriseId));
    final isConnected = ref.watch(myGoogleConnectionProvider).value != null;
    final people = ref.watch(sessionPeopleProvider(enterpriseId)).value ?? const <SessionPerson>[];

    return Scaffold(
      floatingActionButton: isConnected
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'start-meeting-now',
                  icon: const Icon(Icons.bolt),
                  label: const Text('Start meeting now'),
                  onPressed: () => _startNow(context, ref),
                ),
                const SizedBox(height: 12),
                TourAnchor(id: TourAnchors.sessionsAdd, child: FloatingActionButton.extended(
                  heroTag: 'schedule-meeting',
                  icon: const Icon(Icons.video_call),
                  label: const Text('Schedule meeting'),
                  onPressed: () async {
                    final created = await showScheduleSessionDialog(context, enterpriseId);
                    if (created) {
                      ref.invalidate(consultationSessionsProvider(enterpriseId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meeting scheduled. Participants have been invited.')),
                        );
                      }
                    }
                  },
                )),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(consultationSessionsProvider(enterpriseId)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
          children: [
            const TourAnchor(id: TourAnchors.sessionsGoogle, child: GoogleCalendarConnectionCard()),
            const SizedBox(height: 16),
            ...sessionsAsync.when(
              loading: () => [const AjwLoadingView()],
              error: (_, _) => [const Center(child: Text('Could not load sessions.'))],
              data: (sessions) => _buildSections(context, sessions, people),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNow(BuildContext context, WidgetRef ref) async {
    final session = await showStartMeetingNowDialog(context, enterpriseId);
    if (session == null) return;
    ref.invalidate(consultationSessionsProvider(enterpriseId));
    final link = session.meetLink ?? session.calendarHtmlLink;
    Future<void> join() async {
      if (link != null) await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    }
    // A browser may block the automatic tab (it opens after a server
    // call, not straight from the click), so the message offers it too.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Meeting started. Participants have been invited.'),
        duration: const Duration(seconds: 10),
        action: link == null ? null : SnackBarAction(label: 'Join', onPressed: join),
      ));
    }
    await join();
  }

  List<Widget> _buildSections(
    BuildContext context,
    List<ConsultationSession> sessions,
    List<SessionPerson> people,
  ) {
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
      for (final s in upcoming) TourAnchor(id: TourAnchors.sessionsFirst, child: _SessionCard(session: s, people: _peopleOf(s, people))),
      if (past.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text('Past & cancelled', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final s in past) TourAnchor(id: TourAnchors.sessionsFirst, child: _SessionCard(session: s, people: _peopleOf(s, people))),
      ],
    ];
  }

  static List<SessionPerson> _peopleOf(ConsultationSession s, List<SessionPerson> people) =>
      people.where((p) => p.sessionId == s.id).toList();
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session, required this.people});
  final ConsultationSession session;
  final List<SessionPerson> people;

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
          'The event is removed from Google Calendar and participants get a cancellation email.',
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
          SnackBar(content: Text('Could not cancel: ${userMessage(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelled = session.status == SessionStatus.cancelled;
    final myId = ref.read(authRepositoryProvider).currentUser?.id;
    final isAdmin = ref.watch(currentUserProfileProvider).value?.role == UserRole.administrator;
    final canCancel = session.organizerId == myId || isAdmin;
    final organizer = people.where((p) => p.isOrganizer).map((p) => p.userId == myId ? 'you' : p.fullName);
    final others = people.where((p) => !p.isOrganizer).map((p) => p.userId == myId ? 'you' : p.fullName);

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
            if (organizer.isNotEmpty) Text('Organised by ${organizer.first}'),
            if (others.isNotEmpty) Text('With ${others.join(', ')}'),
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
                  TextButton.icon(
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('Email participants'),
                    onPressed: () => showComposeEmailDialog(
                      context,
                      ref,
                      enterpriseId: session.enterpriseId,
                      preselectUserIds: {for (final p in people) if (p.userId != myId) p.userId},
                      subject: 'Re: ${session.title}',
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Find emails'),
                    onPressed: () async {
                      final connection = await ref.read(myGoogleConnectionProvider.future).catchError((_) => null);
                      await launchUrl(
                        gmailSearchUri(phrase: session.title, accountEmail: connection?.googleEmail),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  if (canCancel)
                    TextButton(
                      onPressed: () => _cancel(context, ref),
                      child: const Text('Cancel session'),
                    ),
                ],
              ),
            if (session.isUpcoming && session.organizerId == myId && session.meetLink != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Want notes? In the meeting, click "Take notes with Gemini". '
                      'They appear here and in the Files tab after the call.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (session.hasEnded && session.meetLink != null) _MeetingNotesSection(session: session),
          ],
        ),
      ),
    );
  }
}

/// Notes and transcript of a finished meeting. Asks the server once when
/// shown while they're still pending; Google can take a while after the
/// call to write them.
class _MeetingNotesSection extends ConsumerStatefulWidget {
  const _MeetingNotesSection({required this.session});
  final ConsultationSession session;

  @override
  ConsumerState<_MeetingNotesSection> createState() => _MeetingNotesSectionState();
}

class _MeetingNotesSectionState extends ConsumerState<_MeetingNotesSection> {
  /// Set by "Check again", so a meeting already marked unavailable is
  /// looked up again (e.g. after the organizer reconnects Google).
  bool _asked = false;

  ConsultationSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final saved = session.notes;
    final MeetingNotes notes;
    var checking = false;
    if (saved.status == MeetingNotesStatus.pending || _asked) {
      final live = ref.watch(meetingNotesProvider(session.id));
      checking = live.isLoading;
      notes = live.value ?? saved;
    } else {
      notes = saved;
    }

    Widget line(IconData icon, String message, {Widget? action}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(message, style: text.bodySmall)),
              ?action,
            ],
          ),
        );

    final checkAgain = TextButton(
      onPressed: () {
        setState(() => _asked = true);
        ref.invalidate(meetingNotesProvider(session.id));
      },
      child: const Text('Check again'),
    );
    if (checking) return line(Icons.hourglass_empty, 'Looking for meeting notes…');
    return switch (notes.status) {
      MeetingNotesStatus.ready => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            children: [
              if (notes.notesUrl != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Meeting notes'),
                  onPressed: () => launchUrl(Uri.parse(notes.notesUrl!), mode: LaunchMode.externalApplication),
                ),
              if (notes.transcriptUrl != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.subject, size: 18),
                  label: const Text('Transcript'),
                  onPressed: () => launchUrl(Uri.parse(notes.transcriptUrl!), mode: LaunchMode.externalApplication),
                ),
            ],
          ),
        ),
      MeetingNotesStatus.pending => line(Icons.hourglass_empty, 'Meeting notes are not ready yet.', action: checkAgain),
      MeetingNotesStatus.none => line(Icons.notes, 'No notes were taken in this meeting.'),
      MeetingNotesStatus.unavailable =>
        line(Icons.info_outline, 'Meeting notes not available for this account.', action: checkAgain),
    };
  }
}
