import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/models/user_profile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../consultants/models/consultant_assignment.dart';
import '../../consultants/providers/consultant_assignment_providers.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../models/task.dart';
import '../models/task_template.dart';
import '../providers/legal_workstream_providers.dart';
import '../../tutorial/models/tour_catalog.dart';
import '../../tutorial/presentation/tour_anchor.dart';

/// An enterprise's tasks. Terms of Reference (ToR) tasks are grouped by
/// the ToR's two milestones (going concern by month 3, bankable by month
/// 6); anything added by hand sits under "Other tasks".
///
/// ToR tasks are never applied by hand: when the tab opens, the missing
/// items of each relevant discipline's checklist are added (a consultant:
/// their own discipline; an Admin: every assigned discipline). The
/// database function makes that safe to repeat and never duplicates, so
/// it also back-fills older enterprises. See task_template.dart.
class TasksTab extends ConsumerStatefulWidget {
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

  /// Governs whether the "add task" button shows at all. Separate from
  /// [readOnly] because the Owner can create tasks (assigned to one of
  /// their enterprise's consultants) without editing existing ones.
  /// Defaults to `!readOnly`.
  final bool? canCreateTasks;

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> {
  /// ToR tasks for every checklist key, to know an item's phase.
  static final Map<String, TaskTemplate> _templates = {
    for (final s in ConsultantSpecialization.values)
      for (final t in torChecklistFor(s)) t.key: t,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureTorTasks());
  }

  Future<void> _ensureTorTasks() async {
    try {
      final profile = await ref.read(currentUserProfileProvider.future);
      if (profile == null) return;
      final List<ConsultantSpecialization> disciplines;
      if (profile.role == UserRole.administrator) {
        final active = await ref.read(activeAssignmentsForEnterpriseProvider(widget.enterpriseId).future);
        disciplines = active.map((a) => a.specialization).whereType<ConsultantSpecialization>().toSet().toList();
      } else if (profile.role == UserRole.consultant && profile.specialization != null) {
        disciplines = [profile.specialization!];
      } else {
        return; // Owners see tasks but don't create the checklist.
      }
      if (disciplines.isEmpty) return;
      final enterprise = await ref.read(enterpriseDetailProvider(widget.enterpriseId).future);
      if (enterprise == null) return;

      var added = 0;
      for (final d in disciplines) {
        added += await ref.read(taskRepositoryProvider).ensureTorTasks(
              enterpriseId: widget.enterpriseId,
              specialization: d,
              enrolledAt: enterprise.enrolledAt,
            );
      }
      if (added > 0 && mounted) ref.invalidate(tasksProvider(widget.enterpriseId));
    } catch (e) {
      // Not fatal: the list still shows what exists, and the next visit
      // tries again.
      if (kDebugMode) debugPrint('Ensuring ToR tasks failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider(widget.enterpriseId));
    final showAddButton = widget.canCreateTasks ?? !widget.readOnly;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: !showAddButton
          ? null
          : TourAnchor(id: TourAnchors.tasksAdd, child: FloatingActionButton.extended(
              onPressed: () => _showCreateTaskDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add a task'),
            )),
      body: tasksAsync.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load tasks",
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(tasksProvider(widget.enterpriseId)),
            child: const Text('Try again'),
          ),
        ),
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt,
              title: 'No tasks yet',
              message: 'Terms of Reference tasks appear here automatically once a consultant is assigned. '
                  'You can also add your own.',
            );
          }
          return _TaskList(
            tasks: tasks,
            templates: _templates,
            enterpriseId: widget.enterpriseId,
            readOnly: widget.readOnly,
            bottomPadding: showAddButton ? 88 : 0,
          );
        },
      ),
    );
  }

  Future<void> _showCreateTaskDialog(BuildContext context) async {
    final active = await ref.read(activeAssignmentsForEnterpriseProvider(widget.enterpriseId).future);
    if (!context.mounted) return;
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No consultant is assigned to this enterprise yet.')),
      );
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _NewTaskDialog(enterpriseId: widget.enterpriseId, active: active),
    );
    if (created == true) ref.invalidate(tasksProvider(widget.enterpriseId));
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.templates,
    required this.enterpriseId,
    required this.readOnly,
    required this.bottomPadding,
  });

  final List<WorkstreamTask> tasks;
  final Map<String, TaskTemplate> templates;
  final String enterpriseId;
  final bool readOnly;
  final double bottomPadding;

  static int _order(WorkstreamTask t) => switch (t.status) {
        TaskStatus.overdue => 0,
        TaskStatus.inProgress => 1,
        TaskStatus.pending => 2,
        TaskStatus.completed => 3,
      };

  List<WorkstreamTask> _sorted(Iterable<WorkstreamTask> list) {
    final l = list.toList();
    l.sort((a, b) {
      final s = _order(a).compareTo(_order(b));
      if (s != 0) return s;
      final p = b.priority.index.compareTo(a.priority.index);
      if (p != 0) return p;
      return (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999));
    });
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tor = tasks.where((t) => t.isTor).toList();
    final done = tor.where((t) => t.status == TaskStatus.completed).length;
    final disciplines = tasks.map((t) => t.specialization).whereType<String>().toSet();
    final showDiscipline = disciplines.length > 1;

    final sections = <(String, List<WorkstreamTask>)>[
      for (final phase in TorPhase.values)
        (phase.label, _sorted(tor.where((t) => templates[t.torKey]?.phase == phase))),
      ('Other tasks', _sorted(tasks.where((t) => !t.isTor || templates[t.torKey] == null))),
    ].where((s) => s.$2.isNotEmpty).toList();

    final padding = PageBody.paddingFor(context);
    return ListView(
      padding: padding.copyWith(bottom: padding.bottom + bottomPadding),
      children: [
        PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tor.isNotEmpty) ...[
                TourAnchor(id: TourAnchors.tasksProgress, child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Terms of Reference progress', style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft)),
                        const SizedBox(height: Space.sm),
                        Text('$done of ${tor.length} done', style: text.titleLarge),
                        const SizedBox(height: Space.md),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: tor.isEmpty ? 0 : done / tor.length,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceSunken,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: Space.xl),
              ],
              for (final (title, list) in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: text.titleMedium)),
                      Text(
                        '${list.where((t) => t.status == TaskStatus.completed).length}/${list.length}',
                        style: text.labelMedium?.copyWith(color: AppColors.charcoalSoft),
                      ),
                    ],
                  ),
                ),
                for (final task in list) ...[
                  TourAnchor(id: TourAnchors.tasksFirst, child: _TaskCard(
                    task: task,
                    showDiscipline: showDiscipline,
                    onTap: () => context.push('/workstream/enterprises/$enterpriseId/tasks/${task.id}?readOnly=$readOnly'),
                  )),
                  const SizedBox(height: Space.sm),
                ],
                const SizedBox(height: Space.xl),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.showDiscipline, required this.onTap});
  final WorkstreamTask task;
  final bool showDiscipline;
  final VoidCallback onTap;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final completed = task.status == TaskStatus.completed;
    final (StatusTone tone, IconData? icon) = switch (task.status) {
      TaskStatus.completed => (StatusTone.success, Icons.check_circle),
      TaskStatus.inProgress => (StatusTone.warning, Icons.timelapse),
      TaskStatus.overdue => (StatusTone.danger, Icons.error_outline),
      TaskStatus.pending => (StatusTone.neutral, null),
    };
    final meta = [
      if (showDiscipline && task.specialization != null) task.specialization!,
      '${task.priority.dbValue} priority',
      if (completed && task.completedAt != null)
        'Done ${_date(task.completedAt!.toLocal())}'
      else if (task.dueDate != null)
        'Due ${_date(task.dueDate!)}',
    ].join('  ·  ');

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          child: Row(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: completed ? AppColors.successGreen : AppColors.lightGray,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: AppFonts.bodyStrong,
                        color: completed ? AppColors.charcoalSoft : AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(meta, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              StatusChip(task.status.dbValue, tone: tone, icon: icon),
            ],
          ),
        ),
      ),
    );
  }
}

/// A task added by hand, on top of the ToR checklist. Never offers a
/// checklist: those are added automatically per discipline.
class _NewTaskDialog extends ConsumerStatefulWidget {
  const _NewTaskDialog({required this.enterpriseId, required this.active});
  final String enterpriseId;
  final List<ConsultantAssignment> active;

  @override
  ConsumerState<_NewTaskDialog> createState() => _NewTaskDialogState();
}

class _NewTaskDialogState extends ConsumerState<_NewTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  String? _assigneeId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // A consultant adding their own task is the common case; Admin and
    // Owner pick explicitly since they're never the one doing the work.
    final me = ref.read(authRepositoryProvider).currentUser?.id;
    if (widget.active.any((a) => a.consultantId == me)) _assigneeId = me;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(taskRepositoryProvider).createTask(
            enterpriseId: widget.enterpriseId,
            consultantId: _assigneeId!,
            title: _title.text.trim(),
            description: _description.text.trim(),
            priority: _priority,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not add the task: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a task'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 440),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'For work beyond the Terms of Reference checklist, which is added automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Give the task a title' : null,
                ),
                const SizedBox(height: Space.lg),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: Space.lg),
                DropdownButtonFormField<String>(
                  initialValue: _assigneeId,
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: [
                    for (final a in widget.active)
                      DropdownMenuItem(
                        value: a.consultantId,
                        child: Text(
                          '${a.consultantName ?? 'Consultant'}'
                          '${a.specialization != null ? ' (${a.specialization!.label})' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _assigneeId = v),
                  validator: (v) => v == null ? 'Choose who does it' : null,
                ),
                const SizedBox(height: Space.lg),
                DropdownButtonFormField<TaskPriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [for (final p in TaskPriority.values) DropdownMenuItem(value: p, child: Text(p.dbValue))],
                  onChanged: (v) => setState(() => _priority = v ?? TaskPriority.medium),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _create,
          child: _saving ? const AjwLoader(dotSize: 6) : const Text('Add task'),
        ),
      ],
    );
  }
}
