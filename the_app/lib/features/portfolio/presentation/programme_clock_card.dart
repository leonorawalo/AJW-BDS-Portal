import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../enterprises/models/enterprise.dart';
import '../models/programme_clock.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _day(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// The enterprise's place on the programme timeline: month N of 12, with
/// the ToR milestones (going concern by month 3, bankable by month 6) as
/// steps on a track.
class ProgrammeClockCard extends StatelessWidget {
  const ProgrammeClockCard({super.key, required this.enterprise});
  final Enterprise enterprise;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = ProgrammeClock(enterprise);
    final progress = (c.month - 1 + (c.now.day / 31)).clamp(0, ProgrammeClock.incubationMonths) / ProgrammeClock.incubationMonths;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
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
                      Text('Month ${c.month} of ${ProgrammeClock.incubationMonths}', style: text.headlineMedium),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.isOverdue ? const Color(0xFFFDECEA) : AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    c.headline,
                    style: text.labelMedium?.copyWith(color: c.isOverdue ? AppColors.errorRed : AppColors.charcoal),
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress.toDouble(),
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceSunken,
                          ),
                        ),
                      ),
                      _Dot(left: x(ProgrammeClock.goingConcernMonths), done: c.goingConcernAchieved),
                      _Dot(left: x(ProgrammeClock.bankableMonths), done: c.bankableAchieved),
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
                _Legend(label: 'Going concern by', date: _day(c.goingConcernDue), done: c.goingConcernAchieved),
                _Legend(label: 'Bankable by', date: _day(c.bankableDue), done: c.bankableAchieved),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              'Enrolled ${_day(c.start)}  ·  incubation ends ${_day(c.incubationEnds)}',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.left, required this.done});
  final double left;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left - 9,
      top: 3,
      child: _MilestoneDot(done: done),
    );
  }
}

class _MilestoneDot extends StatelessWidget {
  const _MilestoneDot({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: done ? AppColors.successGreen : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: done ? AppColors.successGreen : AppColors.charcoal, width: 2),
        ),
        child: done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.date, required this.done});
  final String label;
  final String date;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MilestoneDot(done: done),
        const SizedBox(width: Space.sm),
        Text.rich(TextSpan(children: [
          TextSpan(text: done ? '${label.replaceAll(' by', '')}: done' : '$label ', style: text.bodySmall),
          if (!done) TextSpan(text: date, style: text.bodySmall?.copyWith(fontWeight: AppFonts.bodyStrong, color: AppColors.charcoal)),
        ])),
      ],
    );
  }
}
