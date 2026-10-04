import 'package:flutter/widgets.dart';

/// Marks a spot a guided tour can point at (ids in TourAnchors). Has no
/// effect on layout or behaviour. Every item of a list can share one id:
/// the tour points at the top-most one on screen.
class TourAnchor extends StatefulWidget {
  const TourAnchor({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  /// The on-screen anchor for [id] (the top-most, then left-most, if
  /// several share it), or null if none is showing. Only anchors on the top
  /// route count, so a page under a pushed screen or dialog is never used.
  static BuildContext? find(String id) {
    BuildContext? best;
    Offset? bestAt;
    for (final key in _registry[id] ?? const <GlobalKey>[]) {
      final context = key.currentContext;
      if (context == null || !context.mounted) continue;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty) continue;
      if (ModalRoute.of(context)?.isCurrent == false) continue;
      final at = box.localToGlobal(Offset.zero);
      if (bestAt == null || at.dy < bestAt.dy || (at.dy == bestAt.dy && at.dx < bestAt.dx)) {
        best = context;
        bestAt = at;
      }
    }
    return best;
  }

  static final _registry = <String, List<GlobalKey>>{};

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TourAnchor._registry.putIfAbsent(widget.id, () => []).add(_key);
  }

  @override
  void didUpdateWidget(TourAnchor old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      TourAnchor._registry[old.id]?.remove(_key);
      TourAnchor._registry.putIfAbsent(widget.id, () => []).add(_key);
    }
  }

  @override
  void dispose() {
    TourAnchor._registry[widget.id]?.remove(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}
