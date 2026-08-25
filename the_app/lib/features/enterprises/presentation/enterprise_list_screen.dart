import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/enterprise.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseListScreen extends ConsumerWidget {
  const EnterpriseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enterprises')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/enterprises/new'),
        icon: const Icon(Icons.add),
        label: const Text('Register enterprise'),
      ),
      body: enterprisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load enterprises. Pull to refresh or try again.'),
        ),
        data: (enterprises) {
          if (enterprises.isEmpty) {
            return const Center(
              child: Text('No enterprises registered yet. Tap "Register enterprise" to add one.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(enterprisesListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: enterprises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final enterprise = enterprises[index];
                return _EnterpriseListTile(
                  enterprise: enterprise,
                  onTap: () => context.go('/admin/enterprises/${enterprise.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EnterpriseListTile extends StatelessWidget {
  const _EnterpriseListTile({required this.enterprise, required this.onTap});

  final Enterprise enterprise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(enterprise.businessName),
        subtitle: Text('${enterprise.ownerName} · ${enterprise.county ?? 'No county set'}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(enterprise.lifecycleStatus.label, style: Theme.of(context).textTheme.bodySmall),
            if (enterprise.goingConcernStatus == GoingConcernStatus.achieved)
              const Text('Going Concern ✓', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}