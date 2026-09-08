import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Placeholder home screen shown until each role gets its real feature
/// screens (Phase 2+). Includes a sign-out button purely so you can
/// switch between test accounts without closing the app — the real
/// home screens will have this in a proper menu/profile section instead.
class RoleHomePlaceholder extends ConsumerWidget {
  const RoleHomePlaceholder({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            // No manual navigation needed — signing out changes the auth
            // state, which the router's redirect picks up automatically
            // and sends you to /login.
          ),
        ],
      ),
      body: Center(child: Text(label)),
    );
  }
}