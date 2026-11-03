import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../../calendar/providers/calendar_providers.dart';
import '../data/gmail_links.dart';
import '../data/inbox_repository.dart';
import '../models/inbox_message.dart';
import '../providers/email_providers.dart';
import 'compose_email_dialog.dart';

/// "Emails": this enterprise's emails from the signed-in user's own Gmail,
/// i.e. mail to or from its Owner, consultants and Admins. Nobody sets up
/// a filter: the server builds the search from the enterprise's people.
/// Replies go out through the existing "Write email" (gmail.send).
class InboxTab extends ConsumerStatefulWidget {
  const InboxTab({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  ConsumerState<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends ConsumerState<InboxTab> {
  /// Pages loaded with "Load more", after the first.
  final _more = <InboxMessage>[];
  String? _nextToken;
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    final token = _nextToken;
    if (token == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(inboxRepositoryProvider).list(widget.enterpriseId, pageToken: token);
      setState(() {
        _more.addAll(page.messages);
        _nextToken = page.nextPageToken;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _more.clear();
      _nextToken = null;
    });
    ref.invalidate(enterpriseInboxProvider(widget.enterpriseId));
  }

  @override
  Widget build(BuildContext context) {
    // Answer from the saved Google connection first (a quick database
    // read): without Gmail read access there's no point waking the
    // gmail-inbox function and calling Google just to be told no.
    final connection = ref.watch(myGoogleConnectionProvider);
    if (connection.isLoading) return const AjwLoadingView();
    if (!connection.hasError) {
      final conn = connection.value;
      if (conn == null) {
        return _ErrorState(error: const GoogleNotConnectedException(), enterpriseId: widget.enterpriseId, onRetry: _refresh);
      }
      if (!conn.canReadEmail) {
        return _ErrorState(error: const GmailReadNotGrantedException(), enterpriseId: widget.enterpriseId, onRetry: _refresh);
      }
    }
    final inbox = ref.watch(enterpriseInboxProvider(widget.enterpriseId));
    return inbox.when(
      loading: () => const AjwLoadingView(),
      error: (e, _) => _ErrorState(error: e, enterpriseId: widget.enterpriseId, onRetry: _refresh),
      data: (page) {
        // The first page's token, until "Load more" replaces it.
        if (_more.isEmpty) _nextToken = page.nextPageToken;
        final messages = [...page.messages, ..._more];
        if (messages.isEmpty) {
          return const EmptyState(
            icon: Icons.mark_email_read_outlined,
            title: 'No emails yet',
            message: "Emails between you and this enterprise's people will show here.",
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: PageBody.paddingFor(context),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "From your Gmail: messages to or from this enterprise's owner, consultants and administrators.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: Space.md),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (i, m) in messages.indexed) ...[
                            if (i > 0) const Divider(height: 1),
                            _MessageTile(
                              message: m,
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (_) => _MessageDialog(enterpriseId: widget.enterpriseId, summary: m),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_nextToken != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.md),
                        child: Center(
                          child: _loadingMore
                              ? const AjwLoader()
                              : OutlinedButton(onPressed: _loadMore, child: const Text('Load more')),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.onTap});
  final InboxMessage message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final strong = message.unread ? FontWeight.w700 : null;
    final date = message.date;
    return ListTile(
      onTap: onTap,
      leading: Icon(message.unread ? Icons.mark_email_unread : Icons.drafts_outlined,
          color: message.unread ? AppColors.brandRed : AppColors.charcoalSoft),
      title: Text(message.fromName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: strong)),
      subtitle: Text(
        '${message.subject.isEmpty ? '(no subject)' : message.subject} – ${message.snippet}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: date == null
          ? null
          : Text(MaterialLocalizations.of(context).formatShortDate(date), style: text.bodySmall),
    );
  }
}

class _MessageDialog extends ConsumerWidget {
  const _MessageDialog({required this.enterpriseId, required this.summary});
  final String enterpriseId;
  final InboxMessage summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final full = ref.watch(inboxMessageProvider((enterpriseId, summary.id)));
    final m = full.value ?? summary;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(m.subject.isEmpty ? '(no subject)' : m.subject),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 640),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: ${m.from}', style: text.bodySmall),
              Text('To: ${m.to}', style: text.bodySmall),
              if (m.date != null)
                Text(
                  '${MaterialLocalizations.of(context).formatFullDate(m.date!)}, '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(m.date!))}',
                  style: text.bodySmall,
                ),
              const Divider(height: Space.xl),
              if (full.isLoading)
                const AjwLoadingView()
              else if (full.hasError)
                Text("Couldn't open this email.", style: TextStyle(color: Theme.of(context).colorScheme.error))
              else
                SelectableText(m.body?.trim().isNotEmpty == true ? m.body!.trim() : m.snippet),
            ],
          ),
        ),
      ),
      actions: [
        if (m.gmailUrl != null)
          TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open in Gmail'),
            onPressed: () => launchUrl(Uri.parse(m.gmailUrl!), mode: LaunchMode.externalApplication),
          ),
        FilledButton.icon(
          icon: const Icon(Icons.reply, size: 18),
          label: const Text('Reply'),
          onPressed: () async {
            final contacts = await ref.read(enterpriseEmailContactsProvider(enterpriseId).future);
            final sender = contacts.where((c) => c.userId != null && c.email.toLowerCase() == m.fromEmail);
            if (!context.mounted) return;
            Navigator.pop(context);
            await showComposeEmailDialog(
              context,
              ref,
              enterpriseId: enterpriseId,
              preselectUserIds: {for (final c in sender) c.userId!},
              subject: m.subject.toLowerCase().startsWith('re:') ? m.subject : 'Re: ${m.subject}',
            );
          },
        ),
      ],
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error, required this.enterpriseId, required this.onRetry});
  final Object error;
  final String enterpriseId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Until Google approves Gmail read access, the old search link still
    // finds the same mail in Gmail itself.
    final findInGmail = OutlinedButton.icon(
      icon: const Icon(Icons.search),
      label: const Text('Find these emails in Gmail'),
      onPressed: () async {
        final contacts = await ref.read(enterpriseEmailContactsProvider(enterpriseId).future);
        final connection = await ref.read(myGoogleConnectionProvider.future).catchError((_) => null);
        await launchUrl(
          gmailSearchUri(emails: [for (final c in contacts) c.email], accountEmail: connection?.googleEmail),
          mode: LaunchMode.externalApplication,
        );
      },
    );
    return switch (error) {
      GoogleNotConnectedException() => const EmptyState(
          icon: Icons.link_off,
          title: 'Connect your Google account',
          message: 'Connect Google from the Sessions tab to see emails here.',
        ),
      GmailReadNotGrantedException() => EmptyState(
          icon: Icons.mark_email_unread_outlined,
          title: 'Inbox not available yet',
          message: 'Reading emails inside the portal needs Gmail read access, which is waiting for '
              "Google's approval. Until then, open them in Gmail.",
          action: findInGmail,
        ),
      _ => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load emails",
          message: 'Check your connection and try again.',
          action: OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ),
    };
  }
}
