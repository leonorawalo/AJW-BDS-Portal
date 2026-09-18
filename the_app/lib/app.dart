import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';

import 'core/theme/app_theme.dart';
import 'features/notifications/providers/notification_providers.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AjwBagsApp extends ConsumerWidget {
  const AjwBagsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Side-effect-only provider (keeps public.device_tokens in sync with
    // sign-in state) — watched here purely to keep it alive for the life
    // of the app.
    ref.watch(notificationSyncProvider);

    ref.listen(foregroundMessagesProvider, (previous, next) {
      final notification = next.value?.notification;
      if (notification == null) return;
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            [
              notification.title,
              notification.body,
            ].whereType<String>().join(': '),
          ),
        ),
      );
    });

    return MaterialApp.router(
      title: 'AJW BAGS Portal',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      // Real theme (deep brand red for primary/logo, semantic red reserved
      // for "Overdue" only) lands with lib/core/theme — placeholder here
      // so Module 1 isn't blocked on the theme system.
      theme: ajwLightTheme,
      routerConfig: router,
    );
  }
}
