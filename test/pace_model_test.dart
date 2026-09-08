import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// PN-047 / PN-048 — the speed-up / slow-down recommendation.
///
/// `estimatedFinishDriftMinutes()` lives on AppProvider and needs Firebase to
/// construct, so the arithmetic is reproduced here exactly as the provider
/// implements it and exercised over the scenarios that were wrong. If the
/// provider changes, these must be updated in step — the comment in
/// `app_provider_timer.dart` says so.
int drift({
  required int startingField,
  required int activeRemaining,
  required double targetHours,
  required int levelDurationMins,
  required int plannedLevels,
  required int currentLevel,
  required int currentSecondsRemaining,
  /// Wall-clock minutes since the first Start press. Null reproduces the
  /// legacy path, where elapsed time is summed from level durations and no
  /// pause is visible (PN-050).
  double? wallClockElapsedMins,
}) {
  final targetMins = targetHours * 60;

  var elapsedMins = 0.0;
  if (wallClockElapsedMins != null) {
    elapsedMins = wallClockElapsedMins < 0 ? 0 : wallClockElapsedMins;
  } else {
    for (var i = 0; i < currentLevel - 1 && i < plannedLevels; i++) {
      elapsedMins += levelDurationMins;
    }
    final consumed = levelDurationMins * 60 - currentSecondsRemaining;
    elapsedMins += consumed.clamp(0, levelDurationMins * 60) / 60.0;
  }

  var remaining = 0.0;
  for (var i = currentLevel; i < plannedLevels; i++) {
    remaining += levelDurationMins;
  }
  // PN-048: the rest of the level being played is still work to do.
  remaining +=
      currentSecondsRemaining.clamp(0, levelDurationMins * 60) / 60.0;

  // PN-047: actual field vs the field the SCHEDULE expects by now.
  final elapsedFraction = (elapsedMins / targetMins).clamp(0.0, 1.0);
  final expectedNow = startingField * (1 - elapsedFraction) < 2.0
      ? 2.0
      : startingField * (1 - elapsedFraction);
  final paceFactor = (activeRemaining / expectedNow).clamp(0.5, 2.0);

  return (remaining * paceFactor - (targetMins - elapsedMins)).round();
}

const _threshold = 20;

void main() {
  group('PN-048 — a freshly started event is not already drifting', () {
    test('level 1, full field, nothing consumed → inside the threshold', () {
      final d = drift(
        startingField: 10,
        activeRemaining: 10,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 1,
        currentSecondsRemaining: 15 * 60,
      );
      expect(
        d.abs(),
        lessThanOrEqualTo(_threshold),
        reason: 'level 1 of a 3.5 h event reports $d minutes of drift — '
            'a recommendation before anything has happened',
      );
    });

    test('the same instant reads the same either way it is described', () {
      // "Level 1, nothing left on the clock" and "level 2, a full level left"
      // are the SAME moment. They agree only if the unplayed part of the
      // current level is counted as remaining work; without it the first
      // description loses a whole level.
      final endOfLevelOne = drift(
        startingField: 10,
        activeRemaining: 10,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 1,
        currentSecondsRemaining: 0,
      );
      final startOfLevelTwo = drift(
        startingField: 10,
        activeRemaining: 10,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 2,
        currentSecondsRemaining: 15 * 60,
      );
      expect(
        endOfLevelOne,
        startOfLevelTwo,
        reason: 'the same instant produced $endOfLevelOne and '
            '$startOfLevelTwo minutes of drift',
      );
    });
  });

  group('PN-047 — the recommendation points the right way', () {
    test('a thinning field near the end does NOT ask to speed up', () {
      // The reviewer's worked example: 10 players, 3.5 h, 15-minute levels,
      // level 10, three players left. The old factor (starting / current)
      // clamped to 2.0 and recommended speeding up a final table that was
      // about to finish early.
      final d = drift(
        startingField: 10,
        activeRemaining: 3,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 10,
        currentSecondsRemaining: 0,
      );
      expect(
        d,
        lessThanOrEqualTo(_threshold),
        reason: 'three-handed at level 10 reports +$d — "Speed Up" at a '
            'final table that is running ahead',
      );
    });

    test('a full field halfway through DOES ask to speed up', () {
      // Nobody eliminated at the midpoint is genuinely slow.
      final d = drift(
        startingField: 10,
        activeRemaining: 10,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 8,
        currentSecondsRemaining: 0,
      );
      expect(
        d,
        greaterThan(_threshold),
        reason: 'a full field at the midpoint reports $d — it should be '
            'clearly running long',
      );
    });

    test('the factor rises with a bigger-than-expected field, not a smaller one',
        () {
      int f(int active) => drift(
            startingField: 10,
            activeRemaining: active,
            targetHours: 3.5,
            levelDurationMins: 15,
            plannedLevels: 14,
            currentLevel: 8,
            currentSecondsRemaining: 0,
          );
      expect(
        f(9),
        greaterThan(f(3)),
        reason: 'more players left than expected must read as SLOWER, '
            'not faster',
      );
    });
  });

  group('PN-050 — a pause the clock cannot see still registers', () {
    test('a 30-minute settlement break produces a Speed Up', () {
      // Level 7 of a 3.5 h event: 90 minutes of level time played, but two
      // hours of wall clock gone because settlement took half an hour. The
      // old model summed level durations and read on-target while the
      // dashboard's wall-clock window showed the slip.
      final legacy = drift(
        startingField: 10,
        activeRemaining: 4,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 7,
        currentSecondsRemaining: 15 * 60,
      );
      final wallClock = drift(
        startingField: 10,
        activeRemaining: 4,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 7,
        currentSecondsRemaining: 15 * 60,
        wallClockElapsedMins: 120,
      );
      // The level-time model is not merely blind to the pause — it reads
      // NEGATIVE, i.e. "running early", and would offer Slow Down while the
      // evening is half an hour behind. That contradiction is the defect.
      expect(
        legacy,
        lessThan(0),
        reason: 'the level-time model should read as running early here — '
            'it read $legacy',
      );
      expect(
        wallClock,
        greaterThan(_threshold),
        reason: 'half an hour lost to settlement must surface as drift; '
            'wall-clock model read $wallClock',
      );
    });

    test('with no pause the two models agree', () {
      final legacy = drift(
        startingField: 10,
        activeRemaining: 5,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 7,
        currentSecondsRemaining: 15 * 60,
      );
      final wallClock = drift(
        startingField: 10,
        activeRemaining: 5,
        targetHours: 3.5,
        levelDurationMins: 15,
        plannedLevels: 14,
        currentLevel: 7,
        currentSecondsRemaining: 15 * 60,
        wallClockElapsedMins: 90,
      );
      expect((legacy - wallClock).abs(), lessThanOrEqualTo(2));
    });
  });

  group('PN-045 / PN-046 — stacks are deep and postable', () {
    test('every preset and field opens at a playable depth with change', () {
      for (final preset in TournamentEngine.presetNames) {
        for (final players in [4, 6, 8, 10, 14, 18]) {
          final s = TournamentEngine.generate(
            TournamentParams(
              players: players,
              durationHours: 3.5,
              buyIn: 15,
              chipSet: TournamentEngine.getPreset(preset),
              rebuys: true,
              rebuysCloseLevel: 6,
              addOn: true,
              anteEnabled: false,
              anteAfterLevel: 7,
              koEnabled: false,
              koAmount: 0,
              organizerPct: 0,
            ),
          );
          final sb = s.levels.first.sb;
          final depth = s.startingStack / s.levels.first.bb;
          final label = '$preset/${players}p';

          // The chip plan must total the declared stack exactly (23-002) —
          // the change seeding must never cost coverage.
          final covered =
              s.chipPlan.fold<int>(0, (a, e) => a + e.count * e.value);
          expect(covered, s.startingStack, reason: '$label: plan totals '
              '$covered against a declared ${s.startingStack}');

          // PN-046: never trade depth away to make the change test easier.
          expect(
            depth,
            greaterThanOrEqualTo(20),
            reason: '$label: ${depth.toStringAsFixed(1)} BB is push-fold from '
                'level one',
          );

          // Something in hand can pay the small blind.
          final payable = s.chipPlan
              .where((e) => e.value <= sb)
              .fold<int>(0, (a, e) => a + e.count);
          expect(payable, greaterThanOrEqualTo(2), reason: '$label: no chip '
              'small enough to post $sb');
        }
      }
    });
  });
}
