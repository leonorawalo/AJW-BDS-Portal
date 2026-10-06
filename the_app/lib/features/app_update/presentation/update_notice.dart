import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_version.dart';
import '../providers/app_update_providers.dart';

/// Android only: once per app run, if a newer APK has been released, a
/// banner offers it ("Download" opens the portal's download page; "Later"
/// hides it until the next launch). The app isn't in the Play Store, so
/// this is how phones learn about updates. The website never needs it:
/// a reload always loads the newest version.
class UpdateNotice extends ConsumerStatefulWidget {
  const UpdateNotice({super.key, required this.child, this.isAndroid});

  final Widget child;

  /// For tests; null = the real platform.
  final bool? isAndroid;

  @override
  ConsumerState<UpdateNotice> createState() => _UpdateNoticeState();
}

/// AppShell is rebuilt on every page, so check once per app run.
bool _checkedThisRun = false;

@visibleForTesting
void resetUpdateNoticeForTest() => _checkedThisRun = false;

class _UpdateNoticeState extends ConsumerState<UpdateNotice> {
  @override
  void initState() {
    super.initState();
    final android = widget.isAndroid ?? (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
    if (android && !_checkedThisRun) {
      _checkedThisRun = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    final latest = await ref.read(appUpdateRepositoryProvider).latestAndroidRelease();
    if (latest == null || !latest.isNewerThan(appBuildNumber) || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.system_update_outlined),
        content: Text(
          'A new version of the app is available ($appVersionName → ${latest.version}). '
          'Download it and install it over this one; you stay signed in.',
        ),
        actions: [
          TextButton(onPressed: messenger.hideCurrentMaterialBanner, child: const Text('Later')),
          FilledButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
              launchUrl(Uri.parse(latest.downloadUrl), mode: LaunchMode.externalApplication);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
