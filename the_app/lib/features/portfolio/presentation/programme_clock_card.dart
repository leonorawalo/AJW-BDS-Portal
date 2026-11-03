import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dashboard_card.dart';
import '../../enterprises/models/enterprise.dart';
import '../models/programme_clock.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The enterprise's place on the programme timeline: month N of 12, with
/// the ToR milestones (going concern by month 3, bankable by month 6) as
/// steps on a track.
class ProgrammeClockCard extends ConsumerWidget {
  const ProgrammeClockCard({super.key, required this.enterprise});
  final Enterprise enterprise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final palette = ref.watch(dashboardPaletteProvider);
    final accent = palette.accent;
    final c = ProgrammeClock(enterprise);
    final progress = (c.month - 1 + (c.now.day / 31)).clamp(0, ProgrammeClock.incubationMonths) / ProgrammeClock.incubationMonths;

    return DashboardCard(
      accent: accent,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Programme', style: text.titleSmall?.copyWith(color: AppColors.charcoalSoft)),
                      const SizedBox(height: 2),
                      Text(
                        'Month ${c.month} of ${ProgrammeClock.incubationMonths}',
                        style: text.headlineMedium?.copyWith(color: palette.deep),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.isOverdue ? const Color(0xFFFDECEA) : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    c.headline,
                    style: text.labelMedium?.copyWith(color: c.isOverdue ? AppColors.errorRed : palette.deep),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            LayoutBuilder(
              builder: (context, box) {
                double x(int month) => box.maxWidth * month / ProgrammeClock.incubationMonths;
                return SizedBox(
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 8,
                        child: AccentBar(value: progress.toDouble(), accent: accent),
                      ),
                      _Dot(left: x(ProgrammeClock.goingConcernMonths), done: c.goingConcernAchieved, accent: accent),
                      _Dot(left: x(ProgrammeClock.bankableMonths), done: c.bankableAchieved, accent: accent),
                      // "You are here": a softly pulsing marker at today.
                      Positioned(
                        left: box.maxWidth * progress.toDouble() - 7,
                        top: 5,
                        child: _NowMarker(color: accent),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.xl,
              runSpacing: Space.sm,
              children: [
                _Legend(label: 'Going concern by', date: _day(c.goingConcernDue), done: c.goingConcernAchieved, accent: accent),
                _Legend(label: 'Bankable by', date: _day(c.bankableDue), done: c.bankableAchieved, accent: accent),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Enrolled ${_day(c.start)}  ·  incubation ends ${_day(c.incubationEnds)}',
              style: text.bodySmall,
            ),
          ],
        ),
    );
  }
}

/// Today's position on the programme track: a dot with a ring that slowly
/// breathes out and fades (still when the device asks for less motion).
class _NowMarker extends StatefulWidget {
  const _NowMarker({required this.color});
  final Color color;

  @override
  State<_NowMarker> createState() => _NowMarkerState();
}

class _NowMarkerState extends State<_NowMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Today',
      child: SizedBox(
        width: 14,
        height: 14,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + _c.value * 1.4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
                  ),
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.left, required this.done, required this.accent});
  final double left;
  final bool done;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left - 9,
      top: 3,
      child: _MilestoneDot(done: done, accent: accent),
    );
  }
}

class _MilestoneDot extends StatelessWidget {
  const _MilestoneDot({required this.done, required this.accent});
  final bool done;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: done ? accent : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: done ? accent : AppColors.charcoal, width: 2),
        ),
        child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.date, required this.done, required this.accent});
  final String label;
  final String date;
  final bool done;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MilestoneDot(done: done, accent: accent),
        const SizedBox(width: Space.sm),
        Text.rich(TextSpan(children: [
          TextSpan(text: done ? '${label.replaceAll(' by', '')}: done' : '$label ', style: text.bodySmall),
          if (!done) TextSpan(text: date, style: text.bodySmall?.copyWith(fontWeight: AppFonts.bodyStrong, color: AppColors.charcoal)),
        ])),
      ],
    );
  }
}
