import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_app/core/widgets/app_shell.dart';
import 'package:the_app/features/attention/data/attention_repository.dart';
import 'package:the_app/features/attention/models/attention_spots.dart';
import 'package:the_app/features/attention/providers/attention_providers.dart';
import 'package:the_app/features/enterprises/providers/enterprise_providers.dart';
import 'package:the_app/features/auth/providers/auth_providers.dart';
import 'package:the_app/features/tutorial/data/tour_progress_repository.dart';
import 'package:the_app/features/tutorial/models/tour_catalog.dart';
import 'package:the_app/features/tutorial/presentation/tour_anchor.dart';
import 'package:the_app/features/tutorial/presentation/tour_host.dart';
import 'package:the_app/features/tutorial/providers/tutorial_providers.dart';
import 'package:the_app/shared/models/user_profile.dart';

/// Guided tours: every bubble follows the writing rules and points at a
/// spot that exists in the app; tours show once per account, skip any
/// spot that isn't on screen, and can always be skipped or turned off.
void main() {
  const places = [
    'welcome', 'enterprise', 'enterprises', 'programme', 'workshops', 'users', 'audit', 'portfolio',
    'section.dashboard', 'section.tasks', 'section.visits', 'section.recommendations',
    'section.documents', 'section.files', 'section.sessions', 'section.details', 'task', 'assign',
  ];

  group('catalog', () {
    final tours = [
      for (final role in UserRole.values)
        for (final place in places) ?tourFor(role, place),
    ];

    test('every role has a welcome tour and tours for its main pages', () {
      for (final role in UserRole.values) {
        expect(tourFor(role, 'welcome'), isNotNull, reason: '$role welcome');
        expect(tourFor(role, 'section.tasks'), isNotNull, reason: '$role tasks');
        expect(tourFor(role, 'task'), isNotNull, reason: '$role task detail');
      }
      expect(tours.length, greaterThan(35));
    });

    test('bubbles: short title, 2-3 short sentences', () {
      for (final tour in tours) {
        for (final step in tour.steps) {
          final where = '${tour.id}: ${step.title}';
          expect(step.title.split(' ').length, lessThanOrEqualTo(5), reason: where);
          final sentences = RegExp(r'[.!?](\s|$)').allMatches(step.body).length;
          expect(sentences, inInclusiveRange(2, 3), reason: where);
          expect(step.body.split(' ').length, lessThanOrEqualTo(35), reason: where);
        }
      }
    });

    test('every spot a bubble points at is marked somewhere in the app', () {
      final catalog = File('lib/features/tutorial/models/tour_catalog.dart').readAsStringSync();
      final nameOf = {
        for (final m in RegExp(r"static const (\w+) = '([\w.]+)';").allMatches(catalog)) m.group(2)!: m.group(1)!,
      };
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('tour_catalog.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      for (final tour in tours) {
        for (final step in tour.steps) {
          for (final id in step.anchors) {
            // Menu items are marked by the shell from their keys.
            if (id.startsWith('menu.') || id.startsWith('section.')) continue;
            final name = nameOf[id];
            expect(name, isNotNull, reason: '${tour.id}: "$id" is not a TourAnchors constant');
            expect(source, contains('TourAnchors.$name'), reason: '${tour.id}: nothing marks "$id"');
          }
        }
      }
    });
  });

  group('tour host', () {
    const admin = UserProfile(
      id: 'u1',
      firstName: 'Gloria',
      lastName: 'Asiba',
      email: 'admin@example.com',
      role: UserRole.administrator,
      status: 'active',
    );
    late _FakeProgress progress;
    setUp(() => progress = _FakeProgress());

    // The Audit log page: its tour points at the filters. The welcome
    // tour's menu/badge spots aren't on this test page, so only its
    // centred first bubble shows.
    Widget page({bool withFilters = true}) => ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) async => admin),
            tourProgressRepositoryProvider.overrideWithValue(progress),
          ],
          child: MaterialApp(
            home: TourHost(
              place: 'audit',
              child: Scaffold(
                body: Center(
                  child: withFilters
                      ? const TourAnchor(id: TourAnchors.auditFilters, child: SizedBox(width: 200, height: 40))
                      : const SizedBox(),
                ),
              ),
            ),
          ),
        );

    Future<void> settle(WidgetTester tester) async {
      // Long enough for a tour whose spots never appear to give up (4 s).
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
    }

    testWidgets('first visit: welcome, then the page tour; each saved as seen', (tester) async {
      await tester.pumpWidget(page());
      await settle(tester);

      expect(find.text('Welcome to the BAGS Portal'), findsOneWidget);
      expect(find.text('Skip'), findsNothing, reason: 'one-bubble tour: Done is the way out');
      expect(find.text("Don't show tips"), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(find.text('Filter the log'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(progress.seen, {'admin.welcome', 'admin.audit'});
      expect(find.text('Filter the log'), findsNothing);

      // Coming back: nothing again.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await settle(tester);
      expect(find.text('Filter the log'), findsNothing);
      expect(find.text('Welcome to the BAGS Portal'), findsNothing);
    });

    testWidgets("\"Don't show tips\" stops the automatic tours", (tester) async {
      await tester.pumpWidget(page());
      await settle(tester);
      await tester.tap(find.text("Don't show tips"));
      await settle(tester);

      expect(progress.tipsOff, isTrue);
      expect(find.text('Filter the log'), findsNothing);
    });

    testWidgets('Esc skips; a skipped tour counts as seen', (tester) async {
      progress.seen.add('admin.welcome');
      await tester.pumpWidget(page());
      await settle(tester);
      expect(find.text('Filter the log'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Filter the log'), findsNothing);
      expect(progress.seen, contains('admin.audit'));
    });

    testWidgets("a spot that isn't on screen is left out, and the tour isn't used up", (tester) async {
      progress.seen.add('admin.welcome');
      await tester.pumpWidget(page(withFilters: false));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('Filter the log'), findsNothing);
      expect(progress.seen, isNot(contains('admin.audit')));
    });

    testWidgets('never before the password is set', (tester) async {
      progress.ready = false;
      await tester.pumpWidget(page());
      await settle(tester);
      expect(find.text('Welcome to the BAGS Portal'), findsNothing);
    });
  });

  group('in the real shell', () {
    const consultant = UserProfile(
      id: 'u2',
      firstName: 'Amina',
      lastName: 'Otieno',
      email: 'consultant@example.com',
      role: UserRole.consultant,
      status: 'active',
      specialization: ConsultantSpecialization.accounting,
    );

    Widget shell(_FakeProgress progress) => ProviderScope(
          overrides: [
            currentUserProfileProvider.overrideWith((ref) async => consultant),
            tourProgressRepositoryProvider.overrideWithValue(progress),
            enterprisesListProvider.overrideWith((ref) async => []),
            attentionProvider.overrideWith((ref) async => AttentionSpots.none),
            attentionRepositoryProvider.overrideWithValue(_NoDots()),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => AppShell(
                  title: 'Blue Farm',
                  enterprise: ShellEnterprise(
                    id: 'e1',
                    name: 'Blue Farm',
                    sections: const [ShellSection('dashboard', 'Dashboard', Icons.dashboard_outlined)],
                    currentSection: 'dashboard',
                    onSelectSection: (_) {},
                    onSwitchEnterprise: (_) {},
                  ),
                  body: const SizedBox(),
                ),
              ),
            ]),
          ),
        );

    for (final (name, size) in [('phone', Size(360, 740)), ('laptop', Size(1366, 768))]) {
      testWidgets('$name: welcome and enterprise tours lay out and step through cleanly', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final progress = _FakeProgress();

        await tester.pumpWidget(shell(progress));
        var bubbles = 0;
        for (var i = 0; i < 80 && progress.seen.length < 2; i++) {
          await tester.pump(const Duration(milliseconds: 300));
          final next = find.text('Next');
          final done = find.text('Done');
          if (next.evaluate().isNotEmpty || done.evaluate().isNotEmpty) {
            bubbles++;
            expect(find.text('Skip').evaluate().isNotEmpty || done.evaluate().isNotEmpty, isTrue,
                reason: 'every bubble can be left');
            await tester.tap(next.evaluate().isNotEmpty ? next : done);
          }
        }
        // Let the dashboard tour (its spots aren't on this test page) give up.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(tester.takeException(), isNull);
        expect(progress.seen, {'consultant.welcome', 'consultant.enterprise'});
        // Welcome: laptop points at the menu, badge, dots and help (5); a
        // phone points at the hamburger and leaves out the badge (4). Plus
        // the enterprise switcher (this test page has no email/export).
        expect(bubbles, name == 'laptop' ? 6 : 5);
      });
    }
  });
}

class _FakeProgress implements TourProgressRepository {
  @override
  bool ready = true;
  @override
  bool tipsOff = false;
  final seen = <String>{};

  @override
  bool hasSeen(String tourId) => seen.contains(tourId);

  @override
  Future<void> markSeen(String tourId) async => seen.add(tourId);

  @override
  Future<void> setTipsOff(bool off) async => tipsOff = off;
}

class _NoDots implements AttentionRepository {
  @override
  Future<AttentionSpots> fetch() async => AttentionSpots.none;
  @override
  Future<void> markSeen({String? enterpriseId, required String section}) async {}
}
