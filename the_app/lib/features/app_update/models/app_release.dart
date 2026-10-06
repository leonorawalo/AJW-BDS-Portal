/// The newest Android release, as published in web/android-latest.json.
class AppRelease {
  const AppRelease({required this.version, required this.build, required this.downloadUrl});

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
        version: json['version'] as String,
        build: (json['build'] as num).toInt(),
        downloadUrl: json['downloadUrl'] as String,
      );

  /// Shown to people, e.g. "1.2.1".
  final String version;

  /// What's compared: the build number after the + in pubspec's version.
  final int build;
  final String downloadUrl;

  bool isNewerThan(int installedBuild) => build > installedBuild;
}
