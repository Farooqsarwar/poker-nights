import '../models/tournament.dart';
import 'tournament_engine.dart';

/// The one place the structure builder's host choices meet the engine.
///
/// The builder (quick game, create structure, free blind generator) and the
/// provider's Recalculate / Start paths all call this, so a forced stack,
/// pinned levels and typed level minutes mean the same thing everywhere and a
/// Recalculate can never undo them. It only composes the existing engine API
/// ([TournamentEngine.recalculate]) — no engine change.

/// Why [pins] cannot be solved around, or null when they can. The engine
/// silently falls back to the unpinned ladder for an unsolvable set, which would
/// make a pin look applied when it is not, so the builder checks first.
String? validatePins(List<LevelPin> pins, {int? levelCount}) {
  final sorted = [...pins]..sort((a, b) => a.level - b.level);
  for (final p in sorted) {
    if (p.sb <= 0 || p.bb <= 0) return 'Level ${p.level}: blinds must be above 0.';
    if (p.sb >= p.bb) {
      return 'Level ${p.level}: the small blind must be below the big blind.';
    }
    if (levelCount != null && (p.level < 1 || p.level > levelCount)) {
      return 'Level ${p.level} is outside the structure.';
    }
    final m = p.durationMins;
    if (m != null &&
        (m < TournamentEngine.kMinLevelDurationMins ||
            m > TournamentEngine.kMaxLevelDurationMins)) {
      return 'Level ${p.level}: minutes must be between '
          '${TournamentEngine.kMinLevelDurationMins} and '
          '${TournamentEngine.kMaxLevelDurationMins}.';
    }
  }
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].bb <= sorted[i - 1].bb) {
      return 'Level ${sorted[i].level} must have a bigger big blind than '
          'level ${sorted[i - 1].level}.';
    }
  }
  return null;
}

/// Generates the structure for [params] and re-solves the unpinned levels
/// around [pins]. Pinned rows keep their typed blinds exactly and their typed
/// minutes; every other level is the engine's.
TournamentStructure solveWithPins(
  TournamentParams params,
  List<LevelPin> pins,
) {
  if (pins.isEmpty) return TournamentEngine.generate(params);
  final base = TournamentEngine.generate(params);
  final usable = [
    for (final p in pins)
      if (p.level >= 1 && p.level <= base.levels.length) p,
  ];
  if (usable.isEmpty || base.isBlocked) return base;
  final solved = TournamentEngine.recalculate(
    params,
    [
      for (final p in usable)
        PinnedLevel(levelNum: p.level, sb: p.sb, bb: p.bb),
    ],
  );
  final byLevel = {for (final p in usable) p.level: p};
  // A pinned row is the host's own: its blinds and minutes are exactly what
  // they typed (the solver rounds a small blind to its ladder, which would
  // otherwise quietly change a typed 37/75 into 40/75).
  return solved.copyWith(
    levels: [
      for (final l in solved.levels)
        if (byLevel[l.level] case final p?)
          l.copyWith(
            sb: p.sb,
            bb: p.bb,
            ante: l.ante != null && params.anteStyle == AnteStyle.bigBlind
                ? p.bb
                : l.ante,
            durationMins: p.durationMins ?? l.durationMins,
            manuallyEdited: true,
          )
        else
          l,
    ],
  );
}
