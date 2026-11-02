import 'package:supabase_flutter/supabase_flutter.dart';

/// What to show a person when something fails: our own sentences, never a
/// raw exception (no SQL, table names or stack traces). Rule:
/// docs/security/SECURITY.md, "Error messages".
String userMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  final e = error;
  if (e is PostgrestException) {
    // Row level security refusing a write names the table: say it plainly.
    if (e.message.contains('row-level security')) return "You don't have permission to do that.";
    // Raised on purpose by the database's own rules, worded for people.
    if (const {'42501', '23514', 'P0001', 'P0002'}.contains(e.code)) return e.message;
    if (e.code == '23505') return 'That already exists.';
    return fallback;
  }
  if (e is AuthException) return e.message;
  if (e is FunctionException) {
    final details = e.details;
    if (details is Map && details['error'] is String) return details['error'] as String;
    return fallback;
  }
  // The app's own exceptions (Exception('A sentence.')).
  final text = e.toString();
  if (e is Exception && text.startsWith('Exception: ')) return text.substring('Exception: '.length);
  return fallback;
}
