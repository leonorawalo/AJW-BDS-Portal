import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/calendar_providers.dart';

/// Wraps every signed-in screen (via AppShell). The first time a user lands
/// in the app after accepting their invite, if they have no Google
/// connection, it offers "Connect your Google suite" straight away, with a
/// "Later" option. Either answer is remembered in their auth metadata
/// (google_prompt_done), so it's asked once; after "Later" the normal
/// Connect card in Sessions is still there.
class GoogleFirstRunPrompt extends ConsumerStatefulWidget {
  const GoogleFirstRunPrompt({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<GoogleFirstRunPrompt> createState() => _GoogleFirstRunPromptState();
}

class _GoogleFirstRunPromptState extends ConsumerState<GoogleFirstRunPrompt> {
  /// AppShell is rebuilt on every page, so check once per user per app run.
  static String? _checkedForUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    final bool connect;
    try {
      final auth = ref.read(authRepositoryProvider);
      final user = auth.currentUser;
      if (user == null || _checkedForUserId == user.id) return;
      _checkedForUserId = user.id;
      if (auth.needsPassword || auth.googlePromptDone) return;

      final connection = await ref.read(googleConnectionRepositoryProvider).fetchMyConnection();
      if (connection != null) {
        await auth.markGooglePromptDone();
        return;
      }
      if (!mounted) return;
      connect =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              icon: const Icon(Icons.hub_outlined),
              title: const Text('Connect your Google suite'),
              content: const Text(
                'Use Calendar and Meet for sessions, Gmail to email the people you work with, '
                'and Docs, Sheets and Slides for reports, all from your own Google account.\n\n'
                'The app only sees files it creates and never reads your email. '
                'You can also do this later from Sessions.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Later')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Connect Google')),
              ],
            ),
          ) ??
          false;
      await auth.markGooglePromptDone();
    } catch (_) {
      // Never block the app over this: the Connect card in Sessions is
      // always there as the fallback.
      return;
    }
    if (!connect) return;
    try {
      final url = await ref.read(googleConnectionRepositoryProvider).startConnect();
      await launchUrl(url, mode: LaunchMode.externalApplication);
      ref.invalidate(myGoogleConnectionProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start Google sign-in. You can connect later from Sessions. ($e)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
