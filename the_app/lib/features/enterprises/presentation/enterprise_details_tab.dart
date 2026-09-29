import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_profile.dart';
import '../../consultants/providers/consultant_assignment_providers.dart';
import '../models/enterprise.dart';
import '../providers/enterprise_providers.dart';
import '../../user_management/models/invite_request.dart';
import '../../user_management/presentation/invite_flow.dart';

/// Business info, lifecycle status, Going Concern toggle, and current
/// consultant assignments — what used to be the whole of the Admin's
/// enterprise detail screen, now one tab alongside the loan-readiness
/// Dashboard, Tasks, Recommendations, and Documents.
class EnterpriseDetailsTab extends ConsumerStatefulWidget {
  const EnterpriseDetailsTab({super.key, required this.enterprise});

  final Enterprise enterprise;

  @override
  ConsumerState<EnterpriseDetailsTab> createState() => _EnterpriseDetailsTabState();
}

class _EnterpriseDetailsTabState extends ConsumerState<EnterpriseDetailsTab> {
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
          const SizedBox(height: 24),

          Text('Owner account', style: Theme.of(context).textTheme.titleMedium),
          Text(
            "The login account that sees this enterprise as \"theirs\" — separate from the "
            '"Owner" text above, which is just a name.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _OwnerAccountLink(enterprise: enterprise),
          const SizedBox(height: 24),

          Text('Consultants', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _AssignedConsultants(enterpriseId: enterprise.id),
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

/// Shows which login account (if any) is linked as this enterprise's
/// owner, and lets the Admin link or relink one — the only place this
/// can currently be set, since nothing does it automatically.
class _OwnerAccountLink extends ConsumerStatefulWidget {
  const _OwnerAccountLink({required this.enterprise});

  final Enterprise enterprise;

  @override
  ConsumerState<_OwnerAccountLink> createState() => _OwnerAccountLinkState();
}

class _OwnerAccountLinkState extends ConsumerState<_OwnerAccountLink> {
  String? _selectedOwnerUserId;
  bool _isLinking = false;

  Future<void> _link() async {
    final ownerUserId = _selectedOwnerUserId;
    if (ownerUserId == null) return;
    setState(() => _isLinking = true);
    try {
      await ref.read(enterpriseRepositoryProvider).linkOwnerAccount(
            enterpriseId: widget.enterprise.id,
            ownerUserId: ownerUserId,
          );
      ref.invalidate(enterpriseDetailProvider(widget.enterprise.id));
      ref.invalidate(linkedOwnerAccountProvider(ownerUserId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner account linked.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOwnerUserId = widget.enterprise.ownerUserId;
    final ownerAccountsAsync = ref.watch(ownerAccountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentOwnerUserId == null)
          const Text('Not linked to any login account yet.')
        else
          Consumer(
            builder: (context, ref, _) {
              final linkedAsync = ref.watch(linkedOwnerAccountProvider(currentOwnerUserId));
              return linkedAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Could not load the linked account.'),
                data: (account) => Text(
                  account == null
                      ? 'Linked account no longer exists.'
                      : 'Linked to: ${account['first_name']} ${account['last_name']} (${account['email']})',
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        _InviteOwnerActions(enterprise: widget.enterprise),
        const SizedBox(height: 8),
        ownerAccountsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load Owner accounts.'),
          data: (accounts) {
            if (accounts.isEmpty) {
              return const Text('No Enterprise Owner accounts exist yet.');
            }
            return Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedOwnerUserId,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Link a different Owner account',
                    ),
                    items: accounts
                        .map((a) => DropdownMenuItem(
                              value: a['id'] as String,
                              child: Text('${a['first_name']} ${a['last_name']} (${a['email']})'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedOwnerUserId = v),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: (_selectedOwnerUserId != null && !_isLinking) ? _link : null,
                  child: _isLinking
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Link'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Invite the Owner (email) or share a set-password link (copy / WhatsApp).
/// Also the "resend" for an Owner who hasn't accepted yet. Needs the
/// enterprise's email, which is where the Owner's email is recorded.
class _InviteOwnerActions extends ConsumerWidget {
  const _InviteOwnerActions({required this.enterprise});
  final Enterprise enterprise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = enterprise.email;
    if (email == null || email.trim().isEmpty) {
      return Text(
        "Add the owner's email to this enterprise to invite them to the portal.",
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final request = InviteRequest.forOwner(
      email: email.trim(),
      ownerName: enterprise.ownerName,
      enterpriseId: enterprise.id,
      phoneNumber: enterprise.phoneNumber,
    );
    void refresh() {
      ref.invalidate(enterpriseDetailProvider(enterprise.id));
      ref.invalidate(ownerAccountsProvider);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.mail_outline),
          label: Text('Invite owner ($email)'),
          onPressed: () async {
            if (await runInvite(context, ref, request)) refresh();
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('Share invite link'),
          onPressed: () async {
            if (await shareInviteLink(context, ref, request)) refresh();
          },
        ),
      ],
    );
  }
}

/// One row per Trio specialization (Legal / Accounting / Marketing)
/// showing who's currently assigned, or "Unassigned".
class _AssignedConsultants extends ConsumerWidget {
  const _AssignedConsultants({required this.enterpriseId});

  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeAssignmentsForEnterpriseProvider(enterpriseId));

    return activeAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => const Text('Could not load consultant assignments.'),
      data: (active) {
        String labelFor(ConsultantSpecialization specialization) {
          for (final assignment in active) {
            if (assignment.specialization == specialization) {
              return assignment.consultantName ?? 'Unassigned';
            }
          }
          return 'Unassigned';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final specialization in ConsultantSpecialization.values)
              Text('${specialization.label}: ${labelFor(specialization)}'),
          ],
        );
      },
    );
  }
}
