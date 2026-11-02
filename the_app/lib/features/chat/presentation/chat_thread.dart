import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/chat_message.dart';
import '../providers/chat_providers.dart';
import '../../../core/user_message.dart';

/// One conversation: messages arrive live (Realtime), newest at the
/// bottom, with a "New messages" line above what the user hadn't read.
/// Opening it marks the conversation read.
class ChatThread extends ConsumerStatefulWidget {
  const ChatThread({super.key, required this.conversationId, this.emptyHint});
  final String conversationId;
  final String? emptyHint;

  @override
  ConsumerState<ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends ConsumerState<ChatThread> {
  final _text = TextEditingController();
  bool _sending = false;

  /// Unread count when the thread opened, for the "New messages" line.
  int? _unreadAtOpen;
  int _lastMarkedCount = -1;

  @override
  void initState() {
    super.initState();
    final chats = ref.read(myChatsProvider).value ?? const [];
    _unreadAtOpen = chats.where((c) => c.id == widget.conversationId).map((c) => c.unread).firstOrNull ?? 0;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _markRead(int count) {
    if (count == _lastMarkedCount) return;
    _lastMarkedCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(chatRepositoryProvider).markRead(widget.conversationId);
        ref.invalidate(myChatsProvider);
      } catch (_) {
        // Read state is a nicety.
      }
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).send(widget.conversationId, body);
      _text.clear();
    } catch (e) {
      _snack('Could not send: ${userMessage(e)}');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final file = files.first;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendAttachment(
            conversationId: widget.conversationId,
            fileName: file.name,
            bytes: await file.readAsBytes(),
            caption: _text.text,
          );
      _text.clear();
    } catch (e) {
      _snack(userMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final me = ref.read(authRepositoryProvider).currentUser?.id;
    final names = {
      for (final c in ref.watch(chatContactsProvider).value ?? const []) c.userId: c.fullName,
    };

    return Column(
      children: [
        Expanded(
          child: messages.when(
            loading: () => const AjwLoadingView(),
            error: (_, _) => const EmptyState(
              isError: true,
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load messages",
              message: 'Check your connection and try again.',
            ),
            data: (list) {
              _markRead(list.length);
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No messages yet',
                  message: widget.emptyHint ?? 'Say hello.',
                );
              }
              final newFrom = (_unreadAtOpen ?? 0) > 0
                  ? list.length - _unreadAtOpen!.clamp(0, list.length)
                  : null;
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(Space.lg),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final index = list.length - 1 - i;
                  final m = list[index];
                  final previous = index > 0 ? list[index - 1] : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (index == newFrom) const _NewMessagesLine(),
                      _Bubble(
                        message: m,
                        mine: m.senderId == me,
                        senderName: names[m.senderId] ?? 'Former member',
                        showName: m.senderId != me && previous?.senderId != m.senderId,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, Space.sm),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Attach a file (pictures, PDF, Word, Excel; up to 10 MB)',
                  icon: const Icon(Icons.attach_file),
                  onPressed: _sending ? null : _attach,
                ),
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Write a message', counterText: ''),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: Space.sm),
                IconButton.filled(
                  tooltip: 'Send',
                  icon: _sending ? const AjwLoader(dotSize: 5) : const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NewMessagesLine extends StatelessWidget {
  const _NewMessagesLine();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            const Expanded(child: Divider(color: AppColors.brandRed)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Text('New messages',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.brandRedDeep)),
            ),
            const Expanded(child: Divider(color: AppColors.brandRed)),
          ],
        ),
      );
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.mine, required this.senderName, required this.showName});
  final ChatMessage message;
  final bool mine;
  final String senderName;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l = MaterialLocalizations.of(context);
    final t = message.createdAt;
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    final time = '${sameDay ? '' : '${l.formatShortMonthDay(t)}, '}${l.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.only(top: showName ? Space.md : Space.xs),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (showName)
                Padding(
                  padding: const EdgeInsets.only(left: Space.sm, bottom: 2),
                  child: Text(senderName, style: text.labelSmall?.copyWith(color: AppColors.charcoalSoft)),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: mine ? AppColors.brandRedTint : AppColors.surface,
                  border: Border.all(color: AppColors.hairline),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.attachmentPath != null) _Attachment(message: message),
                      if (message.body.trim().isNotEmpty) SelectableText(message.body),
                      const SizedBox(height: 2),
                      Text(time, style: text.labelSmall?.copyWith(color: AppColors.charcoalSoft)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Attachment extends ConsumerWidget {
  const _Attachment({required this.message});
  final ChatMessage message;

  Future<void> _open(WidgetRef ref) async {
    final url = await ref.read(chatRepositoryProvider).attachmentUrl(message.attachmentPath!);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.isImage) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: FutureBuilder<String>(
          future: ref.read(chatRepositoryProvider).attachmentUrl(message.attachmentPath!),
          builder: (context, snap) => InkWell(
            onTap: () => _open(ref),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: snap.hasData
                  ? Image.network(
                      snap.data!,
                      height: 180,
                      fit: BoxFit.cover,
                      semanticLabel: message.attachmentName,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                    )
                  : const SizedBox(height: 180, width: 180, child: Center(child: AjwLoader())),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xs),
      child: ActionChip(
        avatar: const Icon(Icons.insert_drive_file_outlined, size: 18),
        label: Text(message.attachmentName ?? 'Attachment', overflow: TextOverflow.ellipsis),
        onPressed: () => _open(ref),
      ),
    );
  }
}
