import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum StatusTone { neutral, brand, success, warning, danger }

/// A small rounded status label (lifecycle, Going Concern, task status).
/// Tinted background + darker text of the same hue; an optional icon so
/// status never relies on colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = StatusTone.neutral, this.icon});

  final String label;
  final StatusTone tone;
  final IconData? icon;

  (Color, Color) get _colors => switch (tone) {
        StatusTone.neutral => (AppColors.surfaceSunken, AppColors.charcoal),
        StatusTone.brand => (AppColors.brandRedTint, AppColors.brandRedDeep),
        StatusTone.success => (const Color(0xFFE3F1E4), const Color(0xFF1E5E22)),
        StatusTone.warning => (const Color(0xFFFFF3D6), const Color(0xFF7A5200)),
        StatusTone.danger => (const Color(0xFFFDECEA), AppColors.errorRed),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, height: 1.2)),
        ],
      ),
    );
  }
}
