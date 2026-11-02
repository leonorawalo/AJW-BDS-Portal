import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';

/// Signs the person out after [timeout] without a tap, click, scroll or
/// key press, so a portal left open on a shared computer or phone doesn't
/// stay signed in. A minute before, a message offers to stay.
class InactivityLogout extends ConsumerStatefulWidget {
  const InactivityLogout({super.key, required this.child});
  final Widget child;

  /// Change the idle limit here.
  static const timeout = Duration(minutes: 30);
  static const warning = Duration(minutes: 1);

  @override
  ConsumerState<InactivityLogout> createState() => _InactivityLogoutState();
}

class _InactivityLogoutState extends ConsumerState<InactivityLogout> {
  Timer? _warnTimer;
  Timer? _logoutTimer;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _warning;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _warnTimer?.cancel();
    _logoutTimer?.cancel();
    _warning?.close();
    _warning = null;
    _warnTimer = Timer(InactivityLogout.timeout - InactivityLogout.warning, _warn);
    _logoutTimer = Timer(InactivityLogout.timeout, _signOut);
  }

  void _warn() {
    if (!mounted) return;
    _warning = ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      duration: InactivityLogout.warning,
      content: const Text('You will be signed out in a minute because nothing has happened for a while.'),
      action: SnackBarAction(label: 'Stay signed in', onPressed: _reset),
    ));
  }

  void _signOut() {
    if (!mounted) return;
    ref.read(authRepositoryProvider).signOut();
  }

  @override
  void dispose() {
    _warnTimer?.cancel();
    _logoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _reset(),
        onPointerSignal: (_) => _reset(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, _) {
            _reset();
            return KeyEventResult.ignored;
          },
          child: widget.child,
        ),
      );
}
