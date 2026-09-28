/// A file google-export created in the user's own Google Drive.
class ExportedFile {
  const ExportedFile({required this.id, required this.url});

  factory ExportedFile.fromMap(Map<String, dynamic> map) =>
      ExportedFile(id: map['id'] as String, url: map['url'] as String);

  final String id;
  final String url;
}
