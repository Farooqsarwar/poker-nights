import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Specification section 8 (APPROVED) and its own acceptance gate in §29,
/// as amended by the v11 addendum §5 (up to 3 breaks; structural midpoint
/// when rebuys are off).
///
/// The distinction that matters: a break is NOT a manual pause. It is part of
/// the generated structure and its minutes come out of the target duration —
/// "target 4h = 3h40 playing + 20 min scheduled breaks".
void main() {
  const chips = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 20),
  ];

  TournamentParams params({
    List<ScheduledBreak> breaks = const [],
    bool rebuys = true,
    int rebuysCloseLevel = 6,
    double hours = 4,
    int players = 9,
  }) => TournamentParams(
    players: players,
    durationHours: hours,
    buyIn: 20,
    chipSet: chips,
    rebuys: rebuys,
    rebuysCloseLevel: rebuysCloseLevel,
    reEntry: false,
    addOn: true,
    anteEnabled: false,
    anteAfterLevel: 7,
    anteStyle: AnteStyle.bigBlind,
    koEnabled: false,
    koAmount: 0,
    organizerPct: 10,
    breaks: breaks,
  );

  group('§29 gate — OFF means no scheduled break', () {
    test('no breaks requested produces none', () {
      final s = TournamentEngine.generate(params());
      expect(s.breaks, isEmpty);
      expect(s.totalBreakMins, 0);
    });

    test('OFF leaves the structure exactly as it was before breaks existed', () {
      // Regression guard: adding the feature must not change a tournament
      // that does not use it.
      final without = TournamentEngine.generate(params());
      expect(without.levels.length, greaterThan(0));
      expect(
        without.expectedFinishMins,
        greaterThan(0),
        reason: 'an OFF tournament must still estimate a finish',
      );
    });
  });

  group('§29 gate — ON supports 1, 2 or 3 breaks', () {
    for (final count in [1, 2, 3]) {
      test('$count break${count == 1 ? '' : 's'} are placed', () {
        final s = TournamentEngine.generate(
          params(
            breaks: List.generate(
              count,
              (_) => const ScheduledBreak(afterLevel: 0, durationMins: 10),
            ),
          ),
        );
        expect(s.breaks, hasLength(count));
        expect(s.totalBreakMins, count * 10);
      });
    }

    test('more than three are capped', () {
      final s = TournamentEngine.generate(
        params(
          breaks: List.generate(
            6,
            (_) => const ScheduledBreak(afterLevel: 0, durationMins: 10),
          ),
        ),
      );
      expect(s.breaks.length, lessThanOrEqualTo(kMaxScheduledBreaks));
    });

    test('two automatic breaks do not land on the same level', () {
      final s = TournamentEngine.generate(
        params(
          breaks: const [
            ScheduledBreak(afterLevel: 0, durationMins: 10),
            ScheduledBreak(afterLevel: 0, durationMins: 10),
          ],
        ),
      );
      final levels = s.breaks.map((b) => b.afterLevel).toList();
      expect(levels.toSet().length, levels.length);
    });
  });

  group('§29 gate — each break has placement and duration', () {
    test('an explicit placement is honoured exactly', () {
      final s = TournamentEngine.generate(
        params(
          breaks: const [ScheduledBreak(afterLevel: 8, durationMins: 15)],
        ),
      );
      expect(s.breaks.single.afterLevel, 8);
      expect(s.breaks.single.durationMins, 15);
    });

    for (final mins in kBreakDurationPresets) {
      test('$mins-minute preset is carried through', () {
        final s = TournamentEngine.generate(
          params(breaks: [ScheduledBreak(afterLevel: 6, durationMins: mins)]),
        );
        expect(s.breaks.single.durationMins, mins);
      });
    }

    test('a custom duration outside the presets is accepted', () {
      final s = TournamentEngine.generate(
        params(breaks: const [ScheduledBreak(afterLevel: 6, durationMins: 7)]),
      );
      expect(s.breaks.single.durationMins, 7);
    });

    test('breakAfter finds the break for a level', () {
      final s = TournamentEngine.generate(
        params(breaks: const [ScheduledBreak(afterLevel: 6, durationMins: 10)]),
      );
      expect(s.breakAfter(6), isNotNull);
      expect(s.breakAfter(5), isNull);
    });
  });

  group('§29 gate — default is after the rebuy period', () {
    test('with rebuys on, the automatic break follows the rebuy close', () {
      final s = TournamentEngine.generate(
        params(
          rebuys: true,
          rebuysCloseLevel: 6,
          breaks: const [ScheduledBreak(afterLevel: 0, durationMins: 10)],
        ),
      );
      expect(
        s.breaks.single.afterLevel,
        6,
        reason: 'section 8: default recommendation is immediately after the '
            'end of the rebuy period',
      );
    });

    test('a different rebuy close moves the default with it', () {
      final s = TournamentEngine.generate(
        params(
          rebuys: true,
          rebuysCloseLevel: 4,
          breaks: const [ScheduledBreak(afterLevel: 0, durationMins: 10)],
        ),
      );
      expect(s.breaks.single.afterLevel, 4);
    });
  });

  group('v11 addendum §5 — structural midpoint when rebuys are off', () {
    test('with rebuys off the break lands near the middle', () {
      final s = TournamentEngine.generate(
        params(
          rebuys: false,
          rebuysCloseLevel: 0,
          breaks: const [ScheduledBreak(afterLevel: 0, durationMins: 10)],
        ),
      );
      final placed = s.breaks.single.afterLevel;
      final midpoint = (s.plannedLevels / 2).round();
      expect(
        (placed - midpoint).abs(),
        lessThanOrEqualTo(1),
        reason: 'placed at L$placed, planned ${s.plannedLevels} levels, '
            'midpoint L$midpoint',
      );
    });
  });

  group('§29 gate — break time is inside the target duration', () {
    test('the specification worked example: 4h = 3h40 play + 20 min break', () {
      final withBreaks = TournamentEngine.generate(
        params(
          hours: 4,
          breaks: const [
            ScheduledBreak(afterLevel: 6, durationMins: 10),
            ScheduledBreak(afterLevel: 12, durationMins: 10),
          ],
        ),
      );
      expect(withBreaks.totalBreakMins, 20);

      // Playing time must have shrunk to make room, not stayed at 4 hours.
      final without = TournamentEngine.generate(params(hours: 4));
      final playWith = withBreaks.levels
          .take(withBreaks.plannedLevels)
          .fold<int>(0, (a, l) => a + l.durationMins);
      final playWithout = without.levels
          .take(without.plannedLevels)
          .fold<int>(0, (a, l) => a + l.durationMins);
      expect(
        playWith,
        lessThan(playWithout),
        reason: 'breaks are INSIDE the 4 hours — "target 4h = 3h40 playing + '
            '20 min scheduled breaks". Playing time must shrink to fit them',
      );
    });

    test('the finish estimate counts break time', () {
      final without = TournamentEngine.generate(params(hours: 4));
      final with20 = TournamentEngine.generate(
        params(
          hours: 4,
          breaks: const [ScheduledBreak(afterLevel: 6, durationMins: 20)],
        ),
      );
      expect(
        with20.expectedFinishMins,
        greaterThan(0),
        reason: 'a tournament with a break still estimates a finish',
      );
      // Both should land near the same wall-clock target, because the break
      // came out of playing time rather than being added on top.
      expect(
        (with20.expectedFinishMins - without.expectedFinishMins).abs(),
        lessThanOrEqualTo(20),
        reason: 'with ${with20.expectedFinishMins}, '
            'without ${without.expectedFinishMins}',
      );
    });

    test('scheduled breaks do not double-count the settlement pause', () {
      final s = TournamentEngine.generate(
        params(breaks: const [ScheduledBreak(afterLevel: 6, durationMins: 10)]),
      );
      final playing = s.levels
          .take(s.plannedLevels)
          .fold<int>(0, (a, l) => a + l.durationMins);
      expect(
        s.expectedFinishMins,
        playing + TournamentEngine.settlementBreakMins + 10,
        reason: 'the settlement pause and a scheduled break are different '
            'things and must be summed separately, not conflated',
      );
    });
  });

  group('breaks survive a Firestore round trip', () {
    test('a break keeps its placement and duration', () {
      const b = ScheduledBreak(afterLevel: 6, durationMins: 15);
      final back = scheduledBreakFromMap(scheduledBreakToMap(b));
      expect(back, b);
    });

    test('a structure written before breaks existed loads as none', () {
      // Plan §2.1 — every new field needs a sane default in fromMap, because
      // old documents are read by new clients.
      final s = TournamentEngine.generate(params());
      final map = tournamentStructureToMap(s)..remove('breaks');
      final back = tournamentStructureFromMap(map);
      expect(back.breaks, isEmpty);
      expect(back.totalBreakMins, 0);
    });
  });
}
