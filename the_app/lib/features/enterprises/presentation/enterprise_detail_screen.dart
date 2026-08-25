import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/enterprise.dart';
import '../providers/enterprise_providers.dart';

class EnterpriseDetailScreen extends ConsumerWidget {
  const EnterpriseDetailScreen({super.key, required this.enterpriseId});

  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enterpriseAsync = ref.watch(enterpriseDetailProvider(enterpriseId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise details'),
        leading: BackButton(onPressed: () => context.go('/admin')),
      ),
      body: enterpriseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load this enterprise.')),
        data: (enterprise) {
          if (enterprise == null) {
            return const Center(child: Text('Enterprise not found.'));
          }
          return _EnterpriseDetailBody(enterprise: enterprise);
        },
      ),
    );
  }
}

class _EnterpriseDetailBody extends ConsumerStatefulWidget {
  const _EnterpriseDetailBody({required this.enterprise});

  final Enterprise enterprise;

  @override
  ConsumerState<_EnterpriseDetailBody> createState() => _EnterpriseDetailBodyState();
}

class _EnterpriseDetailBodyState extends ConsumerState<_EnterpriseDetailBody> {
  bool _isUpdating = false;

  Future<void> _updateLifecycleStatus(LifecycleStatus status) async {
    setState(() => _isUpdating = true);
    try {
      await ref.read(enterpriseRepositoryProvider).updateLifecycleStatus(
            enterpriseId: widget.enterprise.id,
            status: status,
          );
      ref.invalidate(enterpriseDetailProvider(widget.enterprise.id));
      ref.invalidate(enterprisesListProvider);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _toggleGoingConcern(bool achieved) async {
    setState(() => _isUpdating = true);
    try {
      await ref.read(enterpriseRepositoryProvider).updateGoingConcernStatus(
            enterpriseId: widget.enterprise.id,
            status: achieved ? GoingConcernStatus.achieved : GoingConcernStatus.notYet,
          );
      ref.invalidate(enterpriseDetailProvider(widget.enterprise.id));
      ref.invalidate(enterprisesListProvider);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enterprise = widget.enterprise;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(enterprise.businessName, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Owner: ${enterprise.ownerName}'),
          if (enterprise.phoneNumber != null) Text('Phone: ${enterprise.phoneNumber}'),
          if (enterprise.email != null) Text('Email: ${enterprise.email}'),
          if (enterprise.county != null) Text('County: ${enterprise.county}'),
          if (enterprise.industry != null) Text('Industry: ${enterprise.industry}'),
          if (enterprise.registrationNumber != null)
            Text('Registration no.: ${enterprise.registrationNumber}'),
          if (enterprise.kraPin != null) Text('KRA PIN: ${enterprise.kraPin}'),
          Text('Enrolled: ${enterprise.enrolledAt.toLocal().toString().split(' ').first}'
              ' (${enterprise.monthsSinceEnrolment} months ago)'),
          const SizedBox(height: 32),

          Text('Lifecycle status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButton<LifecycleStatus>(
            value: enterprise.lifecycleStatus,
            onChanged: _isUpdating
                ? null
                : (status) {
                    if (status != null) _updateLifecycleStatus(status);
                  },
            items: LifecycleStatus.values
                .map((status) => DropdownMenuItem(value: status, child: Text(status.label)))
                .toList(),
          ),
          const SizedBox(height: 24),

          Text('Going Concern (TOR KPI — independent of lifecycle status)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Achieved'),
            subtitle: enterprise.goingConcernAchievedAt != null
                ? Text('Since ${enterprise.goingConcernAchievedAt!.toLocal().toString().split(' ').first}')
                : const Text('Not yet achieved'),
            value: enterprise.goingConcernStatus == GoingConcernStatus.achieved,
            onChanged: _isUpdating ? null : _toggleGoingConcern,
          ),
        ],
      ),
    );
  }
}