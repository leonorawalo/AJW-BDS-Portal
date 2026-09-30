import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/progress_dialog.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/invite_request.dart';
import '../models/managed_user.dart';
import '../providers/user_management_providers.dart';
import 'invite_flow.dart';
import 'invite_user_dialog.dart';
import '../../email/models/email_contact.dart';
import '../../email/presentation/compose_email_dialog.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/ajw_loader.dart';

/// Admin: every account, with role, specialization and status
/// (invited / active / suspended), plus resend invite, change
/// specialization, and suspend / reactivate (Phase 9b).
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  static const _roleFilters = {
    null: 'All',
    'Administrator': 'Admins',
    'Consultant': 'Consultants',
    'Enterprise Owner': 'Owners',
  };

  String? _roleFilter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(managedUsersProvider);

    return AppShell(
      title: 'Users',
      globalKey: 'users',
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invite user'),
        onPressed: () async {
          await showInviteUserDialog(context);
          ref.invalidate(managedUsersProvider);
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or email',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final MapEntry(key: role, value: label) in _roleFilters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _roleFilter == role,
                      onSelected: (_) => setState(() => _roleFilter = role),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const AjwLoadingView(),
              error: (_, _) => const Center(child: Text('Could not load users. Pull to refresh.')),
              data: (users) {
                final visible = users.where((u) {
                  if (_roleFilter != null && u.roleName != _roleFilter) return false;
                  if (_query.isEmpty) return true;
                  return u.fullName.toLowerCase().contains(_query) || u.email.toLowerCase().contains(_query);
                }).toList();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(managedUsersProvider),
                  child: visible.isEmpty
                      ? ListView(children: const [
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No users match.')),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _UserTile(user: visible[i]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _Action { email, resendInvite, shareLink, changeSpecialization, suspend, reactivate }

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});
  final ManagedUser user;

  InviteRequest get _inviteRequest => InviteRequest(
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        roleName: user.roleName,
        specialization: user.specialization,
        phoneNumber: user.phoneNumber,
      );

  Future<void> _run(BuildContext context, WidgetRef ref, _Action action) async {
    final repo = ref.read(userAdminRepositoryProvider);
    try {
      switch (action) {
        case _Action.email:
          await showComposeEmailDialog(
            context,
            ref,
            directRecipients: [
              EmailContact(userId: user.id, fullName: user.fullName, roleName: user.roleName, email: user.email),
            ],
          );
          return;
        case _Action.resendInvite:
          await runInvite(context, ref, _inviteRequest);
        case _Action.shareLink:
          await shareInviteLink(context, ref, _inviteRequest);
        case _Action.changeSpecialization:
          final chosen = await _pickSpecialization(context);
          if (chosen == null || chosen == user.specialization || !context.mounted) return;
          await withProgress(context, 'Saving…', repo.updateSpecialization(user.id, chosen));
        case _Action.suspend:
          if (!await _confirmSuspend(context) || !context.mounted) return;
          await withProgress(context, 'Suspending…', repo.suspend(user.id));
        case _Action.reactivate:
          await withProgress(context, 'Reactivating…', repo.reactivate(user.id));
      }
      ref.invalidate(managedUsersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<bool> _confirmSuspend(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Suspend ${user.fullName}?'),
        content: const Text(
          'They will be signed out and blocked from signing in, and will stop receiving '
          'notifications. Their data stays. You can reactivate them at any time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Suspend')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String?> _pickSpecialization(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Specialization for ${user.fullName}'),
        children: [
          for (final s in const ['Legal', 'Accounting', 'Marketing'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, s),
              child: Text(s + (s == user.specialization ? '  (current)' : '')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = user.id == ref.read(authRepositoryProvider).currentUser?.id;
    final (Color color, String label) = switch (user.state) {
      AccountState.active => (AppColors.successGreen, 'Active'),
      AccountState.invited => (AppColors.pendingAmber, 'Invited'),
      AccountState.suspended => (AppColors.errorRed, 'Suspended'),
    };
    final roleLine = [
      user.roleName == 'Enterprise Owner' ? 'Owner' : user.roleName,
      if (user.specialization != null) user.specialization!,
      if (user.activeAssignments > 0)
        '${user.activeAssignments} active assignment${user.activeAssignments == 1 ? '' : 's'}',
    ].join(' · ');

    final actions = <PopupMenuEntry<_Action>>[
      if (!isMe && user.state != AccountState.suspended)
        const PopupMenuItem(value: _Action.email, child: Text('Email (from your Gmail)')),
      if (user.state == AccountState.invited) ...const [
        PopupMenuItem(value: _Action.resendInvite, child: Text('Resend invite email')),
        PopupMenuItem(value: _Action.shareLink, child: Text('Share invite link')),
      ],
      if (user.isConsultant)
        PopupMenuItem(
          value: _Action.changeSpecialization,
          enabled: user.activeAssignments == 0,
          child: Text(user.activeAssignments == 0
              ? 'Change specialization'
              : 'Change specialization (end their assignments first)'),
        ),
      if (!isMe && user.state != AccountState.suspended)
        const PopupMenuItem(value: _Action.suspend, child: Text('Suspend')),
      if (user.state == AccountState.suspended)
        const PopupMenuItem(value: _Action.reactivate, child: Text('Reactivate')),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(isMe ? '${user.fullName} (you)' : user.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            Text(roleLine, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label, style: TextStyle(color: color, fontWeight: AppFonts.bodyStrong, fontSize: 12)),
            ),
            if (actions.isNotEmpty)
              PopupMenuButton<_Action>(
                tooltip: 'Actions',
                onSelected: (a) => _run(context, ref, a),
                itemBuilder: (_) => actions,
              ),
          ],
        ),
      ),
    );
  }
}
