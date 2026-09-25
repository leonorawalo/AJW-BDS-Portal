import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/document.dart';
import '../models/task.dart';
import '../providers/legal_workstream_providers.dart';
import 'document_viewer_screen.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    required this.readOnly,
  });

  final String taskId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskProvider(taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: taskAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this task.')),
        data: (task) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
              if (task.description != null) ...[
                const SizedBox(height: 8),
                Text(task.description!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Chip(label: Text(task.priority.dbValue)),
                  const SizedBox(width: 8),
                  if (readOnly)
                    Chip(label: Text(task.status.dbValue))
                  else
                    DropdownButton<TaskStatus>(
                      value: task.status,
                      items: TaskStatus.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(s.dbValue)))
                          .toList(),
                      onChanged: (status) async {
                        if (status == null) return;
                        try {
                          await ref.read(taskRepositoryProvider).updateTaskStatus(taskId, status);
                          ref.invalidate(taskProvider(taskId));
                          ref.invalidate(tasksProvider(task.enterpriseId));
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not update status: $e')),
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
              const Divider(height: 32),
              Text('Documents', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _TaskDocuments(taskId: taskId, enterpriseId: task.enterpriseId),
              const Divider(height: 32),
              Text('Comments', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _TaskComments(taskId: taskId),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDocuments extends ConsumerWidget {
  const _TaskDocuments({required this.taskId, required this.enterpriseId});
  final String taskId;
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(taskDocumentsProvider(taskId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        docsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load documents.'),
          data: (docs) {
            if (docs.isEmpty) return const Text('No documents attached to this task.');
            return Column(
              children: docs
                  .map((d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description),
                        title: Text(d.fileName),
                        subtitle: Text(d.category ?? 'Uncategorized'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DocumentViewerScreen(document: d),
                        )),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: const Text('Attach document'),
          onPressed: () => _pickAndAttach(context, ref),
        ),
      ],
    );
  }

  Future<void> _pickAndAttach(BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    String? category = documentCategories.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text('Attach "${file.name}"'),
          content: DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: documentCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => category = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Attach')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final uploadedBy = ref.read(authRepositoryProvider).currentUser!.id;
    await ref.read(documentRepositoryProvider).uploadDocument(
          enterpriseId: enterpriseId,
          taskId: taskId,
          uploadedByUserId: uploadedBy,
          fileName: file.name,
          bytes: bytes,
          category: category,
          mimeType: file.extension,
        );
    ref.invalidate(taskDocumentsProvider(taskId));
  }
}

class _TaskComments extends ConsumerStatefulWidget {
  const _TaskComments({required this.taskId});
  final String taskId;

  @override
  ConsumerState<_TaskComments> createState() => _TaskCommentsState();
}

class _TaskCommentsState extends ConsumerState<_TaskComments> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(taskCommentsProvider(widget.taskId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        commentsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Could not load comments.'),
          data: (comments) {
            if (comments.isEmpty) return const Text('No comments yet.');
            return Column(
              children: comments
                  .map((c) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.commentText),
                        subtitle: Text(
                          '${c.authorName ?? 'Unknown'} · ${c.createdAt.toLocal().toString().split('.').first}',
                        ),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Add a comment...'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                if (_controller.text.trim().isEmpty) return;
                final authorId = ref.read(authRepositoryProvider).currentUser!.id;
                await ref.read(taskCommentRepositoryProvider).addComment(
                      taskId: widget.taskId,
                      authorId: authorId,
                      commentText: _controller.text.trim(),
                    );
                _controller.clear();
                ref.invalidate(taskCommentsProvider(widget.taskId));
              },
            ),
          ],
        ),
      ],
    );
  }
}