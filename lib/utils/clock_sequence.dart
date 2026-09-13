import '../models/tournament.dart';

/// One segment of a running clock: a blind level, or a break between two.
///
/// §8 made breaks first-class in the structure, and a clock that treats them
/// as an attribute of the preceding level ends up with a boolean flag and two
/// countdowns fighting over the same variable. A break is simply the next
/// thing that happens, so it gets to be a segment like any other.
class ClockSegment {
  const ClockSegment.level(this.level)
      : breakDurationMins = null,
        afterLevel = null;

  const ClockSegment.breakAfter({
    required int this.afterLevel,
    required int this.breakDurationMins,
  }) : level = null;

  /// The level being played, or null on a break.
  final BlindLevel? level;

  /// Break length in minutes, or null on a level.
  final int? breakDurationMins;

  /// The level this break follows. Null on a level.
  final int? afterLevel;

  bool get isBreak => level == null;

  /// How long this segment runs, in seconds.
  int get seconds =>
      (level?.durationMins ?? breakDurationMins ?? 0) * 60;

  /// What to put on the clock's headline.
  String get label => isBreak ? 'Break' : 'Level ${level!.level}';
}

/// Flattens a structure into the order a clock actually plays it.
///
/// The point of doing this up front rather than deciding at each rollover is
/// that "what comes next" becomes an index, not a branch. The end of the list
/// is the end of the tournament: a clock that loops back to level one because
/// nobody told it to stop is worse than one that simply stops.
abstract final class ClockSequence {
  static List<ClockSegment> build(TournamentStructure structure) {
    final levels = plannedLevels(structure);
    final segments = <ClockSegment>[];

    for (final level in levels) {
      segments.add(ClockSegment.level(level));
      for (final b in structure.breaks) {
        if (b.afterLevel == level.level && b.durationMins > 0) {
          segments.add(
            ClockSegment.breakAfter(
              afterLevel: b.afterLevel,
              breakDurationMins: b.durationMins,
            ),
          );
        }
      }
    }

    // A break scheduled after the last played level is dropped by the loop
    // above only if that level was never reached; one scheduled after the
    // final level would leave the clock on a break with nothing following it,
    // which is not a break — it is the end.
    while (segments.isNotEmpty && segments.last.isBreak) {
      segments.removeLast();
    }

    return segments;
  }

  /// The levels a structure is actually planned to play.
  ///
  /// `plannedLevels` is 0 on structures generated before the field existed,
  /// and the engine can emit more levels than it plans to use as headroom.
  /// Both cases mean "play all of them".
  static List<BlindLevel> plannedLevels(TournamentStructure structure) {
    final n = structure.plannedLevels;
    if (n <= 0 || n > structure.levels.length) return structure.levels;
    return structure.levels.take(n).toList();
  }

  /// The level in play at [index], or the one the break at [index] follows.
  ///
  /// During a break the blinds that matter are the ones about to start, but
  /// the level that just finished is what everybody remembers playing — so
  /// callers get both rather than having this guess for them.
  static BlindLevel? levelAt(List<ClockSegment> segments, int index) {
    if (index < 0 || index >= segments.length) return null;
    final segment = segments[index];
    if (!segment.isBreak) return segment.level;
    for (var i = index - 1; i >= 0; i--) {
      if (!segments[i].isBreak) return segments[i].level;
    }
    return null;
  }

  /// The next level to be played after [index], or null if there is none.
  static BlindLevel? nextLevelAfter(List<ClockSegment> segments, int index) {
    for (var i = index + 1; i < segments.length; i++) {
      if (!segments[i].isBreak) return segments[i].level;
    }
    return null;
  }
}
