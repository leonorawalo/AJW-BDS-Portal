import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:the_app/core/widgets/app_shell.dart';
import 'package:the_app/features/auth/providers/auth_providers.dart';
import 'package:the_app/features/enterprises/models/enterprise.dart';
import 'package:the_app/features/enterprises/providers/enterprise_providers.dart';
import 'package:the_app/shared/models/user_profile.dart';

/// C5: the side-navigation shell must lay out without overflow on a laptop
/// and on a phone, show the role's pages plus the enterprise's sections,
/// collapse on wide screens, and open as a drawer on phones.
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
    expect(find.text('AJW BAGS Portal'), findsOneWidget);
    for (final label in ['Enterprises', 'Users', 'Audit log', 'Dashboard', 'Tasks', 'Google files', 'Sign out']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('BLUE FARM'), findsOneWidget);
    expect(find.text('Gloria Asiba · Administrator'), findsOneWidget);

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
    expect(find.text('Gloria Asiba · Administrator'), findsOneWidget);

    await tester.tap(find.text('Google files'));
    await tester.pumpAndSettle();
    expect(selected, 'files');
    expect(find.text('Dashboard'), findsNothing, reason: 'drawer closes after choosing');
  });
}
