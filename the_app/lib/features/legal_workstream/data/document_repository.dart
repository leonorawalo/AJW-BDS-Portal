import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/file_signature.dart';
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
    final problem = checkUpload(fileName, bytes.length);
    if (problem != null) throw Exception(problem);
    final storagePath = '$enterpriseId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ext = fileName.split('.').last.toLowerCase();
    if (!contentMatchesExtension(bytes, ext)) throw Exception(mismatchMessage(ext));

    await _client.storage
        .from('documents')
        .uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: allowedTypes[ext]));

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

  /// A link that works for five minutes: long enough to open, too short
  /// to be worth passing around.
  Future<String> getDownloadUrl(String storagePath) {
    return _client.storage.from('documents').createSignedUrl(storagePath, 300);
  }

  /// Records a view or download in the audit log (log_document_access(),
  /// which checks the caller may see the document). Never blocks opening.
  Future<void> logAccess(String documentId, {required bool download}) async {
    try {
      await _client.rpc('log_document_access', params: {
        'p_document_id': documentId,
        'p_action': download ? 'downloaded' : 'viewed',
      });
    } catch (_) {}
  }

  /// File types the portal accepts, with the content type each is stored as.
  static const allowedTypes = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'csv': 'text/csv',
    'txt': 'text/plain',
  };

  /// Same as the documents bucket's own limit.
  static const maxBytes = 20 * 1024 * 1024;

  /// Null when the file can be uploaded, otherwise why not.
  static String? checkUpload(String fileName, int size) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!allowedTypes.containsKey(ext)) {
      return "This file type isn't accepted. Upload a PDF, a picture, or a Word, Excel, PowerPoint, CSV or text file.";
    }
    if (size > maxBytes) return 'Files can be up to 20 MB.';
    return null;
  }

  /// A file whose content isn't what its name says (checked by its first
  /// bytes, not only the extension).
  static String mismatchMessage(String ext) =>
      "This file doesn't look like a real .$ext file, so it wasn't uploaded. Check you picked the right file.";

  /// Raw bytes for in-app viewing (PDF rendering needs the actual file
  /// content, not just a URL to hand off to a browser).
  Future<Uint8List> downloadBytes(String storagePath) {
    return _client.storage.from('documents').download(storagePath);
  }
}