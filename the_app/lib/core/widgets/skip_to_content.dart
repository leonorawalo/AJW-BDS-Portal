import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Web keyboard users: the first Tab stop on every page is "Skip to main
/// content" (WCAG 2.1, 2.4.1). It stays invisible until it has focus;
/// pressing it moves focus to the first control in the page's main
/// content, past the top bar and the side menu. Android: no change.
class SkipToContent extends StatefulWidget {
  const SkipToContent({super.key, required this.builder});

  /// Builds the page. Wrap its main content (not the menus) with [main].
  final Widget Function(BuildContext context, Widget Function(Widget child) main) builder;

  @override
  State<SkipToContent> createState() => _SkipToContentState();
}

class _SkipToContentState extends State<SkipToContent> {
  final _main = FocusNode(debugLabel: 'Main content', skipTraversal: true);
  bool _shown = false;

  @override
  void dispose() {
    _main.dispose();
    super.dispose();
  }

  Widget _wrapMain(Widget child) => Focus(
        focusNode: _main,
        child: Semantics(container: true, explicitChildNodes: true, label: 'Main content', child: child),
      );

  void _skip() {
    final targets = ReadingOrderTraversalPolicy()
        .sortDescendants(_main.traversalDescendants.where((n) => n.canRequestFocus && !n.skipTraversal), _main);
    (targets.isEmpty ? _main : targets.first).requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.builder(context, _wrapMain);
    if (!kIsWeb) return page;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
        children: [
          FocusTraversalOrder(order: const NumericFocusOrder(1), child: FocusTraversalGroup(child: page)),
          Positioned(
            left: Space.sm,
            top: Space.sm,
            child: FocusTraversalOrder(
              order: const NumericFocusOrder(0),
              child: Focus(
                skipTraversal: true,
                onFocusChange: (f) => setState(() => _shown = f),
                child: IgnorePointer(
                  ignoring: !_shown,
                  child: Opacity(
                    opacity: _shown ? 1 : 0,
                    child: FilledButton(onPressed: _skip, child: const Text('Skip to main content')),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
