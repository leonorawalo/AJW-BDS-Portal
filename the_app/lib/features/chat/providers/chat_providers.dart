import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/chat_repository.dart';
import '../models/chat_contact.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

/// The user's chats with unread counts. Refreshes itself whenever a new
/// message the user can see arrives (Realtime), so the menu's unread dot
/// and the list stay current.
final myChatsProvider = FutureProvider<List<ChatConversation>>((ref) async {
  ref.watch(authStateChangesProvider);
  final repo = ref.watch(chatRepositoryProvider);
  if (ref.read(supabaseClientProvider).auth.currentUser == null) return const [];
  final channel = repo.onAnyMessage(ref.invalidateSelf);
  ref.onDispose(() => repo.removeChannel(channel));
  try {
    return await repo.myChats();
  } catch (_) {
    // Unread dots are a nicety; never an error screen.
    return const [];
  }
});

final chatContactsProvider = FutureProvider.autoDispose<List<ChatContact>>((ref) {
  return ref.watch(chatRepositoryProvider).contacts();
});

/// The enterprise's group chat id (created on first open).
final enterpriseChatIdProvider = FutureProvider.autoDispose.family<String, String>((ref, enterpriseId) {
  return ref.watch(chatRepositoryProvider).openEnterpriseChat(enterpriseId);
});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).messages(conversationId);
});

/// Red-dot places for unread chats: (enterprise id, 'chat') for an
/// enterprise's group chat, and (null, 'messages') when anything is unread.
final chatAttentionProvider = Provider<List<(String?, String)>>((ref) {
  final chats = ref.watch(myChatsProvider).value ?? const [];
  final unread = chats.where((c) => c.unread > 0).toList();
  return [
    for (final c in unread)
      if (c.isEnterprise && c.enterpriseId != null) (c.enterpriseId, 'chat'),
    if (unread.isNotEmpty) (null, 'messages'),
  ];
});
