import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';

class AjwBdsApp extends ConsumerWidget {
  const AjwBdsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AJW BDS Portal',
      debugShowCheckedModeBanner: false,
      // Real theme (deep brand red for primary/logo, semantic red reserved
      // for "Overdue" only) lands with lib/core/theme — placeholder here
      // so Module 1 isn't blocked on the theme system.
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: router,
    );
  }
}
