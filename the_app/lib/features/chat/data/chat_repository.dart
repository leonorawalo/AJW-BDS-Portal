import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/file_signature.dart';
import '../models/chat_contact.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';

/// Chat. Who can read or write what is decided by RLS and the chat
/// functions in migration 20261008140000; nothing here filters by hand.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'chat-attachments';

  /// Matches the bucket's own limit (it refuses bigger files anyway).
  static const maxAttachmentBytes = 10 * 1024 * 1024;

  /// Matches the bucket's allowed types.
  static const allowedTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
  };

  Future<List<ChatConversation>> myChats() async {
    final rows = await _client.rpc('my_chats') as List;
    return rows.map((r) => ChatConversation.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<List<ChatContact>> contacts() async {
    final rows = await _client.rpc('chat_contacts') as List;
    return rows.map((r) => ChatContact.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<String> openEnterpriseChat(String enterpriseId) async =>
      await _client.rpc('open_enterprise_chat', params: {'p_enterprise_id': enterpriseId}) as String;

  Future<String> openDirectChat(String otherUserId) async =>
      await _client.rpc('open_direct_chat', params: {'p_other': otherUserId}) as String;

  /// The conversation's messages, oldest first, updating live (Realtime).
  Stream<List<ChatMessage>> messages(String conversationId) => _client
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((rows) => rows.map(ChatMessage.fromMap).toList());

  /// Fires whenever a message the user can see is added anywhere (RLS
  /// filters what Realtime delivers), e.g. to refresh unread counts.
  RealtimeChannel onAnyMessage(void Function() callback) => _client
      .channel('chat-inbox-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'chat_messages',
        callback: (_) => callback(),
      )
      .subscribe();

  Future<void> removeChannel(RealtimeChannel channel) => _client.removeChannel(channel);

  Future<void> send(String conversationId, String body) =>
      _client.from('chat_messages').insert({'conversation_id': conversationId, 'body': body.trim()});

  /// Checks type and size before uploading; throws a readable message.
  Future<void> sendAttachment({
    required String conversationId,
    required String fileName,
    required Uint8List bytes,
    String caption = '',
  }) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final mime = allowedTypes[ext];
    if (mime == null) {
      throw Exception("That file type can't be shared here. Use a picture, PDF, Word, Excel or text file.");
    }
    if (bytes.length > maxAttachmentBytes) throw Exception('Files can be up to 10 MB.');
    if (!contentMatchesExtension(bytes, ext)) {
      throw Exception("This file doesn't look like a real .$ext file, so it wasn't sent. Check you picked the right file.");
    }
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$conversationId/${DateTime.now().millisecondsSinceEpoch}-$safeName';
    await _client.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    await _client.from('chat_messages').insert({
      'conversation_id': conversationId,
      'body': caption.trim(),
      'attachment_path': path,
      'attachment_name': fileName,
      'attachment_mime': mime,
      'attachment_size': bytes.length,
    });
  }

  /// A link that works for five minutes.
  Future<String> attachmentUrl(String path) => _client.storage.from(bucket).createSignedUrl(path, 300);

  Future<void> markRead(String conversationId) =>
      _client.rpc('mark_chat_read', params: {'p_conversation_id': conversationId});
}
