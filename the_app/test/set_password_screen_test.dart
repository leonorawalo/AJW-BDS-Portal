import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:the_app/features/auth/data/auth_repository.dart';
import 'package:the_app/features/auth/presentation/set_password_screen.dart';
import 'package:the_app/features/auth/providers/auth_providers.dart';

/// Reset and invite links (bug, 6 Oct): the password form must only ever
/// be offered for the link's own account. Before, someone already signed
/// in on the device got the form for THEIR account (and Supabase asked for
/// a current password), and a failed link still showed the form.
void main() {
  final someone = User(id: 'u-old', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '');

  Widget app(_FakeAuth auth, {String? token, String type = 'recovery'}) {
    final router = GoRouter(
      initialLocation: Uri(path: '/set-password', queryParameters: {'token_hash': ?token, 'type': type}).toString(),
      routes: [
        GoRoute(
          path: '/set-password',
          builder: (_, s) => SetPasswordScreen(
            tokenHash: s.uri.queryParameters['token_hash'],
            type: s.uri.queryParameters['type'],
          ),
        ),
        GoRoute(path: '/forgot-password', builder: (_, _) => const Text('FORGOT')),
        GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
      ],
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        authStateChangesProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('signed in, no link, not flagged: no form', (tester) async {
    await tester.pumpWidget(app(_FakeAuth(user: someone)));
    await tester.pumpAndSettle();
    expect(find.text('Save password'), findsNothing);
  });

  testWidgets('expired link while someone is signed in: error, new-link button, no form', (tester) async {
    final auth = _FakeAuth(user: someone, fail: true);
    await tester.pumpWidget(app(auth, token: 'used-token'));
    await tester.pumpAndSettle();
    expect(auth.exchangeCalls, 1, reason: 'the link is always tried, even with someone signed in');
    expect(find.textContaining('expired or was already used'), findsOneWidget);
    expect(find.text('Save password'), findsNothing);
    await tester.ensureVisible(find.text('Request a new reset link'));
    await tester.tap(find.text('Request a new reset link'));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);
    expect(find.text('FORGOT'), findsOneWidget);
  });

  testWidgets('a good link: the form appears for that account', (tester) async {
    final auth = _FakeAuth(user: someone);
    await tester.pumpWidget(app(auth, token: 'fresh-token'));
    await tester.pumpAndSettle();
    expect(auth.exchangeCalls, 1);
    expect(find.text('Save password'), findsOneWidget);
  });
}

class _FakeAuth implements AuthRepository {
  _FakeAuth({this.user, this.fail = false});

  User? user;
  final bool fail;
  int exchangeCalls = 0;
  bool signedOut = false;
  bool _flagged = false;
  final _exchanged = <String>{};

  @override
  User? get currentUser => user;

  @override
  bool get needsPassword => _flagged;

  @override
  bool tokenExchanged(String tokenHash) => _exchanged.contains(tokenHash);

  @override
  Future<void> verifyInviteToken({required String tokenHash, required String type}) async {
    exchangeCalls++;
    if (fail) throw const AuthException('Email link is invalid or has expired', code: 'otp_expired');
    user = User(id: 'u-link', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '');
    _flagged = true;
    _exchanged.add(tokenHash);
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    user = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
