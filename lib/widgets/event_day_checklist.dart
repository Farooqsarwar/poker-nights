import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/live_game.dart';
import 'app_badge.dart';
import 'app_card.dart';

/// Event-day preparation checklist (user-flow spec §4.6).
///
/// On event day the admin "should never have to remember the correct
/// sequence", so this card walks through the eight preparation steps in the
/// exact order they must happen:
///
/// 1. Review event information and recent changes
/// 2. Open check-in
/// 3. Confirm chip set and inventory
/// 4. Review expected late arrivals
/// 5. Prepare starting stacks
/// 6. Reserve rebuy and add-on chips
/// 7. Open TV Mode if required
/// 8. Test voice announcements
///
/// Steps are either **auto-derived** — completed purely from the [LiveGame]
/// state, shown with a green check and not tappable — or **manual toggles**
/// the admin taps to confirm (user-flow spec §4.6). Manual ticks are session
///-local by design: the checklist is a run-of-show aid, nothing is persisted.
///
/// The card only applies while the event sits in the pre-live window
/// (`published`, `checkin` or `ready`); outside that window it renders
/// nothing (§4.6 hides it once the tournament is running or finished).
class EventDayChecklist extends StatelessWidget {
  const EventDayChecklist({
    super.key,
    required this.game,
    required this.onOpenCheckIn,
    required this.onOpenTvMode,
    required this.onTestVoice,
  });

  /// The live game whose status/structure/change log drive the auto-derived
  /// steps.
  final LiveGame game;

  /// Action for step 2 ("Open check-in") when the host screen is *not* the
  /// check-in screen itself (e.g. Home or the event page). When null the
  /// step falls back to a manual toggle so it can still be ticked off.
  final VoidCallback? onOpenCheckIn;

  /// Fired when the admin taps step 7 ("Open TV Mode if required").
  final VoidCallback? onOpenTvMode;

  /// Fired when the admin taps step 8 ("Test voice announcements").
  final VoidCallback? onTestVoice;

  /// True while the event is inside the event-day preparation window
  /// (user-flow spec §4.6): after publication but before the tournament is
  /// live past its start or finished.
  static bool appliesTo(LiveGame game) =>
      game.status == LiveGameStatus.published ||
      game.status == LiveGameStatus.checkin ||
      game.status == LiveGameStatus.ready;

  @override
  Widget build(BuildContext context) {
    if (!appliesTo(game)) return const SizedBox.shrink();
    return _EventDayChecklistBody(
      game: game,
      onOpenCheckIn: onOpenCheckIn,
      onOpenTvMode: onOpenTvMode,
      onTestVoice: onTestVoice,
    );
  }
}

/// Internal stateful shell: keeps the session-local ticks for the manual
/// steps so the public [EventDayChecklist] can stay stateless.
class _EventDayChecklistBody extends StatefulWidget {
  const _EventDayChecklistBody({
    required this.game,
    required this.onOpenCheckIn,
    required this.onOpenTvMode,
    required this.onTestVoice,
  });

  final LiveGame game;
  final VoidCallback? onOpenCheckIn;
  final VoidCallback? onOpenTvMode;
  final VoidCallback? onTestVoice;

  @override
  State<_EventDayChecklistBody> createState() =>
      _EventDayChecklistBodyState();
}

class _EventDayChecklistBodyState extends State<_EventDayChecklistBody> {
  /// Step indices, in spec order (user-flow spec §4.6).
  static const int _reviewChanges = 0;
  static const int _openCheckIn = 1;
  static const int _chipSet = 2;
  static const int _lateArrivals = 3;
  // Step 4 (index 4, "Prepare starting stacks") is fully auto-derived from
  // game.structureConfirmed and therefore needs no toggle index.
  static const int _reserves = 5;
  static const int _tvMode = 6;
  static const int _voice = 7;

  static const int _stepCount = 8;

  /// Manually confirmed steps. Session-local only (§4.6): nothing persists,
  /// the list resets when the card leaves the tree.
  final Set<int> _manualDone = {};

  void _toggle(int step) {
    setState(() {
      if (_manualDone.contains(step)) {
        _manualDone.remove(step);
      } else {
        _manualDone.add(step);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    // ── Step completion (user-flow spec §4.6) ────────────────────────────────
    // 1 · Review changes: with an empty change log there is nothing to
    //     review (§10.4 posts edits there once they exist), so the step is
    //     automatic until then — afterwards the admin acknowledges manually.
    final changesReviewed =
        game.changeLog.isEmpty || _manualDone.contains(_reviewChanges);
    // 2 · Open check-in: automatic once the lifecycle moves past
    //     'published'. Without a navigation handler (we are already on the
    //     check-in screen) the step degrades to a manual toggle.
    final checkinReached =
        game.status.index >= LiveGameStatus.checkin.index;
    final checkInOpened = checkinReached ||
        (widget.onOpenCheckIn == null &&
            _manualDone.contains(_openCheckIn));
    // 3 · Chip set + inventory: physical-world confirmation, manual only.
    final chipsConfirmed = _manualDone.contains(_chipSet);
    // 4 · Late arrivals reviewed: manual only.
    final lateArrivalsReviewed = _manualDone.contains(_lateArrivals);
    // 5 · Starting stacks: mirrors the AI structure confirmation made in the
    //     30-minute pre-start review window (07-018).
    final stacksPrepared = game.structureConfirmed;
    // 6 · Reserves set aside: manual only.
    final reservesSetAside = _manualDone.contains(_reserves);
    // 7 · TV Mode tested: manual tick; tapping additionally opens TV Mode.
    final tvModeTested = _manualDone.contains(_tvMode);
    // 8 · Voice tested: manual tick; tapping additionally speaks a test line.
    final voiceTested = _manualDone.contains(_voice);

    final doneCount = [
      changesReviewed,
      checkInOpened,
      chipsConfirmed,
      lateArrivalsReviewed,
      stacksPrepared,
      reservesSetAside,
      tvModeTested,
      voiceTested,
    ].where((done) => done).length;

    final rows = <Widget>[
      _row(
        title: 'Review event information and recent changes',
        done: changesReviewed,
        auto: game.changeLog.isEmpty,
        onTap: game.changeLog.isEmpty
            ? null
            : () => _toggle(_reviewChanges),
      ),
      _row(
        title: 'Open check-in',
        done: checkInOpened,
        auto: widget.onOpenCheckIn != null,
        onTap: widget.onOpenCheckIn ??
            (checkinReached
                ? null
                : () => _toggle(_openCheckIn)),
      ),
      _row(
        title: 'Confirm chip set and inventory',
        done: chipsConfirmed,
        onTap: () => _toggle(_chipSet),
      ),
      _row(
        title: 'Review expected late arrivals',
        done: lateArrivalsReviewed,
        onTap: () => _toggle(_lateArrivals),
      ),
      _row(
        title: 'Prepare starting stacks',
        done: stacksPrepared,
        auto: true,
      ),
      _row(
        title: 'Reserve rebuy and add-on chips',
        done: reservesSetAside,
        onTap: () => _toggle(_reserves),
      ),
      _row(
        title: 'Open TV Mode if required',
        done: tvModeTested,
        onTap: () {
          _toggle(_tvMode);
          widget.onOpenTvMode?.call();
        },
      ),
      _row(
        title: 'Test voice announcements',
        done: voiceTested,
        onTap: () {
          _toggle(_voice);
          widget.onTestVoice?.call();
        },
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Event-day preparation',
                  style: AppTypography.display(
                    size: AppFontSizes.lg,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$doneCount/$_stepCount',
                style: AppTypography.monoSm.copyWith(
                  color: doneCount == _stepCount
                      ? AppColors.success
                      : AppColors.mutedForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Work top to bottom — never remember the sequence again.',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...rows,
          if (doneCount == _stepCount) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Ready to run.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// One checklist line. Auto-derived steps render a static green check with
  /// an 'Auto' badge and ignore taps; manual steps render a tappable circle
  /// that fills green once confirmed (user-flow spec §4.6 interaction model).
  Widget _row({
    required String title,
    required bool done,
    bool auto = false,
    VoidCallback? onTap,
  }) {
    final Icon icon;
    if (done) {
      icon = const Icon(Icons.check_circle, size: 20, color: AppColors.success);
    } else if (auto) {
      icon = const Icon(Icons.circle_outlined, size: 20, color: AppColors.border);
    } else {
      icon = const Icon(
        Icons.circle_outlined,
        size: 20,
        color: AppColors.mutedForeground,
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            icon,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: AppTypography.bodySm.copyWith(
                  color: done ? AppColors.success : AppColors.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (auto) ...[
              const SizedBox(width: AppSpacing.sm),
              const AppBadge(label: 'Auto', variant: AppBadgeVariant.muted),
            ],
          ],
        ),
      ),
    );
  }
}
