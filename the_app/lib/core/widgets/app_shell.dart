import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attention/models/attention_spots.dart';
import '../../features/attention/providers/attention_providers.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/calendar/presentation/google_first_run_prompt.dart';
import '../../features/enterprises/providers/enterprise_providers.dart';
import '../../shared/models/user_profile.dart';
import '../branding/ajw_logo.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'attention_dot.dart';
import 'user_profile_badge.dart';

/// Laptop-first navigation shell (C5), in the style of Google Cloud /
/// Gemini: a side menu with the role's own pages at the top and, inside an
/// enterprise, that enterprise's sections below. The top bar has the
/// hamburger, the enterprise switcher, screen actions and the name badge.
///
/// Wide screens (>= [_wideBreakpoint]): the menu is always visible; the
/// hamburger collapses it to icons. Narrow screens (phones): the hamburger
/// opens it as a slide-out drawer.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.globalKey,
    this.enterprise,
    this.actions = const [],
    this.floatingActionButton,
  });

  /// Shown in the top bar when not inside an enterprise.
  final String title;
  final Widget body;

  /// Which role-level page is current ('enterprises', 'users', 'audit',
  /// 'portfolio'), highlighted in the menu. Null inside an enterprise.
  final String? globalKey;

  /// Set when the screen is one enterprise's workspace.
  final ShellEnterprise? enterprise;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  static const _wideBreakpoint = 1000.0;

  /// The open place never shows a dot: opening it is what clears it.
  static bool _dotForPage(AttentionSpots spots, String key, String? openKey) {
    if (key == openKey) return false;
    return key == 'portfolio' ? spots.anyEnterprise : spots.page(key);
  }

  static bool _dotForSection(AttentionSpots spots, ShellEnterprise e, String key) =>
      key != e.currentSection && spots.section(e.id, key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final collapsed = ref.watch(sideNavCollapsedProvider);
    final role = ref.watch(currentUserProfileProvider).value?.role;
    final spots = ref.watch(attentionProvider).value ?? AttentionSpots.none;
    // Phone (or collapsed menu): the hamburger carries a dot when anything
    // in the menu has one.
    final e = enterprise;
    final menuHasDot = _globalEntries(context, role).any((g) => _dotForPage(spots, g.key, globalKey)) ||
        (e != null && e.sections.any((s) => _dotForSection(spots, e, s.key)));

    final menu = _SideMenu(
      role: role,
      globalKey: globalKey,
      enterprise: enterprise,
      expanded: !wide || !collapsed,
      inDrawer: !wide,
    );

    return GoogleFirstRunPrompt(
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (innerContext) => IconButton(
              icon: AttentionDot(show: menuHasDot && (!wide || collapsed), child: const Icon(Icons.menu)),
              tooltip: wide ? (collapsed ? 'Expand menu' : 'Collapse menu') : 'Menu',
              onPressed: () => wide
                  ? ref.read(sideNavCollapsedProvider.notifier).toggle()
                  : Scaffold.of(innerContext).openDrawer(),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              if (wide) ...[
                const AjwLogo(height: 30),
                const SizedBox(width: 10),
                Text('BAGS Portal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: Space.lg),
                Container(width: 1, height: 24, color: AppColors.hairline),
                const SizedBox(width: Space.lg),
              ],
              Flexible(
                child: enterprise == null
                    ? Text(title, overflow: TextOverflow.ellipsis)
                    : _EnterpriseSwitcher(enterprise: enterprise!),
              ),
            ],
          ),
          actions: [...actions, if (wide) const UserProfileBadge(), const SizedBox(width: Space.sm)],
          bottom: const PreferredSize(preferredSize: Size.fromHeight(3), child: _BrandBar()),
        ),
        drawer: wide ? null : Drawer(child: menu),
        floatingActionButton: floatingActionButton,
        body: _SeenMarker(
          enterpriseId: enterprise?.id,
          section: enterprise?.currentSection ?? globalKey,
          child: wide
              ? Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: collapsed ? 72 : 248,
                      child: menu,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
        ),
      ),
    );
  }
}

/// One enterprise's sections for the side menu, and how to switch to
/// another enterprise (same section).
class ShellEnterprise {
  const ShellEnterprise({
    required this.id,
    required this.name,
    required this.sections,
    required this.currentSection,
    required this.onSelectSection,
    this.onSwitchEnterprise,
  });

  final String id;
  final String name;
  final List<ShellSection> sections;
  final String currentSection;
  final void Function(String sectionKey) onSelectSection;

  /// Null = no switcher (the Owner has a single enterprise).
  final void Function(String enterpriseId)? onSwitchEnterprise;
}

class ShellSection {
  const ShellSection(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

/// Whether the wide-screen side menu is collapsed to icons. Kept for the
/// session so it stays put while moving between screens.
final sideNavCollapsedProvider = NotifierProvider<SideNavCollapsed, bool>(SideNavCollapsed.new);

class SideNavCollapsed extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// The role's own pages at the top of the menu.
List<_NavEntry> _globalEntries(BuildContext context, UserRole? role) => <_NavEntry>[
      if (role == UserRole.administrator) ...[
        _NavEntry('enterprises', 'Enterprises', Icons.business_outlined, () => context.go('/admin')),
        _NavEntry('programme', 'Programme', Icons.insights_outlined, () => context.go('/admin/programme')),
        _NavEntry('workshops', 'Workshops', Icons.groups_outlined, () => context.go('/admin/workshops')),
        _NavEntry('users', 'Users', Icons.manage_accounts_outlined, () => context.go('/admin/users')),
        _NavEntry('audit', 'Audit log', Icons.history, () => context.go('/admin/audit')),
      ],
      if (role == UserRole.consultant) ...[
        _NavEntry('portfolio', 'My portfolio', Icons.work_outline, () => context.go('/consultant')),
        _NavEntry('workshops', 'Workshops', Icons.groups_outlined, () => context.go('/consultant/workshops')),
      ],
    ];

/// Marks the open page / enterprise section as seen (clearing its red dot)
/// when it opens, and again whenever the user moves to another one.
class _SeenMarker extends ConsumerStatefulWidget {
  const _SeenMarker({required this.enterpriseId, required this.section, required this.child});

  final String? enterpriseId;
  final String? section;
  final Widget child;

  @override
  ConsumerState<_SeenMarker> createState() => _SeenMarkerState();
}

class _SeenMarkerState extends ConsumerState<_SeenMarker> {
  @override
  void initState() {
    super.initState();
    _mark();
  }

  @override
  void didUpdateWidget(_SeenMarker old) {
    super.didUpdateWidget(old);
    if (old.enterpriseId != widget.enterpriseId || old.section != widget.section) _mark();
  }

  void _mark() {
    final section = widget.section;
    if (section == null) return;
    // After the frame: providers can't be changed while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) markSeen(ref, enterpriseId: widget.enterpriseId, section: section);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NavEntry {
  const _NavEntry(this.key, this.label, this.icon, this.onTap);
  final String key;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _SideMenu extends ConsumerWidget {
  const _SideMenu({
    required this.role,
    required this.globalKey,
    required this.enterprise,
    required this.expanded,
    required this.inDrawer,
  });

  final UserRole? role;
  final String? globalKey;
  final ShellEnterprise? enterprise;
  final bool expanded;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spots = ref.watch(attentionProvider).value ?? AttentionSpots.none;
    void go(VoidCallback action) {
      if (inDrawer) Navigator.of(context).pop();
      action();
    }

    final global = _globalEntries(context, role);
    final e = enterprise;
    final sections = [
      if (e != null)
        for (final s in e.sections) _NavEntry(s.key, s.label, s.icon, () => e.onSelectSection(s.key)),
    ];

    Widget item(_NavEntry entry, bool selected, {bool dot = false}) {
      final icon = AttentionDot(show: dot && !selected, child: Icon(entry.icon, size: expanded ? 22 : null));
      if (!expanded) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Tooltip(
            message: entry.label,
            child: IconButton(
              isSelected: selected,
              style: IconButton.styleFrom(
                backgroundColor: selected ? AppColors.brandRedTint : null,
                foregroundColor: selected ? AppColors.brandRed : AppColors.charcoalSoft,
                minimumSize: const Size(48, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
              ),
              icon: icon,
              onPressed: () => go(entry.onTap),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: ListTile(
          selected: selected,
          selectedTileColor: AppColors.brandRedTint,
          selectedColor: AppColors.brandRedDeep,
          iconColor: AppColors.charcoalSoft,
          minTileHeight: 44,
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
          horizontalTitleGap: Space.md,
          leading: icon,
          title: Text(
            entry.label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.brandRedDeep : AppColors.charcoal,
                ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
          onTap: () => go(entry.onTap),
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      child: SafeArea(
        child: Stack(
          children: [
            // AJW watermark (guideline p.5), tucked into the menu's corner.
            if (expanded)
              const Positioned(left: -40, bottom: 56, child: AjwWatermark(height: 200, opacity: 0.05)),
            Column(
          crossAxisAlignment: expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: [
            if (inDrawer)
              const Padding(
                padding: EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.md),
                child: UserProfileBadge(onAppBar: false),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.md),
                children: [
                  for (final entry in global)
                    item(entry, entry.key == globalKey, dot: AppShell._dotForPage(spots, entry.key, globalKey)),
                  if (e != null) ...[
                    if (global.isNotEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: Space.md), child: Divider()),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Space.md, Space.xs, Space.md, Space.sm),
                        child: Text(
                          e.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.1),
                        ),
                      ),
                    for (final entry in sections)
                      item(entry, entry.key == e.currentSection, dot: AppShell._dotForSection(spots, e, entry.key)),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: item(
                _NavEntry('signout', 'Sign out', Icons.logout, () => ref.read(authRepositoryProvider).signOut()),
                false,
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }
}

/// The enterprise name in the top bar; for Admins and consultants it's a
/// switcher (like Google Cloud's project picker) that keeps the section.
class _EnterpriseSwitcher extends ConsumerWidget {
  const _EnterpriseSwitcher({required this.enterprise});
  final ShellEnterprise enterprise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSwitch = enterprise.onSwitchEnterprise;
    final label = Text(enterprise.name, overflow: TextOverflow.ellipsis);
    if (onSwitch == null) return label;

    final enterprises = ref.watch(enterprisesListProvider).value ?? const [];
    return PopupMenuButton<String>(
      tooltip: 'Switch enterprise',
      onSelected: onSwitch,
      itemBuilder: (_) => [
        for (final e in enterprises)
          PopupMenuItem(
            value: e.id,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: e.id == enterprise.id ? const Icon(Icons.check, size: 18) : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(e.businessName)),
              ],
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Flexible(child: label), const Icon(Icons.arrow_drop_down)],
      ),
    );
  }
}

/// A 3px strip under the top bar: charcoal then AJW red, meeting on the
/// brand-stripe slant.
class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 3, width: double.infinity, child: CustomPaint(painter: _BrandBarPainter()));
}

class _BrandBarPainter extends CustomPainter {
  const _BrandBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.brandRed);
    final split = size.width * 0.18;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(split + 1, 0)
        ..lineTo(split, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()..color = AppColors.charcoal,
    );
  }

  @override
  bool shouldRepaint(_BrandBarPainter oldDelegate) => false;
}
