import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Shown in the AppBar on every authenticated screen (Admin, Consultant,
/// Owner) — "Name · Role", e.g. "Leonora Awalo · Enterprise Owner". Uses a
/// placeholder person icon for now; swap the CircleAvatar's `child` for
/// a real profile photo later (e.g. NetworkImage from a stored avatar
/// URL) without touching anywhere this widget is used.
class UserProfileBadge extends ConsumerWidget {
  const UserProfileBadge({super.key, this.onAppBar = true});

  /// White on the brand-coloured app bar; theme colours elsewhere (the
  /// phone drawer).
  final bool onAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (profile) {
        if (profile == null) return const SizedBox.shrink();

        final foreground = onAppBar ? Colors.white : Theme.of(context).colorScheme.onSurface;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: onAppBar ? 12 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: onAppBar ? Colors.white24 : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.person, size: 16, color: foreground),
              ),
              const SizedBox(width: 8),
              // Capped so a long name can't push the app-bar actions off a
              // phone screen.
              // Flexible: shrinks to fit (e.g. the phone drawer); the cap
              // stops a long name crowding the app-bar actions.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                  '${'${profile.firstName} ${profile.lastName}'.trim()} · ${profile.roleDisplayLabel}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
