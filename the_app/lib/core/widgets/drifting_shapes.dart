import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft translucent circles and rings drifting slowly in a banner's
/// corners. Purely decorative: ignored by screen readers, painted behind
/// the content, and still (no animation) when the device asks for reduced
/// motion. One controller and one painter, so it stays light on phones.
class DriftingShapes extends StatefulWidget {
  const DriftingShapes({super.key, required this.colors});
  final List<Color> colors;

  @override
  State<DriftingShapes> createState() => _DriftingShapesState();
}

class _DriftingShapesState extends State<DriftingShapes> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _ShapesPainter(_controller, widget.colors),
            size: Size.infinite,
          ),
        ),
      );
}

class _ShapesPainter extends CustomPainter {
  _ShapesPainter(this.t, this.colors) : super(repaint: t);
  final Animation<double> t;
  final List<Color> colors;

  // (corner x, corner y, radius as a share of height, ring?, phase)
  static const _shapes = [
    (1.0, 0.0, 0.9, false, 0.0),
    (0.92, 1.0, 0.45, true, 0.3),
    (0.0, 1.0, 0.6, false, 0.55),
    (0.08, 0.0, 0.3, true, 0.8),
    (0.75, 0.15, 0.18, false, 0.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final angle = t.value * 2 * math.pi;
    for (var i = 0; i < _shapes.length; i++) {
      final (cx, cy, r, ring, phase) = _shapes[i];
      final a = angle + phase * 2 * math.pi;
      final radius = size.height * r;
      final centre = Offset(
        size.width * cx + math.cos(a) * size.height * 0.08,
        size.height * cy + math.sin(a) * size.height * 0.08,
      );
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: ring ? 0.28 : 0.14)
        ..style = ring ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 6;
      canvas.drawCircle(centre, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ShapesPainter old) => old.colors != colors;
}
