import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/dashboard_palette.dart';

/// The signed-in person's dashboard colours (one colour family per role;
/// see DashboardPalette).
final dashboardPaletteProvider = Provider<DashboardPalette>(
  (ref) => DashboardPalette.forProfile(ref.watch(currentUserProfileProvider).value),
);

/// True when the device asks for less motion: every animation here then
/// shows its end state straight away.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A dashboard card in the role's colour: a stripe along the top, a faint
/// wash of the colour, a soft coloured shadow, a slide-in when the page
/// opens ([entranceIndex] staggers cards one after another) and a small
/// lift under the mouse.
class DashboardCard extends StatefulWidget {
  const DashboardCard({
    super.key,
    required this.child,
    required this.accent,
    this.entranceIndex = 0,
    this.padding = const EdgeInsets.all(Space.lg),
    this.wash = true,
  });

  final Widget child;
  final Color accent;
  final int entranceIndex;
  final EdgeInsetsGeometry padding;

  /// The faint colour wash behind the content. Off for cards full of form
  /// fields, which read better on plain white.
  final bool wash;

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    final accent = widget.accent;
    final card = AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _hover && !still ? -3 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: _hover ? 0.22 : 0.12),
            blurRadius: _hover ? 22 : 14,
            offset: Offset(0, _hover ? 10 : 6),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.wash
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent.withValues(alpha: 0.07), Colors.white],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.35)]),
                ),
              ),
              Padding(padding: widget.padding, child: widget.child),
            ],
          ),
        ),
      ),
    );
    return Entrance(
      index: widget.entranceIndex,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: card,
      ),
    );
  }
}

/// Fades and slides [child] up into place once, [index] x 70 ms after the
/// page opens, so a dashboard's cards arrive one after another.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: 70 * widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, 16 * (1 - _t.value)), child: child),
      ),
    );
  }
}

/// A whole number that counts up from 0 when it first appears (and to
/// its new value when it changes).
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style});
  final num value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(v.round().toString(), style: style),
    );
  }
}

/// A rounded bar in the role's colour that fills to [value] (0..1).
class AccentBar extends StatelessWidget {
  const AccentBar({super.key, required this.value, required this.accent, this.height = 8});
  final double value;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: accent.withValues(alpha: 0.14),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(colors: [accent.withValues(alpha: 0.75), accent]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title with a short bar of the role's colour before it.
class AccentHeading extends StatelessWidget {
  const AccentHeading(this.title, {super.key, required this.accent, this.subtitle});
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 22,
          margin: const EdgeInsets.only(top: 3, right: Space.sm),
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: text.bodySmall?.copyWith(color: AppColors.charcoalSoft)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
