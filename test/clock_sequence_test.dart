import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/clock_sequence.dart';

/// The public Tournament Clock's ordering (§2 tool, §8 breaks).
///
/// These pin what a clock must never do at a real table: skip a break, sit on
/// a break with nothing after it, or quietly start again at level one.
void main() {
  BlindLevel level(int n, {int mins = 20}) => BlindLevel(
        level: n,
        sb: 25 * n,
        bb: 50 * n,
        ante: null,
        durationMins: mins,
      );

  TournamentStructure structure({
    required int levels,
    int planned = 0,
    List<ScheduledBreak> breaks = const [],
    int mins = 20,
  }) =>
      TournamentStructure(
        startingStack: 10000,
        chipPlan: const [],
        rebuyStack: 10000,
        rebuyChipPlan: const [],
        addOnStack: 10000,
        addOnChipPlan: const [],
        levels: [for (var i = 1; i <= levels; i++) level(i, mins: mins)],
        levelDuration: mins,
        plannedLevels: planned,
        expectedFinishMins: levels * mins,
        prizes: const [],
        prizePool: 0,
        organizerAmount: 0,
        colorUpInstructions: const [],
        warnings: const [],
        breaks: breaks,
      );

  group('the order a clock actually plays', () {
    test('no breaks is just the levels, in order', () {
      final s = ClockSequence.build(structure(levels: 4));
      expect(s.length, 4);
      expect(s.every((seg) => !seg.isBreak), isTrue);
      expect([for (final seg in s) seg.level!.level], [1, 2, 3, 4]);
    });

    test('a break lands after the level it follows, not before', () {
      final s = ClockSequence.build(
        structure(
          levels: 4,
          breaks: const [ScheduledBreak(afterLevel: 2, durationMins: 10)],
        ),
      );
      expect(s.length, 5);
      expect(s[1].level!.level, 2);
      expect(s[2].isBreak, isTrue);
      expect(s[3].level!.level, 3);
    });

    test('several breaks all survive', () {
      final s = ClockSequence.build(
        structure(
          levels: 9,
          breaks: const [
            ScheduledBreak(afterLevel: 3, durationMins: 5),
            ScheduledBreak(afterLevel: 6, durationMins: 15),
          ],
        ),
      );
      expect(s.where((seg) => seg.isBreak).length, 2);
      expect(s.length, 11);
    });

    test('a break carries its own length, not the level duration', () {
      final s = ClockSequence.build(
        structure(
          levels: 3,
          mins: 20,
          breaks: const [ScheduledBreak(afterLevel: 1, durationMins: 15)],
        ),
      );
      expect(s[1].seconds, 15 * 60);
      expect(s[0].seconds, 20 * 60);
    });
  });

  group('the end is the end', () {
    test('a break scheduled after the final level is dropped', () {
      final s = ClockSequence.build(
        structure(
          levels: 3,
          breaks: const [ScheduledBreak(afterLevel: 3, durationMins: 10)],
        ),
      );
      expect(
        s.last.isBreak,
        isFalse,
        reason: 'a clock must never finish on a break — there is nothing to '
            'come back from',
      );
      expect(s.length, 3);
    });

    test('a break for a level that is never played does not appear', () {
      final s = ClockSequence.build(
        structure(
          levels: 12,
          planned: 4,
          breaks: const [ScheduledBreak(afterLevel: 9, durationMins: 10)],
        ),
      );
      expect(s.length, 4);
      expect(s.every((seg) => !seg.isBreak), isTrue);
    });

    test('a zero-length break is not a segment', () {
      final s = ClockSequence.build(
        structure(
          levels: 3,
          breaks: const [ScheduledBreak(afterLevel: 1, durationMins: 0)],
        ),
      );
      expect(s.length, 3);
    });
  });

  group('planned levels decide how much is played', () {
    test('planned below the emitted count truncates', () {
      final s = ClockSequence.build(structure(levels: 20, planned: 8));
      expect(s.length, 8);
    });

    test('planned of zero means play everything', () {
      // Structures generated before the field existed carry 0.
      final s = ClockSequence.build(structure(levels: 6, planned: 0));
      expect(s.length, 6);
    });

    test('planned above the emitted count means play everything', () {
      final s = ClockSequence.build(structure(levels: 6, planned: 99));
      expect(s.length, 6);
    });
  });

  group('what to show on the clock face', () {
    final segments = ClockSequence.build(
      structure(
        levels: 5,
        breaks: const [ScheduledBreak(afterLevel: 2, durationMins: 10)],
      ),
    );

    test('on a level, the current level is that level', () {
      expect(ClockSequence.levelAt(segments, 0)!.level, 1);
      expect(ClockSequence.levelAt(segments, 3)!.level, 3);
    });

    test('on a break, the current level is the one just played', () {
      expect(segments[2].isBreak, isTrue);
      expect(
        ClockSequence.levelAt(segments, 2)!.level,
        2,
        reason: 'the table remembers the level it just finished, not the one '
            'it has not started',
      );
    });

    test('the next level skips over a break', () {
      expect(ClockSequence.nextLevelAfter(segments, 1)!.level, 3);
    });

    test('there is no next level at the end', () {
      expect(ClockSequence.nextLevelAfter(segments, segments.length - 1),
          isNull);
    });

    test('an index outside the run returns nothing rather than throwing', () {
      expect(ClockSequence.levelAt(segments, -1), isNull);
      expect(ClockSequence.levelAt(segments, 999), isNull);
    });
  });

  test('an empty structure produces an empty run', () {
    expect(ClockSequence.build(structure(levels: 0)), isEmpty);
  });
}
