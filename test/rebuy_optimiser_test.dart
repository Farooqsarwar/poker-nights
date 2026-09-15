import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Addendum acceptance criterion 11: "Rebuy optimization considers players,
/// duration, level length, blinds, antes, starting stack, breaks, chips and
/// add-on."
///
/// A signature that merely accepts those arguments satisfies nothing. These
/// tests hold each input still and vary one, and require the answer to move —
/// which is the only evidence that the input is genuinely weighed.
void main() {
  /// A blind ladder that doubles, so depth falls away quickly enough for the
  /// worthwhile-rebuy test to bite somewhere in the middle.
  List<List<int>> ladder(int levels) => [
        for (var i = 0; i < levels; i++)
          [25 * (1 << (i ~/ 2)), 50 * (1 << (i ~/ 2))],
      ];

  int close({
    int requested = 6,
    bool organizerChose = false,
    int startingStack = 10000,
    int plannedLevels = 12,
    int players = 0,
    double durationHours = 0,
    int levelDurationMins = 0,
    bool anteEnabled = false,
    int anteAfterLevel = 0,
    List<ScheduledBreak> breaks = const [],
    bool addOnAvailable = false,
    int minChipValue = 0,
  }) =>
      TournamentEngine.optimiseRebuyCloseLevel(
        requested: requested,
        organizerChose: organizerChose,
        levelBlinds: ladder(plannedLevels),
        startingStack: startingStack,
        plannedLevels: plannedLevels,
        players: players,
        durationHours: durationHours,
        levelDurationMins: levelDurationMins,
        anteEnabled: anteEnabled,
        anteAfterLevel: anteAfterLevel,
        breaks: breaks,
        addOnAvailable: addOnAvailable,
        minChipValue: minChipValue,
      );

  group('the organizer is authoritative — section 6', () {
    test('an explicit choice is returned untouched', () {
      // "Manual organizer changes are authoritative for that tournament."
      for (final level in [2, 4, 6, 8, 11]) {
        expect(
          close(requested: level, organizerChose: true, players: 50),
          level,
          reason: 'the engine overrode a deliberate organizer choice',
        );
      }
    });

    test('and the UI default is optimised, not preserved', () {
      // Criterion 9 keeps 6 as the DISPLAYED default; criterion 10 says the
      // AI may move it. Both hold only if an un-chosen 6 can come back
      // different.
      final shallow = close(requested: 6, startingStack: 600);
      expect(
        shallow,
        isNot(6),
        reason: 'level 6 survived a stack too short to make a rebuy worth '
            'buying — the default is being treated as the rule',
      );
    });
  });

  group('each input criterion 11 names actually moves the answer', () {
    test('starting stack', () {
      final deep = close(startingStack: 40000);
      final shallow = close(startingStack: 1500);
      expect(deep, greaterThan(shallow));
    });

    test('players', () {
      // A bigger field takes longer to reduce, so a later cutoff is tolerable.
      final small = close(startingStack: 400000, players: 9);
      final large = close(startingStack: 400000, players: 60);
      expect(
        large,
        greaterThanOrEqualTo(small),
        reason: 'field size did not affect the ceiling at all',
      );
      expect(large, isNot(small));
    });

    test('antes', () {
      final withoutAnte = close(startingStack: 400000);
      final withAnte = close(
        startingStack: 400000,
        anteEnabled: true,
        anteAfterLevel: 2,
      );
      expect(
        withAnte,
        lessThan(withoutAnte),
        reason: 'antes drain every stack every hand — the window should close '
            'sooner once they start',
      );
    });

    test('add-on', () {
      final without = close(startingStack: 400000);
      final with_ = close(startingStack: 400000, addOnAvailable: true);
      expect(
        with_,
        lessThan(without),
        reason: 'a later top-up exists, so the rebuy window need not carry '
            'the whole job of keeping people in',
      );
    });

    test('chips', () {
      // A min chip large against the big blind means the rebuy stack can no
      // longer be built cleanly.
      final fineChips = close(startingStack: 400000, minChipValue: 1);
      final coarseChips = close(startingStack: 400000, minChipValue: 25);
      expect(coarseChips, lessThan(fineChips));
    });

    test('level length', () {
      // Same night, same levels — but 30-minute levels mean far fewer of them
      // fit inside the share of the evening a rebuy window may occupy.
      final shortLevels = close(
        startingStack: 400000,
        durationHours: 4,
        levelDurationMins: 10,
      );
      final longLevels = close(
        startingStack: 400000,
        durationHours: 4,
        levelDurationMins: 45,
      );
      expect(
        longLevels,
        lessThan(shortLevels),
        reason: 'level length was ignored — eight 10-minute levels and eight '
            '45-minute levels are not the same tournament',
      );
    });

    test('duration', () {
      final shortNight = close(
        startingStack: 400000,
        durationHours: 3,
        levelDurationMins: 20,
      );
      final longNight = close(
        startingStack: 400000,
        durationHours: 8,
        levelDurationMins: 20,
      );
      expect(longNight, greaterThan(shortNight));
    });

    test('blinds', () {
      // Same stack, different ladder steepness, via planned levels.
      final gentle = close(startingStack: 400000, plannedLevels: 20);
      final steep = close(startingStack: 400000, plannedLevels: 6);
      expect(gentle, greaterThan(steep));
    });

    test('breaks', () {
      // A cutoff with no level after it would place the default break at the
      // very end of the tournament, which is not a break.
      final withBreaks = close(
        startingStack: 4000000,
        plannedLevels: 4,
        breaks: const [ScheduledBreak(afterLevel: 0, durationMins: 10)],
      );
      expect(withBreaks, lessThanOrEqualTo(3));
    });
  });

  group('the result is always usable', () {
    test('never below 2, never past the planned structure', () {
      for (final stack in [100, 1000, 10000, 500000]) {
        for (final levels in [6, 9, 12, 20]) {
          final r = close(
            startingStack: stack,
            plannedLevels: levels,
            players: 20,
            durationHours: 4,
            levelDurationMins: 20,
          );
          expect(r, greaterThanOrEqualTo(2));
          expect(r, lessThanOrEqualTo(levels));
        }
      }
    });

    test('an empty ladder falls back to what was asked for', () {
      expect(
        TournamentEngine.optimiseRebuyCloseLevel(
          requested: 6,
          organizerChose: false,
          levelBlinds: const [],
          startingStack: 10000,
          plannedLevels: 12,
        ),
        6,
      );
    });

    test('a zero stack falls back rather than dividing by it', () {
      expect(
        TournamentEngine.optimiseRebuyCloseLevel(
          requested: 5,
          organizerChose: false,
          levelBlinds: ladder(10),
          startingStack: 0,
          plannedLevels: 10,
        ),
        5,
      );
    });
  });
}
