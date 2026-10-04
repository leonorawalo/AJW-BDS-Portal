class WorkstreamDocument {
  const WorkstreamDocument({
    required this.id,
    this.enterpriseId,
    this.taskId,
    this.workshopId,
    this.workshopTitle,
    required this.uploadedBy,
    this.category,
    required this.fileName,
    required this.storagePath,
    this.mimeType,
    required this.uploadedAt,
    this.uploaderName,
  });

  factory WorkstreamDocument.fromMap(Map<String, dynamic> map) => WorkstreamDocument(
        id: map['id'] as String,
        enterpriseId: map['enterprise_id'] as String?,
        taskId: map['task_id'] as String?,
        workshopId: map['workshop_id'] as String?,
        workshopTitle: (map['workshop'] as Map<String, dynamic>?)?['title'] as String?,
        uploadedBy: map['uploaded_by'] as String,
        category: map['category'] as String?,
        fileName: map['file_name'] as String,
        storagePath: map['storage_path'] as String,
        mimeType: map['mime_type'] as String?,
        uploadedAt: DateTime.parse(map['uploaded_at'] as String),
        uploaderName: map['uploader'] == null
            ? null
            : '${map['uploader']['first_name'] ?? ''} ${map['uploader']['last_name'] ?? ''}'.trim(),
      );

  final String id;

  /// Null for programme files (e.g. a workshop registration list).
  final String? enterpriseId;
  final String? taskId;
  final String? workshopId;
  final String? workshopTitle;
  final String uploadedBy;
  final String? category;
  final String fileName;
  final String storagePath;
  final String? mimeType;
  final DateTime uploadedAt;
  final String? uploaderName;

  bool get isImage {
    final ext = fileName.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool get isPdf => fileName.toLowerCase().endsWith('.pdf');
}

/// Fixed category list — a real dropdown, not freeform text, so
/// reporting on document types later stays consistent.
const List<String> documentCategories = [
  'Registration Certificate',
  'KRA PIN',
  'Trading License',
  'Contract',
  'Tenancy Agreement',
  'Financial Record',
  'ID/Photo Evidence',
  'Other',
];

/// Category of the programme file a workshop's registration list is saved as.
const workshopRegistrationListCategory = 'Workshop registration list';
