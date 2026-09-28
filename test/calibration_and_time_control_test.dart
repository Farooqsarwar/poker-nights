import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/calibration_record.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// The two layers the General Poker Tournament Structuring Framework adds on
/// top of §F1: §13 time-control architecture and §14 the calibration loop.
///
/// Both are agreed change requests — they are not in Build Specification v3.1
/// (see `BUILD_PLAN.md` §3.1) — so the citations here are to the Framework.
void main() {
  const chips = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 300),
    ChipColor(color: 'Red', hex: 0xFFD53032, value: 5, quantity: 300),
    ChipColor(color: 'Green', hex: 0xFF3FBF6B, value: 25, quantity: 300),
    ChipColor(color: 'Black', hex: 0xFF141414, value: 100, quantity: 300),
    ChipColor(color: 'Purple', hex: 0xFF7A3FBF, value: 500, quantity: 200),
  ];

  TournamentParams params({int players = 12, PaceMode? pace}) =>
      TournamentParams(
        players: players,
        durationHours: 4,
        buyIn: 50,
        chipSet: chips,
        rebuys: false,
        rebuysCloseLevel: 6,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 6,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        pace: pace,
        format: TournamentFormat.freezeOut,
      );

  group('Framework §13 — time-control architecture', () {
    test('the three layers are distinct and ordered', () {
      final s = TournamentEngine.generate(params(pace: PaceMode.regular));

      // Layer 1: the target schedule.
      expect(s.targetScheduleLastLevel, s.effectivePlannedLevels);

      // Layer 2: the compression schedule sits strictly after it.
      expect(s.compressionFromLevel, s.effectivePlannedLevels + 1);

      // Layer 3: the hard ceiling is the last published level.
      expect(s.hardCeilingLevel, s.levels.length);
      expect(s.hardCeilingLevel, greaterThan(s.targetScheduleLastLevel));
    });

    test('compression levels are exactly the tail, and nothing before it', () {
      final s = TournamentEngine.generate(params(pace: PaceMode.regular));
      for (var level = 1; level <= s.levels.length; level++) {
        expect(
          s.isCompressionLevel(level),
          level > s.effectivePlannedLevels,
          reason: 'level $level',
        );
      }
    });

    test('the ceiling is reached only at the final level', () {
      final s = TournamentEngine.generate(params(pace: PaceMode.regular));
      expect(s.isAtHardCeiling(s.levels.length - 1), isFalse);
      expect(s.isAtHardCeiling(s.levels.length), isTrue);
      // Framework §13: the ceiling must make an uncontrolled extension
      // impossible, so there is nothing published past it.
      expect(s.levels.length, s.hardCeilingLevel);
    });

    test('a level beyond the ladder is not a compression level', () {
      final s = TournamentEngine.generate(params(pace: PaceMode.regular));
      expect(s.isCompressionLevel(s.levels.length + 1), isFalse);
    });
  });

  group('Framework §14 — the calibration loop', () {
    CalibrationRecord record({
      int entrants = 10,
      int rebuys = 5,
      int addOnsTaken = 6,
      int aliveAtAddOnBreak = 8,
      int startingStack = 1000,
      int targetMinutes = 240,
      int actualMinutes = 240,
      int plannedLevels = 12,
      int levelsPlayed = 12,
      int finalBigBlind = 500,
      int playersRemaining = 2,
      int? totalChips,
    }) =>
        CalibrationRecord(
          gameId: 'g',
          gameName: 'Friday',
          finishedAt: DateTime(2026, 9, 28),
          entrants: entrants,
          rebuys: rebuys,
          reEntries: 0,
          addOnsTaken: addOnsTaken,
          aliveAtAddOnBreak: aliveAtAddOnBreak,
          startingStack: startingStack,
          totalChips: totalChips ??
              startingStack * entrants +
                  startingStack * rebuys +
                  startingStack * addOnsTaken,
          targetMinutes: targetMinutes,
          actualMinutes: actualMinutes,
          plannedLevels: plannedLevels,
          levelsPlayed: levelsPlayed,
          finalBigBlind: finalBigBlind,
          playersRemainingAtFinish: playersRemaining,
        );

    test('r = R/N and q = S/N follow the Framework', () {
      final r = record(entrants: 10, rebuys: 5, addOnsTaken: 6, aliveAtAddOnBreak: 8);
      expect(r.rebuyRate, 0.5);
      expect(r.addOnTakeUp, 0.75);
    });

    test('take-up is measured against who could take it, not the whole field',
        () {
      // Six of eight survivors took it. Measuring against all ten entrants
      // would report 60 % and quietly under-forecast every future night.
      final r = record(entrants: 10, addOnsTaken: 6, aliveAtAddOnBreak: 8);
      expect(r.addOnTakeUp, 0.75);
      expect(r.addOnTakeUp, isNot(0.6));
    });

    test('C/X is the Framework §4 normalised supply', () {
      final r = record(
        entrants: 10,
        rebuys: 5,
        addOnsTaken: 6,
        startingStack: 1000,
      );
      // 10 + 5 + 6 = 21 stacks over 10 entrants.
      expect(r.chipsPerEntrantInStacks, closeTo(2.1, 1e-9));
    });

    test('average live stack in BB is C / (live × BB) — Framework §7', () {
      final r = record(
        totalChips: 21000,
        playersRemaining: 3,
        finalBigBlind: 500,
      );
      expect(r.averageLiveStackBBAtFinish, closeTo(14, 1e-9));
    });

    test('the finish delta is the primary result, signed', () {
      expect(record(targetMinutes: 240, actualMinutes: 300).finishDeltaMins, 60);
      expect(record(targetMinutes: 240, actualMinutes: 210).finishDeltaMins, -30);
    });

    test('a night that finished on time offers no late causes', () {
      expect(record(actualMinutes: 240).lateCauseCandidates, isEmpty);
    });

    test('a late night names what the data can see, and admits what it cannot',
        () {
      final causes = record(
        actualMinutes: 330,
        rebuys: 10,
        levelsPlayed: 15,
        plannedLevels: 12,
        playersRemaining: 5,
      ).lateCauseCandidates;
      expect(causes.any((c) => c.contains('Chip inflation')), isTrue);
      expect(causes.any((c) => c.contains('past the planned finish')), isTrue);
      expect(causes.any((c) => c.contains('5 handed')), isTrue);
      // Framework §16: table speed and behaviour are real causes that leave no
      // trace in these numbers. Saying so is more useful than a false
      // attribution.
      expect(causes.last, contains('not measured'));
    });

    test('degenerate records do not divide by zero', () {
      final r = record(
        entrants: 0,
        startingStack: 0,
        aliveAtAddOnBreak: 0,
        playersRemaining: 0,
        finalBigBlind: 0,
        totalChips: 0,
      );
      expect(r.rebuyRate, 0);
      expect(r.addOnTakeUp, 0);
      expect(r.chipsPerEntrantInStacks, 0);
      expect(r.averageLiveStackBBAtFinish, 0);
    });

    test('a record survives a round trip through its map form', () {
      final r = record();
      final back = CalibrationRecord.fromMap(r.toMap());
      expect(back.entrants, r.entrants);
      expect(back.rebuys, r.rebuys);
      expect(back.addOnsTaken, r.addOnsTaken);
      expect(back.totalChips, r.totalChips);
      expect(back.actualMinutes, r.actualMinutes);
      expect(back.addOnTakeUp, r.addOnTakeUp);
    });

    group('§F1 — forecasts learned from the last 8 games', () {
      test('fewer than 8 games keeps the stated defaults', () {
        final few = List.generate(
          7,
          (i) => record(entrants: 10, rebuys: 10, addOnsTaken: 8, aliveAtAddOnBreak: 8),
        );
        expect(CalibrationForecast.addOnTakeUp(few), kAddOnTakeUpRate);
        expect(CalibrationForecast.rebuyRate(few), kExpectedRebuyRate);
      });

      test('8 games or more averages them', () {
        final history = List.generate(
          8,
          (i) => record(entrants: 10, rebuys: 10, addOnsTaken: 8, aliveAtAddOnBreak: 8),
        );
        expect(CalibrationForecast.addOnTakeUp(history), 1.0);
        expect(CalibrationForecast.rebuyRate(history), 1.0);
      });

      test('take-up is clamped to 0–100 %', () {
        final history = List.generate(
          8,
          (i) => record(addOnsTaken: 20, aliveAtAddOnBreak: 8),
        );
        expect(CalibrationForecast.addOnTakeUp(history), lessThanOrEqualTo(1.0));
      });

      test('games with no add-on do not drag the add-on forecast down', () {
        // Eight real add-on nights at 100 %, plus noise from nights that never
        // offered one. The noise must not count as "nobody took it".
        final history = [
          ...List.generate(
            8,
            (i) => record(addOnsTaken: 8, aliveAtAddOnBreak: 8),
          ),
          ...List.generate(
            5,
            (i) => record(addOnsTaken: 0, aliveAtAddOnBreak: 0),
          ),
        ];
        expect(CalibrationForecast.addOnTakeUp(history), 1.0);
      });
    });
  });
}
