import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/recommendation.dart';
import '../providers/legal_workstream_providers.dart';
import '../../../core/widgets/ajw_loader.dart';

class RecommendationsTab extends ConsumerWidget {
  const RecommendationsTab({super.key, required this.enterpriseId, required this.readOnly});
  final String enterpriseId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(recommendationsProvider(enterpriseId));

    return Scaffold(
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateDialog(context, ref),
              child: const Icon(Icons.add),
            ),
      body: recsAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => const Center(child: Text('Could not load recommendations.')),
        data: (items) {
          if (items.isEmpty) return const Center(child: Text('No recommendations yet.'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final r = items[i];
              return Card(
                child: ListTile(
                  title: Text(r.recommendationText),
                  subtitle: Text(r.status.dbValue),
                  trailing: r.status == RecommendationStatus.open
                      ? TextButton(
                          onPressed: () async {
                            await ref
                                .read(recommendationRepositoryProvider)
                                .updateStatus(r.id, RecommendationStatus.actioned);
                            ref.invalidate(recommendationsProvider(enterpriseId));
                          },
                          child: const Text('Mark actioned'),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New recommendation'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(labelText: 'Recommendation'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (textController.text.trim().isEmpty) return;
              final consultantId = ref.read(authRepositoryProvider).currentUser!.id;
              await ref.read(recommendationRepositoryProvider).createRecommendation(
                    enterpriseId: enterpriseId,
                    consultantId: consultantId,
                    recommendationText: textController.text.trim(),
                  );
              ref.invalidate(recommendationsProvider(enterpriseId));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}