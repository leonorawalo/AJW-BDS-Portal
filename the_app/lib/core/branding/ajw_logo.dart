import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

part 'ajw_logo_paths.dart';

enum _PieceRole { map, letter, accent }

enum _PieceGroup { a, j, w, map }

class _LogoPiece {
  _LogoPiece(this.role, this.group, this.path) : center = path.getBounds().center;
  final _PieceRole role;
  final _PieceGroup group;
  final Path path;
  final Offset center;
}

final List<_LogoPiece> _pieces = _buildPieces();

/// Which colours the mark uses, per the guideline's "Applying the logo to
/// different backgrounds" (p.7).
class AjwLogoColors {
  const AjwLogoColors({required this.map, required this.letters, required this.accent});

  /// White and light backgrounds.
  static const standard = AjwLogoColors(
    map: AppColors.lightGray,
    letters: AppColors.charcoal,
    accent: AppColors.brandRed,
  );

  /// Charcoal or photo backgrounds.
  static const onDark = AjwLogoColors(map: Colors.white, letters: AppColors.lightGray, accent: AppColors.brandRed);

  /// The 10%-opacity grayscale watermark (p.5).
  static const watermark = AjwLogoColors(
    map: AppColors.charcoal,
    letters: AppColors.charcoal,
    accent: AppColors.charcoal,
  );

  final Color map;
  final Color letters;
  final Color accent;
}

/// The AJW mark (Africa + A J W) drawn from the brand vector artwork, so
/// it's sharp at any size. Pass [progress] to animate it assembling
/// ("connecting the dots"); leave it null for the finished mark.
class AjwLogo extends StatelessWidget {
  const AjwLogo({
    super.key,
    this.height = 64,
    this.colors = AjwLogoColors.standard,
    this.opacity = 1,
    this.progress,
    this.semanticLabel = 'AJW Africa',
  });

  final double height;
  final AjwLogoColors colors;
  final double opacity;
  final Animation<double>? progress;
  final String semanticLabel;

  static const aspectRatio = 230.8 / 254.1;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: SizedBox(
        height: height,
        width: height * aspectRatio,
        child: CustomPaint(
          painter: _AjwLogoPainter(colors: colors, opacity: opacity, progress: progress),
        ),
      ),
    );
  }
}

class _AjwLogoPainter extends CustomPainter {
  _AjwLogoPainter({required this.colors, required this.opacity, this.progress}) : super(repaint: progress);

  final AjwLogoColors colors;
  final double opacity;
  final Animation<double>? progress;

  static final _mapOrder = () {
    // Map fragments connect in order around the continent, top-left first.
    final map = _pieces.where((p) => p.role == _PieceRole.map).toList();
    const c = Offset(115, 127);
    map.sort((a, b) => (a.center - c).direction.compareTo((b.center - c).direction));
    return {for (var i = 0; i < map.length; i++) map[i]: i};
  }();

  /// Per-piece 0..1 for an overall progress [t].
  double _pieceT(_LogoPiece p, double t) {
    final double start;
    final double length;
    switch (p.role) {
      case _PieceRole.map:
        start = 0.0 + _mapOrder[p]! * 0.045;
        length = 0.42;
      case _PieceRole.letter:
        start = 0.34 + p.group.index * 0.08;
        length = 0.36;
      case _PieceRole.accent:
        start = 0.62 + p.group.index * 0.06;
        length = 0.3;
    }
    return ((t - start) / length).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress?.value ?? 1.0;
    final scale = size.height / _logoSize.height;
    canvas.save();
    canvas.scale(scale);
    for (final piece in _pieces) {
      final pt = _pieceT(piece, t);
      if (pt <= 0) continue;
      final color = switch (piece.role) {
        _PieceRole.map => colors.map,
        _PieceRole.letter => colors.letters,
        _PieceRole.accent => colors.accent,
      };
      final paint = Paint()
        ..isAntiAlias = true
        ..color = color.withValues(alpha: color.a * opacity * Curves.easeOut.transform(pt));
      if (pt >= 1) {
        canvas.drawPath(piece.path, paint);
        continue;
      }
      final e = Curves.easeOutCubic.transform(pt);
      canvas.save();
      switch (piece.role) {
        case _PieceRole.map:
          // Drift in from outside the continent and settle into place.
          final away = piece.center - const Offset(115, 127);
          final dir = away.distance == 0 ? Offset.zero : away / away.distance;
          final offset = dir * 46 * (1 - e);
          canvas.translate(piece.center.dx + offset.dx, piece.center.dy + offset.dy);
          canvas.rotate((1 - e) * (_mapOrder[piece]!.isEven ? 0.35 : -0.35));
          canvas.translate(-piece.center.dx, -piece.center.dy);
        case _PieceRole.letter:
          canvas.translate(0, 28 * (1 - e));
        case _PieceRole.accent:
          // Along the brand-stripe slant (~17 degrees), from below right.
          final d = 34 * (1 - Curves.easeOutBack.transform(pt));
          canvas.translate(d * math.sin(0.3), d);
      }
      canvas.drawPath(piece.path, paint);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AjwLogoPainter old) => old.colors != colors || old.opacity != opacity || old.progress != progress;
}

/// The guideline's grayscale logo watermark at 10% opacity (p.5), for
/// large empty areas and headers. Decorative, so hidden from screen
/// readers.
class AjwWatermark extends StatelessWidget {
  const AjwWatermark({super.key, this.height = 240, this.opacity = 0.06});
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AjwLogo(height: height, colors: AjwLogoColors.watermark, opacity: opacity),
  );
}
