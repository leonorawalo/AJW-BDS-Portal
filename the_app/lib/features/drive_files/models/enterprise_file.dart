enum GoogleFileKind { doc, sheet, slides }

extension GoogleFileKindX on GoogleFileKind {
  static GoogleFileKind fromDb(String v) => switch (v) {
        'sheet' => GoogleFileKind.sheet,
        'slides' => GoogleFileKind.slides,
        _ => GoogleFileKind.doc,
      };

  String get dbValue => name;

  String get label => switch (this) {
        GoogleFileKind.doc => 'Google Doc',
        GoogleFileKind.sheet => 'Google Sheet',
        GoogleFileKind.slides => 'Google Slides',
      };
}

/// A working Google file for an enterprise (enterprise_files): created in
/// its creator's Drive and shared with the enterprise's Owner and
/// consultants.
class EnterpriseFile {
  const EnterpriseFile({
    required this.id,
    required this.enterpriseId,
    required this.googleFileId,
    required this.kind,
    required this.title,
    required this.webUrl,
    required this.createdBy,
    required this.createdAt,
    this.creatorName,
    this.lastSharedAt,
  });

  factory EnterpriseFile.fromMap(Map<String, dynamic> map) {
    final creator = map['creator'] as Map<String, dynamic>?;
    return EnterpriseFile(
      id: map['id'] as String,
      enterpriseId: map['enterprise_id'] as String,
      googleFileId: map['google_file_id'] as String,
      kind: GoogleFileKindX.fromDb(map['kind'] as String),
      title: map['title'] as String,
      webUrl: map['web_url'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      lastSharedAt: map['last_shared_at'] == null ? null : DateTime.parse(map['last_shared_at'] as String).toLocal(),
      creatorName: creator == null ? null : '${creator['first_name']} ${creator['last_name']}'.trim(),
    );
  }

  final String id;
  final String enterpriseId;
  final String googleFileId;
  final GoogleFileKind kind;
  final String title;
  final String webUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? lastSharedAt;

  /// Null if the viewer can't read the creator's profile.
  final String? creatorName;

  /// Google's own "download as PDF" link. It downloads in the browser using
  /// the viewer's Google login and their access to the file, so no extra
  /// permission is needed.
  Uri get pdfUrl => Uri.parse(switch (kind) {
        GoogleFileKind.doc => 'https://docs.google.com/document/d/$googleFileId/export?format=pdf',
        GoogleFileKind.sheet => 'https://docs.google.com/spreadsheets/d/$googleFileId/export?format=pdf',
        GoogleFileKind.slides => 'https://docs.google.com/presentation/d/$googleFileId/export/pdf',
      });
}
