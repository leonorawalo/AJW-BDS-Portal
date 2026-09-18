import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../consultants/providers/consultant_assignment_providers.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../providers/legal_workstream_providers.dart';

class TasksTab extends ConsumerWidget {
  const TasksTab({
    super.key,
    required this.enterpriseId,
    required this.readOnly,
    this.canCreateTasks,
  });

  final String enterpriseId;

  /// Governs whether tapping into an *existing* task allows editing its
  /// status (passed through to TaskDetailScreen).
  final bool readOnly;

  /// Governs whether the "add task" FAB shows at all. Separate from
  /// [readOnly] because Owner can create new tasks (assigned to one of
  /// their enterprise's consultants) while still not being able to edit
  /// existing ones. Defaults to `!readOnly` when not given, matching the
  /// old combined behaviour for Admin/Consultant.
  final bool? canCreateTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(enterpriseId));
    final showAddButton = canCreateTasks ?? !readOnly;

    return Scaffold(
      floatingActionButton: !showAddButton
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddMenu(context, ref),
              child: const Icon(Icons.add),
            ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load tasks.')),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(
              child: Text('No tasks yet. Tap + to add one or apply the standard checklist.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, i) {
              final task = tasks[i];
              return Card(
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text(
                    '${task.specialization ?? 'Unspecified'} · ${task.priority.dbValue}'
                    '${task.dueDate != null ? ' · Due ${task.dueDate!.toLocal().toString().split(' ').first}' : ''}'
                    '${task.completedAt != null ? ' · Completed ${task.completedAt!.toLocal().toString().split(' ').first}' : ''}',
                  ),
                  trailing: Text(task.status.dbValue),
                  onTap: () => context.push(
                    '/workstream/enterprises/$enterpriseId/tasks/${task.id}?readOnly=$readOnly',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Apply standard Legal checklist'),
              subtitle: const Text('Creates the standard set of ToR compliance tasks'),
              onTap: () => Navigator.pop(sheetContext, 'template'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Add a custom task'),
              onTap: () => Navigator.pop(sheetContext, 'custom'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (choice == 'template') {
      await _applyTemplate(context, ref);
    } else if (choice == 'custom') {
      await _showCreateTaskDialog(context, ref);
    }
  }

  Future<void> _applyTemplate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply standard checklist?'),
        content: const Text(
          'This adds the standard set of Legal & HR compliance tasks from the ToR '
          'to this enterprise. You can still add custom tasks as well.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) return;

    final active = await ref.read(activeAssignmentsForEnterpriseProvider(enterpriseId).future);
    final legalAssignment = active.where((a) => a.specialization == ConsultantSpecialization.legal);
    if (legalAssignment.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Legal consultant is assigned to this enterprise yet.')),
        );
      }
      return;
    }

    await ref.read(taskRepositoryProvider).applyChecklist(
          enterpriseId: enterpriseId,
          consultantId: legalAssignment.first.consultantId,
          checklist: standardLegalChecklist,
        );
    ref.invalidate(tasksProvider(enterpriseId));
  }

  Future<void> _showCreateTaskDialog(BuildContext context, WidgetRef ref) async {
    final active = await ref.read(activeAssignmentsForEnterpriseProvider(enterpriseId).future);
    if (!context.mounted) return;
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No consultant is assigned to this enterprise yet.')),
      );
      return;
    }

    final currentUserId = ref.read(authRepositoryProvider).currentUser!.id;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    TaskPriority priority = TaskPriority.medium;
    // Default to the current user when they're one of the assigned
    // consultants (the common case: a Consultant adding their own
    // custom task); Admin/Owner have to pick explicitly since they're
    // never the one doing the work.
    String? assigneeId = active.any((a) => a.consultantId == currentUserId) ? currentUserId : null;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('New task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
              DropdownButtonFormField<String>(
                initialValue: assigneeId,
                decoration: const InputDecoration(labelText: 'Assign to'),
                items: active
                    .map((a) => DropdownMenuItem(
                          value: a.consultantId,
                          child: Text(
                            '${a.consultantName ?? 'Consultant'}'
                            '${a.specialization != null ? ' (${a.specialization!.label})' : ''}',
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => assigneeId = v),
              ),
              DropdownButton<TaskPriority>(
                value: priority,
                items: TaskPriority.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.dbValue)))
                    .toList(),
                onChanged: (v) => setState(() => priority = v ?? TaskPriority.medium),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || assigneeId == null) return;
                await ref.read(taskRepositoryProvider).createTask(
                      enterpriseId: enterpriseId,
                      consultantId: assigneeId!,
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      priority: priority,
                    );
                ref.invalidate(tasksProvider(enterpriseId));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}