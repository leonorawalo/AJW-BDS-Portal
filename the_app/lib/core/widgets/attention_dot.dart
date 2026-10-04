import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The small red "needs your attention" dot (no number) on a menu icon or
/// an enterprise card. Brand red, not the error crimson: it's news, not a
/// problem.
class AttentionDot extends StatelessWidget {
  const AttentionDot({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Badge(isLabelVisible: show, smallSize: 9, backgroundColor: AppColors.brandRed, child: child);
}
