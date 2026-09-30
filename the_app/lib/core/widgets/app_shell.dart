import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/calendar/presentation/google_first_run_prompt.dart';
import '../../features/enterprises/providers/enterprise_providers.dart';
import '../../shared/models/user_profile.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final collapsed = ref.watch(sideNavCollapsedProvider);
    final role = ref.watch(currentUserProfileProvider).value?.role;

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
              icon: const Icon(Icons.menu),
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
                const Text('AJW BAGS Portal', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: Colors.white24),
                const SizedBox(width: 16),
              ],
              Flexible(
                child: enterprise == null
                    ? Text(title, overflow: TextOverflow.ellipsis)
                    : _EnterpriseSwitcher(enterprise: enterprise!),
              ),
            ],
          ),
          actions: [...actions, if (wide) const UserProfileBadge()],
        ),
        drawer: wide ? null : Drawer(child: menu),
        floatingActionButton: floatingActionButton,
        body: wide
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
    void go(VoidCallback action) {
      if (inDrawer) Navigator.of(context).pop();
      action();
    }

    final global = <_NavEntry>[
      if (role == UserRole.administrator) ...[
        _NavEntry('enterprises', 'Enterprises', Icons.business_outlined, () => context.go('/admin')),
        _NavEntry('users', 'Users', Icons.manage_accounts_outlined, () => context.go('/admin/users')),
        _NavEntry('audit', 'Audit log', Icons.history, () => context.go('/admin/audit')),
      ],
      if (role == UserRole.consultant)
        _NavEntry('portfolio', 'My portfolio', Icons.work_outline, () => context.go('/consultant')),
    ];
    final e = enterprise;
    final sections = [
      if (e != null)
        for (final s in e.sections) _NavEntry(s.key, s.label, s.icon, () => e.onSelectSection(s.key)),
    ];

    Widget item(_NavEntry entry, bool selected) {
      if (!expanded) {
        return Tooltip(
          message: entry.label,
          child: IconButton(
            isSelected: selected,
            icon: Icon(entry.icon),
            onPressed: () => go(entry.onTap),
          ),
        );
      }
      return ListTile(
        dense: true,
        selected: selected,
        leading: Icon(entry.icon),
        title: Text(entry.label),
        shape: const StadiumBorder(),
        onTap: () => go(entry.onTap),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: [
            if (inDrawer)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: UserProfileBadge(onAppBar: false),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  for (final entry in global) item(entry, entry.key == globalKey),
                  if (e != null) ...[
                    if (global.isNotEmpty) const Divider(height: 24),
                    if (expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          e.name.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                letterSpacing: 0.8,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    for (final entry in sections) item(entry, entry.key == e.currentSection),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: item(
                _NavEntry('signout', 'Sign out', Icons.logout, () => ref.read(authRepositoryProvider).signOut()),
                false,
              ),
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
