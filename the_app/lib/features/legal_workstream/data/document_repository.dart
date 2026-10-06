import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document.dart';

class DocumentRepository {
  DocumentRepository(this._client);

  final SupabaseClient _client;

  /// All documents for an enterprise, regardless of whether they're
  /// attached to a specific task or not: used by the enterprise-level
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

  /// Documents attached to one specific task: used inside Task Detail.
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

  /// Programme files (not tied to an enterprise), newest first: workshop
  /// registration lists. Admins see all of them; others only their own (RLS).
  Future<List<WorkstreamDocument>> fetchProgrammeDocuments() async {
    final rows = await _client
        .from('documents')
        .select('*, uploader:uploaded_by(first_name, last_name), workshop:workshop_id(title)')
        .isFilter('enterprise_id', null)
        .order('uploaded_at', ascending: false);
    return (rows as List).map((r) => WorkstreamDocument.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// The registration lists submitted for one workshop, newest first.
  Future<List<WorkstreamDocument>> fetchWorkshopLists(String workshopId) async {
    final rows = await _client
        .from('documents')
        .select('*, uploader:uploaded_by(first_name, last_name), workshop:workshop_id(title)')
        .eq('workshop_id', workshopId)
        .order('uploaded_at', ascending: false);
    return (rows as List).map((r) => WorkstreamDocument.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Saves a workshop's registration list as a programme file. Storage path
  /// starts with the workshop id (see migration 20261005120000).
  Future<void> uploadWorkshopList({
    required String workshopId,
    required String uploadedByUserId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final storagePath = '$workshopId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage
        .from('documents')
        .uploadBinary(storagePath, bytes, fileOptions: const FileOptions(contentType: 'text/csv'));
    await _client.from('documents').insert({
      'workshop_id': workshopId,
      'uploaded_by': uploadedByUserId,
      'category': workshopRegistrationListCategory,
      'file_name': fileName,
      'storage_path': storagePath,
      'mime_type': 'text/csv',
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