import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/branding/ajw_logo.dart';
import '../../../core/site_links.dart';
import '../../../core/branding/brand_stripes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';


/// Shared frame for the sign-in, reset-password and set-password screens.
///
/// Wide screens: a brand panel (the guideline's red + charcoal stripes with
/// the portal name) on the left, the form on the right. Phones: a short
/// striped header above the form.
///
/// With [playIntro], the first visit in each app run opens with the logo
/// assembling large in the middle of the screen ("connecting the dots"),
/// then gliding into its place above the form while the stripes sweep in
/// and the form fades up. Tapping skips it; it never plays when the
/// platform asks for reduced motion.
class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key, required this.child, this.playIntro = false, this.onBack});

  final Widget child;
  final bool playIntro;

  /// Shows a back button in the corner (e.g. reset password -> sign in).
  final VoidCallback? onBack;

  static const wideBreakpoint = 960.0;

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> with SingleTickerProviderStateMixin {
  static bool _introPlayed = false;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2100),
  );
  final _stackKey = GlobalKey();
  final _logoSlotKey = GlobalKey();
  Rect? _slotRect;

  static const _slotHeight = 76.0;

  Animation<double> _interval(double begin, double end, [Curve curve = Curves.linear]) => CurvedAnimation(
    parent: _intro,
    curve: Interval(begin, end, curve: curve),
  );

  late final _logoBuild = _interval(0.0, 0.58);
  late final _logoMove = _interval(0.55, 0.82, Curves.easeInOutCubic);
  late final _stripes = _interval(0.38, 0.8);
  late final _content = _interval(0.68, 1.0, Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (!widget.playIntro || _introPlayed) {
      _intro.value = 1;
    } else {
      _introPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
          _intro.value = 1;
          return;
        }
        _measureSlot();
        _intro.forward();
      });
    }
    _intro.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
  }

  void _measureSlot() {
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final slot = _logoSlotKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || slot == null) return;
    final topLeft = slot.localToGlobal(Offset.zero, ancestor: stack);
    setState(() => _slotRect = topLeft & slot.size);
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AuthLayout.wideBreakpoint;
    final animating = !_intro.isCompleted;

    final form = _FormColumn(
      logoSlotKey: _logoSlotKey,
      slotHeight: _slotHeight,
      showLogo: !animating,
      content: _content,
      child: widget.child,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        key: _stackKey,
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: wide
                ? Row(
                    children: [
                      Expanded(
                        flex: 11,
                        child: _BrandPanel(stripes: _stripes, text: _content),
                      ),
                      Expanded(flex: 10, child: form),
                    ],
                  )
                : Column(
                    children: [
                      SizedBox(
                        height: 132,
                        width: double.infinity,
                        child: _PhoneHeader(stripes: _stripes, text: _content),
                      ),
                      Expanded(child: form),
                    ],
                  ),
          ),
          if (widget.onBack != null)
            Positioned(
              left: 0,
              top: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: IconButton.filledTonal(
                    onPressed: widget.onBack,
                    tooltip: 'Back to sign in',
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
            ),
          if (animating) Positioned.fill(child: _introOverlay(context)),
        ],
      ),
    );
  }

  /// The large assembling logo, gliding from the centre into the form's
  /// logo slot. Covers the screen with white until the stripes arrive.
  Widget _introOverlay(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bigHeight = (size.shortestSide * 0.34).clamp(120.0, 230.0);
    final bigRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: bigHeight * AjwLogo.aspectRatio,
      height: bigHeight,
    );
    final slot = _slotRect;
    final endRect = slot == null
        ? bigRect
        : Rect.fromCenter(center: slot.center, width: _slotHeight * AjwLogo.aspectRatio, height: _slotHeight);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _intro.value = 1,
      child: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final rect = Rect.lerp(bigRect, endRect, _logoMove.value)!;
          // White veil fades away as the logo starts moving.
          final veil = 1 - _interval(0.5, 0.75).value;
          return Stack(
            children: [
              if (veil > 0)
                Positioned.fill(
                  child: ColoredBox(color: Colors.white.withValues(alpha: veil)),
                ),
              Positioned.fromRect(
                rect: rect,
                child: AjwLogo(height: rect.height, progress: _logoBuild),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.logoSlotKey,
    required this.slotHeight,
    required this.showLogo,
    required this.content,
    required this.child,
  });

  final GlobalKey logoSlotKey;
  final double slotHeight;
  final bool showLogo;
  final Animation<double> content;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - Space.xxl * 2),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SizedBox(
                        key: logoSlotKey,
                        height: slotHeight,
                        width: slotHeight * AjwLogo.aspectRatio,
                        child: showLogo ? AjwLogo(height: slotHeight) : null,
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    AnimatedBuilder(
                      animation: content,
                      builder: (context, child) => Opacity(
                        opacity: content.value,
                        child: Transform.translate(offset: Offset(0, 18 * (1 - content.value)), child: child),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          child,
                          const SizedBox(height: Space.xxl),
                          const _LegalLinks(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.stripes, required this.text});
  final Animation<double> stripes;
  final Animation<double> text;

  @override
  Widget build(BuildContext context) {
    final white = Theme.of(context).textTheme;
    return ClipRect(
      child: BrandStripes(
        redWidth: 0.74,
        charcoalFrom: 0.66,
        reveal: stripes,
        child: Stack(
          children: [
            // The guideline's logo watermark (p.5), low on the red band.
            Positioned(
              left: 150,
              bottom: -70,
              child: FadeTransition(opacity: text, child: const AjwWatermark(height: 420, opacity: 0.1)),
            ),
            Positioned.fill(
              child: FadeTransition(
                opacity: text,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 56, 96, 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APPRENTICE JOB WORK AFRICA',
                        style: white.labelMedium?.copyWith(color: Colors.white, letterSpacing: 2.4),
                      ),
                      const Spacer(),
                      Text(
                        'BAGS\nPortal',
                        style: white.displayLarge?.copyWith(color: Colors.white, fontSize: 64, height: 1.02),
                      ),
                      const SizedBox(height: Space.lg),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(
                          'Business Advancement and Growth Services',
                          style: white.titleLarge?.copyWith(color: Colors.white.withValues(alpha: 0.92), height: 1.4),
                        ),
                      ),
                      const Spacer(flex: 2),
                      Text(
                        'Connecting the dots',
                        style: white.titleSmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader({required this.stripes, required this.text});
  final Animation<double> stripes;
  final Animation<double> text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ClipRect(
      child: BrandStripes(
        redWidth: 0.72,
        charcoalFrom: 0.5,
        showGreyBand: true,
        reveal: stripes,
        child: SafeArea(
          bottom: false,
          child: FadeTransition(
            opacity: text,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('BAGS Portal', style: theme.headlineLarge?.copyWith(color: Colors.white)),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Connecting the dots',
                    style: theme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    Widget link(String label, String path) => TextButton(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.charcoalSoft,
        textStyle: Theme.of(context).textTheme.labelMedium,
        minimumSize: const Size(0, 36),
      ),
      onPressed: () => launchUrl(Uri.parse('${SiteLinks.site}/$path'), mode: LaunchMode.externalApplication),
      child: Text(label),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [link('About', 'about.html'), link('Privacy', 'privacy.html'), link('Terms', 'terms.html')],
    );
  }
}

/// An error message with an icon, so it never relies on colour alone.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heading + one-line explanation at the top of each auth form.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: Space.sm),
        Text(
          subtitle,
          style: t.bodyLarge?.copyWith(color: AppColors.charcoalSoft),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
