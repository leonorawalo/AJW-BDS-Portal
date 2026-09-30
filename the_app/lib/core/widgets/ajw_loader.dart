import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's loading indicator: three softly pulsing dots in brand colours
/// (red, charcoal, red), matching the web loading screen. Calmer than a
/// spinning ring.
class AjwLoader extends StatefulWidget {
  const AjwLoader({super.key, this.dotSize = 9, this.color, this.semanticsLabel = 'Loading'});

  final double dotSize;

  /// One colour for all three dots, e.g. white inside a filled button.
  final Color? color;
  final String semanticsLabel;

  @override
  State<AjwLoader> createState() => _AjwLoaderState();
}

class _AjwLoaderState extends State<AjwLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  static const _colors = [AppColors.brandRed, AppColors.charcoal, AppColors.brandRed];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0..1..0 pulse for dot [i], each a fifth of a cycle behind the last.
  double _pulse(int i) {
    final t = (_controller.value - i * 0.14) % 1.0;
    if (t > 0.8) return 0;
    return Curves.easeInOut.transform(1 - ((t - 0.4).abs() / 0.4));
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: widget.semanticsLabel,
      liveRegion: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.4),
                child: Builder(
                  builder: (context) {
                    final p = reduceMotion ? 0.6 : _pulse(i);
                    return Transform.scale(
                      scale: 0.8 + 0.2 * p,
                      child: Container(
                        width: widget.dotSize,
                        height: widget.dotSize,
                        decoration: BoxDecoration(
                          color: (widget.color ?? _colors[i]).withValues(alpha: 0.28 + 0.72 * p),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Centred [AjwLoader] for a whole screen or panel that's loading.
class AjwLoadingView extends StatelessWidget {
  const AjwLoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(24), child: AjwLoader()),
  );
}
