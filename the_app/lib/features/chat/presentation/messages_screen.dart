import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/chat_contact.dart';
import '../models/chat_conversation.dart';
import '../providers/chat_providers.dart';
import 'chat_thread.dart';
import '../../../core/user_message.dart';

/// "Messages": every chat the user is in (enterprise group chats and
/// direct chats), newest first with unread counts, plus "New message".
/// [conversationId] set = that chat, full screen. [basePath] is the
/// role's own address for this page (/admin/messages, ...).
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key, required this.basePath, this.conversationId});
  final String basePath;
  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(myChatsProvider);
    final open = conversationId;
    if (open != null) {
      final title = chats.value?.where((c) => c.id == open).map((c) => c.title).firstOrNull ?? 'Chat';
      return AppShell(
        title: title,
        globalKey: 'messages',
        actions: [
          IconButton(
            tooltip: 'All messages',
            icon: const Icon(Icons.forum_outlined),
            onPressed: () => context.go(basePath),
          ),
        ],
        body: ChatThread(conversationId: open),
      );
    }

    return AppShell(
      title: 'Messages',
      globalKey: 'messages',
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New message'),
        onPressed: () => _newMessage(context, ref),
      ),
      body: chats.when(
        loading: () => const AjwLoadingView(),
        error: (_, _) => const EmptyState(
          isError: true,
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load messages",
          message: 'Check your connection and try again.',
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.forum_outlined,
                title: 'No chats yet',
                message: "Start one with \"New message\", or open an enterprise's Chat.",
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myChatsProvider),
                child: ListView(
                  padding: PageBody.paddingFor(context).copyWith(bottom: 96),
                  children: [
                    PageBody(
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, c) in list.indexed) ...[
                              if (i > 0) const Divider(height: 1),
                              _ChatTile(chat: c, onTap: () => context.go('$basePath?c=${c.id}')),
                            ],
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

  Future<void> _newMessage(BuildContext context, WidgetRef ref) async {
    final contact = await showDialog<ChatContact>(context: context, builder: (_) => const _ContactPicker());
    if (contact == null || !context.mounted) return;
    try {
      final id = await ref.read(chatRepositoryProvider).openDirectChat(contact.userId);
      ref.invalidate(myChatsProvider);
      if (context.mounted) context.go('$basePath?c=$id');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start the chat: ${userMessage(e)}')));
      }
    }
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});
  final ChatConversation chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final unread = chat.unread > 0;
    final at = chat.lastMessageAt;
    return ListTile(
      onTap: onTap,
      leading: chat.isEnterprise || chat.otherUserId == null
          ? const CircleAvatar(child: Icon(Icons.storefront_outlined))
          : UserAvatar(id: chat.otherUserId!, firstName: chat.title, lastName: '', radius: 20),
      title: Text(
        chat.isEnterprise ? '${chat.title} (group)' : chat.title,
        style: unread ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Text(chat.lastMessage ?? 'No messages yet', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (at != null) Text(MaterialLocalizations.of(context).formatShortMonthDay(at), style: text.bodySmall),
          if (unread)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: AppColors.brandRed, borderRadius: BorderRadius.circular(999)),
              child: Text(
                '${chat.unread}',
                semanticsLabel: '${chat.unread} unread',
                style: text.labelSmall?.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactPicker extends ConsumerWidget {
  const _ContactPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(chatContactsProvider);
    return AlertDialog(
      title: const Text('New message'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 440, maxHeight: 480),
        child: contacts.when(
          loading: () => const AjwLoadingView(),
          error: (_, _) => const Text("Couldn't load people."),
          data: (list) => list.isEmpty
              ? const Text('There is nobody you can message yet.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final c in list)
                      ListTile(
                        leading: UserAvatar(id: c.userId, firstName: c.fullName, lastName: '', radius: 18),
                        title: Text(c.fullName),
                        subtitle: Text(c.roleLabel),
                        onTap: () => Navigator.pop(context, c),
                      ),
                  ],
                ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}
