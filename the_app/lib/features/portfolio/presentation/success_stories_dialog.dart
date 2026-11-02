import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../enterprises/models/enterprise.dart';
import '../../enterprises/providers/enterprise_providers.dart';
import '../models/monthly_report.dart';
import '../models/success_story.dart';
import '../providers/portfolio_providers.dart';
import '../../../core/user_message.dart';

/// Step two of "Monthly report": the month's success stories, each written
/// in six guided parts. Returns true to go on and create the report, null
/// if the person cancels.
Future<bool?> showSuccessStoriesDialog(BuildContext context, DateTime month) =>
    showDialog<bool>(context: context, builder: (_) => _SuccessStoriesDialog(month: month));

class _SuccessStoriesDialog extends ConsumerWidget {
  const _SuccessStoriesDialog({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(successStoriesProvider(month));
    final enterprises = ref.watch(enterprisesListProvider).value ?? const <Enterprise>[];
    String nameOf(String id) =>
        enterprises.where((e) => e.id == id).map((e) => e.businessName).firstOrNull ?? 'Enterprise';
    final text = Theme.of(context).textTheme;

    Future<void> edit([SuccessStory? story]) async {
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _StoryEditor(month: month, enterprises: enterprises, story: story),
      );
      if (saved == true) ref.invalidate(successStoriesProvider(month));
    }

    return AlertDialog(
      title: Text('Success stories for ${monthLabel(month)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'They go into section 4 of the report. Optional: you can create the report without one.',
                style: text.bodySmall,
              ),
              const SizedBox(height: Space.md),
              ...stories.when(
                loading: () => [const AjwLoadingView()],
                error: (_, _) => [const Text("Couldn't load this month's stories.")],
                data: (list) => [
                  if (list.isEmpty) Text('No stories yet.', style: text.bodyMedium),
                  for (final s in list)
                    Card(
                      margin: const EdgeInsets.only(bottom: Space.sm),
                      child: ListTile(
                        leading: const Icon(Icons.auto_stories_outlined),
                        title: Text(nameOf(s.enterpriseId)),
                        subtitle: Text(
                          s.results.isNotEmpty ? s.results : s.beforeStory,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete story',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ref.read(successStoryRepositoryProvider).delete(s.id!);
                            ref.invalidate(successStoriesProvider(month));
                          },
                        ),
                        onTap: () => edit(s),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add a success story'),
                  onPressed: enterprises.isEmpty ? null : () => edit(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create report')),
      ],
    );
  }
}

class _StoryEditor extends ConsumerStatefulWidget {
  const _StoryEditor({required this.month, required this.enterprises, this.story});
  final DateTime month;
  final List<Enterprise> enterprises;
  final SuccessStory? story;

  @override
  ConsumerState<_StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends ConsumerState<_StoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late String? _enterpriseId = widget.story?.enterpriseId;
  late final List<TextEditingController> _fields = [
    for (final (_, _, value) in (widget.story ?? SuccessStory(enterpriseId: '', reportMonth: widget.month)).parts)
      TextEditingController(text: value),
  ];
  late bool _involvesMinor = widget.story?.involvesMinor ?? false;
  late bool _guardianConsent = widget.story?.guardianConsent ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_involvesMinor && !_guardianConsent) {
      setState(() => _error = "A story about someone under 18 needs their parent or guardian's consent first.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(successStoryRepositoryProvider).save(SuccessStory(
            id: widget.story?.id,
            enterpriseId: _enterpriseId!,
            reportMonth: widget.month,
            beforeStory: _fields[0].text,
            whatWeDid: _fields[1].text,
            results: _fields[2].text,
            humanImpact: _fields[3].text,
            ownerQuote: _fields[4].text,
            whatsNext: _fields[5].text,
            involvesMinor: _involvesMinor,
            guardianConsent: _guardianConsent,
          ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save the story: ${userMessage(e)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.story == null ? 'New success story' : 'Edit success story'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 560),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _enterpriseId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Enterprise'),
                  items: [
                    for (final e in widget.enterprises)
                      DropdownMenuItem(value: e.id, child: Text(e.businessName, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _enterpriseId = v),
                  validator: (v) => v == null ? 'Choose the enterprise' : null,
                ),
                for (final (i, (heading, prompt)) in storyPrompts.indexed) ...[
                  const SizedBox(height: Space.lg),
                  TextFormField(
                    controller: _fields[i],
                    minLines: i == 4 ? 1 : 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: '${i + 1}. $heading',
                      helperText: prompt,
                      helperMaxLines: 3,
                      alignLabelWithHint: true,
                    ),
                    // Before, what we did and results make the story; the
                    // rest are encouraged but optional.
                    validator: (v) => i < 3 && (v == null || v.trim().isEmpty) ? 'Add a sentence or two' : null,
                  ),
                ],
                const SizedBox(height: Space.lg),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _involvesMinor,
                  onChanged: (v) => setState(() => _involvesMinor = v ?? false),
                  title: const Text('This story names, quotes or shows someone under 18'),
                ),
                if (_involvesMinor)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _guardianConsent,
                    onChanged: (v) => setState(() => _guardianConsent = v ?? false),
                    title: const Text('Their parent or guardian has agreed to it being used in programme reports'),
                    subtitle: const Text('Required by the Kenya Data Protection Act, 2019 (section 33).'),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: Space.lg),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const AjwLoader(dotSize: 6) : const Text('Save story'),
        ),
      ],
    );
  }
}
