import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../models/tour.dart';
import '../models/tour_catalog.dart';
import '../providers/tutorial_providers.dart';
import 'tour_anchor.dart';
import 'tour_overlay.dart';

/// Runs the guided tours for the page it wraps (AppShell wraps every
/// signed-in page; task detail and assign consultants wrap themselves).
/// Never used on sign-in, set-password or reset screens.
///
/// The first time an account reaches a page it shows, in order and only
/// those not seen yet: the welcome tour, the "inside an enterprise" tour
/// (when [inEnterprise]) and the page's own tour. Seen tours are saved per
/// account. "Don't show tips" stops the automatic tours; the menu's "Show
/// tips for this page" ([replay]) always works.
class TourHost extends ConsumerStatefulWidget {
  const TourHost({super.key, required this.place, this.inEnterprise = false, required this.child});

  /// e.g. 'users', 'section.tasks', 'task'. Null = no page tour.
  final String? place;
  final bool inEnterprise;
  final Widget child;

  /// Replays this page's tips (the menu's "Show tips for this page").
  static Future<void> replay(BuildContext context) async =>
      context.findAncestorStateOfType<_TourHostState>()?._replay();

  @override
  ConsumerState<TourHost> createState() => _TourHostState();
}

class _TourHostState extends ConsumerState<TourHost> {
  /// One tour on screen at a time, across the whole app.
  static bool _running = false;

  /// Bumped when the page changes, so a pending run for the old page stops.
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(TourHost old) {
    super.didUpdateWidget(old);
    if (old.place != widget.place || old.inEnterprise != widget.inEnterprise) _schedule();
  }

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  void _schedule() {
    final run = ++_run;
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRun(run));
  }

  List<String> get _places => ['welcome', if (widget.inEnterprise) 'enterprise', ?widget.place];

  Future<void> _autoRun(int run) async {
    try {
      final progress = ref.read(tourProgressRepositoryProvider);
      if (!progress.ready || progress.tipsOff) return;
      final role = (await ref.read(currentUserProfileProvider.future))?.role;
      if (role == null) return;

      for (final place in _places) {
        final tour = tourFor(role, place);
        if (tour == null || progress.hasSeen(tour.id)) continue;
        if (!await _waitUntilReady(run, tour)) return;
        final result = await _show(tour, tipsOff: false);
        if (result == null) return;
        if (result != TourResult.nothingShown) await _save(tour.id);
        if (result == TourResult.tipsTurnedOff) {
          await progress.setTipsOff(true);
          return;
        }
      }
    } catch (e) {
      // Tips are a nicety: never get in the way of the app.
      if (kDebugMode) debugPrint('Tour failed: $e');
    }
  }

  Future<void> _replay() async {
    final role = ref.read(currentUserProfileProvider).value?.role;
    if (role == null || _running) return;
    final progress = ref.read(tourProgressRepositoryProvider);
    // Let the phone drawer finish closing first.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    var shown = false;
    for (final place in [if (widget.inEnterprise) 'enterprise', ?widget.place]) {
      final tour = tourFor(role, place);
      if (tour == null) continue;
      final result = await _show(tour, tipsOff: progress.tipsOff);
      if (result == null) return;
      if (result != TourResult.nothingShown) shown = true;
      if (result == TourResult.skipped) return;
      if (await _applyToggle(result)) return;
    }
    if (shown || !mounted) return;
    // Nothing for this page: fall back to the welcome tips.
    final welcome = tourFor(role, 'welcome');
    if (welcome == null) return;
    final result = await _show(welcome, tipsOff: progress.tipsOff);
    if (result != null) await _applyToggle(result);
  }

  /// Saves a tips on/off choice. True when one was made (the tour stopped).
  Future<bool> _applyToggle(TourResult result) async {
    if (result != TourResult.tipsTurnedOff && result != TourResult.tipsTurnedOn) return false;
    await ref.read(tourProgressRepositoryProvider).setTipsOff(result == TourResult.tipsTurnedOff);
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            result == TourResult.tipsTurnedOff
                ? 'Tips are off. Use "Show tips for this page" in the menu any time.'
                : 'Tips are back on for pages you have not seen yet.',
          ),
        ),
      );
    }
    return true;
  }

  Future<TourResult?> _show(Tour tour, {required bool tipsOff}) async {
    if (!mounted || _running) return null;
    _running = true;
    try {
      return await showTour(context, tour, tipsOff: tipsOff);
    } finally {
      _running = false;
    }
  }

  Future<void> _save(String tourId) async {
    try {
      await ref.read(tourProgressRepositoryProvider).markSeen(tourId);
    } catch (e) {
      if (kDebugMode) debugPrint('Saving tour $tourId failed: $e');
    }
  }

  /// Waits for the page to settle: no dialog on top (e.g. the "Connect
  /// your Google suite" prompt), no other tour running, and the tour's
  /// spots loaded (lists arrive a moment after the page). False = the user
  /// moved on, so don't show it here.
  Future<bool> _waitUntilReady(int run, Tour tour) async {
    bool anchorShowing() => tour.steps.any((s) => s.anchors.any((a) => TourAnchor.find(a) != null));

    await Future<void>.delayed(const Duration(milliseconds: 700));
    // Checked every 400 ms: spots get 4 s to appear, the page 20 s to free up.
    for (var round = 0; round < 50; round++) {
      if (!mounted || run != _run) return false;
      final routeOnTop = ModalRoute.of(context)?.isCurrent ?? true;
      final spotsReady = tour.steps.every((s) => s.centred) || anchorShowing() || round >= 10;
      if (routeOnTop && !_running && spotsReady) return true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
