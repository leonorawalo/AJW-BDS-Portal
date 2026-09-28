import 'package:flutter/material.dart';

/// Shown instead of the real app when startup config is missing, so a
/// broken setup names its cause on screen rather than leaving a blank page.
/// Deliberately standalone (no theme, router or Supabase) — none of those
/// are available when this runs.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AJW BAGS Portal',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('App configuration error', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    SelectableText(message),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
