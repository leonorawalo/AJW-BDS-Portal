import 'package:supabase_flutter/supabase_flutter.dart';

import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../models/deck_slide.dart';
import '../models/exported_file.dart';
import '../models/sheet_tab.dart';

/// Thrown when the user connected Google before exports existed, so their
/// token lacks drive.file — reconnecting once fixes it.
class GoogleReconnectNeededException implements Exception {
  const GoogleReconnectNeededException();
}

/// Creates files in the user's own Google Drive via the google-export Edge
/// Function. The app sends content it already loaded under the user's RLS;
/// the function only holds the Google token and talks to Google.
class GoogleExportRepository {
  GoogleExportRepository(this._client);

  final SupabaseClient _client;

  Future<ExportedFile> exportDoc({required String title, required String html}) =>
      _invoke({'kind': 'doc', 'title': title, 'html': html});

  Future<ExportedFile> exportSheet({required String title, required List<SheetTab> tabs}) =>
      _invoke({'kind': 'sheet', 'title': title, 'tabs': [for (final t in tabs) t.toJson()]});

  Future<ExportedFile> exportSlides({
    required String title,
    String? subtitle,
    required List<DeckSlide> slides,
  }) =>
      _invoke({
        'kind': 'slides',
        'title': title,
        'subtitle': subtitle,
        'slides': [for (final s in slides) s.toJson()],
      });

  Future<ExportedFile> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('google-export', body: body);
      return ExportedFile.fromMap(res.data as Map<String, dynamic>);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (e.status == 412 && message == 'not_connected') throw const GoogleNotConnectedException();
      if (e.status == 412 && message == 'reconnect_needed') throw const GoogleReconnectNeededException();
      throw Exception(message ?? 'Export failed (${e.status})');
    }
  }
}
