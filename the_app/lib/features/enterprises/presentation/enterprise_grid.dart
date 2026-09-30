import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/greeting_header.dart';
import '../models/enterprise.dart';
import 'enterprise_tile.dart';

/// A role's home list of enterprises: greeting, then the enterprises as
/// cards (two columns on wide screens). Pull to refresh.
class EnterpriseGrid extends StatelessWidget {
  const EnterpriseGrid({
    super.key,
    required this.enterprises,
    required this.onOpen,
    required this.onRefresh,
    required this.emptyState,
    this.showOwner = true,
    this.bottomPadding = 0,
  });

  final List<Enterprise> enterprises;
  final void Function(Enterprise) onOpen;
  final Future<void> Function() onRefresh;
  final Widget emptyState;
  final bool showOwner;

  /// Room for a floating action button.
  final double bottomPadding;

  String get _summary {
    final n = enterprises.length;
    final gc = enterprises.where((e) => e.goingConcernStatus == GoingConcernStatus.achieved).length;
    return '$n ${n == 1 ? 'enterprise' : 'enterprises'}  ·  $gc going concern';
  }

  @override
  Widget build(BuildContext context) {
    final padding = PageBody.paddingFor(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 2 : 1;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: padding.copyWith(bottom: 0),
                sliver: SliverToBoxAdapter(
                  child: PageBody(child: GreetingHeader(summary: enterprises.isEmpty ? null : _summary)),
                ),
              ),
              if (enterprises.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: emptyState)
              else
                SliverPadding(
                  padding: padding.copyWith(top: 0, bottom: padding.bottom + bottomPadding),
                  sliver: SliverToBoxAdapter(
                    child: PageBody(
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 112,
                          crossAxisSpacing: Space.lg,
                          mainAxisSpacing: Space.md,
                        ),
                        itemCount: enterprises.length,
                        itemBuilder: (context, i) => EnterpriseTile(
                          enterprise: enterprises[i],
                          showOwner: showOwner,
                          onTap: () => onOpen(enterprises[i]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
