import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ajw_loader.dart';
import '../../../core/widgets/empty_state.dart';
import '../providers/chat_providers.dart';
import 'chat_thread.dart';

/// "Chat": the enterprise's group chat, for its Owner, its consultants
/// and Admins (whoever is on the enterprise right now).
class EnterpriseChatTab extends ConsumerWidget {
  const EnterpriseChatTab({super.key, required this.enterpriseId});
  final String enterpriseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(enterpriseChatIdProvider(enterpriseId));
    return id.when(
      loading: () => const AjwLoadingView(),
      error: (_, _) => EmptyState(
        isError: true,
        icon: Icons.cloud_off_outlined,
        title: "Couldn't open the chat",
        message: 'Check your connection and try again.',
        action: OutlinedButton(
          onPressed: () => ref.invalidate(enterpriseChatIdProvider(enterpriseId)),
          child: const Text('Try again'),
        ),
      ),
      data: (conversationId) => ChatThread(
        conversationId: conversationId,
        emptyHint: "Everyone on this enterprise sees this chat: the owner, the consultants and the administrators.",
      ),
    );
  }
}
