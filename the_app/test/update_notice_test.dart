import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/app_version.dart';
import 'package:the_app/features/app_update/data/app_update_repository.dart';
import 'package:the_app/features/app_update/models/app_release.dart';
import 'package:the_app/features/app_update/presentation/update_notice.dart';
import 'package:the_app/features/app_update/providers/app_update_providers.dart';

/// Phones learn about a new APK from web/android-latest.json: a banner when
/// it's newer than this build, nothing otherwise, and never on the website.
void main() {
  Widget app(AppRelease? latest, {bool android = true}) => ProviderScope(
        overrides: [appUpdateRepositoryProvider.overrideWithValue(_Fake(latest))],
        child: MaterialApp(
          home: UpdateNotice(isAndroid: android, child: const Scaffold(body: Text('PAGE'))),
        ),
      );
  AppRelease release(int build) => AppRelease(version: '9.9.9', build: build, downloadUrl: 'https://example.com');

  setUp(resetUpdateNoticeForTest);

  testWidgets('a newer release shows the banner', (tester) async {
    await tester.pumpWidget(app(release(appBuildNumber + 1)));
    await tester.pumpAndSettle();
    expect(find.textContaining('A new version of the app is available'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('the same build shows nothing', (tester) async {
    await tester.pumpWidget(app(release(appBuildNumber)));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('not on the website', (tester) async {
    await tester.pumpWidget(app(release(appBuildNumber + 1), android: false));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('an unreadable file shows nothing', (tester) async {
    await tester.pumpWidget(app(null));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsNothing);
  });
}

class _Fake extends AppUpdateRepository {
  _Fake(this.latest);
  final AppRelease? latest;
  @override
  Future<AppRelease?> latestAndroidRelease() async => latest;
}
