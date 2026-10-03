import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document.dart';

class DocumentRepository {
  DocumentRepository(this._client);

  final SupabaseClient _client;

  /// All documents for an enterprise, regardless of whether they're
  /// attached to a specific task or not — used by the enterprise-level
  /// Documents tab.
  Future<List<WorkstreamDocument>> fetchDocuments(String enterpriseId) async {
    final rows = await _client
        .from('documents')
        .select('*, uploader:uploaded_by(first_name, last_name)')
        .eq('enterprise_id', enterpriseId)
        .order('uploaded_at', ascending: false);
    return (rows as List)
        .map((r) => WorkstreamDocument.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Documents attached to one specific task — used inside Task Detail.
  Future<List<WorkstreamDocument>> fetchDocumentsForTask(String taskId) async {
    final rows = await _client
        .from('documents')
        .select('*, uploader:uploaded_by(first_name, last_name)')
        .eq('task_id', taskId)
        .order('uploaded_at', ascending: false);
    return (rows as List)
        .map((r) => WorkstreamDocument.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> uploadDocument({
    required String enterpriseId,
    String? taskId,
    required String uploadedByUserId,
    required String fileName,
    required Uint8List bytes,
    String? category,
    String? mimeType,
  }) async {
    final storagePath = '$enterpriseId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from('documents').uploadBinary(storagePath, bytes);

    await _client.from('documents').insert({
      'enterprise_id': enterpriseId,
      'task_id': taskId,
      'uploaded_by': uploadedByUserId,
      'category': category,
      'file_name': fileName,
      'storage_path': storagePath,
      'mime_type': mimeType,
    });
  }

  Future<String> getDownloadUrl(String storagePath) {
    return _client.storage.from('documents').createSignedUrl(storagePath, 3600);
  }

  /// Raw bytes for in-app viewing (PDF rendering needs the actual file
  /// content, not just a URL to hand off to a browser).
  Future<Uint8List> downloadBytes(String storagePath) {
    return _client.storage.from('documents').download(storagePath);
  }
}