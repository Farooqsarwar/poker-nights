import 'dart:math' as math;

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
        afterLevel = null,
        isRebuyPause = false,
        isHold = false;

  const ClockSegment.breakAfter({
    required int this.afterLevel,
    required int this.breakDurationMins,
  })  : level = null,
        isRebuyPause = false,
        isHold = false;

  const ClockSegment.rebuyPause({
    required int this.afterLevel,
    this.breakDurationMins = 10,
    this.isHold = false,
  })  : level = null,
        isRebuyPause = true;

  /// The level being played, or null on a break.
  final BlindLevel? level;

  /// Break length in minutes, or null on a level.
  final int? breakDurationMins;

  /// The level this break follows. Null on a level.
  final int? afterLevel;

  /// True when this segment is a post-rebuy settlement hold (§F1.2, §F4).
  final bool isRebuyPause;

  /// True when the rebuy pause is an indefinite host hold rather than timed countdown (§F4).
  final bool isHold;

  bool get isBreak => level == null;

  /// How long this segment runs, in seconds (0 for indefinite hold).
  int get seconds => isHold ? 0 : (level?.durationMins ?? breakDurationMins ?? 0) * 60;

  /// What to put on the clock's headline.
  String get label => isRebuyPause
      ? (isHold ? 'Rebuy Settlement (Hold)' : 'Rebuy Settlement')
      : (isBreak ? 'Break' : 'Level ${level!.level}');
}

/// Flattens a structure into the order a clock actually plays it.
///
/// The point of doing this up front rather than deciding at each rollover is
/// that "what comes next" becomes an index, not a branch. The end of the list
/// is the end of the tournament: a clock that loops back to level one because
/// nobody told it to stop is worse than one that simply stops.
abstract final class ClockSequence {
  static List<ClockSegment> build(
    TournamentStructure structure, {
    bool includeRebuyPause = false,
    int rebuyPauseMins = 10,
  }) {
    final levels = plannedLevels(structure);
    final segments = <ClockSegment>[];

    for (final level in levels) {
      segments.add(ClockSegment.level(level));
      if (includeRebuyPause &&
          structure.rebuysCloseLevel == level.level &&
          !structure.breaks.any((b) => b.afterLevel == level.level)) {
        segments.add(
          ClockSegment.rebuyPause(
            afterLevel: level.level,
            breakDurationMins: rebuyPauseMins,
          ),
        );
      }
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

  /// Calculates drift Duration between wall clock time and planned schedule.
  /// A positive drift means the tournament is running behind schedule (taking longer than planned).
  static Duration calculateDrift({
    required DateTime startedAt,
    required DateTime now,
    required List<ClockSegment> segments,
    required int currentSegmentIndex,
    int segmentElapsedSeconds = 0,
  }) {
    var plannedSeconds = 0;
    for (var i = 0; i < currentSegmentIndex && i < segments.length; i++) {
      plannedSeconds += segments[i].seconds;
    }
    plannedSeconds += segmentElapsedSeconds;
    final actualSeconds = now.difference(startedAt).inSeconds;
    return Duration(seconds: actualSeconds - plannedSeconds);
  }

  /// Calculates drift in minutes.
  static int calculateDriftMinutes({
    required DateTime startedAt,
    required DateTime now,
    required List<ClockSegment> segments,
    required int currentSegmentIndex,
    int segmentElapsedSeconds = 0,
  }) =>
      calculateDrift(
        startedAt: startedAt,
        now: now,
        segments: segments,
        currentSegmentIndex: currentSegmentIndex,
        segmentElapsedSeconds: segmentElapsedSeconds,
      ).inMinutes;

  /// Pure client-side late refit: adjusts durations of remaining levels so that
  /// the tournament finishes within [targetRemainingMinutes].
  /// Must only be called from an explicit host action (late-start keep-endBy);
  /// never call silently on tick — Spec F4 forbids silent regen once running.
  static List<ClockSegment> refitRemaining({
    required List<ClockSegment> segments,
    required int fromSegmentIndex,
    required int targetRemainingMinutes,
    int minLevelDurationMins = 5,
  }) {
    if (fromSegmentIndex >= segments.length || targetRemainingMinutes <= 0) {
      return segments;
    }
    final result = List<ClockSegment>.from(segments);

    var remainingBreakMins = 0;
    var remainingLevelCount = 0;
    for (var i = fromSegmentIndex; i < result.length; i++) {
      if (result[i].isBreak) {
        remainingBreakMins += result[i].breakDurationMins ?? 0;
      } else {
        remainingLevelCount++;
      }
    }

    if (remainingLevelCount == 0) return result;

    final availableForLevels = math.max(
      remainingLevelCount * minLevelDurationMins,
      targetRemainingMinutes - remainingBreakMins,
    );
    final newLevelDuration = math.max(
      minLevelDurationMins,
      availableForLevels ~/ remainingLevelCount,
    );

    for (var i = fromSegmentIndex; i < result.length; i++) {
      final seg = result[i];
      if (!seg.isBreak && seg.level != null) {
        final updatedLevel = seg.level!.copyWith(
          durationMins: newLevelDuration,
        );
        result[i] = ClockSegment.level(updatedLevel);
      }
    }
    return result;
  }

  /// Spec F4: Projected finish time accounting for drift.
  static DateTime projectedFinishTime({
    required DateTime startedAt,
    required int plannedMinutes,
    required Duration drift,
  }) =>
      startedAt.add(Duration(minutes: plannedMinutes)).add(drift);

  /// Spec F4: Whether drift has exceeded the ±20 minute alert threshold.
  static bool isDriftSignificant(Duration drift) => drift.inMinutes.abs() >= 20;

  /// Spec F4: Late-start keep end-by refit.
  /// When a tournament starts late by [lateMinutes], compresses the remaining
  /// levels so the tournament still finishes by the target finish time.
  static List<ClockSegment> lateKeepEndBy({
    required List<ClockSegment> segments,
    required int lateMinutes,
    required int totalPlannedMinutes,
    int fromSegmentIndex = 0,
    int minLevelDurationMins = 5,
  }) {
    final targetRemaining = totalPlannedMinutes - lateMinutes;
    return refitRemaining(
      segments: segments,
      fromSegmentIndex: fromSegmentIndex,
      targetRemainingMinutes: math.max(0, targetRemaining),
      minLevelDurationMins: minLevelDurationMins,
    );
  }

  /// Spec F4: Repeat current level by re-inserting it at [currentSegmentIndex].
  static List<ClockSegment> repeatLevel(
    List<ClockSegment> segments,
    int currentSegmentIndex,
  ) {
    if (currentSegmentIndex < 0 || currentSegmentIndex >= segments.length) {
      return segments;
    }
    final result = List<ClockSegment>.from(segments);
    result.insert(currentSegmentIndex + 1, segments[currentSegmentIndex]);
    return result;
  }

  /// Spec F4: Add extra [minutesToAdd] to a specific segment.
  static List<ClockSegment> addMinutesToSegment({
    required List<ClockSegment> segments,
    required int segmentIndex,
    required int minutesToAdd,
  }) {
    if (segmentIndex < 0 || segmentIndex >= segments.length || minutesToAdd <= 0) {
      return segments;
    }
    final result = List<ClockSegment>.from(segments);
    final seg = result[segmentIndex];
    if (seg.isBreak) {
      result[segmentIndex] = ClockSegment.breakAfter(
        afterLevel: seg.afterLevel ?? 0,
        breakDurationMins: (seg.breakDurationMins ?? 0) + minutesToAdd,
      );
    } else if (seg.level != null) {
      result[segmentIndex] = ClockSegment.level(
        seg.level!.copyWith(durationMins: seg.level!.durationMins + minutesToAdd),
      );
    }
    return result;
  }
}
