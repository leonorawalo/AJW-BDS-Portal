import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/consent_record.dart';
import '../models/data_request.dart';
import '../models/retention_setting.dart';

/// Consent, data subject requests, "Download my data" and retention. The
/// rules (deadlines, who may resolve, what an export contains) live in
/// the database (migration 20261008150000).
class PrivacyRepository {
  PrivacyRepository(this._client);

  final SupabaseClient _client;

  String? get _me => _client.auth.currentUser?.id;

  Future<void> recordConsent(String noticeVersion) =>
      _client.from('data_consents').upsert({'notice_version': noticeVersion}, ignoreDuplicates: true);

  /// The caller's latest answer per purpose (user_consents history).
  Future<ConsentStatus> consentStatus() async {
    final rows = await _client.rpc('my_consents') as List;
    final answers = <ConsentPurpose, ConsentAnswer>{};
    for (final r in rows) {
      final map = r as Map<String, dynamic>;
      if (ConsentPurposeX.fromDb(map['purpose'] as String) == null) continue;
      final a = ConsentAnswer.fromMap(map);
      answers[a.purpose] = a;
    }
    return ConsentStatus(answers);
  }

  /// Appends answers to the consent history; the database stamps the time.
  /// [fromSettings]: changed later in Settings rather than at first sign-in.
  Future<void> recordAnswers(Map<ConsentPurpose, bool> answers, {bool fromSettings = false}) =>
      _client.from('user_consents').insert([
        for (final e in answers.entries)
          {
            'purpose': e.key.dbValue,
            'document_version': e.key.currentVersion,
            'granted': e.value,
            'source': fromSettings ? 'settings' : 'app',
          },
      ]);

  /// Everything the portal holds about the caller, as pretty JSON bytes.
  Future<Uint8List> exportMyData() async {
    final data = await _client.rpc('export_my_data');
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
  }

  /// The caller's own requests; Admins get everyone's (RLS).
  Future<List<DataRequest>> requests({bool everyone = false}) async {
    var query = _client.from('data_requests').select('*, requester:user_id(first_name, last_name)');
    if (!everyone && _me != null) query = query.eq('user_id', _me!);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => DataRequest.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// The deadline is set by the database, whatever is sent.
  Future<void> createRequest(DataRequestKind kind, String details) => _client.from('data_requests').insert({
        'kind': kind.dbValue,
        'details': details.trim(),
        'due_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<void> updateRequest(String id, DataRequestStatus status, {String? note}) =>
      _client.from('data_requests').update({'status': status.dbValue, 'resolution_note': ?note}).eq('id', id);

  Future<List<RetentionSetting>> retention() async {
    final rows = await _client.from('retention_settings').select().order('key');
    return (rows as List).map((r) => RetentionSetting.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<void> setRetention(String key, int? keepDays) => _client
      .from('retention_settings')
      .update({'keep_days': keepDays, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('key', key);

  /// Deletes what's past its period; returns how many rows went per kind.
  Future<Map<String, dynamic>> applyRetention() async =>
      Map<String, dynamic>.from(await _client.rpc('apply_retention') as Map);
}
