import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/site_links.dart';
import '../models/app_release.dart';

/// Reads which Android build is the newest released one. The file lives on
/// the portal's own site, so publishing a release is: upload the APK, then
/// deploy web/android-latest.json (DO_NOT_BREAK.md section 5).
class AppUpdateRepository {
  AppUpdateRepository([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// Null when the file can't be read: the check is a nicety and never
  /// gets in the way.
  Future<AppRelease?> latestAndroidRelease() async {
    try {
      final res = await _client.get(Uri.parse(SiteLinks.androidLatest)).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return AppRelease.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
