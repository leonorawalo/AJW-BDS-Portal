import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';

import '../../shared/models/user_profile.dart';
//import '../../features/auth/providers/auth_providers.dart';

/// Shown in the AppBar on every authenticated screen (Admin, Consultant,
/// Owner) — "FirstName.Role", e.g. "Leonora.Enterprise Owner". Uses a
/// placeholder person icon for now; swap the CircleAvatar's `child` for
/// a real profile photo later (e.g. NetworkImage from a stored avatar
/// URL) without touching anywhere this widget is used.
class UserProfileBadge extends ConsumerWidget {
  const UserProfileBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                '${profile.firstName}.${profile.role.label}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }
}
extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.administrator:
        return 'Administrator';
      case UserRole.consultant:
        return 'Consultant';
      case UserRole.enterpriseOwner:
        return 'Enterprise Owner';
    }
  }
}