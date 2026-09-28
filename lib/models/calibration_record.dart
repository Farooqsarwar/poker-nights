import 'game.dart';
import 'live_game.dart';
import 'tournament.dart';

/// One night's measured outcome — the General Poker Tournament Structuring
/// Framework §14, "Calibration Loop".
///
/// The Framework's closing argument (§16) is that there is no honest formula
/// from starting stack and player count alone that guarantees a finish minute:
/// *"The correct methodology is therefore formula + assumptions +
/// calibration, not formula alone."* The engine supplies the formula and §F1
/// supplies the assumptions. This is the third leg, and until now the app had
/// no version of it — nothing recorded what actually happened, so nothing
/// could be recalibrated against it.
///
/// It also unblocks a rule the specification already asks for and the app
/// never implemented: §F1's add-on take-up learned from *"the last 8 completed
/// games with an add-on"*. That rule needs measured take-up, which is exactly
/// [addOnsTaken] over [aliveAtAddOnBreak].
///
/// **This is a record, not an autopilot.** §E17 row 20 requires that nothing
/// is applied silently, and the Framework §14 instruction is to *"adjust one
/// major variable at a time"* — a human judgement about which variable, not a
/// regression the app runs on its own. So this class measures and reports; it
/// never rewrites a structure.
class CalibrationRecord {
  const CalibrationRecord({
    required this.gameId,
    required this.gameName,
    required this.finishedAt,
    required this.entrants,
    required this.rebuys,
    required this.reEntries,
    required this.addOnsTaken,
    required this.aliveAtAddOnBreak,
    required this.startingStack,
    required this.totalChips,
    required this.targetMinutes,
    required this.actualMinutes,
    required this.plannedLevels,
    required this.levelsPlayed,
    required this.finalBigBlind,
    required this.playersRemainingAtFinish,
  });

  final String gameId;
  final String gameName;
  final DateTime finishedAt;

  /// Framework §14 `N` — original entrants.
  final int entrants;

  /// Framework §14 `R` — total rebuys.
  final int rebuys;
  final int reEntries;

  /// Framework §14 "Add-ons — actual uptake".
  final int addOnsTaken;

  /// Framework §14 `S` — players eligible/alive for the add-on.
  final int aliveAtAddOnBreak;

  /// Framework §3 `X`.
  final int startingStack;

  /// Framework §14 "Total chips" — `N·X + rebuy chips + add-on chips`.
  final int totalChips;

  /// The window the night was designed for, and what it actually took.
  /// Framework §14 calls the finish time "Primary result".
  final int targetMinutes;
  final int actualMinutes;

  /// Framework §14 "Level at checkpoints — Pace".
  final int plannedLevels;
  final int levelsPlayed;

  final int finalBigBlind;
  final int playersRemainingAtFinish;

  /// Framework §3 `r = R/N`.
  double get rebuyRate => entrants == 0 ? 0 : rebuys / entrants;

  /// Framework §3 `q = S/N`, measured against the players who could actually
  /// take it rather than the whole field — which is the quantity §F1's
  /// eight-game rule averages.
  double get addOnTakeUp =>
      aliveAtAddOnBreak == 0 ? 0 : addOnsTaken / aliveAtAddOnBreak;

  /// Framework §4 — normalised supply, `C/X`. Comparable across nights with
  /// different stack sizes, which absolute chip counts are not.
  double get chipsPerEntrantInStacks =>
      (entrants == 0 || startingStack == 0)
          ? 0
          : totalChips / (startingStack * entrants);

  /// Framework §7 — average live stack in big blinds at the finish,
  /// `C / (live players × current BB)`. The Framework's point is that once
  /// rebuys and add-ons have landed, the starting stack no longer describes
  /// the tournament and this does.
  double get averageLiveStackBBAtFinish =>
      (playersRemainingAtFinish == 0 || finalBigBlind == 0)
          ? 0
          : totalChips / (playersRemainingAtFinish * finalBigBlind);

  /// Minutes over (positive) or under (negative) the target. The single number
  /// the calibration loop is trying to drive to zero.
  int get finishDeltaMins => actualMinutes - targetMinutes;

  /// Framework §14: "If the tournament is late, identify whether the cause is
  /// chip inflation, blind growth, level duration, breaks, table speed, or
  /// unusual player behaviour."
  ///
  /// This returns the *candidates the data can distinguish*, most likely
  /// first, and deliberately stops short of picking one — table speed and
  /// player behaviour leave no trace in these numbers, so a confident single
  /// answer would be a guess dressed as a finding.
  List<String> get lateCauseCandidates {
    if (finishDeltaMins <= 0) return const [];
    final out = <String>[];
    if (chipsPerEntrantInStacks > 1.05) {
      out.add(
        'Chip inflation — ${chipsPerEntrantInStacks.toStringAsFixed(2)}× the '
        'starting chips ended up in play.',
      );
    }
    if (levelsPlayed > plannedLevels) {
      out.add(
        'The night ran ${levelsPlayed - plannedLevels} level(s) past the '
        'planned finish.',
      );
    }
    if (playersRemainingAtFinish > 2) {
      out.add(
        'The field was still $playersRemainingAtFinish handed at the finish.',
      );
    }
    out.add('Table speed and player behaviour are not measured here.');
    return out;
  }

  /// Builds the record from a completed game. Returns null while the game is
  /// unfinished or carries no structure to compare against.
  static CalibrationRecord? fromCompletedGame(LiveGame game) {
    if (game.status != LiveGameStatus.completed) return null;
    final structure = game.structure;
    final players = game.players;
    if (players.isEmpty || structure.levels.isEmpty) return null;

    final entrants = players.length;
    final rebuys = players.fold<int>(0, (a, Player p) => a + p.rebuys);
    final reEntries = players.fold<int>(0, (a, Player p) => a + p.reEntries);
    final addOnsTaken = players.where((p) => p.hasAddOn).length;

    // Who could actually have taken the add-on. The window opens at the
    // settlement break, so anyone still in at that point was eligible; a
    // player who busted earlier never had the choice and must not drag the
    // measured take-up down. Without a per-level bust record the best
    // available reading is "still in at the end, plus everyone who did take
    // one" — which never understates eligibility.
    final stillIn = players.where((p) => !p.eliminated).length;
    final aliveAtAddOnBreak =
        addOnsTaken > stillIn ? addOnsTaken : stillIn;

    final levelsPlayed = game.currentLevel.clamp(1, structure.levels.length);
    final finalBigBlind = structure.levels[levelsPlayed - 1].bb;

    final totalChips = structure.startingStack * entrants +
        structure.rebuyStack * rebuys +
        structure.rebuyStack * reEntries +
        structure.addOnStack * addOnsTaken;

    return CalibrationRecord(
      gameId: game.id,
      gameName: game.settings.name,
      finishedAt: DateTime.now(),
      entrants: entrants,
      rebuys: rebuys,
      reEntries: reEntries,
      addOnsTaken: addOnsTaken,
      aliveAtAddOnBreak: aliveAtAddOnBreak,
      startingStack: structure.startingStack,
      totalChips: totalChips,
      targetMinutes: structure.expectedFinishMins,
      actualMinutes: game.actualDurationMins ?? structure.expectedFinishMins,
      plannedLevels: structure.effectivePlannedLevels,
      levelsPlayed: levelsPlayed,
      finalBigBlind: finalBigBlind,
      playersRemainingAtFinish: stillIn,
    );
  }

  Map<String, dynamic> toMap() => {
        'gameId': gameId,
        'gameName': gameName,
        'finishedAt': finishedAt.toIso8601String(),
        'entrants': entrants,
        'rebuys': rebuys,
        'reEntries': reEntries,
        'addOnsTaken': addOnsTaken,
        'aliveAtAddOnBreak': aliveAtAddOnBreak,
        'startingStack': startingStack,
        'totalChips': totalChips,
        'targetMinutes': targetMinutes,
        'actualMinutes': actualMinutes,
        'plannedLevels': plannedLevels,
        'levelsPlayed': levelsPlayed,
        'finalBigBlind': finalBigBlind,
        'playersRemainingAtFinish': playersRemainingAtFinish,
      };

  static CalibrationRecord fromMap(Map<String, dynamic> m) => CalibrationRecord(
        gameId: (m['gameId'] as String?) ?? '',
        gameName: (m['gameName'] as String?) ?? '',
        finishedAt:
            DateTime.tryParse((m['finishedAt'] as String?) ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        entrants: (m['entrants'] as num?)?.toInt() ?? 0,
        rebuys: (m['rebuys'] as num?)?.toInt() ?? 0,
        reEntries: (m['reEntries'] as num?)?.toInt() ?? 0,
        addOnsTaken: (m['addOnsTaken'] as num?)?.toInt() ?? 0,
        aliveAtAddOnBreak: (m['aliveAtAddOnBreak'] as num?)?.toInt() ?? 0,
        startingStack: (m['startingStack'] as num?)?.toInt() ?? 0,
        totalChips: (m['totalChips'] as num?)?.toInt() ?? 0,
        targetMinutes: (m['targetMinutes'] as num?)?.toInt() ?? 0,
        actualMinutes: (m['actualMinutes'] as num?)?.toInt() ?? 0,
        plannedLevels: (m['plannedLevels'] as num?)?.toInt() ?? 0,
        levelsPlayed: (m['levelsPlayed'] as num?)?.toInt() ?? 0,
        finalBigBlind: (m['finalBigBlind'] as num?)?.toInt() ?? 0,
        playersRemainingAtFinish:
            (m['playersRemainingAtFinish'] as num?)?.toInt() ?? 0,
      );
}

/// §F1's forecast rules, learned from measured nights (Framework §14).
///
/// Both rules follow the specification exactly, including its boundaries:
/// the last **8** games, and the stated default when there are fewer.
abstract final class CalibrationForecast {
  /// §F1: *"from the last 8 completed games with an add-on,
  /// `takeUp = mean(addOnsTaken / playersAliveAtTheAddOnBreak)`, clamped
  /// 0–100 %; fewer than 8 → the default 70 %."*
  ///
  /// The specification is explicit about the limit of this number: it changes
  /// only the chips-in-play estimate `C`, and **never** the chip bank check,
  /// which assumes every player takes the add-on. A bank sized on a 70 %
  /// forecast fails on the night everybody takes one.
  static double addOnTakeUp(List<CalibrationRecord> history) {
    final withAddOn = history
        .where((r) => r.aliveAtAddOnBreak > 0 && r.addOnsTaken > 0)
        .toList()
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    if (withAddOn.length < 8) return kAddOnTakeUpRate;
    final last8 = withAddOn.take(8);
    final mean =
        last8.fold<double>(0, (a, r) => a + r.addOnTakeUp) / last8.length;
    return mean.clamp(0.0, 1.0);
  }

  /// The same shape for the rebuy rate `r`. §F1 states the eight-game rule for
  /// the add-on; applying it to rebuys is the Framework §14 instruction
  /// ("Estimate rebuy rate r ... from historical play") using the same window,
  /// so the two forecasts move on the same evidence rather than on two
  /// different definitions of "recent".
  static double rebuyRate(List<CalibrationRecord> history) {
    final withRebuys = history.where((r) => r.entrants > 0).toList()
      ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    if (withRebuys.length < 8) return kExpectedRebuyRate;
    final last8 = withRebuys.take(8);
    final mean =
        last8.fold<double>(0, (a, r) => a + r.rebuyRate) / last8.length;
    return mean < 0 ? 0 : mean;
  }
}
