import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/utils/live_play_rules.dart';

GameSettings _settings({int? shootoutTables, required int players}) =>
    GameSettings(
      name: 'Friday',
      date: '2026-09-08',
      time: '20:00',
      location: 'Basement',
      players: players,
      durationHours: 3.5,
      buyIn: 15,
      koEnabled: false,
      koAmount: 0,
      rebuys: false,
      rebuysCloseLevel: 6,
      addOn: false,
      anteEnabled: false,
      anteAfterLevel: 7,
      organizerPct: 0,
      chipSet: const [],
      chipSetName: 'Home',
      shootoutTables: shootoutTables,
    );

void main() {
  group('GameSettings.effectiveShootoutTables', () {
    // §11.4 / §26.1: live seating pins the Stage A table count to this
    // getter rather than re-deriving it from maxPerTable, so a mismatch
    // between the generated structure's table split and the room's actual
    // seating is a bug this getter alone must prevent.
    test('the host override wins when it is at least 2', () {
      expect(
        _settings(shootoutTables: 4, players: 27).effectiveShootoutTables,
        4,
      );
    });

    test('a host override of 1 or 0 is not honoured (falls back to the derived count)', () {
      // "1 table" is not a shootout at all, and 0 is meaningless — mirrors
      // TournamentParams.effectiveShootoutTables's own floor.
      expect(
        _settings(shootoutTables: 1, players: 27).effectiveShootoutTables,
        3,
      );
      expect(
        _settings(shootoutTables: 0, players: 27).effectiveShootoutTables,
        3,
      );
    });

    test('null derives from the field size at kDefaultTableSize (9) per table', () {
      expect(_settings(players: 9).effectiveShootoutTables, 1);
      expect(_settings(players: 10).effectiveShootoutTables, 2);
      expect(_settings(players: 27).effectiveShootoutTables, 3);
      expect(_settings(players: 28).effectiveShootoutTables, 4);
    });
  });

  group('finishPositionFromIndex', () {
    test('the winner (last entry) is position 1', () {
      // finishOrder is first-out-first; a field of 9 has the winner at
      // index 8.
      expect(finishPositionFromIndex(index: 8, listLength: 9), 1);
    });

    test('the first player eliminated (index 0) is last place', () {
      expect(finishPositionFromIndex(index: 0, listLength: 9), 9);
    });

    test('this is the exact bug that shipped: index + 1 was backwards', () {
      const listLength = 9;
      for (var index = 0; index < listLength; index++) {
        final correct = finishPositionFromIndex(
          index: index,
          listLength: listLength,
        );
        final buggy = index + 1;
        // They agree only at the exact midpoint of an odd-length field —
        // everywhere else the old formula reported the wrong place entirely.
        if (index != (listLength - 1) / 2) {
          expect(correct, isNot(buggy),
              reason: 'index $index: old formula gave $buggy, which is only '
                  'right by coincidence, not by construction');
        }
      }
    });
  });

  group('isEarlyArrivalEligible', () {
    final start = DateTime(2026, 1, 1, 20, 0);

    test('false when the bonus is switched off', () {
      expect(
        isEarlyArrivalEligible(
          bonusEnabled: false,
          scheduledStart: start,
          now: start.subtract(const Duration(hours: 2)),
          cutoffMins: 30,
        ),
        isFalse,
      );
    });

    test('false with no scheduled start to measure against', () {
      expect(
        isEarlyArrivalEligible(
          bonusEnabled: true,
          scheduledStart: null,
          now: DateTime(2026, 1, 1),
          cutoffMins: 30,
        ),
        isFalse,
      );
    });

    test('true well before the cutoff', () {
      expect(
        isEarlyArrivalEligible(
          bonusEnabled: true,
          scheduledStart: start,
          now: start.subtract(const Duration(hours: 1)),
          cutoffMins: 30,
        ),
        isTrue,
      );
    });

    test('false after the cutoff, even if before scheduled start', () {
      expect(
        isEarlyArrivalEligible(
          bonusEnabled: true,
          scheduledStart: start,
          now: start.subtract(const Duration(minutes: 10)),
          cutoffMins: 30,
        ),
        isFalse,
      );
    });
  });

  group('earlyArrivalBonusChips', () {
    test('the documented default: 12.5% of the starting stack', () {
      expect(
        earlyArrivalBonusChips(startingStack: 10000, effectivePct: 0.125),
        1250,
      );
    });

    test('zero when the effective percentage is zero (bonus off)', () {
      expect(
        earlyArrivalBonusChips(startingStack: 10000, effectivePct: 0),
        0,
      );
    });
  });

  group('sampledLowestStackBB', () {
    test('a first sample with no prior low is recorded as-is', () {
      expect(
        sampledLowestStackBB(existing: null, stack: 2500, currentBB: 100),
        25,
      );
    });

    test('a lower sample replaces the stored low', () {
      expect(
        sampledLowestStackBB(existing: 30, stack: 1000, currentBB: 100),
        10,
      );
    });

    test('a higher sample does NOT overwrite an existing lower low', () {
      expect(
        sampledLowestStackBB(existing: 10, stack: 5000, currentBB: 100),
        10,
      );
    });

    test('no stack recorded leaves the existing value untouched', () {
      expect(
        sampledLowestStackBB(existing: 15, stack: null, currentBB: 100),
        15,
      );
    });

    test('an unknown current BB (0) leaves the existing value untouched', () {
      expect(
        sampledLowestStackBB(existing: 15, stack: 500, currentBB: 0),
        15,
      );
    });
  });
}
