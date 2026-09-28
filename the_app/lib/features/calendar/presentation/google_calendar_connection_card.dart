import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/calendar_providers.dart';

/// Connect / disconnect the signed-in user's own Google account — used for
/// meetings (Calendar + Meet, free/busy) and exports (Docs/Sheets/Slides).
///
/// Google's consent page opens in the external browser and redirects to
/// the google-oauth Edge Function, not back into the app — so the
/// connection status is simply re-fetched whenever the app returns to the
/// foreground (plus a manual refresh button as a fallback on web).
class GoogleCalendarConnectionCard extends ConsumerStatefulWidget {
  const GoogleCalendarConnectionCard({super.key});

  @override
  ConsumerState<GoogleCalendarConnectionCard> createState() =>
      _GoogleCalendarConnectionCardState();
}

class _GoogleCalendarConnectionCardState extends ConsumerState<GoogleCalendarConnectionCard> {
  late final AppLifecycleListener _lifecycleListener;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.invalidate(myGoogleConnectionProvider),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String failureMessage) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failureMessage: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _connect() => _run(() async {
        final url = await ref.read(googleConnectionRepositoryProvider).startConnect();
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }, 'Could not start Google sign-in');

  Future<void> _disconnect() => _run(() async {
        await ref.read(googleConnectionRepositoryProvider).disconnect();
        ref.invalidate(myGoogleConnectionProvider);
      }, 'Could not disconnect');

  @override
  Widget build(BuildContext context) {
    final connectionAsync = ref.watch(myGoogleConnectionProvider);
    final refreshButton = IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'Refresh connection status',
      onPressed: () => ref.invalidate(myGoogleConnectionProvider),
    );

    return Card(
      child: connectionAsync.when(
        loading: () => const ListTile(
          leading: Icon(Icons.calendar_month),
          title: Text('Checking Google connection…'),
        ),
        error: (_, _) => ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Could not check Google connection.'),
          trailing: refreshButton,
        ),
        data: (connection) {
          if (connection == null) {
            return ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Connect your Google account'),
              subtitle: const Text(
                'Needed to schedule meetings, check availability, and export to '
                'Google Docs, Sheets and Slides. The app only sees files it creates.',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  refreshButton,
                  FilledButton(
                    onPressed: _isBusy ? null : _connect,
                    child: const Text('Connect'),
                  ),
                ],
              ),
            );
          }
          final disconnectButton = TextButton(
            onPressed: _isBusy ? null : _disconnect,
            child: const Text('Disconnect'),
          );
          // Connected before availability checks / exports existed: running
          // Connect again replaces the stored token with one that has the
          // newer permissions.
          if (connection.needsReconnect) {
            return ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              title: Text('Connected as ${connection.googleEmail ?? 'your Google account'}'),
              subtitle: const Text('Reconnect once to enable availability checks and exports.'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  disconnectButton,
                  FilledButton(
                    onPressed: _isBusy ? null : _connect,
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            );
          }
          return ListTile(
            leading: const Icon(Icons.event_available, color: Colors.green),
            title: const Text('Google account connected'),
            subtitle: Text(connection.googleEmail ?? 'Google account'),
            trailing: disconnectButton,
          );
        },
      ),
    );
  }
}
