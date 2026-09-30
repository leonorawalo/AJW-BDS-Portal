import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_chip.dart';
import '../models/enterprise.dart';

/// One enterprise in a list (Admin's Enterprises, a consultant's portfolio):
/// a monogram, the business name, who owns it and where, and its status
/// chips. Used by both lists so they look and behave the same.
class EnterpriseTile extends StatelessWidget {
  const EnterpriseTile({super.key, required this.enterprise, required this.onTap, this.showOwner = true});

  final Enterprise enterprise;
  final VoidCallback onTap;
  final bool showOwner;

  static StatusTone toneFor(LifecycleStatus s) => switch (s) {
        LifecycleStatus.loanReady || LifecycleStatus.graduated => StatusTone.success,
        LifecycleStatus.inactive => StatusTone.neutral,
        LifecycleStatus.newEnterprise => StatusTone.brand,
        _ => StatusTone.warning,
      };

  String get _monogram {
    final words = enterprise.businessName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    return (words.first[0] + (words.length > 1 ? words[1][0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final details = [
      if (showOwner && enterprise.ownerName.isNotEmpty) enterprise.ownerName,
      enterprise.county ?? 'No county set',
    ].join('  ·  ');

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSunken,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Text(_monogram, style: text.titleMedium?.copyWith(color: AppColors.charcoal)),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(enterprise.businessName, style: text.titleMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(details, style: text.bodySmall, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      children: [
                        StatusChip(enterprise.lifecycleStatus.label, tone: toneFor(enterprise.lifecycleStatus)),
                        if (enterprise.goingConcernStatus == GoingConcernStatus.achieved)
                          const StatusChip('Going concern', tone: StatusTone.success, icon: Icons.check_circle),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              const Icon(Icons.chevron_right, color: AppColors.charcoalSoft),
            ],
          ),
        ),
      ),
    );
  }
}
