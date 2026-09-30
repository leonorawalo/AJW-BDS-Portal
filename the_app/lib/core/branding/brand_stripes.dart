import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The guideline's brand stripes ("Applying the brand stripes", p.6): a
/// wide AJW-red band and a charcoal wedge, both on the ~17 degree slant
/// used across AJW's title pages. [reveal] 0..1 sweeps them in from the
/// left.
class BrandStripes extends StatelessWidget {
  const BrandStripes({
    super.key,
    this.redWidth = 0.62,
    this.charcoalFrom = 0.64,
    this.showGreyBand = false,
    this.reveal,
    this.child,
  });

  /// Where the red band's top edge ends, as a fraction of the width.
  final double redWidth;

  /// Where the charcoal wedge starts on the left edge, as a fraction of
  /// the height.
  final double charcoalFrom;

  /// The light-grey band on the far right, as on some title slides.
  final bool showGreyBand;
  final Animation<double>? reveal;
  final Widget? child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _StripesPainter(redWidth, charcoalFrom, showGreyBand, reveal), child: child);
}

class _StripesPainter extends CustomPainter {
  _StripesPainter(this.redWidth, this.charcoalFrom, this.showGreyBand, this.reveal) : super(repaint: reveal);

  final double redWidth;
  final double charcoalFrom;
  final bool showGreyBand;
  final Animation<double>? reveal;

  /// Horizontal run per unit of height (from the brand stroke artwork).
  static const slope = 0.305;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = reveal == null ? 1.0 : Curves.easeOutCubic.transform(reveal!.value);
    if (t <= 0) return;

    double shift(double delayed) {
      final local = ((t - delayed) / (1 - delayed)).clamp(0.0, 1.0);
      return -(1 - Curves.easeOutCubic.transform(local)) * (w * redWidth + h * slope);
    }

    // Never let the slanted edge run past the right side, where it would be
    // cut off vertically.
    final redTop = (w * redWidth).clamp(0.0, w - h * slope);
    final red = Path()
      ..moveTo(0, 0)
      ..lineTo(redTop, 0)
      ..lineTo(redTop + h * slope, h)
      ..lineTo(0, h)
      ..close();
    canvas.save();
    canvas.translate(shift(0), 0);
    canvas.drawPath(red, Paint()..color = AppColors.brandRed);
    canvas.restore();

    final charTop = h * charcoalFrom;
    final charcoal = Path()
      ..moveTo(0, charTop)
      ..lineTo((h - charTop) * slope, h)
      ..lineTo(0, h)
      ..close();
    canvas.save();
    canvas.translate(shift(0.15), 0);
    canvas.drawPath(charcoal, Paint()..color = AppColors.charcoal);
    canvas.restore();

    if (showGreyBand) {
      final greyTop = w * 0.86;
      final grey = Path()
        ..moveTo(greyTop, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(greyTop + h * slope, h)
        ..close();
      canvas.drawPath(grey, Paint()..color = AppColors.lightGray.withValues(alpha: t));
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) =>
      old.redWidth != redWidth ||
      old.charcoalFrom != charcoalFrom ||
      old.showGreyBand != showGreyBand ||
      old.reveal != reveal;
}
