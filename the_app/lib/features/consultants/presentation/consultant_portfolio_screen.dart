import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../enterprises/providers/enterprise_providers.dart';

import '../../enterprises/models/enterprise.dart'; //fix for the ".label" error that was occuring in line 55 (was line 53 before) of this file. The Enterprise model was not imported, so the compiler could not find the "label" property of the lifecycleStatus enum.

/// Reuses enterprisesListProvider — the *same* query Admin's screen uses.
/// What comes back differs per role purely because of RLS
/// ("enterprises_select_assigned_consultant"), not because of any
/// client-side filtering here. A Consultant querying "all enterprises"
/// only ever receives the ones actually assigned to them.
class ConsultantPortfolioScreen extends ConsumerWidget {
  const ConsultantPortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterprisesAsync = ref.watch(enterprisesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My portfolio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: enterprisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Could not load your portfolio. Pull to refresh or try again.'),
        ),
        data: (enterprises) {
          if (enterprises.isEmpty) {
            return const Center(
              child: Text('No enterprises assigned to you yet.'),
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
                return Card(
                  child: ListTile(
                    title: Text(enterprise.businessName),
                    subtitle: Text(enterprise.county ?? 'No county set'),
                    trailing: Text(enterprise.lifecycleStatus.label),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}