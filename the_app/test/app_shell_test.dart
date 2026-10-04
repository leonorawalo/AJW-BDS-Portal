import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_app/core/widgets/app_shell.dart';
import 'package:the_app/features/attention/data/attention_repository.dart';
import 'package:the_app/features/attention/models/attention_spots.dart';
import 'package:the_app/features/attention/providers/attention_providers.dart';
import 'package:the_app/features/auth/providers/auth_providers.dart';
import 'package:the_app/features/enterprises/models/enterprise.dart';
import 'package:the_app/features/enterprises/providers/enterprise_providers.dart';
import 'package:the_app/features/tutorial/data/tour_progress_repository.dart';
import 'package:the_app/features/tutorial/providers/tutorial_providers.dart';
import 'package:the_app/shared/models/user_profile.dart';

/// C5: the side-navigation shell must lay out without overflow on a laptop
/// and on a phone, show the role's pages plus the enterprise's sections,
/// collapse on wide screens, and open as a drawer on phones. Red dots show
/// on sections with something new, never on the open one, and opening a
/// section marks it seen.
void main() {
  const admin = UserProfile(
    id: 'u1',
    firstName: 'Gloria',
    lastName: 'Asiba',
    email: 'admin@example.com',
    role: UserRole.administrator,
    status: 'active',
  );
  final blueFarm = Enterprise(
    id: 'e1',
    businessName: 'Blue Farm',
    ownerName: 'Joe Prathik',
    lifecycleStatus: LifecycleStatusX.fromDb('Active'),
    goingConcernStatus: GoingConcernStatusX.fromDb('Not Yet'),
    enrolledAt: DateTime(2026, 8, 1),
  );

  String? selected;
  late _FakeAttention attention;
  setUp(() => attention = _FakeAttention(AttentionSpots.none));

  Widget app() {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => AppShell(
          title: 'Enterprise',
          enterprise: ShellEnterprise(
            id: 'e1',
            name: 'Blue Farm',
            sections: const [
              ShellSection('dashboard', 'Dashboard', Icons.dashboard_outlined),
              ShellSection('tasks', 'Tasks', Icons.task_alt),
              ShellSection('files', 'Google files', Icons.drive_file_move_outline),
            ],
            currentSection: 'dashboard',
            onSelectSection: (key) => selected = key,
            onSwitchEnterprise: (_) {},
          ),
          actions: [IconButton(icon: const Icon(Icons.mail_outline), onPressed: () {})],
          body: const Center(child: Text('BODY')),
        ),
      ),
    ]);
    return ProviderScope(
      overrides: [
        currentUserProfileProvider.overrideWith((ref) async => admin),
        enterprisesListProvider.overrideWith((ref) async => [blueFarm]),
        attentionRepositoryProvider.overrideWithValue(attention),
        attentionProvider.overrideWith((ref) => attention.fetch()),
        // Tours have their own tests (tutorial_test.dart); keep them out of these.
        tourProgressRepositoryProvider.overrideWithValue(_NoTours()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('laptop: permanent menu with role pages + sections, collapses to icons', (tester) async {
    await setSize(tester, const Size(1400, 900));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('BAGS Portal'), findsOneWidget);
    for (final label in ['Enterprises', 'Users', 'Audit log', 'Dashboard', 'Tasks', 'Google files', 'Sign out']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('BLUE FARM'), findsOneWidget);
    expect(find.text('Gloria Asiba'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    expect(selected, 'tasks');

    // Hamburger collapses the menu to icons (labels become tooltips).
    await tester.tap(find.byTooltip('Collapse menu'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks'), findsNothing);
    expect(find.byTooltip('Tasks'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('phone: no permanent menu; hamburger opens the drawer', (tester) async {
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Gloria Asiba'), findsOneWidget);

    await tester.tap(find.text('Google files'));
    await tester.pumpAndSettle();
    expect(selected, 'files');
    expect(find.text('Dashboard'), findsNothing, reason: 'drawer closes after choosing');
  });

  testWidgets('red dots: on sections with news, not the open one; opening marks it seen', (tester) async {
    attention = _FakeAttention(AttentionSpots.fromRows([
      {'enterprise_id': 'e1', 'section': 'tasks'},
      {'enterprise_id': 'e1', 'section': 'dashboard'},
      {'enterprise_id': null, 'section': 'users'},
    ]));
    await setSize(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(attention.seen, ['e1|dashboard'], reason: 'the open section is marked seen');

    Badge badgeOn(String label) => tester.widget<Badge>(
          find.ancestor(of: find.byIcon(_icons[label]!), matching: find.byType(Badge)).first,
        );
    expect(badgeOn('Menu').isLabelVisible, isTrue, reason: 'phone: the hamburger carries the dot');

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(badgeOn('Tasks').isLabelVisible, isTrue);
    expect(badgeOn('Users').isLabelVisible, isTrue);
    expect(badgeOn('Dashboard').isLabelVisible, isFalse, reason: 'the open section never shows a dot');
    expect(badgeOn('Google files').isLabelVisible, isFalse);
  });
}

const _icons = {
  'Menu': Icons.menu,
  'Tasks': Icons.task_alt,
  'Users': Icons.manage_accounts_outlined,
  'Dashboard': Icons.dashboard_outlined,
  'Google files': Icons.drive_file_move_outline,
};

class _FakeAttention implements AttentionRepository {
  _FakeAttention(this.spots);
  final AttentionSpots spots;
  final seen = <String>[];

  @override
  Future<AttentionSpots> fetch() async => spots;

  @override
  Future<void> markSeen({String? enterpriseId, required String section}) async =>
      seen.add('${enterpriseId ?? ''}|$section');
}

class _NoTours implements TourProgressRepository {
  @override
  bool get ready => false;
  @override
  bool get tipsOff => true;
  @override
  bool hasSeen(String tourId) => true;
  @override
  Future<void> markSeen(String tourId) async {}
  @override
  Future<void> setTipsOff(bool off) async {}
}
