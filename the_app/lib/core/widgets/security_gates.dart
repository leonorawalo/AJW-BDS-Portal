import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/mfa_gate.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/privacy/presentation/consent_gate.dart';
import 'inactivity_logout.dart';

/// Wraps the whole app (MaterialApp.router's builder) once someone is
/// signed in: privacy notice consent first, then two-step verification
/// for Admins and Owners, then the automatic sign-out after inactivity.
/// Signed-out pages, and an invitee who hasn't chosen a password yet,
/// pass straight through.
class SecurityGates extends ConsumerWidget {
  const SecurityGates({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateChangesProvider);
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null || user.userMetadata?['needs_password'] == true) return child;
    return InactivityLogout(
      child: ConsentGate(
        child: MfaGate(child: child),
      ),
    );
  }
}

/// A gate's own full-screen page sits above the app's router, so it gets
/// its own Navigator (text fields and dialogs need one).
///
/// It uses the `pages` list, not `onGenerateRoute`: `onGenerateRoute`
/// builds the page once and never again, so a gate's screen never showed
/// new state (the consent checkboxes looked unclickable, 3 Nov 2026).
/// With `pages`, every rebuild of the gate hands the Navigator the new
/// screen and it redraws.
Widget standaloneScreen(Object key, Widget screen) => Navigator(
      key: ValueKey(key),
      pages: [MaterialPage<void>(key: ValueKey('$key-page'), child: screen)],
      // The gate's only page is never removed by the Navigator itself
      // (there is nothing under it to go back to).
      onDidRemovePage: (_) {},
    );
