import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/recommendation.dart';
import '../providers/legal_workstream_providers.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

class RecommendationsTab extends ConsumerWidget {
  const RecommendationsTab({super.key, required this.enterpriseId, required this.readOnly});
  final String enterpriseId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(recommendationsProvider(enterpriseId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add recommendation'),
            ),
      body: recsAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load recommendations",
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(recommendationsProvider(enterpriseId)),
            child: const Text('Try again'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.lightbulb_outline,
              title: 'No recommendations yet',
              message: readOnly
                  ? "Your consultants' advice for the business will appear here."
                  : 'Record advice for the owner here, then mark it actioned once it has been done.',
            );
          }
          final open = items.where((r) => r.status == RecommendationStatus.open).toList();
          final closed = items.where((r) => r.status != RecommendationStatus.open).toList();
          final padding = PageBody.paddingFor(context);
          return ListView(
            padding: padding.copyWith(bottom: padding.bottom + (readOnly ? 0 : 88)),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (title, list) in [('Open', open), ('Done', closed)])
                      if (list.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.md),
                          child: Text('$title (${list.length})', style: text.titleMedium),
                        ),
                        for (final r in list) ...[
                          _RecommendationCard(
                            rec: r,
                            canAction: !readOnly && r.status == RecommendationStatus.open,
                            onActioned: () async {
                              await ref.read(recommendationRepositoryProvider).updateStatus(r.id, RecommendationStatus.actioned);
                              ref.invalidate(recommendationsProvider(enterpriseId));
                            },
                          ),
                          const SizedBox(height: Space.sm),
                        ],
                        const SizedBox(height: Space.xl),
                      ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a recommendation'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 360, maxWidth: 480),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Advice for the owner. They see it on their Recommendations page.',
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: textController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Recommendation', alignLabelWithHint: true),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Write the recommendation' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final consultantId = ref.read(authRepositoryProvider).currentUser!.id;
              await ref.read(recommendationRepositoryProvider).createRecommendation(
                    enterpriseId: enterpriseId,
                    consultantId: consultantId,
                    recommendationText: textController.text.trim(),
                  );
              ref.invalidate(recommendationsProvider(enterpriseId));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    textController.dispose();
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec, required this.canAction, required this.onActioned});
  final Recommendation rec;
  final bool canAction;
  final VoidCallback onActioned;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (StatusTone tone, IconData? icon) = switch (rec.status) {
      RecommendationStatus.open => (StatusTone.warning, Icons.lightbulb_outline),
      RecommendationStatus.actioned => (StatusTone.success, Icons.check_circle),
      RecommendationStatus.dismissed => (StatusTone.neutral, null),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.recommendationText, style: text.bodyLarge),
            const SizedBox(height: Space.md),
            Row(
              children: [
                StatusChip(rec.status.dbValue, tone: tone, icon: icon),
                const SizedBox(width: Space.sm),
                Expanded(child: Text('Added ${_day(rec.createdAt.toLocal())}', style: text.bodySmall?.copyWith(color: AppColors.charcoalSoft))),
                if (canAction)
                  TextButton.icon(
                    onPressed: onActioned,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Mark actioned'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
