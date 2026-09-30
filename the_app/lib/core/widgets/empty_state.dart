import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Friendly placeholder for an empty list or a failed load: an icon in a
/// soft circle, a short title, one line of guidance and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: isError ? const Color(0xFFFDECEA) : AppColors.brandRedTint,
                child: Icon(icon, size: 30, color: isError ? AppColors.errorRed : AppColors.brandRed),
              ),
              const SizedBox(height: Space.lg),
              Text(title, style: text.titleLarge, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: Space.sm),
                Text(
                  message!,
                  style: text.bodyMedium?.copyWith(color: AppColors.charcoalSoft),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: Space.xl), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps page content at a readable width on large screens, with the
/// standard page padding.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 1120});
  final Widget child;
  final double maxWidth;

  static EdgeInsets paddingFor(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return EdgeInsets.symmetric(horizontal: w < 600 ? Space.lg : Space.xxl, vertical: w < 600 ? Space.lg : Space.xl);
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
