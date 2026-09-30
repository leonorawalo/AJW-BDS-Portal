import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/app_colors.dart';
import 'user_avatar.dart';

/// The signed-in person: their avatar (initials on their own colour), name
/// and role. In the top bar on wide screens and at the top of the phone
/// drawer. Swap [UserAvatar] for a photo later without touching callers.
class UserProfileBadge extends ConsumerWidget {
  const UserProfileBadge({super.key, this.onAppBar = true});

  /// Compact single-line layout for the top bar; roomier in the drawer.
  final bool onAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    if (profile == null) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final name = '${profile.firstName} ${profile.lastName}'.trim();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: onAppBar ? 12 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            id: profile.id,
            firstName: profile.firstName,
            lastName: profile.lastName,
            radius: onAppBar ? 17 : 22,
          ),
          const SizedBox(width: 10),
          // Flexible: shrinks to fit (e.g. the phone drawer); the cap stops a
          // long name crowding the app-bar actions.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                  Text(
                    profile.roleDisplayLabel,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: AppColors.charcoalSoft, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
