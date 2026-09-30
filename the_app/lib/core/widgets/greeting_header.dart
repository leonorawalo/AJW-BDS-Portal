import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// Top of each role's home page: "Good afternoon, Gloria", today's date and
/// a one-line summary, next to the person's own avatar. The person first,
/// AJW around them.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key, this.summary, this.trailing});

  /// e.g. "12 enterprises · 4 going concern".
  final String? summary;
  final Widget? trailing;

  static String greetingFor(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;
    final phone = MediaQuery.sizeOf(context).width < 600;
    final date = '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}';

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (profile != null && !phone) ...[
            UserAvatar(id: profile.id, firstName: profile.firstName, lastName: profile.lastName, radius: 28),
            const SizedBox(width: Space.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile == null ? greetingFor(now) : '${greetingFor(now)}, ${profile.firstName}',
                  style: phone ? text.headlineMedium : text.headlineLarge,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  [date, if (summary != null) summary].join('  ·  '),
                  style: text.bodyMedium?.copyWith(color: AppColors.charcoalSoft),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
