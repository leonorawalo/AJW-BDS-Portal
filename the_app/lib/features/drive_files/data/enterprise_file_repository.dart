import 'package:supabase_flutter/supabase_flutter.dart';

import '../../calendar/data/consultation_session_repository.dart' show GoogleNotConnectedException;
import '../../google_exports/data/google_export_repository.dart' show GoogleReconnectNeededException;
import '../models/enterprise_file.dart';

/// Result of creating or re-sharing a file: who has access now, and any
/// addresses Google couldn't share with (no Google account behind them).
typedef ShareResult = ({List<String> sharedWith, List<String> notShared});

class EnterpriseFileRepository {
  EnterpriseFileRepository(this._client);

  final SupabaseClient _client;

  Future<List<EnterpriseFile>> fetchFiles(String enterpriseId) async {
    final rows = await _client
        .from('enterprise_files')
        .select('*, creator:created_by(first_name, last_name)')
        .eq('enterprise_id', enterpriseId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => EnterpriseFile.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<(EnterpriseFile, ShareResult)> create({
    required String enterpriseId,
    required GoogleFileKind kind,
    required String title,
  }) async {
    final data = await _invoke({
      'action': 'create',
      'enterprise_id': enterpriseId,
      'kind': kind.dbValue,
      'title': title,
    });
    return (EnterpriseFile.fromMap(data['file'] as Map<String, dynamic>), _shareResult(data));
  }

  /// Re-shares with the enterprise's current Owner and consultants (e.g.
  /// after a new consultant is assigned). Creator only.
  Future<ShareResult> updateSharing(String fileId) async =>
      _shareResult(await _invoke({'action': 'share', 'file_id': fileId}));

  /// Removes the portal's list entry; the Google file stays in its
  /// creator's Drive.
  Future<void> removeFromList(String fileId) => _client.from('enterprise_files').delete().eq('id', fileId);

  static ShareResult _shareResult(Map<String, dynamic> data) => (
        sharedWith: [for (final e in (data['shared_with'] as List? ?? const [])) e as String],
        notShared: [for (final e in (data['not_shared'] as List? ?? const [])) e as String],
      );

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('drive-files', body: body);
      return res.data as Map<String, dynamic>;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error'] as String? : null;
      if (e.status == 412 && message == 'not_connected') throw const GoogleNotConnectedException();
      if (e.status == 412 && message == 'reconnect_needed') throw const GoogleReconnectNeededException();
      throw Exception(message ?? 'Request failed (${e.status})');
    }
  }
}
