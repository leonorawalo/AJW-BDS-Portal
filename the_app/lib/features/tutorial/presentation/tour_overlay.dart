import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../models/tour.dart';
import 'tour_anchor.dart';

enum TourResult {
  /// Went through to the end.
  finished,

  /// Closed with Skip (or Esc).
  skipped,

  /// Chose "Don't show tips" on the first bubble.
  tipsTurnedOff,

  /// Chose "Turn tips back on" (only offered when tips are off).
  tipsTurnedOn,

  /// None of the tour's spots were on screen, so nothing was shown.
  nothingShown,
}

/// Shows [tour] over the whole app: the screen dims, a spotlight circles
/// each step's spot, and a bubble explains it. Steps whose spots aren't on
/// screen are left out. Skip is always there.
Future<TourResult> showTour(BuildContext context, Tour tour, {required bool tipsOff}) async {
  final steps = [
    for (final s in tour.steps)
      if (s.centred || s.anchors.any((a) => TourAnchor.find(a) != null)) s,
  ];
  if (steps.isEmpty) return TourResult.nothingShown;

  final done = Completer<TourResult>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TourView(
      steps: steps,
      tipsOff: tipsOff,
      onDone: (result) {
        entry.remove();
        if (!done.isCompleted) done.complete(result);
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return done.future;
}

class _TourView extends StatefulWidget {
  const _TourView({required this.steps, required this.tipsOff, required this.onDone});

  final List<TourStep> steps;
  final bool tipsOff;
  final void Function(TourResult) onDone;

  @override
  State<_TourView> createState() => _TourViewState();
}

class _TourViewState extends State<_TourView> {
  int _index = 0;
  final _focus = FocusNode();

  TourStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    _go(0);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The current step's spot, in screen coordinates (null = centred).
  Rect? _targetRect() {
    for (final id in _step.anchors) {
      final context = TourAnchor.find(id);
      final box = context?.findRenderObject();
      if (box is RenderBox && box.hasSize) return box.localToGlobal(Offset.zero) & box.size;
    }
    return null;
  }

  Future<void> _go(int index) async {
    setState(() => _index = index);
    // Bring the spot into view first (e.g. Business facts lower down).
    for (final id in _step.anchors) {
      final context = TourAnchor.find(id);
      if (context == null) continue;
      await Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      break;
    }
    if (mounted) setState(() {});
    _focus.requestFocus();
  }

  void _next() => _index == widget.steps.length - 1 ? widget.onDone(TourResult.finished) : _go(_index + 1);
  void _back() => _index > 0 ? _go(_index - 1) : null;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final target = _step.centred ? null : _targetRect()?.inflate(6);

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.escape) {
          widget.onDone(TourResult.skipped);
        } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.enter) {
          _next();
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          _back();
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Dim everything; taps outside the bubble do nothing, so the app
            // can't be changed mid-tour by accident.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: target == null
                    ? const CustomPaint(painter: _ScrimPainter(null))
                    : TweenAnimationBuilder<Rect?>(
                        tween: RectTween(end: target),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        builder: (_, rect, _) => CustomPaint(painter: _ScrimPainter(rect)),
                      ),
              ),
            ),
            CustomSingleChildLayout(
              delegate: _BubbleLayout(target: target, screen: screen),
              child: _Bubble(
                key: ValueKey(_index),
                step: _step,
                index: _index,
                count: widget.steps.length,
                tipsOff: widget.tipsOff,
                onNext: _next,
                onBack: _index > 0 ? _back : null,
                onSkip: () => widget.onDone(TourResult.skipped),
                onTipsToggle: () =>
                    widget.onDone(widget.tipsOff ? TourResult.tipsTurnedOn : TourResult.tipsTurnedOff),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dim layer with a rounded hole over the spot.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final h = hole;
    if (h == null) {
      canvas.drawRect(Offset.zero & size, dim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(h, const Radius.circular(Radii.md));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(rrect)),
      dim,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

/// Puts the bubble below the spot if it fits, otherwise above, clamped
/// inside the screen; centred when there's no spot.
class _BubbleLayout extends SingleChildLayoutDelegate {
  const _BubbleLayout({required this.target, required this.screen});

  final Rect? target;
  final Size screen;

  static const _margin = 16.0;
  static const _gap = 12.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
        maxWidth: (constraints.maxWidth - 2 * _margin).clamp(0, 360),
        maxHeight: constraints.maxHeight - 2 * _margin,
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final t = target;
    if (t == null) return Offset((size.width - child.width) / 2, (size.height - child.height) / 2);

    final left = (t.center.dx - child.width / 2).clamp(_margin, size.width - child.width - _margin);
    final below = t.bottom + _gap;
    final above = t.top - _gap - child.height;
    final double top;
    if (below + child.height <= size.height - _margin) {
      top = below;
    } else if (above >= _margin) {
      top = above;
    } else {
      // A tall spot (e.g. the side menu): sit beside it if there's room,
      // else at the bottom of the screen.
      final right = t.right + _gap;
      if (right + child.width <= size.width - _margin) {
        return Offset(right, (t.top).clamp(_margin, size.height - child.height - _margin));
      }
      top = size.height - child.height - _margin;
    }
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_BubbleLayout old) => old.target != target || old.screen != screen;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.step,
    required this.index,
    required this.count,
    required this.tipsOff,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.onTipsToggle,
  });

  final TourStep step;
  final int index;
  final int count;
  final bool tipsOff;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final VoidCallback onTipsToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = index == count - 1;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      builder: (_, t, child) => Opacity(opacity: t, child: child),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Tip ${index + 1} of $count',
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.sm, Space.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: Text(step.title, style: text.titleMedium),
                ),
                const SizedBox(height: Space.sm),
                Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: Text(step.body, style: text.bodyMedium?.copyWith(height: 1.45)),
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        count > 1 ? '${index + 1} of $count' : '',
                        style: text.bodySmall?.copyWith(color: AppColors.charcoalSoft),
                      ),
                    ),
                    if (!last) TextButton(onPressed: onSkip, child: const Text('Skip')),
                    if (onBack != null) TextButton(onPressed: onBack, child: const Text('Back')),
                    const SizedBox(width: Space.xs),
                    FilledButton(onPressed: onNext, child: Text(last ? 'Done' : 'Next')),
                  ],
                ),
                if (index == 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.charcoalSoft,
                        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onTipsToggle,
                      child: Text(tipsOff ? 'Turn tips back on' : "Don't show tips"),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
