import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/features/auth/presentation/password_field.dart';

/// The app's password rules must match Supabase's (min 8; lowercase,
/// uppercase, digits and symbols from Supabase's symbol set).
void main() {
  bool met(String rule, String p) => PasswordRules.rules.firstWhere((r) => r.$1.startsWith(rule)).$2(p);

  test('each rule on its own', () {
    expect(met('At least 8', 'Abc1!xy'), isFalse);
    expect(met('At least 8', 'Abc1!xyz'), isTrue);
    expect(met('An uppercase', 'abc'), isFalse);
    expect(met('An uppercase', 'aBc'), isTrue);
    expect(met('A lowercase', 'ABC'), isFalse);
    expect(met('A lowercase', 'ABc'), isTrue);
    expect(met('A number', 'Abc'), isFalse);
    expect(met('A number', 'Ab3'), isTrue);
    expect(met('A special', 'Abc123'), isFalse);
    expect(met('A special', 'Abc123?'), isTrue);
  });

  test('symbols follow Supabase: a space or a non-ASCII sign does not count', () {
    expect(met('A special', 'Abc 123'), isFalse);
    expect(met('A special', 'Abc£123'), isFalse);
    for (final s in r'''!@#$%^&*()_+-=[]{};'\:"|<>?,./`~'''.split('')) {
      expect(met('A special', 'a$s'), isTrue, reason: 'symbol $s');
    }
  });

  test('allMet', () {
    expect(PasswordRules.allMet('Bags2026!'), isTrue);
    expect(PasswordRules.allMet('bags2026!'), isFalse);
    expect(PasswordRules.allMet('Bags2026'), isFalse);
    expect(PasswordRules.allMet(''), isFalse);
  });
}
