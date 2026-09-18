import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    await dotenv.load(fileName: '.env');
  }

  // Web needs an explicit FirebaseOptions (no google-services.json
  // equivalent exists for browsers) — no Firebase Web app is registered
  // yet, and push notifications aren't in scope for the web/Admin-desktop
  // target, so skip init there rather than crash on boot.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }

  await Supabase.initialize(
    url: supabaseUrl.isNotEmpty ? supabaseUrl : dotenv.env['SUPABASE_URL']!,
    publishableKey: supabaseAnonKey.isNotEmpty ? supabaseAnonKey : dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const ProviderScope(child: AjwBagsApp()));
}
