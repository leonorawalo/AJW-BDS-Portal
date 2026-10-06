import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/widgets/config_error_app.dart';

Future<void> main() async {
  // Web: readable addresses (portal.ajwafrica.org/admin/users) instead of
  // /#/admin/users. Old /#/ links, including invite and reset emails, are
  // turned into these by a script in web/index.html before the app starts.
  // No effect on Android.
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  final ({String url, String anonKey}) supabaseConfig;
  try {
    supabaseConfig = await _loadSupabaseConfig();
  } on _ConfigException catch (e) {
    runApp(ConfigErrorApp(message: e.message));
    return;
  }

  // Web needs an explicit FirebaseOptions (no google-services.json
  // equivalent exists for browsers): no Firebase Web app is registered
  // yet, and push notifications aren't in scope for the web/Admin-desktop
  // target, so skip init there rather than crash on boot.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  await Supabase.initialize(
    url: supabaseConfig.url,
    publishableKey: supabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: AjwBagsApp()));
}

class _ConfigException implements Exception {
  _ConfigException(this.message);
  final String message;
}

/// Each value comes from --dart-define if given, otherwise from the .env
/// asset. Throws [_ConfigException] naming exactly what's missing, so a
/// broken setup shows [ConfigErrorApp] instead of a blank white page.
Future<({String url, String anonKey})> _loadSupabaseConfig() async {
  const definedUrl = String.fromEnvironment('SUPABASE_URL');
  const definedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (definedUrl.isEmpty || definedAnonKey.isEmpty) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      throw _ConfigException(
        'Could not load the .env file.\n\n'
        'Check that the_app/.env exists and that pubspec.yaml lists it under '
        'flutter: > assets:, then run "flutter clean" and "flutter pub get".\n\n'
        'Details: $e',
      );
    }
  }

  final url = definedUrl.isNotEmpty ? definedUrl : (dotenv.env['SUPABASE_URL'] ?? '');
  final anonKey = definedAnonKey.isNotEmpty ? definedAnonKey : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
  final missing = [
    if (url.isEmpty) 'SUPABASE_URL',
    if (anonKey.isEmpty) 'SUPABASE_ANON_KEY',
  ];
  if (missing.isNotEmpty) {
    throw _ConfigException('Missing or empty in .env: ${missing.join(', ')}.');
  }
  return (url: url, anonKey: anonKey);
}
