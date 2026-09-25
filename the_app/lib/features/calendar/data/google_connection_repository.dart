import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/google_connection.dart';

class GoogleConnectionRepository {
  GoogleConnectionRepository(this._client);

  final SupabaseClient _client;

  /// Null when the user hasn't connected Google (or the connection was
  /// dropped after Google rejected the stored token).
  Future<GoogleConnection?> fetchMyConnection() async {
    final rows = await _client.rpc('get_my_google_connection') as List;
    if (rows.isEmpty) return null;
    return GoogleConnection.fromMap(rows.first as Map<String, dynamic>);
  }

  /// Returns the Google consent URL for the app to open in a browser.
  /// Google redirects back to the google-oauth Edge Function, not to the
  /// app, so completion is detected by re-checking fetchMyConnection().
  Future<Uri> startConnect() async {
    final res = await _client.functions.invoke('google-oauth', body: {'action': 'start'});
    return Uri.parse((res.data as Map<String, dynamic>)['url'] as String);
  }

  Future<void> disconnect() async {
    await _client.functions.invoke('google-oauth', body: {'action': 'disconnect'});
  }
}
