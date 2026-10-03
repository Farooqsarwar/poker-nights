import 'payout_bridge.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/chip_color.dart';
import '../models/tournament.dart';
import '../models/tournament_format.dart';

/// Thrown when a chip set contains two colours with the same value
/// (spec User Flow §12.4 — duplicates are rejected, not warned).
class DuplicateChipValueException implements Exception {
  const DuplicateChipValueException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// §11.4. The two structures a shootout actually plays.
///
/// Deliberately not one structure with a multiplier. §39 deviation 11: "Shootout
/// is two Freeze Out generations, not a duration multiplier" — every table plays
/// its own short Freeze Out, and the survivors play another one. There is no
/// third growth formula to get wrong, which is the point.
class ShootoutPlan {
  const ShootoutPlan({
    required this.tables,
    required this.playersPerTable,
    required this.advancePerTable,
    required this.stageA,
    required this.stageB,
  });

  /// How many independent tables Stage A runs at once.
  final int tables;

  /// Seats at one Stage A table — `ceil(field / tables)`, so the last table is
  /// the short one rather than an overfull one.
  final int playersPerTable;

  /// Survivors each table sends up. One, per §11.4.
  final int advancePerTable;

  /// The structure EVERY Stage A table plays, independently and concurrently.
  /// One structure, not one per table: the tables are identical by
  /// construction, and a shootout where the tables played different blinds
  /// would not be a shootout.
  final TournamentStructure stageA;

  /// The final table, played by the `tables × advancePerTable` survivors.
  final TournamentStructure stageB;

  /// Seats at the final table.
  int get finalists => tables * advancePerTable;
}

/// Spec v3.1 §F1.2 STYLE — turbo/standard/deep. (The spec defines exactly
/// these three; there is no "fast" fourth tier here.)
///
/// Not to be confused with [PaceMode], which is §F1.2's OTHER table, `PACE`.
/// STYLE sets the target opening depth and growth; PACE sets level length and
/// the growth ceiling, and is chosen by the host.
enum PaceStyle { turbo, standard, deep }

/// The result of [TournamentEngine.solveUniformLevels] (§F1.3).
typedef PaceSolveResult = ({
  /// `e` — levels to the target finish, excluding the spare tail.
  int levels,

  /// `g` — the growth applied per level, one value for the whole night.
  double growth,

  /// `L` — minutes per level.
  int levelMinutes,

  /// §F1.3 `fits`. False means the night runs over, and `paceOptions` must
  /// warn rather than silently accept it.
  bool fits,

  /// Minutes the structure needs, levels only.
  int minutesNeeded,

  /// Minutes over the window; zero when it fits.
  int overBy,
});

/// One pace's offer in [TournamentEngine.paceOptions] (§F1.3, C1 step 4).
typedef PaceOption = ({
  PaceMode pace,
  int openingBB,
  int openingSB,

  /// Starting depth in big blinds — `D0 = X / B0` (Framework §3).
  double startingDepthBB,
  int levels,
  int levelMinutes,
  bool fits,
  int overBy,

  /// Minutes from the start to the projected finish, breaks included.
  int finishMins,

  /// True when the chip bank can actually supply this option.
  bool bankOk,
});

/// §F1.3 `paceOptions` — the three offers plus the recommendation, or a
/// warning with named choices when nothing fits.
typedef PaceOptions = ({
  List<PaceOption> options,

  /// The slowest of Deep, then Regular that fits AND whose bank is OK.
  /// Null when nothing qualifies — turbo is never recommended.
  PaceMode? recommended,

  /// Set only when no pace fits. The host picks; nothing is applied silently.
  String? warning,

  /// §F1.3's named choices: `later`, `noAddOn`, `turbo`.
  List<String> choices,
});

/// A host-fixed level for [TournamentEngine.resolveAroundPins] (Build Spec
/// v3.1 §F1.12) — an editor pins a level's own sb/bb and the ladder around it
/// is re-solved.
class PinnedLevel {
  const PinnedLevel({required this.levelNum, required this.sb, required this.bb});

  /// 1-indexed level number.
  final int levelNum;
  final int sb;
  final int bb;
}

/// Tournament structure engine — a faithful Dart port of the web app's
/// `src/engine/tournament.ts`. Used to generate mock structures for the UI.
///
/// Engine version is tracked for deterministic structure regeneration and
/// future compatibility (tech spec §4.1 — shared, versioned module).
class TournamentEngine {
  TournamentEngine._();

  /// Semantic version of this engine implementation. Persisted with each
  /// generated structure so the UI can detect engine upgrades.
  static const String engineVersion = '2.2.0';

  /// §10.1. How much to stretch or compress level length for this group, based
  /// on how their last nights actually ran. Null means "not enough evidence" or
  /// "the estimate is already good" — and null must mean the host is not asked.
  static double? paceAdjustmentFor({
    required List<int> actualDurationMins,
    required List<int> estimatedDurationMins,
  }) {
    if (actualDurationMins.length < 5) return null;
    if (actualDurationMins.length != estimatedDurationMins.length) return null;

    double sumOverage = 0;
    for (int i = 0; i < actualDurationMins.length; i++) {
      sumOverage += (actualDurationMins[i] - estimatedDurationMins[i]);
    }
    double meanOverage = sumOverage / actualDurationMins.length;
    if (meanOverage.abs() < 15) return null;

    double sumEstimated = 0;
    for (int i = 0; i < estimatedDurationMins.length; i++) {
      sumEstimated += estimatedDurationMins[i];
    }
    double meanEstimated = sumEstimated / estimatedDurationMins.length;
    if (meanEstimated == 0) return null;

    double ratio = meanOverage / meanEstimated;
    return ratio.clamp(-0.20, 0.20);
  }

  /// A rebuy or add-on box must stretch to roughly two takers per seat before
  /// the host is handing out chips that are already in someone's stack.
  static const double lateEntryReserveMultiplier = 2;

  static const Map<String, List<ChipColor>> chipPresets = {
    'Standard 300': [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
      ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
      ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 20),
    ],
    'Standard 500': [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
      ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 60),
      ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 40),
    ],
    'Home Set (4 colour)': [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 5, quantity: 100),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 80),
      ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 100, quantity: 60),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 30),
    ],
  };

  static List<String> get presetNames => chipPresets.keys.toList();

  static List<ChipColor> getPreset(String name) =>
      chipPresets[name] ?? chipPresets['Standard 300']!;

  /// Value ladder used to recommend denominations for unnumbered home chips
  /// (checklist 10-023). Starts at 5 — the workhorse chip — rather than 1, so
  /// the most-available colour maps to the denomination expected to be used
  /// most, not automatically the absolute lowest value (10-024).
  static const List<int> valueLadder = [5, 25, 100, 500, 1000, 5000];

  /// Build Spec v3.1 §F1.5 step 2 — bank-aware S_max ceiling.
  static double sMax({
    required int bankValue,
    required int draws,
    required int players,
    double addOnMult = 1.25,
    double bonusPct = 0.125,
  }) {
    final denom = draws + (addOnMult * players) + (bonusPct * players);
    if (denom <= 0) return 0;
    return bankValue / denom;
  }

  /// Build Spec v3.1 §F1.11 — fewest chips to make an amount, largest-chip-first.
  static Map<int, int> fewestChips(
    int amount,
    List<int> values, {
    Map<int, int>? limits,
  }) {
    if (amount <= 0) return const {};
    final unique = <int>[];
    for (final v in [...values.where((v) => v > 0)]..sort((a, b) => b.compareTo(a))) {
      if (!unique.contains(v)) unique.add(v);
    }
    if (unique.isEmpty) return const {};

    var bestCount = 2147483647; // int.max, safe for JavaScript number representation
    final best = <int, int>{};
    final counts = <int, int>{for (final v in unique) v: 0};

    void dfs(int index, int remaining, int used) {
      if (remaining == 0) {
        if (used < bestCount) {
          bestCount = used;
          best.clear();
          for (final entry in counts.entries) {
            if (entry.value > 0) best[entry.key] = entry.value;
          }
        }
        return;
      }
      if (index >= unique.length) return;
      if (used + (remaining / unique[index]).ceil() >= bestCount) return;

      final value = unique[index];
      final maxByValue = limits != null && limits.containsKey(value)
          ? limits[value]!
          : (remaining ~/ value) + 1;
      final maxTake = maxByValue.clamp(0, remaining ~/ value);
      for (var take = maxTake; take >= 0; take--) {
        counts[value] = take;
        final nextRemaining = remaining - (take * value);
        if (nextRemaining < 0) continue;
        final nextUsed = used + take;
        if (take > 0 || index == unique.length - 1) {
          dfs(index + 1, nextRemaining, nextUsed);
        } else {
          dfs(index + 1, nextRemaining, nextUsed);
        }
      }
      counts[value] = 0;
    }

    dfs(0, amount, 0);
    return best;
  }

  /// Build Spec v3.1 §F1.5 — score one composition, lower is better.
  static double scoreComposition(List<int> counts, List<int> values, int totalChips) {
    if (counts.isEmpty || values.isEmpty) return double.infinity;
    final present = <({int value, int count})>[];
    for (var i = 0; i < counts.length && i < values.length; i++) {
      if (counts[i] > 0) {
        present.add((value: values[i], count: counts[i]));
      }
    }
    if (present.isEmpty) return double.infinity;
    present.sort((a, b) => a.value.compareTo(b.value));

    var pen = 0.0;

    // 1. Smallest chip: target count t = 12 if v1/v0 = 4 else 10
    //    pen += ((c0 − t)/2)² + (c0 < 8 || c0 > 16 ? 25 : 0)
    final c0 = present.first.count;
    final v0 = present.first.value;
    final target = (present.length >= 2 && present[1].value == 4 * v0) ? 12 : 10;
    final diff = (c0 - target) / 2.0;
    pen += diff * diff + (c0 < 8 || c0 > 16 ? 25.0 : 0.0);

    // 2. Change coverage: Walking denominations low to high, if sum of lower denoms < 2 × current chip value, add +15
    var lowerSum = present.first.value * present.first.count;
    for (var i = 1; i < present.length; i++) {
      final vi = present[i].value;
      if (lowerSum < 2 * vi) {
        pen += 15.0;
      }
      lowerSum += vi * present[i].count;
    }

    // 3. Total chip count sanity:
    //    3 points per chip under 20, 3 points per chip over 40, plus flat +2 if total not in 25–35 sweet spot
    final n = totalChips > 0 ? totalChips : present.fold<int>(0, (s, e) => s + e.count);
    pen += 3.0 * math.max(0, 20 - n) + 3.0 * math.max(0, n - 40) + ((n >= 25 && n <= 35) ? 0.0 : 2.0);

    // 4. Round counts: Denomination count divisible by 5 or 2 gets -0.5 discount
    for (final e in present) {
      if (e.count % 5 == 0 || e.count % 2 == 0) {
        pen -= 0.5;
      }
    }

    return pen;
  }

  /// Recommends unique values for unnumbered chips ordered from most-available
  /// to least-available. Keeps printed ordering and existing quantities.
  static List<ChipColor> recommendUnnumberedChipSet(List<ChipColor> ordered) {
    return [
      for (var i = 0; i < ordered.length; i++)
        ordered[i].copyWith(
          value: i < valueLadder.length
              ? valueLadder[i]
              : valueLadder.last *
                    math.pow(10, i - valueLadder.length + 1).toInt(),
        ),
    ];
  }

  /// Practical blind ladder.
  ///
  /// Extended downward from 25/50 so small chip sets have somewhere to start:
  /// 11-015 / 11-016 require openings drawn from the chip set, "including 5/10
  /// and 10/20". 20/50 is deliberately NOT a 2x pair — 11-009 forbids assuming
  /// the small blind is always half the big blind and 11-010 names 20/50 as
  /// permitted, and Technical section 8.4 step 8 wants the SB at 40-50% of BB.
  /// Entries are filtered against the live denominations at generation time so
  /// every blind is actually postable (11-004).
  static const List<List<int>> validBlindLevels = [
    // The low rungs a 1-value chip can post. §F1.6 derives blinds as nice
    // multiples of `2 × cmin` rather than from a fixed table, and this table
    // started at 5/10 — so a chip set holding 1s could never open below 10,
    // and a 100 BB stack had to be 1,000 chips instead of 200.
    //
    // §F1.15's demo night is the case in point: White 1 · Red 5 · Green 25 ·
    // Black 100, ten players, regular pace, specified to open at **1/2** with
    // a 200 stack. Without these rungs the engine opened at 5/10 and 60 BB —
    // turbo depth for a regular night.
    //
    // A set whose smallest chip is 25 still skips every one of these: the
    // selection loop rejects any rung where `sb % minChip != 0`, so no
    // structure can be handed a blind its chips cannot post.
    [1, 2],
    [2, 4],
    [3, 6],
    [4, 8],
    [5, 10],
    [6, 12],
    [10, 20],
    [15, 30],
    [20, 40],
    [25, 50],
    [40, 80],
    [50, 100],
    [60, 120],
    [75, 150],
    [100, 200],
    [150, 300],
    [200, 400],
    [250, 500],
    [300, 600],
    [400, 800],
    [500, 1000],
    [600, 1200],
    [700, 1400],
    [800, 1600],
    [900, 1800],
    [1000, 2000],
    [1100, 2200],
    [1200, 2400],
    [1300, 2600],
    [1400, 2800],
    [1500, 3000],
    [1600, 3200],
    [1700, 3400],
    [1800, 3600],
    [1900, 3800],
    [2000, 4000],
    [2200, 4400],
    [2400, 4800],
    [2600, 5200],
    [2800, 5600],
    [3000, 6000],
  ];

  /// Level durations offered as one-tap presets.
  ///
  /// No longer the only values a structure may use — [TournamentParams
  /// .levelDurationMins] accepts anything in [kMinLevelDurationMins] ..
  /// [kMaxLevelDurationMins]. Bucketing to 10/15/20 meant the level LENGTH was
  /// fixed before the level COUNT was known, so a 4-hour target could only ever
  /// be approximated: 16 levels of 15 is 4h00 by luck, 3h30 is not reachable at
  /// all. Choosing the length directly is what lets the two line up.
  static const List<int> validLevelDurations = [10, 15, 20, 30];

  /// Bounds on a host-chosen level length. Below 3 minutes the blinds move
  /// faster than a hand plays out; above an hour the structure stops being one.
  static const int kMinLevelDurationMins = 3;
  static const int kMaxLevelDurationMins = 60;

  /// Extra levels generated past the target duration so a slow field never
  /// plays off the end of the structure (11-014). They are deliberately
  /// excluded from the finish estimate.
  static const int _spareLevels = 4;

  /// Allowance for the end-of-rebuy settlement pause (User Flow section 4.13).
  /// It has no clock of its own but it is real elapsed time, so 11-031 counts
  /// it in the duration model.
  ///
  /// Build Spec v3.1 §F1.2: "Rebuy pause | 10 min (rebuy and re-entry formats)
  /// | the settlement hold". Was 15, and was added to every format — so a
  /// freeze-out, which has no rebuys to settle, was charged a quarter of an
  /// hour it never spends. Use [settlementPauseFor] rather than this constant
  /// directly; the format is what decides whether it applies at all.
  static const int settlementBreakMins = 10;

  /// §F1.2 — the settlement hold in minutes for a given format. Zero for a
  /// freeze-out and a shootout: there is nothing to settle.
  static int settlementPauseFor(TournamentFormat format) =>
      switch (format) {
        TournamentFormat.rebuy || TournamentFormat.reEntry =>
          settlementBreakMins,
        _ => 0,
      };

  /// Standard blind level lengths. Short events get 10-minute levels so the
  /// admin's speed up/slow down can nudge them to 15/20 later (12-078).
  static int _levelDurationFor(double hours) =>
      hours <= 3 ? 10 : (hours <= 5 ? 15 : 20);

  /// Default table capacity used to size individual antes (tech spec §8.5:
  /// "Individual ante candidate = big blind divided by expected table size").
  static const int defaultTableSize = 9;

  /// Calibration constant for the final blind target (tech spec §8.3):
  /// targetFinalBB = expectedTotalChips / (2 × this). The default 15 means
  /// heads-up play should begin with the average stack around 15 big blinds.
  ///
  /// Superseded inside [generate] by [kEndTargetKNoAnte] / [kEndTargetKWithAnte]
  /// (Build Spec v3.1 §F1.2/§F1.18: `BB_end = C / K`, K=20 with no ante in
  /// play anywhere on the ladder, K=27 the moment any ante is). Left defined
  /// — unused by the formula now, but still a public calibration constant —
  /// since nothing else in this port has any use for a bare "15".
  static const double targetHeadsUpAverageBB = 15;

  /// Spec v3.1 §F1.2/§F1.18 — the end-of-night target expressed as a
  /// divisor of total chips in play (`BB_end = C / K`) rather than as
  /// "heads-up average stack in BB". An ante speeds up the effective blind
  /// pressure per orbit, so the same total-chip count should produce a
  /// SMALLER final big blind (a larger K) when antes are live.
  static const double kEndTargetKNoAnte = 20;
  static const double kEndTargetKWithAnte = 27;

  /// Spec v3.1 §F1.2/§F1.5/§F1.18 — MIN_PLAYABLE_DEPTH. Below this many big
  /// blinds the opening stack is push-fold from level one, which the spec
  /// treats as a hard floor, not merely a "shallow" warning.
  static const double kMinPlayableDepthBB = 20;

  /// Spec v3.1 §F1.2/§F1.18 — per-style admissible opening-depth bands
  /// (STYLE.turbo/standard/deep, each with its own D/min/max). The engine has
  /// no explicit style selector input, so [paceStyleFor] classifies the
  /// UNCLAMPED continuous depth target the existing duration/player formula
  /// produces, and [admissibleDepthBand] returns that style's band for the
  /// final clamp — replacing the single flat 80-240 BB band every style used
  /// to share.
  static const double _turboAim = 60;
  static const double _standardAim = 100;
  static const double _deepAim = 160;

  /// Classifies a raw (pre-clamp) target depth into the spec's three style
  /// bands, using the midpoints between each pair of aim depths as the
  /// boundary.
  static PaceStyle paceStyleFor(double rawTargetBB) {
    if (rawTargetBB < (_turboAim + _standardAim) / 2) return PaceStyle.turbo;
    if (rawTargetBB < (_standardAim + _deepAim) / 2) return PaceStyle.standard;
    return PaceStyle.deep;
  }

  /// Spec v3.1 §F1.2/§F1.18: turbo 50-70 BB, standard 85-130 BB (aim 100),
  /// deep >=150 BB (aim 160, unbounded above).
  static ({double min, double max}) admissibleDepthBand(PaceStyle style) {
    switch (style) {
      case PaceStyle.turbo:
        return (min: 50, max: 70);
      case PaceStyle.standard:
        return (min: 85, max: 130);
      case PaceStyle.deep:
        return (min: 150, max: double.infinity);
    }
  }

  /// Build Spec v3.1 §F1.8 — recommends whether antes should run at all, and
  /// which style.
  ///
  /// The spec's rule is exactly two branches, and NEVER recommends the
  /// individual style — it is a legal host override (still available via
  /// [AnteStyle.individual]), but the system default is always big-blind
  /// ante once antes are warranted at all:
  ///   * short game, small field (< 3.5h AND <= 6 players) -> no antes;
  ///   * everything else -> big-blind ante.
  ///
  /// Verified against all four of the spec's worked vectors (§F1.8): (6,
  /// 180min) -> none; (6, 240min) -> bb; (10, 180min) -> bb; (12, 270min) ->
  /// bb.
  static AnteRecommendation recommendAnteStyle({
    required int players,
    required double durationHours,
  }) {
    if (durationHours < 3.5 && players <= 6) {
      return const AnteRecommendation(
        enabled: false,
        style: AnteStyle.bigBlind,
        reason: 'A short game with a small field does not need antes — the '
            'blinds create the pressure on their own.',
      );
    }
    return const AnteRecommendation(
      enabled: true,
      style: AnteStyle.bigBlind,
      reason: 'One payment per hand from the big blind — faster at a full '
          'table than collecting from everybody, and the system default '
          'once a game runs long enough to want antes at all.',
    );
  }

  /// Build Spec v3.1 §F1.8 D7 — the individual ante value: 10% of the big
  /// blind, rounded to the nearest denomination actually in play, floored at
  /// one chip.
  ///
  /// Replaces the previous `bb / defaultTableSize` snap (dividing by an
  /// assumed 9-handed table rather than taking a fixed fraction of the BB),
  /// which is not the spec's rule and drifted with table size instead of
  /// blind size.
  static int individualAnteValue(int bb, List<int> chipValuesInPlay) {
    final values = chipValuesInPlay.where((v) => v > 0).toList()..sort();
    if (values.isEmpty) return math.max(1, (bb * 0.10).round());
    final minChip = values.first;
    final target = bb * 0.10;
    var best = minChip;
    var bestDist = (target - minChip).abs();
    for (final v in values) {
      final dist = (target - v).abs();
      if (dist < bestDist) {
        best = v;
        bestDist = dist;
      }
    }
    return math.max(minChip, best);
  }

  static int snapToPracticalBlind(double raw, List<ChipColor> chips) {
    final values = chips.map((c) => c.value).where((v) => v > 0).toList()..sort();
    final minChip = values.isEmpty ? 1 : values.first;
    
    if (raw <= minChip) return minChip;

    int magnitude = 1;
    while (raw / magnitude >= 10) {
      magnitude *= 10;
    }

    // Standard practical blind prefixes used universally in poker.
    final standardPrefixes = [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0];
    
    int bestBlind = (raw / minChip).round() * minChip;
    double minDiff = (bestBlind - raw).abs();

    for (final prefix in standardPrefixes) {
      final candidate = (prefix * magnitude).round();
      if (candidate < minChip || candidate % minChip != 0) continue;
      
      final diff = (candidate - raw).abs();
      // Heavily favor standard poker increments if the difference is reasonable.
      if (diff <= minDiff * 1.5) {
        minDiff = diff;
        bestBlind = candidate;
      }
    }

    return math.max(bestBlind, minChip);
  }

  /// Maximum number of chips of a SINGLE COLOR allocated to one player
  /// in a starting stack, rebuy, or add-on.
  ///
  /// Origin: Physical/UX constraint — a standard chip tray row holds 25 chips.
  /// Exceeding this makes stacks unwieldy and colour-up exchanges impractical.
  /// This value is NOT explicitly mandated by the PNT Technical Specification
  /// or the reference payout schedule; it is a practical tournament-operation
  /// constraint that has been validated as correct for home games.
  /// TODO(product): confirm maxChipsPerPlayer value with spec owner if a
  /// future spec version mandates a different limit.
  ///
  /// Rationale:
  ///  - 25 chips per row is the physical capacity of a standard casino chip
  ///    tray. Keeping to this limit means each colour in a player's starting
  ///    stack fits in exactly one tray row, making distribution, counting, and
  ///    colour-up exchanges fast and error-free.
  ///  - Lowering the value reduces stack size options; raising it risks stacks
  ///    that exceed physical tray capacity.
  ///
  /// Changing this value affects:
  ///  - Initial stack composition (fewer large-denomination chips if lowered).
  ///  - Rebuy and add-on chip counts.
  ///  - Colour-up exchange timing (chip-plan logic).
  ///  - Physical chip inventory requirements.
  ///
  /// Validation: values outside [1, 100] are rejected at structure-generation
  /// time via [_validateMaxChipsPerPlayer]. A warning is logged if the value
  /// deviates from the production default of 25.
  ///
  /// Configurable: this constant is the compile-time default. To override per
  /// tournament, pass the desired value through TournamentParams.maxChipsPerPlayer
  /// (Firestore-driven override) — add that field when operator configurability
  /// is required. Until then, 25 is used universally.
  static const int maxChipsPerPlayer = 25;

  // NOTE: this class used to carry a second, v11-addendum-based opening-depth
  // band (`kMinTargetBBDepth`/`kMaxTargetBBDepth` + an
  // `admissibleDepthBand(double target)` keyed off [TournamentStyle]) that
  // did the same job as [admissibleDepthBand] above (turbo/standard/deep
  // band lookup for the solver's target-depth clamp) but with different,
  // pre-Build-Spec-v3.1 numbers. Dart does not allow two members named
  // `admissibleDepthBand` regardless of parameter type, and [generate] now
  // clamps against the Build Spec v3.1 §F1.2/§F1.18-verified [PaceStyle]
  // band exclusively, so the older duplicate was removed rather than kept
  // as dead, misleading code. [TournamentStyle] itself (in tournament.dart)
  // is unaffected and still drives the post-hoc style label shown to the
  // host via [_styleNarrative] / `chosenStyle` below — only the SOLVER'S
  // depth-clamp band changed.

  /// Validates [value] as a legal maxChipsPerPlayer limit. Throws an
  /// [ArgumentError] if out of range [1, 100].
  static void _validateMaxChipsPerPlayer(int value) {
    if (value < 1 || value > 100) {
      throw ArgumentError.value(
        value,
        'maxChipsPerPlayer',
        'Must be in the range 1–100. Default is 25 (standard chip-tray row depth).',
      );
    }
    if (value != 25) {
      // ignore: avoid_print
      // Coverage: non-default value in use — confirm this is intentional.
      assert(
        false,
        'WARNING: maxChipsPerPlayer=$value deviates from the production default of 25. '
        'Verify this is intentional for the current venue.',
      );
    }
  }

  /// Test-only wrapper exposing [_validateMaxChipsPerPlayer] for unit tests.
  @visibleForTesting
  static void validateMaxChipsPerPlayerForTest(int value) =>
      _validateMaxChipsPerPlayer(value);

  /// Recommended add-on CHIP AMOUNT for the live table.
  ///
  /// 09-032 splits this the other way round from how it shipped: the admin
  /// enters only the PRICE (defaulting to the buy-in, 09-033) and the engine
  /// recommends the chip amount. The add-on stack was instead pinned to one
  /// full starting stack at generation time while the settlement screen
  /// suggested a price from stack depth — the inverse of the specification.
  ///
  /// Derived from the live figures User Flow section 4.13 names: average
  /// stack, big blind, remaining players and total chips. An add-on should be
  /// worth taking without dwarfing the table, so it targets the larger of the
  /// current average stack and 25 big blinds, and is capped at twice the
  /// starting stack.
  static int recommendedAddOnStack({
    required int startingStack,
    required int totalChipsInPlay,
    required int playersRemaining,
    required int currentBB,
    required List<ChipColor> chips,
  }) {
    if (startingStack <= 0) return 0;
    final avg = playersRemaining > 0
        ? totalChipsInPlay ~/ playersRemaining
        : startingStack;
    var target = math.max(avg, currentBB > 0 ? currentBB * 25 : startingStack);
    target = math.min(target, startingStack * 2);
    target = math.max(target, startingStack ~/ 2);
    // Snap to something the box can actually hand over.
    final values = chips.map((c) => c.value).where((v) => v > 0).toList()
      ..sort();
    final unit = values.isEmpty ? 1 : values.first;
    final snapped = (target / unit).round() * unit;
    return snapped <= 0 ? startingStack : snapped;
  }

  /// Physical composition of one [stack] handed out at the CURRENT level.
  ///
  /// 10-041 / 10-043 and Technical section 7.4: a rebuy keeps the same total
  /// value, but its composition changes as blinds grow — "use fewer obsolete
  /// small chips and more medium/high chips while keeping enough chips to post
  /// the current blinds easily". The stored `rebuyChipPlan` is generated once
  /// at setup, so a level-9 rebuy was being handed out in level-1 chips; live
  /// screens call this instead.
  ///
  /// [currentBB] drives which denominations count as obsolete: anything below
  /// a tenth of the big blind is skipped unless it is needed to make the total
  /// exact, and at least a few blind-payable chips are always included.
  static List<ChipPlanEntry> chipPlanAtLevel({
    required int stack,
    required List<ChipColor> chips,
    required int currentBB,
    int playersRemaining = 1,
  }) {
    if (stack <= 0 || chips.isEmpty) return const [];
    final obsoleteBelow = currentBB > 0 ? currentBB ~/ 10 : 0;
    final usable = chips
        .where((c) => c.value > 0 && c.value >= obsoleteBelow)
        .toList();
    // Never strip the set bare — if the filter removed everything, fall back
    // to the full set so the total can still be made exactly.
    final source = usable.isEmpty ? chips : usable;
    final plan = _buildChipPlan(
      stack,
      source,
      math.max(1, playersRemaining),
      1.0,
      smallBlind: currentBB > 0 ? currentBB ~/ 2 : 0,
    );
    final covered = plan.fold<int>(0, (a, e) => a + e.count * e.value);
    if (covered >= stack) return plan;
    // Shortfall: top up from the full set so the declared value is exact
    // (23-002 — a rebuy stack equals the starting stack in value).
    return _buildChipPlan(
      stack,
      chips,
      math.max(1, playersRemaining),
      1.0,
      smallBlind: currentBB > 0 ? currentBB ~/ 2 : 0,
    );
  }

  /// Builds one player's physical stack out of the host's chips.
  ///
  /// Technical section 7.3 asks for a SCORED ENUMERATION over practical chip
  /// combinations rather than a single greedy pass, judged on
  /// `early_blind_payability + counting_simplicity + stack_aesthetics +
  /// rebuy_reserve_health + colour_up_efficiency - excessive_chip_count`.
  ///
  /// Greedy top-down (the previous implementation) cannot satisfy that. It
  /// produced the failure the client reported from a real game: a stack of
  /// seven high-value chips and nothing small enough to post the small blind
  /// with. Filling from the top is locally optimal for chip COUNT and pessimal
  /// for payability, and a single fixed change seed in front of it only moved
  /// the problem — it ate the per-colour headroom the final top-up needed, so
  /// exact coverage was lost and the solver fell back to absurd stacks
  /// (measured: 1 BB).
  ///
  /// What runs now is the enumeration. The only real degree of freedom is how
  /// much change to reserve before filling, so the search walks a ladder of
  /// reserve sizes across the three lowest blind-payable denominations,
  /// completes each one top-down, and scores the finished stacks. The all-zero
  /// reserve is one of the candidates, so this can never do worse than the
  /// plain greedy fill it replaces, and the "rebuild without the seed"
  /// fallback the old code needed is gone with it.
  ///
  /// [smallBlind] is what makes a chip "change": denominations at or below it
  /// can post the blind, denominations strictly below it can make change for
  /// it. With no blind context (0) there is nothing to be payable FOR, so the
  /// search collapses to the single unseeded fill.
  ///
  /// PERFORMANCE. The stack solver calls this thousands of times while walking
  /// candidate depths, so the inner loop works on parallel `List<int>` buffers
  /// allocated once per call rather than on maps of colour names — the first
  /// cut of this enumeration did the latter and took 1.4 SECONDS per
  /// `generate`, which is a visible freeze on every settings save. Only the
  /// winning candidate is ever turned into [ChipPlanEntry] objects.
  static List<ChipPlanEntry> _buildChipPlan(
    int targetStack,
    List<ChipColor> chips,
    int playerCount,
    double reserveMultiplier, {
    int smallBlind = 0,
  }) {
    if (targetStack <= 0) return const [];
    final sorted = [...chips.where((c) => c.value > 0)]
      ..sort((a, b) => a.value - b.value);
    final n = sorted.length;
    if (n == 0) return const [];

    // Guard the divisor: a zero head-count (e.g. the structure estimate the
    // admin triggers the instant check-in opens, before anyone has checked in)
    // made `quantity / 0` evaluate to Infinity, and `Infinity.floor()` throws
    // `UnsupportedError: Infinity` — crashing the tap instead of producing a
    // plan. One seat is the smallest meaningful divisor.
    final perPlayerDivisor = math.max(1.0, playerCount * reserveMultiplier);

    final values = List<int>.generate(n, (i) => sorted[i].value);
    final caps = List<int>.generate(
      n,
      (i) => math.min(
        (sorted[i].quantity / perPlayerDivisor).floor(),
        maxChipsPerPlayer,
      ),
    );

    // How many of the lowest denominations can pay the small blind. Only the
    // three lowest are worth reserving: above that a chip is not change, it is
    // just a smaller way of holding the stack.
    var payableCount = 0;
    if (smallBlind > 0) {
      while (payableCount < n &&
          payableCount < 3 &&
          values[payableCount] <= smallBlind) {
        payableCount++;
      }
    }

    // Reserve ladders, coarsest first. Even numbers only — a stack that pays
    // blinds in pairs is easier to count down than one holding sevens.
    const ladder0 = [0, 4, 6, 8, 10, 12];
    const ladder1 = [0, 2, 4, 6, 8];
    const ladder2 = [0, 2, 4];

    final counts = List<int>.filled(n, 0);
    final bestCounts = List<int>.filled(n, 0);
    var bestScore = double.negativeInfinity;
    var haveBest = false;

    void consider(int r0, int r1, int r2) {
      final covered = _fillStack(
        targetStack,
        values,
        caps,
        counts,
        payableCount,
        r0,
        r1,
        r2,
      );
      final score = _scoreStack(
        counts,
        values,
        targetStack,
        covered,
        smallBlind,
      );
      if (!haveBest || score > bestScore) {
        bestScore = score;
        haveBest = true;
        bestCounts.setAll(0, counts);
      }
    }

    if (payableCount == 0) {
      consider(0, 0, 0);
    } else {
      for (final a in ladder0) {
        for (final b in payableCount > 1 ? ladder1 : const [0]) {
          for (final c in payableCount > 2 ? ladder2 : const [0]) {
            consider(a, b, c);
          }
        }
      }
    }

    final plan = <ChipPlanEntry>[];
    for (var i = n - 1; i >= 0; i--) {
      if (bestCounts[i] > 0) {
        plan.add(
          ChipPlanEntry(
            color: sorted[i].color,
            hex: sorted[i].hex,
            value: sorted[i].value,
            count: bestCounts[i],
          ),
        );
      }
    }
    return plan;
  }

  /// Completes one candidate stack into [counts] and returns its total value.
  ///
  /// Lays down the requested change reserve across the lowest [payableCount]
  /// denominations, fills the rest top-down, then tops up from the smallest
  /// denomination so the declared value is exact (23-002).
  static int _fillStack(
    int targetStack,
    List<int> values,
    List<int> caps,
    List<int> counts,
    int payableCount,
    int r0,
    int r1,
    int r2,
  ) {
    final n = values.length;
    for (var i = 0; i < n; i++) {
      counts[i] = 0;
    }
    var remaining = targetStack;

    for (var i = 0; i < payableCount; i++) {
      final want = i == 0
          ? r0
          : i == 1
              ? r1
              : r2;
      if (want <= 0) continue;
      var use = want;
      if (use > caps[i]) use = caps[i];
      final affordable = remaining ~/ values[i];
      if (use > affordable) use = affordable;
      if (use > 0) {
        counts[i] = use;
        remaining -= use * values[i];
      }
    }

    for (var i = n - 1; i >= 0; i--) {
      final headroom = caps[i] - counts[i];
      if (headroom <= 0) continue;
      var use = remaining ~/ values[i];
      if (use > headroom) use = headroom;
      if (use > 0) {
        counts[i] += use;
        remaining -= use * values[i];
      }
    }

    // Any residue smaller than the cheapest chip already placed can only be
    // absorbed by rounding up on the smallest denomination.
    if (remaining > 0) {
      final headroom = caps[0] - counts[0];
      if (headroom > 0) {
        var extra = (remaining + values[0] - 1) ~/ values[0];
        if (extra > headroom) extra = headroom;
        counts[0] += extra;
        remaining -= extra * values[0];
      }
    }

    return targetStack - remaining;
  }

  /// Technical section 7.3's scoring terms, as a single comparable number.
  ///
  /// Exactness is not a term but a gate: a stack that is not worth what it
  /// says is disqualified outright, because every downstream figure — the
  /// prize pool, the average stack, the colour-up — is computed from the
  /// declared value. Missing the target by any amount outranks every
  /// aesthetic consideration there is.
  static double _scoreStack(
    List<int> counts,
    List<int> values,
    int targetStack,
    int covered,
    int smallBlind,
  ) {
    var score = 0.0;

    // ── exactness gate ──────────────────────────────────────────────────
    if (covered != targetStack) {
      // Ordered so that "closer" still beats "further" among failures, and
      // any failure loses to any exact stack.
      score -= 10000 + (covered - targetStack).abs();
    }

    var total = 0;
    var colours = 0;
    var payable = 0;
    var change = 0;
    var tidy = 0.0;
    var singletons = 0;

    for (var i = 0; i < counts.length; i++) {
      final c = counts[i];
      if (c == 0) continue;
      total += c;
      colours++;
      if (c == 1) singletons++;
      if (smallBlind > 0) {
        if (values[i] <= smallBlind) payable += c;
        if (values[i] < smallBlind) change += c;
      }
      // counting_simplicity: counts on 5s and 10s are read at a glance
      // across a table.
      if (c % 10 == 0) {
        tidy += 3;
      } else if (c % 5 == 0) {
        tidy += 2;
      } else if (c.isEven) {
        tidy += 1;
      }
    }
    if (total == 0) return double.negativeInfinity;

    // ── early_blind_payability ──────────────────────────────────────────
    // The term the client's "seven blue chips" complaint lives in.
    if (smallBlind > 0) {
      score += math.min(payable, 12) * 2.5;
      score += math.min(change, 4) * 2.5;
      // The two floors `hasChange` enforces downstream. Scored rather than
      // filtered so a hopeless inventory still yields the best stack it can
      // instead of nothing at all.
      if (payable < 6) score -= 60;
      if (change < 2) score -= 60;
    }

    score += math.min(tidy, 15.0);

    // ── stack_aesthetics ────────────────────────────────────────────────
    // A stack should look like a pyramid: three to five colours, more of the
    // cheap ones than the dear ones. A single stray chip of one colour is the
    // classic "why do I have exactly one of these" annoyance.
    if (colours >= 3 && colours <= 5) score += 8;
    score -= singletons * 1.5;

    // ── excessive_chip_count ────────────────────────────────────────────
    // Too many chips is slow to count and slow to colour up; too few is the
    // unplayable brick the client was handed.
    if (total > 22) score -= (total - 22) * 3.0;
    if (total < 12) score -= (12 - total) * 2.0;

    return score;
  }

  /// Which ante style suits this tournament (§7's "system recommendation").
  ///
  /// The option existed in the UI but always resolved to Big Blind Ante, so it
  /// recommended nothing -- it was a third label for the same choice.
  ///
  /// The real trade-off is operational, not theoretical. A big-blind ante is
  /// one payment per hand from one player: fast, and nobody has to be chased.
  /// An individual ante is a chip from everyone, every hand -- fairer in
  /// principle and slower in practice, and the slowness compounds with the
  /// number of players at the table.
  ///
  /// Spec §F1.8: Auto Big Blind ante standard (one big-blind ante once rebuys close).
  static AnteRecommendation recommendAnte({
    required int players,
    required double durationHours,
  }) =>
      recommendAnteStyle(players: players, durationHours: durationHours);

  /// Step 5 of the addendum's generation sequence: where the rebuy window
  /// should actually close.
  ///
  /// Addendum section 6 is explicit that "Level 6 remains the UI default, not
  /// the authoritative AI rule", and that the engine "may choose different
  /// cutoffs for different player counts, level lengths and blind
  /// progressions". It is equally explicit about what NOT to do: "Do not use a
  /// fixed rule such as 'rebuys always end after two hours.'"
  ///
  /// So this optimises against the shape of the structure rather than the
  /// clock. Rebuys should close while the field is still deep enough that
  /// buying back in is worth the money — once the average stack is short, a
  /// rebuy buys a player a few orbits and nothing more. The window lands on
  /// the last level where a fresh starting stack is still worth at least
  /// [_rebuyWorthwhileBB] big blinds, bounded so it can never swallow the
  /// whole tournament or vanish to nothing.
  ///
  /// [requested] is the organizer's value. Section 6: "Manual organizer
  /// changes are authoritative for that tournament", so an explicit choice is
  /// returned untouched — only the UI default is optimised.
  static const int _rebuyWorthwhileBB = 20;

  /// Every input acceptance criterion 11 requires the cutoff to weigh.
  ///
  /// Named parameters rather than a bundle because the criterion reads as a
  /// list -- players, duration, level length, blinds, antes, starting stack,
  /// breaks, chips, add-on -- and a reader should be able to check the
  /// requirement against this signature without reading the body.
  static int optimiseRebuyCloseLevel({
    required int requested,
    required bool organizerChose,
    required List<List<int>> levelBlinds,
    required int startingStack,
    required int plannedLevels,
    int players = 0,
    double durationHours = 0,
    int levelDurationMins = 0,
    bool anteEnabled = false,
    int anteAfterLevel = 0,
    List<ScheduledBreak> breaks = const [],
    bool addOnAvailable = false,
    int minChipValue = 0,
  }) {
    if (organizerChose) return requested;
    if (levelBlinds.isEmpty || startingStack <= 0) return requested;

    // ── Blinds + starting stack ──────────────────────────────────────────
    // The last level at which buying back in still purchases a playable
    // stack. Past this, a rebuy buys a few orbits and nothing more.
    var viable = 1;
    for (var i = 0; i < levelBlinds.length && i < plannedLevels; i++) {
      final bb = levelBlinds[i][1];
      if (bb <= 0) continue;
      if (startingStack / bb >= _rebuyWorthwhileBB) viable = i + 1;
    }

    // ── Chips ────────────────────────────────────────────────────────────
    // A rebuy has to be payable in physical chips. Once the smallest chip in
    // the box is a meaningful fraction of the big blind, the rebuy stack can
    // no longer be built cleanly and the window should already have closed.
    if (minChipValue > 0) {
      for (var i = 0; i < levelBlinds.length && i < viable; i++) {
        if (levelBlinds[i][1] > 0 && minChipValue * 4 > levelBlinds[i][1]) {
          viable = math.max(1, i);
          break;
        }
      }
    }

    // ── Antes ────────────────────────────────────────────────────────────
    // Antes drain every stack every hand, so the same chips buy less time
    // once they start. Do not let the window run far past their introduction.
    if (anteEnabled && anteAfterLevel > 0) {
      viable = math.min(viable, anteAfterLevel + 1);
    }

    // ── Players ──────────────────────────────────────────────────────────
    // Spec §F1.10 / G1: Rebuy window ceiling is 40% flat of the tournament duration,
    // matching suggestRebuyClose.
    const ceilingFraction = 0.40;

    // ── Level length + duration ──────────────────────────────────────────
    // Section 6 forbids a fixed clock rule ("rebuys always end after two
    // hours"), but level LENGTH still matters: eight 10-minute levels and
    // eight 20-minute levels are not the same tournament. The ceiling stays
    // expressed in levels, then is sanity-checked against the SHARE of the
    // night it covers -- at most 40% of planned duration (Spec §F1.10).
    var ceiling = math.max(2, (plannedLevels * ceilingFraction).floor());
    if (levelDurationMins > 0 && durationHours > 0) {
      final maxWindowMins = durationHours * 60 * 0.40;
      final levelsThatFit = (maxWindowMins / levelDurationMins).floor();
      if (levelsThatFit >= 2) ceiling = math.min(ceiling, levelsThatFit);
    }

    // ── Breaks ───────────────────────────────────────────────────────────
    // The default break placement hangs off this cutoff (section 5), so a
    // cutoff with no level left after it would place a break at the very end
    // of the tournament -- which is not a break.
    if (breaks.isNotEmpty) {
      ceiling = math.min(ceiling, math.max(2, plannedLevels - 1));
    }

    var result = viable.clamp(2, ceiling);
    // Spec-port cross-check (F1.10/G1): the standalone `suggestRebuyClose`
    // enforces the same 40% flat ceiling. Keep both paths in agreement —
    // any future rewire must preserve this invariant.
    assert(result <= ceiling, 'rebuy close exceeds 40% ceiling');

    // ── Field shape ─────────────────────────────────────────────────────
    // Stack-versus-blinds is field-independent, but the FIELD SHAPE is not:
    // a single table is down to the endgame by the midpoint of the schedule
    // — a rebuy there buys a chair at a four-handed table — while a
    // multi-table field is still mid-pack at the same level, so a rebuy is
    // still worth buying. A single-table field therefore closes one level
    // earlier than the ceiling allows; anything bigger keeps the window.
    // (The ceiling itself stays the G1 40% flat maximum either way.)
    final singleTableField = players > 0 && players <= 9;
    if (singleTableField && result > 2) result -= 1;

    // ── Add-on ───────────────────────────────────────────────────────────
    // If a later top-up exists, the rebuy window does not have to carry the
    // whole job of keeping people in -- it can close a level earlier and let
    // the add-on do the rest.
    //
    // Applied AFTER the clamp deliberately. Reducing `viable` first does
    // nothing whenever the blinds alone would allow a later cutoff than the
    // ceiling permits, which is the common case -- the reduction vanished
    // into the clamp and the add-on had no effect at all.
    if (addOnAvailable && result > 2) result -= 1;

    return result;
  }

  /// §11.3's risk premium for this tournament, as a fraction.
  ///
  /// Lives here rather than inside `generate` because §10.2's narrative has to
  /// quote the same number the curve was built from; two copies of the formula
  /// would drift. Zero for any format with no late chips — and NOT zero when
  /// `rebuyCost == buyIn`, because the clamp floors it at 0.05 (§39: the spec's
  /// claim that equal costs reduce to Freeze Out is wrong about this).
  static double maxRiskPremium(TournamentParams params) =>
      params.effectiveFormat.hasLateChips && params.buyIn > 0
          ? (0.30 * (1 - params.effectiveRebuyCost / params.buyIn))
              .clamp(0.05, 0.25)
              .toDouble()
          : 0.0;

  /// §10.2's `formatRationale` — why the curve has the shape it has, in terms
  /// of the format rather than a bare noun.
  ///
  /// The narrative used to emit `format.label` on its own, which named the
  /// format and explained nothing; and it read `params.format` directly, so
  /// every game written before the field existed (format == null) got no
  /// format sentence at all. [TournamentParams.effectiveFormat] never returns
  /// null, so legacy games now get the sentence their settings imply.
  static String formatRationale(TournamentParams params) {
    switch (params.effectiveFormat) {
      case TournamentFormat.freezeOut:
        return 'no rebuy safety net — one bad beat ends the night, so the '
            'curve stays gentler early to protect that.';
      case TournamentFormat.rebuy:
      case TournamentFormat.reEntry:
        final premiumPct = (maxRiskPremium(params) * 100).round();
        return 'the window is open through level ${params.rebuysCloseLevel}, '
            'so the curve runs $premiumPct% steeper until then, then matches '
            'Freeze Out exactly once the safety net closes.';
      case TournamentFormat.shootout:
        return 'each table plays an independent Freeze Out to one winner; the '
            'final table runs as its own Freeze Out once every table reports '
            'in.';
    }
  }

  /// Plain-language explanation of the depth this structure landed on.
  ///
  /// Addendum section 2: "If the engine chooses an unusual depth, explain why
  /// in plain language." Naming the style is half of it; saying why it is not
  /// the default is the half that actually helps.
  ///
  /// [paceAdjustment] is the §10.1 adjustment the host ACCEPTED, or null. It is
  /// a parameter rather than something read off [params] because there is
  /// nothing on the params that records an acceptance — see the pace sentence
  /// below for what reading the wrong field cost.
  static String _styleNarrative({
    required TournamentStyle style,
    required double depth,
    required bool inventoryLimited,
    required TournamentParams params,
    double? paceAdjustment,
  }) {
    final rounded = depth.round();
    final base = '${style.label} — $rounded big blinds to start, '
        '${style.purpose}.';
        
    String depthSentence = base;
    if (style != TournamentStyle.standard) {
      if (inventoryLimited) {
        depthSentence = '$base Your chips could not fund a deeper start, so the '
            'structure opens shorter than usual.';
      } else if (style == TournamentStyle.deep) {
        depthSentence = '$base Chosen because ${params.durationHours}h leaves room for '
            'post-flop play.';
      } else {
        depthSentence = '$base Chosen to finish near your ${params.durationHours}h target.';
      }
    }

    final formatSentence = formatRationale(params);

    // §10.2 gates this on `ante.trigger == afterRebuysClose`. There is no ante
    // TRIGGER on the params — only a switch and the level it starts after — so
    // the honest equivalent is "the ante is on and it starts no earlier than
    // the level the rebuy window closes on", which is the same tournament the
    // spec's trigger describes. Antes run from `anteAfterLevel + 1`, hence the
    // "immediately after" wording.
    final anteSentence =
        params.anteEnabled && params.anteAfterLevel >= params.rebuysCloseLevel
            ? 'Ante starts at level ${params.anteAfterLevel + 1}, immediately '
                'after rebuys close, to start pushing toward a finish.'
            : '';

    // Only an ACCEPTED §10.1 pace adjustment may be claimed here. This used to
    // be gated on `levelDurationMins != null` — the host's own manual level
    // length — so a host who set 18-minute levels by hand was told their
    // structure had been learned from their group's history. It had not.
    final paceSentence = paceAdjustment != null && paceAdjustment != 0
        // A positive adjustment means this group's nights OVERRAN the estimate,
        // so the structure answers by running faster, and vice versa.
        ? '${(paceAdjustment.abs() * 100).round()}% '
            '${paceAdjustment > 0 ? 'faster' : 'slower'} than standard pace, '
            'from this group\'s last 5 games running '
            '${paceAdjustment > 0 ? 'long' : 'short'}.'
        : '';

    return [
      depthSentence,
      if (formatSentence.isNotEmpty) formatSentence,
      if (anteSentence.isNotEmpty) anteSentence,
      if (paceSentence.isNotEmpty) paceSentence,
    ].join(' ');
  }

  /// Decides where scheduled breaks fall (specification section 8, and the
  /// v11 addendum which raised the maximum from 2 to 3).
  ///
  /// A requested break with `afterLevel <= 0` means the organizer turned
  /// breaks on but left the position to us. The rule:
  ///
  ///  * rebuys or re-entry enabled -> immediately after the rebuy window
  ///    closes, because that is when players settle up and the field is about
  ///    to shrink;
  ///  * otherwise -> the structural midpoint of the planned levels, which is
  ///    the ordinary home-game convention.
  ///
  /// Further automatic breaks are spread evenly through what remains, so two
  /// breaks do not land on adjacent levels. Explicit placements are honoured
  /// exactly as given.
  static List<ScheduledBreak> _placeBreaks({
    required List<ScheduledBreak> requested,
    required int plannedLevels,
    required bool rebuysEnabled,
    required int rebuysCloseLevel,
  }) {
    if (requested.isEmpty || plannedLevels <= 1) return const [];

    final capped = requested.take(kMaxScheduledBreaks).toList();
    final placed = <ScheduledBreak>[];
    final taken = <int>{};

    // Honour explicit placements first so an automatic one cannot steal a
    // level the organizer already chose.
    for (final b in capped) {
      if (b.afterLevel > 0) {
        final level = b.afterLevel.clamp(1, plannedLevels - 1);
        if (taken.add(level)) {
          placed.add(b.copyWith(afterLevel: level));
        }
      }
    }

    final autos = capped.where((b) => b.afterLevel <= 0).toList();
    if (autos.isNotEmpty) {
      final midpoint = (plannedLevels / 2).round();
      var anchor = rebuysEnabled && rebuysCloseLevel > 0
          ? rebuysCloseLevel
          : midpoint;
      anchor = anchor.clamp(1, plannedLevels - 1);

      for (var i = 0; i < autos.length; i++) {
        // First automatic break takes the anchor; later ones are spread
        // through the remaining levels rather than stacking beside it.
        var level = i == 0
            ? anchor
            : (anchor + ((plannedLevels - anchor) * i / autos.length)).round();
        level = level.clamp(1, plannedLevels - 1);
        // Nudge off any level already used.
        var guard = 0;
        while (taken.contains(level) && guard < plannedLevels) {
          level = (level + 1).clamp(1, plannedLevels - 1);
          if (taken.contains(level) && level == plannedLevels - 1) {
            level = (level - 1).clamp(1, plannedLevels - 1);
          }
          guard++;
        }
        if (taken.add(level)) {
          placed.add(autos[i].copyWith(afterLevel: level));
        }
      }
    }

    placed.sort((a, b) => a.afterLevel - b.afterLevel);
    return placed;
  }

  /// Gross eligible for the prize pool. KO bounty is EXCLUDED (it is a
  /// separate field, never part of `buyIn`, spec §9.1/§23.1).
  static int grossEligibleFor({
    required int confirmedCount,
    required int buyIn,
    required int totalRebuys,
    required int effectiveRebuyCost,
    required int totalReEntries,
    required bool addOnEnabled,
    required int totalAddOns,
    required int effectiveAddOnCost,
  }) {
    return (confirmedCount * buyIn) +
        (totalRebuys * effectiveRebuyCost) +
        (totalReEntries * buyIn) +
        (totalAddOns * (addOnEnabled ? effectiveAddOnCost : 0));
  }

  /// Build Spec v3.1 §F1.5/§F1.18 support — how large a field this exact
  /// chip set can still seat at or above [kMinPlayableDepthBB], used only to
  /// annotate the infeasible case above with a concrete number rather than
  /// just "add more chips". Deliberately a plain linear scan down from
  /// `params.players - 1`, reusing [_buildChipPlan] directly rather than the
  /// full target-band solve above — this runs only on the rare path where
  /// that solve has already failed outright, so a small, easily-audited
  /// re-check was preferred over threading a player-count parameter through
  /// the much larger joint solve in [generate].
  static int? _largestPlayableFieldSize({
    required TournamentParams params,
    required int minChip,
  }) {
    for (var testPlayers = params.players - 1; testPlayers >= 2; testPlayers--) {
      for (final pair in validBlindLevels) {
        final sb = pair[0];
        final bb = pair[1];
        if (minChip <= 0 || sb % minChip != 0 || bb % minChip != 0) continue;
        final floor = (kMinPlayableDepthBB * bb).round();
        var candidate = (kMinPlayableDepthBB * bb / sb).round() * sb;
        while (candidate >= floor) {
          final plan = _buildChipPlan(
            candidate,
            params.chipSet,
            math.max(1, testPlayers),
            1.0,
            smallBlind: sb,
          );
          final covered = plan.fold<int>(0, (s, e) => s + e.count * e.value);
          if (covered >= candidate) return testPlayers;
          candidate -= sb;
        }
      }
    }
    return null;
  }

  static TournamentStructure generate(TournamentParams params) {
    // §11.4. A shootout has no single structure, so this returns the one the
    // room actually sits down to: Stage A, the per-table Freeze Out. Callers
    // that need the final table as well ask [generateShootout] for both.
    // Throwing instead was tempting and wrong — seven call sites reach this
    // method and the format is already selectable in setup, so refusing to
    // generate would break the screens rather than the format.
    //
    // The MONEY is restated for the whole field: Stage A's own pipeline sees
    // one table's worth of players, and a shootout's prize pool belongs to the
    // event, not to a table.
    if (params.effectiveFormat == TournamentFormat.shootout) {
      final plan = generateShootout(params);
      final recalculated = PayoutBridge.recalculate(
        grossEligible: params.buyIn * params.players,
        players: params.players,
        organizerPct: params.organizerPct,
        buyIn: params.buyIn,
      );
      return plan.stageA.copyWith(
        prizes: recalculated.prizes,
        prizePool: recalculated.prizePool,
        organizerAmount: recalculated.organizerAmount,
        roundingRemainder: recalculated.roundingRemainder,
      );
    }

    final dupValues = params.chipSet.map((c) => c.value).toList();
    if (dupValues.toSet().length != dupValues.length) {
      throw const DuplicateChipValueException(
        'Two chip colours cannot share the same value.',
      );
    }

    final warnings = <String>[];
    // The host's choice wins; the duration-derived bucket is the fallback for
    // every tournament that never made one.
    // §F1.3: on the pace path the level length IS the pace — one length all
    // night, Turbo 15 / Regular 20 / Deep 30. An explicit host override still
    // wins over both, because §E8 makes every generated field overridable.
    final pace = params.pace;
    final levelDuration = params.levelDurationMins
            ?.clamp(kMinLevelDurationMins, kMaxLevelDurationMins) ??
        pace?.levelMinutes ??
        _levelDurationFor(params.durationHours);
    // Full target, not 90% of it. The old 0.9 factor meant a 3.5 h event only
    // ever generated ~3 h 09 m of levels, which both understated the finish
    // (11-030) and made play run off the end of the structure — the trigger
    // for the unconfirmed auto-extension in `nextLevel()` (11-014).
    //
    // Specification section 8: break time is INSIDE the target duration, not
    // added to it -- "target 4h = 3h40 playing + 20 min scheduled breaks". So
    // the levels are generated against what is left after the breaks, which is
    // what stops a 4-hour night with two breaks from actually running 4h20.
    final scheduledBreakMins =
        params.breaks.fold<int>(0, (a, b) => a + b.durationMins);

    // §F1.3 `P = max(30, T − breaks.total − rebuyPause)`. `T` comes from the
    // start/end window when there is one, which is what lets a late start
    // shrink the night while keeping `endBy` (§E17 row 21); otherwise it is
    // the stated duration, exactly as before.
    final paceTargetMinutes = params.effectiveTargetMinutes;
    final pacePlayMinutes = playMinutesFor(
      targetMinutes: paceTargetMinutes,
      scheduledBreakMins: scheduledBreakMins,
      format: params.effectiveFormat,
    );

    final playingMinutes =
        math.max(60.0, params.durationHours * 60 - scheduledBreakMins);
    // Levels that actually fit the target. Everything that models PACE uses
    // this; the spare tail below is overtime insurance, not part of the plan.
    //
    // On the pace path this is a PROVISIONAL count — `eFit`, the levels the
    // window holds. It is refined to §F1.3's `e` once `BB_end` is known, which
    // cannot happen until the stack is solved.
    var plannedLevels = pace != null
        ? math.max(2, pacePlayMinutes ~/ levelDuration)
        : math.max(6, (playingMinutes / levelDuration).ceil());
    var numLevels = plannedLevels + _spareLevels;

    // Build Spec v3.1 §F1.2/§F1.18: the admissible opening-depth band is
    // keyed by STYLE (turbo 50-70, standard 85-130, deep >=150), not one
    // flat 80-240 BB band for every duration/field. There is no explicit
    // style selector input here, so the existing continuous duration/player
    // formula is first read UNCLAMPED to see what depth it is actually
    // asking for, that raw value is classified into a style via
    // [paceStyleFor], and only THEN clamped into that style's own band —
    // rather than clamping every style into the same [80, 240] range.
    // §F1.3: `BB1 = niceBB(S / STYLE[style].D, cmin)`, and on the pace path
    // the style is not inferred at all — it follows the pace the host picked.
    // §F1.2's two tables line up one to one:
    //
    //   PACE.turbo   → STYLE.turbo    D  60   DEPTH_BAND [50, 70]
    //   PACE.regular → STYLE.standard D 100   DEPTH_BAND [85, 130]
    //   PACE.deep    → STYLE.deep     D 160   DEPTH_BAND [150, ∞)
    //
    // The legacy formula below stays for the phased mode (§F1.13), which has
    // no pace to read. It was being applied to paced structures too, and got
    // them wrong: the §F1.15 demo night — 10 players, 20:00–00:30, regular —
    // is specified to open at 1/2 with a 100 BB stack, and the continuous
    // formula produced a 60 BB opening, i.e. TURBO depth for a REGULAR night.
    final rawTargetBBDepth = pace != null
        ? switch (pace) {
            PaceMode.turbo => _turboAim,
            PaceMode.regular => _standardAim,
            PaceMode.deep => _deepAim,
          }
        : 125 +
            28 * (params.durationHours - 3.5) -
            2.5 * math.max(0, params.players - 8);
    final paceStyle = pace != null
        ? switch (pace) {
            PaceMode.turbo => PaceStyle.turbo,
            PaceMode.regular => PaceStyle.standard,
            PaceMode.deep => PaceStyle.deep,
          }
        : paceStyleFor(rawTargetBBDepth);
    // The band this particular tournament must land in. Derived, not imposed.
    final depthBand = admissibleDepthBand(paceStyle);
    final targetBBDepth = math.max(
      depthBand.min,
      math.min(depthBand.max, rawTargetBBDepth),
    );

    final sortedChips = [...params.chipSet]..sort((a, b) => a.value - b.value);
    final minChip = sortedChips.isNotEmpty ? sortedChips.first.value : 1;

    // ── Joint stack + opening-blind solve (Technical sections 7.2 and 8.2,
    // 10-029, 11-019, 11-020) ───────────────────────────────────────────────
    //
    // The opening blind used to be pinned to the first ladder entry the
    // smallest chip could pay (25/50 for any set holding a 25), and the stack
    // was then shrunk 100 at a time until the chip plan covered it — WITHOUT
    // ever reconsidering the blind. On the app's own presets that produced
    // openings of 2, 12, 14 and 16 big blinds: a push-fold game from level 1,
    // against a spec that clamps starting depth to 80-240 BB.
    //
    // Stack and blinds are now solved TOGETHER: every ladder pair the real
    // denominations can post is evaluated, each against the largest stack the
    // inventory can actually supply, and the pair landing closest to the
    // target depth inside the 80-240 band wins.

    // Real expected entries rather than a flat `players x 1.2 x 2` buffer —
    // the same figures Technical section 6.3 step 4 uses for the blind curve.
    final expectedRebuysForChips = params.effectiveExpectedRebuys;
    final expectedAddOnsForChips = params.effectiveExpectedAddOns;

    // How many stacks the inventory is divided across when building ONE
    // player's starting stack. Tried from most conservative to least: hold
    // back chips for every expected rebuy and add-on first, and only relax
    // toward seats-only if that reserve cannot fund a legal starting depth.
    // Relaxing is legitimate — busted stacks return to the box and are
    // recycled into rebuys, so the full reserve is a floor, not a hard need
    // (Technical section 7.2).
    // Build Spec v3.1 §F1.5/§F1.18 — the bank-sizing reserve: rather than a
    // point-estimate rebuy count, size the most conservative tier off the
    // 90th-percentile of a Poisson(mean = expected rebuys) draw, so the
    // reserve holds up for a night that runs a bit hotter than the average
    // case, not just the average case itself. Prepended ahead of the
    // existing point-estimate tiers, which remain as the less conservative
    // fallbacks if the box cannot fund this one.
    // §F1.5 point 1: `Rbank = PoissonQuantile(mean = Rforecast, 0.90)`. The
    // mean is the FORECAST, so a host whose nights genuinely rebuy more than
    // average gets a bank sized for their game — the 0.35 here was hardcoded,
    // which meant the measured rate reached the blind curve but never reached
    // the box that has to fund it.
    final rebuyRateMean =
        params.rebuys ? params.players * params.effectiveExpectedRebuyRate : 0.0;
    final poissonReserveDraws = poissonQuantile90(rebuyRateMean);
    final bankReserveTier = params.players +
        poissonReserveDraws +
        (params.addOn ? params.players : 0);

    final reserveTiers = <int>{
      // Poisson-90th-percentile bank tier first — the most conservative,
      // per Build Spec v3.1 §F1.5/§F1.18 above.
      bankReserveTier,
      // Mainline's own reserve tier, which additionally accounts for
      // expected re-entries via [TournamentParams.reserveMultiplier] —
      // something [bankReserveTier] does not model.
      (params.players * params.reserveMultiplier).ceil(),
      params.players + expectedRebuysForChips + expectedAddOnsForChips,
      params.players + expectedRebuysForChips,
      params.players,
    }.where((v) => v > 0).toList();

    List<ChipPlanEntry> planFor(int candidate, int divisor, int sb) =>
        _buildChipPlan(
          candidate,
          params.chipSet,
          math.max(1, divisor),
          1.0,
          smallBlind: sb,
        );

    bool covers(int candidate, List<ChipPlanEntry> plan) =>
        plan.fold<int>(0, (s, e) => s + e.count * e.value) >= candidate;

    /// A stack has to be postable, not merely large (11-020, 10-033).
    ///
    /// Counting chips worth "<= the small blind" made the test EASIER at
    /// higher blinds — at 25/50 the 25-value chips count as change — so under
    /// tight inventory the solver was pushed toward big blinds and shallow
    /// stacks to satisfy it. Home Set with 18 players came out at 25/50 and
    /// 18.5 BB: perfectly postable, and push-fold from level one. Depth is
    /// selected first (the 80-240 band gate below); change is a constraint
    /// applied INSIDE that band, never a reason to leave it.
    bool hasChange(List<ChipPlanEntry> plan, int sb) {
      final payable =
          plan.where((e) => e.value <= sb).fold<int>(0, (s, e) => s + e.count);
      if (payable < 6) return false;
      // At least a couple of chips must be strictly SMALLER than the small
      // blind, so a player can make change rather than only pay it exactly.
      //
      // Unless the box cannot do it at all: when the cheapest chip the host
      // owns IS the small blind, no stack can hold anything below it. Demanded
      // unconditionally, this rejected every candidate for such a set, sent
      // the solver into the shortage fallback, and printed "these chips cannot
      // fund an 80 big-blind stack" over a stack that was 92 big blinds deep
      // (measured: Home Set, 18 players, 925 at 5/10). An impossible condition
      // is not a failing one.
      if (minChip >= sb) return true;
      final belowBlind = plan
          .where((e) => e.value < sb)
          .fold<int>(0, (s, e) => s + e.count);
      return belowBlind >= 2;
    }

    ({int index, int stack, double depth, int divisor})? best;

    for (final divisor in reserveTiers) {
      for (var i = 0; i < validBlindLevels.length; i++) {
        final sb = validBlindLevels[i][0];
        final bb = validBlindLevels[i][1];
        // 11-004: every blind must be postable with the chips in play.
        if (minChip <= 0 || sb % minChip != 0 || bb % minChip != 0) continue;

        // Largest stack at this opening that both hits the target depth and
        // the inventory can supply.
        //
        // Stepping down one small blind at a time produced stacks like 815,
        // 845 and 995 — 81.5 BB is neither round nor easy to announce at the
        // table (10-034, Technical section 7.3 `counting_simplicity` /
        // `stack_aesthetics`). Try a coarse, countable grid first — 10 then 5
        // big blinds — and only fall back to single-blind steps if nothing
        // coarser fits the box.
        // The floor is this tournament's band, not a universal constant --
        // see [admissibleDepthBand].
        final floor = (depthBand.min * bb / sb).ceil() * sb;
        int? chosen;
        List<ChipPlanEntry>? chosenPlan;

        // §F1.5 point 3: "Candidate S values: **nice numbers** ≤ S_max,
        // deepest first; evaluate up to 20."
        //
        // The blind-multiple grid below was an attempt at the same goal —
        // its own comment complains about stacks like 815, 845 and 995 — but a
        // multiple of the big blind is not a nice number, so it only helped
        // when the blind happened to be round. At 9 players it fell through to
        // single-blind steps and picked **1490**, which is bad twice over:
        //
        //   * it needs 21 small chips to build, blowing the 25-chip target
        //     (§F1.5 `scoreComposition`, "total chips n"), and
        //   * it cannot be rebuilt after colour-up. A rebuy at level 9 has no
        //     1-chips left to make the last 40, so the handout came to 1500
        //     and a rebuy stopped being worth a starting stack (23-002).
        //
        // Nice values fix both at the source: 1500 builds from 25 chips and
        // survives every colour-up, because nice numbers are exactly the ones
        // the surviving denominations can still express.
        final niceCandidates =
            niceValuesInRange(sb, floor.toDouble(), targetBBDepth * bb)
                .reversed // deepest first
                .take(20)
                .toList();
        for (final candidate in niceCandidates) {
          final plan = planFor(candidate, divisor, sb);
          if (covers(candidate, plan) && hasChange(plan, sb)) {
            chosen = candidate;
            chosenPlan = plan;
            break;
          }
        }

        // Fall back to the old grid only when no nice value fits the box at
        // all. A slightly awkward stack the case can actually supply beats
        // refusing to generate a structure.
        if (chosen == null) {
          for (final step in [bb * 10, bb * 5, sb]) {
            if (step <= 0) continue;
            var candidate = (targetBBDepth * bb / step).floor() * step;
            while (candidate >= floor) {
              final plan = planFor(candidate, divisor, sb);
              if (covers(candidate, plan) && hasChange(plan, sb)) {
                chosen = candidate;
                chosenPlan = plan;
                break;
              }
              final next = candidate - step;
              if (next <= 0) break;
              candidate = next;
            }
            if (chosen != null) break;
          }
        }
        if (chosen == null || chosenPlan == null) continue;
        final candidate = chosen;

        final depth = candidate / bb;
        if (depth < depthBand.min || depth > depthBand.max) continue;

        // Prefer the depth closest to target; break ties toward the LARGER
        // opening blind, which needs fewer physical chips per stack (10-034,
        // Technical section 7.3). The ladder is walked ascending and the
        // comparison was strictly `<`, so equal-distance candidates kept the
        // FIRST — i.e. the smaller blind — the opposite of what is documented.
        final delta = (depth - targetBBDepth).abs();
        final bestDelta =
            best == null ? double.infinity : (best.depth - targetBBDepth).abs();
        if (best == null ||
            delta < bestDelta ||
            (delta == bestDelta && bb > validBlindLevels[best.index][1])) {
          best = (index: i, stack: candidate, depth: depth, divisor: divisor);
        }
      }
      // The first tier that yields a legal depth wins — it is the most
      // conservative one that still works.
      if (best != null) break;
    }

    if (best == null) {
      // 10-039: say so rather than silently shipping a push-fold structure.
      warnings.add(
        'These chips cannot fund a ${depthBand.min.round()} big-blind '
        'starting stack (this game\'s style band) for ${params.players} '
        'players. Add more low-denomination chips, or reduce the field, '
        'for a deeper start.',
      );
      // Fall back to the DEEPEST legal opening the inventory can pay, not the
      // first one that happens to fit — and still insist on change in hand.
      //
      // This loop originally tested `covers(...)` alone. Dropping `hasChange`
      // produced stacks nobody can post a blind from: Home Set with 14 players
      // built 1,100 at 5/10 as 2 x 500 + 1 x 100 — three chips, none of them
      // 10 or under (10-033, 11-020, Technical section 7.2). Below spec on
      // DEPTH is a warning; below spec on payability is unplayable.
      ({int index, int stack, double depth, int divisor})? withChange;
      ({int index, int stack, double depth, int divisor})? anyCover;

      for (var i = 0; i < validBlindLevels.length; i++) {
        final sb = validBlindLevels[i][0];
        final bb = validBlindLevels[i][1];
        if (minChip <= 0 || sb % minChip != 0 || bb % minChip != 0) continue;
        var candidate = (targetBBDepth * bb / sb).round() * sb;
        // Floor the search. Walking all the way down to one small blind meant
        // a tight inventory could "succeed" at a 1 big-blind stack, which is
        // not a tournament. Below 20 BB the opening is unplayable, so try the
        // next ladder entry instead — and if every entry bottoms out, the
        // shortage warning above already tells the host why.
        final fallbackFloor = (kMinPlayableDepthBB * bb).round();
        List<ChipPlanEntry>? plan;

        // §F1.5 point 3 applies here too. Point 5 says that when nothing
        // reaches the band "only the closest ones" compete — closest among the
        // NICE candidates, not among every multiple of the small blind.
        //
        // This is the branch that produced 1490. Walking down by `sb` from the
        // target lands on whatever multiple of 5 happens to be fundable, and
        // 1490 was fundable, so it won at 149 BB — one big blind under the
        // deep band, and unbuildable after colour-up. The deepest nice value
        // the box can actually fund is the honest answer: a little shallower,
        // countable at the table, and still a stack after the 1s are gone.
        // A nice value is taken only when it is BOTH fundable and postable.
        //
        // Accepting one on coverage alone is worse than not using nice values
        // here at all: at Standard 300 with 18 players the deepest fundable
        // nice value is 600, which builds as 1 × 500 + 1 × 100 and has no chip
        // at or below the small blind — a stack that cannot post its own blind
        // (10-033, 11-020, PN-045/PN-046). Below spec on DEPTH is a warning;
        // below spec on PAYABILITY is unplayable.
        //
        // So when no nice value is postable, control falls through to the
        // single-blind walk below, which is finer-grained and finds a stack
        // that is. That is the pre-existing behaviour, unchanged.
        for (final v in niceValuesInRange(
          sb,
          fallbackFloor.toDouble(),
          candidate.toDouble(),
        ).reversed) {
          final p = planFor(v, params.players, sb);
          if (covers(v, p) && hasChange(p, sb)) {
            plan = p;
            candidate = v;
            break;
          }
        }

        while (plan == null && candidate >= fallbackFloor) {
          final p = planFor(candidate, params.players, sb);
          if (covers(candidate, p)) {
            plan = p;
            break;
          }
          candidate -= sb;
        }
        if (plan == null || candidate < fallbackFloor) continue;
        final depth = candidate / bb;
        final entry = (
          index: i,
          stack: candidate,
          depth: depth,
          divisor: params.players,
        );
        if (anyCover == null || depth > anyCover.depth) anyCover = entry;
        if (hasChange(plan, sb) &&
            (withChange == null || depth > withChange.depth)) {
          withChange = entry;
        }
      }
      // Prefer the deepest PLAYABLE candidate; only if none has change at all
      // does the deepest coverable one stand.
      best = withChange ?? anyCover;
    }

    // Build Spec v3.1 §F1.5/§F1.18 — MIN_PLAYABLE_DEPTH. `best` reaching
    // here as null means neither the target-band solve nor the shortage
    // fallback above found ANY blind pair the inventory can fund at or
    // above the 20BB floor — the tournament as configured is not playable
    // at all, not merely shallow. That is a distinct, harder failure than
    // the shortage warning above (which still guarantees >= 20BB) and gets
    // its own explicit, structured signal rather than silently shipping a
    // depth:10 structure with no indication anything was wrong.
    final depthFeasible = best != null;
    String? depthShortfallNote;
    int? maxPlayersSupported;
    if (!depthFeasible) {
      maxPlayersSupported =
          _largestPlayableFieldSize(params: params, minChip: minChip);
      depthShortfallNote = maxPlayersSupported != null && maxPlayersSupported > 0
          ? 'This chip set cannot fund a ${kMinPlayableDepthBB.round()}BB '
              'starting stack for ${params.players} players. It supports up '
              'to $maxPlayersSupported players at that depth — add more '
              'low-denomination chips to seat more.'
          : 'This chip set cannot fund a ${kMinPlayableDepthBB.round()}BB '
              'starting stack for any field size. Add more '
              'low-denomination chips.';
      warnings.add(depthShortfallNote);
    }

    // Absolute last resort: an inventory that can pay nothing at all.
    best ??= (
      index: 0,
      stack: math.max(validBlindLevels.first[1], minChip * 10),
      depth: 10,
      divisor: math.max(1, params.players),
    );

    final startIndex = best.index;
    final openingBB = validBlindLevels[startIndex][1];
    final stack = best.stack;
    final chipPlan = planFor(stack, best.divisor, validBlindLevels[startIndex][0]);

    // Chips handed over for each entry type. The solved starting stack is the
    // default for all three — it is what the engine always used — but a host
    // who runs a bigger add-on than a starting stack can now say so, and the
    // blind curve below sees it.
    final rebuyStack = params.rebuyChips ?? stack;
    final addOnStack = params.addOn ? (params.addOnChips ?? stack) : 0;
    final reEntryStack = params.reEntryChips ?? stack;

    // Expected additional money-chip volume (tech spec §6.3 step 4): rebuys,
    // re-entries and add-ons inflate total chips in play and therefore the
    // final blind target. Computed here so the blind curve can use them.
    final expectedRebuysTotal = params.effectiveExpectedRebuys;
    final expectedReEntriesTotal = params.effectiveExpectedReEntries;
    final expectedAddOnsTotal = params.effectiveExpectedAddOns;

    // 12.4 Chip supply sufficiency check.
    //
    // The add-on term carries §12.1's 0.5 weight, the same weight
    // [TournamentParams.reserveMultiplier] gives it and for the same reason: an
    // add-on chip grant is sized from the average stack at rebuy close, not the
    // starting stack, so it draws on a materially different, already-partially-
    // coloured-up denomination mix and must not reserve at full weight against
    // the STARTING chip plan. Charging it in full contradicted §12.1 and made
    // the check fire on ordinary configurations, which is noise, not a warning.
    final totalExpectedEntries = params.players +
        expectedRebuysTotal +
        expectedReEntriesTotal +
        expectedAddOnsTotal * 0.5;

    for (final entry in chipPlan) {
      final requiredChips = (entry.count * totalExpectedEntries).ceil();
      final chipDef = params.chipSet.firstWhere((c) => c.value == entry.value, orElse: () => ChipColor(color: entry.color, hex: entry.hex, value: entry.value, quantity: 0));
      if (chipDef.quantity < requiredChips) {
        final shortfall = requiredChips - chipDef.quantity;
        final parts = <String>[];
        if (expectedRebuysTotal > 0) parts.add('rebuys');
        if (expectedReEntriesTotal > 0) parts.add('re-entries');
        if (expectedAddOnsTotal > 0) parts.add('add-ons');
        final driving = parts.isEmpty ? 'the starting field' : 'expected ${parts.join(', ')}';
        warnings.add(
          'Short ${shortfall}x ${entry.color} chips to fund $driving.',
        );
      }
    }

    // ── Blind curve (tech spec §8.3 / §8.4) ─────────────────────────────────
    // The final big blind is derived from the total chips that will actually
    // be in play: starting stacks plus expected rebuys and add-ons, per the
    // spec formula. A re-entry stack is NOT added whole — the spec's
    // expectedTotalChips (§8.3) counts starting, rebuy and add-on stacks, on
    // the reasoning that a re-entry simply replaces a busted stack already
    // counted as in play. That reasoning holds exactly while a re-entry IS a
    // starting stack. Now that the host can set it larger, only the SURPLUS is
    // genuinely new chips, so that is what goes in: zero when the two match,
    // which is every tournament generated before the field existed.
    // (Re-entries do still count toward the prize pool in §9.1, where
    // behaviour matches the spec.) Build Spec v3.1 §F1.2/§F1.6/§F1.18: the
    // end target is `BB_end = C / K`, where C is the total chips in play and
    // K is 20 normally, or 27 the moment any ante is live anywhere on the
    // ladder (an ante adds pressure per orbit beyond the blinds alone, so
    // the same chip total should produce a SMALLER final big blind — i.e. a
    // larger divisor — once antes are in play). This replaces the previous
    // `C / (2 × targetHeadsUpAverageBB)` — a flat /30 regardless of antes,
    // which is not the spec's rule and never varied with ante status at all:
    //   targetFinalBB = expectedTotalChips / K
    //   rawBB(i)      = openingBB × growthFactor^i
    //   growthFactor  = (targetFinalBB / openingBB)^(1 / max(1, levels − 1))
    // Every raw value is snapped to a legal, easy-to-post amount from the
    // blind ladder, the sequence stays strictly monotonically increasing, and
    // the ladder itself extends in practical +200/+400 steps if a very large
    // field needs blinds beyond its printed end.
    // Build Spec v3.1 §F1.3:
    //
    //   C = S × (N + Rforecast) + addOnMult × S × N × takeUp + bonusPct × S × N
    //
    // and the Structuring Framework §4, which is the same equation with the
    // early bonus dropped because the Framework is general:
    //
    //   C = N·X + R·rebuy_size + S·add_on_size,  i.e.  C/X = N(1 + r + Aq)
    //
    // The early-arrival bonus term was missing. Every player who checks in
    // before the scheduled start receives `effectiveEarlyArrivalPct × S` extra
    // chips (D6, §E17 row 16), and those are chips in play exactly like a
    // rebuy's: they must be in `C`, or `BB_end = C / K` is solved against a
    // chip total the night does not have and the ladder finishes too shallow.
    //
    // The re-entry term keeps its `max(0, reEntryStack − stack)` shape: a
    // re-entry replaces a busted stack rather than adding a fresh one, so only
    // the excess over the starting stack is genuinely new chips. §F1.3 has no
    // re-entry term because it folds re-entries into `Rforecast`; this is the
    // same quantity, spelled out.
    final earlyBonusChips =
        params.effectiveEarlyArrivalPct * stack * params.players;
    final expectedTotalChips =
        stack * params.players +
        rebuyStack * expectedRebuysTotal +
        math.max(0, reEntryStack - stack) * expectedReEntriesTotal +
        addOnStack * expectedAddOnsTotal +
        earlyBonusChips;
    final endTargetK =
        params.anteEnabled ? kEndTargetKWithAnte : kEndTargetKNoAnte;
    final targetFinalBB = expectedTotalChips / endTargetK;

    // ── §F1.3 pace solve ────────────────────────────────────────────────────
    //
    // Now that `BB_end` is known, replace the provisional level count with
    // §F1.3's `e` and take its single growth rate `g`. This is the point where
    // the pace path diverges from the legacy phased mode: below, `gBase` is
    // solved from `targetFinalBB` over `plannedLevels`, which is the same
    // arithmetic — the difference is that `e` here is capped by what the
    // WINDOW holds, so the night is fitted to its finish time rather than the
    // finish time being whatever the ladder happens to take.
    PaceSolveResult? paceSolve;
    if (pace != null) {
      paceSolve = solveUniformLevels(
        openingBB: openingBB,
        endBB: targetFinalBB,
        pace: pace,
        playMinutes: pacePlayMinutes,
      );
      plannedLevels = paceSolve.levels;
      numLevels = plannedLevels + _spareLevels;
    }
    // Technical section 8.4: the exponent is `1 / max(1, plannedLevels - 1)`.
    // Using `numLevels` here spread the curve across the spare tail as well,
    // so blinds grew ~30% slower per level than the formula intends and the
    // big blind at the target finish came in around 2.5x too shallow — about
    // an hour of extra play. The same factor simply continues through the
    // spare levels, which is what you want if the game does run long.
    // ── Risk-adjusted growth (§11.3) ────────────────────────────────────────
    // Chips that enter after level 1 — rebuys, re-entries — are chips the
    // blind curve must eventually outrun. A curve solved only from the total
    // ends up too shallow early and too steep late. The premium front-loads
    // the growth into the window where those chips are actually arriving, and
    // `gBase` is solved DOWN so the ladder still lands on targetFinalBB at the
    // planned finish rather than overshooting by the premium's product.
    final premiumCloseLevel = params.rebuysCloseLevel;
    final maxPremium = maxRiskPremium(params);

    // Level is 1-based here, matching the spec. Zero once rebuys have closed.
    double rebuyPremium(int level) =>
        (maxPremium == 0 || level > premiumCloseLevel || premiumCloseLevel <= 0)
            ? 0.0
            : maxPremium * (premiumCloseLevel - level + 1) / premiumCloseLevel;

    // The compounded effect of every premium the ladder will apply. Solving
    // gBase against this is what keeps the finish on target.
    var premiumGrowthFactor = 1.0;
    for (var l = 2; l <= premiumCloseLevel && l <= plannedLevels; l++) {
      premiumGrowthFactor *= 1 + rebuyPremium(l);
    }

    // On the pace path the growth is the solver's, not a re-derivation.
    //
    // It has to be taken rather than recomputed because §F1.3 CLAMPS it — to
    // `gMax` when the climb is steeper than the pace allows, and to
    // `PACE_G_MIN` when it is flatter than is worth solving. Re-deriving
    // `targetFinalBB / openingBB` over `plannedLevels` here would quietly undo
    // both clamps and let a Deep night climb at a Turbo rate.
    //
    // The premium divisor is the same trick the legacy path uses, read the
    // other way: the ladder must land on `BB1 × g^(e−1)`, and the premium
    // multiplies the curve by `premiumGrowthFactor` along the way, so the base
    // is handed back the premium's per-level share.
    final gBase = paceSolve != null
        ? paceSolve.growth /
            math.pow(
              math.max(1e-9, premiumGrowthFactor),
              1 / math.max(1, plannedLevels - 1),
            )
        : math
            .pow(
              math.max(targetFinalBB, openingBB.toDouble()) /
                  (openingBB * premiumGrowthFactor),
              1 / math.max(1, plannedLevels - 1),
            )
            .toDouble();

    // The growth a Freeze Out with these same chips would have used — the
    // reference the premium is measured AGAINST. Identical to `gBase` bit for
    // bit whenever `premiumGrowthFactor` is 1, which is every structure with
    // no premium (§39 deviation 10, boundary 7).
    // The reference walk must use the SAME clamped growth, or `premiumRatio`
    // below stops being 1.0 on a structure with no premium at all: the printed
    // ladder would then be nudged off the reference by the clamp itself, which
    // is exactly the boundary-7 regression the ratio exists to avoid.
    final gFreezeOut = paceSolve != null
        ? paceSolve.growth
        : math
            .pow(
              math.max(targetFinalBB, openingBB.toDouble()) / openingBB,
              1 / math.max(1, plannedLevels - 1),
            )
            .toDouble();

    // Only the rungs this chip set can actually post.
    //
    // The opening rung was already filtered this way, but the CLIMB was not —
    // it walked the whole table. Adding the low rungs (1/2 … 6/12) exposed
    // that: a Home Set whose smallest chip is 5 opened legally at 5/10 and
    // then climbed to 6/12, which no combination of its chips can post
    // (23-001). §F1.6 avoids this by generating each level as a multiple of
    // `2 × cmin` rather than from a fixed table; filtering the table by the
    // starting chip is the same guarantee within the table.
    final ladder = [
      for (final pair in validBlindLevels)
        if (minChip > 0 && pair[0] % minChip == 0 && pair[1] % minChip == 0)
          pair,
    ];
    if (ladder.isEmpty) ladder.addAll(validBlindLevels);
    final levels = <BlindLevel>[];
    // Two walks over the same ladder. `cursor` is the Freeze Out reference —
    // it is exactly the walk this engine has always done, and it alone decides
    // the printed blinds when there is no premium. `premCursor` is what is
    // actually printed: the reference rung, pushed forward by the premium.
    var cursor = startIndex;
    var premCursor = startIndex;
    var prevRefBB = openingBB;
    var prevBB = openingBB;
    var rawCurve = openingBB.toDouble();
    var refCurve = openingBB.toDouble();

    for (var i = 0; i < numLevels; i++) {
      final int sb;
      final int bb;
      if (i == 0) {
        sb = ladder[startIndex][0];
        bb = openingBB;
      } else {
        // `i` is 0-based; spec levels are 1-based. Level index i IS spec level
        // i+1, so the first multiplication (i == 1) must use rebuyPremium(2).
        rawCurve *= gBase * (1 + rebuyPremium(i + 1));
        refCurve *= gFreezeOut;
        final raw = refCurve;

        // The premium as a MULTIPLE of the Freeze Out curve, not as an absolute
        // big blind.
        //
        // This is the whole fix. The walk below advances at least one rung per
        // level, and the practical ladder has roughly one rung per level, so
        // the walk — not `rawCurve` — is what sets the printed blinds: the two
        // `while` loops below never once fired on the raw value at 6, 9, 12 or
        // 18 players, and Freeze Out and Rebuy came out byte-identical even at
        // maximum premium. Chasing the raw value directly would fix that and
        // simultaneously move every Freeze Out ladder, which boundary 7
        // forbids. Expressing the premium as a ratio instead leaves the
        // reference walk untouched (ratio is exactly 1.0 when every
        // `rebuyPremium` is 0) and still moves the rungs when there is a
        // premium to apply. The ratio peaks inside the rebuy window and decays
        // back to 1 by the planned finish — which is `gBase` being solved down,
        // seen from the other side: the steeper window is handed back so the
        // ladder still ends where a Freeze Out would.
        final premiumRatio = refCurve > 0 ? rawCurve / refCurve : 1.0;

        // Extend the ladder for huge fields once the printed end is reached.
        if (cursor >= ladder.length - 1 && raw > prevRefBB) {
          final lastSb = ladder.last[0];
          ladder.add([lastSb + 200, (lastSb + 200) * 2]);
        }

        // First ladder entry strictly above the previous big blind keeps the
        // curve monotonically increasing even when growth is nearly flat.
        while (cursor < ladder.length - 1 && ladder[cursor][1] <= prevRefBB) {
          cursor++;
        }
        // Then track the raw curve: advance whenever the next entry sits
        // closer to the raw target than the current one.
        while (cursor < ladder.length - 1 &&
            ladder[cursor + 1][1] > prevRefBB &&
            (ladder[cursor + 1][1] - raw).abs() <
                (raw - ladder[cursor][1]).abs()) {
          cursor++;
        }
        prevRefBB = ladder[cursor][1];

        // Apply the premium on top of the reference rung. The printed cursor
        // never sits behind the reference one, so the Freeze Out walk remains
        // the floor and a decaying ratio can never pull the ladder backwards.
        var idx = math.max(premCursor, cursor);
        final premiumTarget = ladder[cursor][1] * premiumRatio;
        // A premium can run past the printed end sooner than the reference
        // walk does. Bounded: each pass appends a strictly larger rung.
        var extended = 0;
        while (idx >= ladder.length - 1 &&
            premiumTarget > ladder.last[1] &&
            extended < 64) {
          final lastSb = ladder.last[0];
          ladder.add([lastSb + 200, (lastSb + 200) * 2]);
          extended++;
        }
        while (idx < ladder.length - 1 &&
            (ladder[idx + 1][1] - premiumTarget).abs() <
                (premiumTarget - ladder[idx][1]).abs()) {
          idx++;
        }
        // 11-009 and the monotonicity invariant: the ladder holds duplicate
        // big blinds (20/50 and 25/50), so "one rung on" is not automatically
        // "one big blind up".
        while (idx < ladder.length - 1 && ladder[idx][1] <= prevBB) {
          idx++;
        }
        premCursor = idx;
        sb = ladder[idx][0];
        bb = ladder[idx][1];
      }
      prevBB = bb;

      final useAnte = params.anteEnabled && i >= params.anteAfterLevel;
      // Big blind ante = one ante per table equal to the big blind (the
      // recommended default). Individual ante = Build Spec v3.1 §F1.8 D7:
      // 10% of the big blind, rounded to the nearest chip actually in play
      // (see [individualAnteValue]) — not the big blind divided by an
      // assumed table size, which drifted with table size instead of blind
      // size and could snap to a value nobody was holding.
      final ante = useAnte
          ? (params.anteStyle == AnteStyle.individual
                ? individualAnteValue(
                    bb,
                    sortedChips.map((c) => c.value).toList(),
                  )
                : bb)
          : null;
      levels.add(
        BlindLevel(
          level: i + 1,
          sb: sb,
          bb: bb,
          ante: ante,
          durationMins: levelDuration,
        ),
      );
    }

    final openingSb = validBlindLevels[startIndex][0];
    final rebuyChipPlan = _buildChipPlan(
      rebuyStack,
      params.chipSet,
      params.players,
      TournamentEngine.lateEntryReserveMultiplier,
      smallBlind: openingSb,
    );
    final addOnChipPlan = _buildChipPlan(
      addOnStack,
      params.chipSet,
      params.players,
      TournamentEngine.lateEntryReserveMultiplier,
      smallBlind: openingSb,
    );

    // Colour-up schedule (10-044): a concrete exchange for every chip colour
    // that becomes impractical once blinds grow past it, tied to the level
    // where it happens. Each instruction names a specific chip count and its
    // replacement so the director can hand out chips without doing maths.
    // A formal chip race (10-048) is not the default; remainders are rounded
    // up in the player's favour instead.
    final colorUpInstructions = <String>[];
    if (sortedChips.length >= 2) {
      final planByValue = {for (final entry in chipPlan) entry.value: entry};
      for (var i = 0; i < sortedChips.length - 1; i++) {
        final chip = sortedChips[i];
        final next = sortedChips[i + 1];
        // A zero-valued denomination would make the exchange ratio below
        // divide by zero (Infinity, which `.ceil()` rejects).
        if (chip.value <= 0 || next.value <= 0) continue;
        // Build Spec v3.1 §F1.7/§F1.18: the chip is played out once the BB
        // reaches 4x the REPLACEMENT chip's value, not 20x the retiring
        // chip's own value. The two coincide whenever the ladder happens to
        // step in clean 5x jumps (5->25->500: 25*4 == 5*20 == 100), which
        // is why this went unnoticed — but they diverge on any other jump,
        // including this app's own "Home Set" preset (25->100 is only a 4x
        // step): the old rule waited for BB>=500 to retire the 25s, the
        // correct one retires them at BB>=400, a full level early.
        final level = levels.indexWhere((l) => l.bb >= next.value * 4);
        if (level < 0 || level == 0) continue;
        final entry = planByValue[chip.value];
        if (entry == null) continue;
        final count = entry.count;
        final newCount = ((count * chip.value) / next.value).ceil();
        colorUpInstructions.add(
          'Level ${levels[level].level}: exchange $count × ${chip.value} ${chip.color} '
          'chips for $newCount × ${next.value} ${next.color}',
        );
      }
      if (colorUpInstructions.isNotEmpty) {
        colorUpInstructions.add(
          'Remaining low-value chips at the final colour-up are rounded up in '
          'the player\'s favour, adding the small increase to total chips in play.',
        );
      }
    }

    final grossEligible =
        params.buyIn * params.players +
        params.effectiveRebuyCost * expectedRebuysTotal +
        params.buyIn * expectedReEntriesTotal +
        params.effectiveAddOnCost * expectedAddOnsTotal;
    // Determines which multiples payouts must be rounded to. The reference
    // schedule below (§4.1 — see §9.4/§23.1) is keyed on pools divisible by
    // 10, so decade buy-ins stay on unit 10 even when the pool is odd.
    final recalculated = PayoutBridge.recalculate(
      grossEligible: grossEligible,
      players: params.players,
      organizerPct: params.organizerPct,
      buyIn: params.buyIn,
    );
    final organizerAmount = recalculated.organizerAmount;
    final prizePool = recalculated.prizePool;
    final prizes = recalculated.prizes;
    final roundingRemainder = recalculated.roundingRemainder;

    // 11-030 / 11-031 and Technical section 6.3 step 11: an ESTIMATE derived
    // from what was actually generated, plus the end-of-rebuy settlement
    // pause — real elapsed time even though no level runs during it.
    //
    // Restating the target (`durationHours * 60 + 15`) made this tautological:
    // it could never disagree with the request, so it could never warn that
    // the generated structure does not fit. Summing the PLANNED levels agrees
    // with the target in the normal case and diverges visibly when it cannot.
    var plannedMins = 0;
    for (var i = 0; i < plannedLevels && i < levels.length; i++) {
      plannedMins += levels[i].durationMins;
    }
    // The settlement pause is a DIFFERENT thing from a scheduled break -- it
    // is the post-rebuy hold -- so the two are summed separately rather than
    // conflated. §F1.2 scopes it to the rebuy and re-entry formats.
    final settlementPause = settlementPauseFor(params.effectiveFormat);
    final expectedFinishMins =
        plannedMins + settlementPause + scheduledBreakMins;

    // Resolve break placement now that the level count is known. A break
    // carrying `afterLevel: 0` means "organizer turned breaks on but left the
    // position to us".
    // Step 5 of the addendum's generation sequence. Done before breaks,
    // because the default break position hangs off where rebuys close.
    final optimisedRebuyClose = (params.rebuys || params.reEntry)
        ? optimiseRebuyCloseLevel(
            requested: params.rebuysCloseLevel,
            organizerChose: params.rebuyCloseChosenByOrganizer,
            levelBlinds: [
              for (final l in levels) [l.sb, l.bb],
            ],
            startingStack: stack,
            plannedLevels: plannedLevels,
            players: params.players,
            durationHours: params.durationHours,
            levelDurationMins: levelDuration,
            anteEnabled: params.anteEnabled,
            anteAfterLevel: params.anteAfterLevel,
            breaks: params.breaks,
            addOnAvailable: params.addOn,
            minChipValue: minChip,
          )
        : params.rebuysCloseLevel;

    final resolvedBreaks = _placeBreaks(
      requested: params.breaks,
      plannedLevels: plannedLevels,
      rebuysEnabled: params.rebuys || params.reEntry,
      rebuysCloseLevel: optimisedRebuyClose,
    );

    // Addendum section 2 — say, in plain language, what depth was chosen and
    // why. A warning is not an explanation.
    final openingDepthBB = levels.isNotEmpty && levels.first.bb > 0
        ? stack / levels.first.bb
        : 0.0;
    final chosenStyle = TournamentStyle.fromBigBlinds(openingDepthBB);
    final styleNote = openingDepthBB <= 0
        ? ''
        : _styleNarrative(
            style: chosenStyle,
            depth: openingDepthBB,
            inventoryLimited: warnings.any((w) => w.contains('cannot fund')),
            params: params,
          );

    if (params.players < 4) {
      warnings.add('Very small field — consider a shorter structure.');
    }

    // §F1.1 `explain [{step, text, numbers}]`.
    //
    // Each entry leads with one plain sentence — that is the part §B4 rule 10
    // shows on screen — and puts the reasoning after it, behind the "Why?"
    // link. The five steps are the ones §B4 names: pace, starting depth, the
    // chip bank, the end target, and the paid curve (which §F2 owns and adds
    // when payouts run).
    final openingDepth =
        levels.isNotEmpty && levels.first.bb > 0 ? stack / levels.first.bb : 0.0;
    final explain = <StructureExplanation>[
      StructureExplanation(
        step: 'stack',
        text: 'Everyone starts with $stack in chips, about '
            '${openingDepth.round()} big blinds deep. '
            'The stack is chosen, not typed: it is the deepest round number '
            'your chip case can actually deal to ${params.players} players — '
            'including the chips set aside for forecast rebuys and add-ons — '
            'while still leaving every player small chips to post a blind '
            'with.',
        numbers: {
          'startingStack': stack,
          'openingDepthBB': openingDepth,
          'players': params.players,
        },
      ),
      if (pace != null)
        StructureExplanation(
          step: 'pace',
          text: '${pace.label} pace: ${pace.levelMinutes}-minute levels, '
              '$plannedLevels of them to the finish. '
              'One level length runs all night; what changes is how fast the '
              'blinds climb, and that is solved backwards from when you want '
              'to finish rather than picked from a table.',
          numbers: {
            'levelMinutes': pace.levelMinutes,
            'plannedLevels': plannedLevels,
            'playMinutes': pacePlayMinutes,
            'growth': paceSolve?.growth ?? 0,
          },
        ),
      StructureExplanation(
        step: 'endTarget',
        text: 'Blinds are built to reach ${targetFinalBB.round()} by the '
            'planned finish. '
            'That target is the total chips expected in play divided by '
            '$endTargetK — the point at which the last few players are short '
            'enough for the night to end rather than drift. '
            '${params.anteEnabled ? 'An ante is in play, so the divisor is larger: antes cost every player each orbit, which ends the night sooner at the same blind.' : ''}',
        numbers: {
          'targetFinalBB': targetFinalBB,
          'expectedTotalChips': expectedTotalChips,
          'K': endTargetK,
        },
      ),
      StructureExplanation(
        step: 'chipBank',
        text: depthFeasible
            ? 'Your chip case covers this field. '
                'It was checked against a busy night, not an average one: '
                'every player taking the add-on and the early bonus, and more '
                'rebuys than forecast.'
            : 'Your chip case cannot deal a playable stack to '
                '${params.players} players. '
                'A stack has to be at least $kMinPlayableDepthBB big blinds or '
                'everyone is short from the first hand.',
        numbers: {
          'players': params.players,
          if (maxPlayersSupported case final int m) 'maxPlayersSupported': m,
        },
      ),
    ];

    return TournamentStructure(
      explain: explain,
      breaks: resolvedBreaks,
      styleNote: styleNote,
      rebuysCloseLevel: optimisedRebuyClose,
      startingStack: stack,
      chipPlan: chipPlan,
      rebuyStack: rebuyStack,
      rebuyChipPlan: rebuyChipPlan,
      addOnStack: addOnStack,
      addOnChipPlan: addOnChipPlan,
      levels: levels,
      levelDuration: levelDuration,
      plannedLevels: plannedLevels,
      expectedFinishMins: expectedFinishMins,
      prizes: prizes,
      prizePool: prizePool,
      organizerAmount: organizerAmount,
      roundingRemainder: roundingRemainder,
      colorUpInstructions: colorUpInstructions,
      warnings: warnings,
      feasible: depthFeasible,
      depthShortfallNote: depthShortfallNote,
      maxPlayersSupported: maxPlayersSupported,
      engineVersion: engineVersion,
      pace: pace,
      // §F1.3: `meta.fits = fits && projectedEnd.minutes ≤ T + 5`. Both halves
      // are needed — the solver can report a growth that fits while the
      // finish, once breaks and the settlement pause are added back, still
      // lands past the window.
      fits: paceSolve == null
          ? true
          : paceSolve.fits &&
              expectedFinishMins <= paceTargetMinutes + kPaceFitToleranceMins,
      paceOverByMins: paceSolve == null
          ? 0
          : math.max(
              paceSolve.overBy,
              math.max(0, expectedFinishMins - paceTargetMinutes),
            ),
    );
  }

  /// Survivors each Stage A table sends to the final table (§11.4). One.
  static const int shootoutAdvancePerTable = 1;

  /// Shortest sensible Stage B budget, in minutes. `generate` floors its own
  /// playing time at 60 anyway; naming it here stops a long Stage A from
  /// producing a negative budget rather than a short one.
  static const int shootoutMinStageMins = 60;

  /// §11.4. Builds both halves of a shootout.
  ///
  /// Each half is the ORDINARY pipeline — `generate` with a `copyWith` that
  /// restates the field, the target duration and the format — because §39
  /// deviation 11 is explicit that a shootout is two Freeze Out generations and
  /// not a duration multiplier. Nothing here knows how to build a blind ladder;
  /// there is still exactly one implementation of that.
  ///
  /// Both stages are freeze-outs with the late-entry options switched off. A
  /// rebuy at a table playing down to one winner would be a different format,
  /// not a shootout with a safety net.
  static ShootoutPlan generateShootout(TournamentParams params) {
    final tables = math.max(1, params.effectiveShootoutTables);
    // ceil, so the split never seats more than a table holds. A one-table
    // "shootout" is degenerate but legal — it is a single Freeze Out that then
    // plays a final table against itself — and it must not divide by zero.
    final playersPerTable = math.max(2, (params.players / tables).ceil());
    final stageATargetMins = math.max(
      kMinLevelDurationMins,
      params.effectiveShootoutTableTargetMins,
    );

    final stageA = generate(
      params.copyWith(
        players: playersPerTable,
        durationHours: stageATargetMins / 60,
        format: TournamentFormat.freezeOut,
        rebuys: false,
        reEntry: false,
        addOn: false,
        // Scheduled breaks belong to the event, and Stage A is a 45-minute
        // sprint; placing the host's breaks in both stages would spend them
        // twice. Stage B carries them.
        breaks: const [],
      ),
    );

    // §11.4 Stage B's budget is `mainTarget − elapsed Stage A time`, and the
    // elapsed time is not knowable at generation: tables finish when they
    // finish. The PLANNED Stage A target stands in for it, which is why
    // boundary 9 calls shootout stage timing a target and not a guarantee —
    // a Stage A that overruns eats into this budget in the room, not here.
    final mainTargetMins = (params.durationHours * 60).round();
    final stageBMins = math.max(
      shootoutMinStageMins,
      mainTargetMins - stageATargetMins,
    );

    final stageB = generate(
      params.copyWith(
        // A final table of one is not a table; two is the floor at which a
        // structure means anything.
        players: math.max(2, tables * shootoutAdvancePerTable),
        durationHours: stageBMins / 60,
        format: TournamentFormat.freezeOut,
        rebuys: false,
        reEntry: false,
        addOn: false,
      ),
    );

    return ShootoutPlan(
      tables: tables,
      playersPerTable: playersPerTable,
      advancePerTable: shootoutAdvancePerTable,
      stageA: stageA,
      stageB: stageB,
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Build Spec v3.1 §F1 port — standalone, spec-faithful functions.
  // Accepted client-side deviation (A3): [generate] keeps its cursor-walk
  // ladder (deterministic, covered by engine_properties_test); the spec-named
  // helpers below are standalone + trace-verified. Full rewire is tracked
  // tech debt — do not partially wire DP snap into the walk.
  //
  // The functions above patch concrete bugs in THIS app's own (differently
  // architected) blind-curve engine. The functions below are new: the spec
  // names them (`dpSnapLadder`, `chooseSB`, `colourUpPlan`,
  // `suggestRebuyClose`, `resolveAroundPins`, `PoissonQuantile`) and gives
  // exact pseudocode and a fully worked, hand-traced example (§F1.15/§F1.16)
  // that nothing in the existing architecture reproduced at all — there was
  // no DP snap, no pin editor, no fresh-M rebuy-close search anywhere in this
  // file before this pass. They are implemented here verified against that
  // worked trace (see the doc comment on each), but are NOT wired into
  // [generate]'s own cursor-walk ladder: that engine has no "raw smooth
  // curve kept separate from its snapped ladder", no pace/style selector
  // input, and no break list to anchor colour-up against — wiring these in
  // for real is the architecture rewrite the task asked NOT to do in this
  // pass. `poissonQuantile90` is the one exception: it IS wired into
  // [generate]'s reserve sizing above, since that slot already existed and
  // only needed a better estimator dropped in.
  // ───────────────────────────────────────────────────────────────────────

  /// Spec v3.1 §F1.2 NICE_M — the mantissa family every "nice" blind/chip
  /// value is built from: `m x 10^k`.
  static const List<double> niceMantissas = [
    1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8,
  ];

  /// Spec v3.1 §F1.6/§F1.17 — every "nice" value (see [niceMantissas]) that
  /// is a multiple of [unit] and falls within `[lo, hi]`, ascending.
  static List<int> niceValuesInRange(int unit, double lo, double hi) {
    if (unit <= 0) return const [];
    final out = <int>{};
    for (var k = -1; k <= 7; k++) {
      final scale = math.pow(10, k).toDouble();
      for (final m in niceMantissas) {
        final v = (m * scale).round();
        if (v <= 0 || v % unit != 0) continue;
        if (v < lo || v > hi) continue;
        out.add(v);
      }
    }
    final list = out.toList()..sort();
    return list;
  }

  /// Spec v3.1 §F1.6 — the opening big blind: the single "nice" multiple of
  /// [cmin]'s unit (`2 x cmin`) closest to [target] in log space, widening
  /// the search window if nothing "nice" happens to sit near it.
  ///
  /// Verified against §F1.16 step 9: `niceBB(2, 1) == 2` (BB1, the exact
  /// opening the worked trace starts from).
  static int niceBB(double target, int cmin) {
    final unit = math.max(1, 2 * cmin);
    if (target <= 0) return unit;
    var lo = target / 1.6;
    var hi = target * 1.6;
    var candidates = niceValuesInRange(unit, lo, hi);
    var guard = 0;
    while (candidates.isEmpty && guard < 12) {
      lo /= 1.6;
      hi *= 1.6;
      candidates = niceValuesInRange(unit, lo, hi);
      guard++;
    }
    if (candidates.isEmpty) return unit;
    candidates.sort(
      (a, b) => (math.log(a / target)).abs().compareTo(
        (math.log(b / target)).abs(),
      ),
    );
    return candidates.first;
  }

  /// Spec v3.1 §F1.6/§F1.17 — the DP blind-ladder snap. Turns a smooth raw
  /// curve (`raw[i] = BB1 x g^i`) into a strictly increasing sequence of
  /// real, chip-payable big blinds: at each level, every "nice" candidate
  /// within a x1.6 window of that level's raw value is scored by its
  /// log-distance from the raw curve PLUS a transition penalty against the
  /// previous level's chosen value (a small slide above a 1.67x jump, a
  /// harsher one above 2x, and a small penalty for a near-flat < 1.15x
  /// jump), and the cheapest end-to-end chain wins.
  ///
  /// [cminOfLevel] is the smallest chip in play at each 0-indexed level
  /// (after colour-up retirements — see [colourUpPlan]). [pinnedFirst] /
  /// [pinnedLast] force a level's candidate list down to one value, which is
  /// how [resolveAroundPins] reuses this same DP inside a segment between
  /// two host-fixed levels.
  ///
  /// Verified level-by-level against §F1.16 step 9's full worked trace:
  /// raw = [2, 3, 4.5, 6.75, 10.13, 15.19, 22.78, 34.17, 51.26, 76.89,
  /// 115.33, 173, 259.49, 389.24, 583.86, 875.79], cmin jumping 1->5 at
  /// (0-indexed) level 9, produces exactly bbLadder = [2, 4, 6, 8, 10, 12,
  /// 20, 30, 50, 80, 120, 150, 250, 400, 600, 800] — matched at every level,
  /// including the two colour-up-boundary levels either side of the jump.
  static List<int> dpSnapLadder({
    required List<double> raw,
    required List<int> cminOfLevel,
    int? pinnedFirst,
    int? pinnedLast,
  }) {
    final n = raw.length;
    if (n == 0) return const [];

    final candidates = List<List<int>>.generate(n, (i) {
      if (i == 0 && pinnedFirst != null) return [pinnedFirst];
      if (i == n - 1 && pinnedLast != null) return [pinnedLast];
      final unit = math.max(1, 2 * cminOfLevel[i]);
      final list = niceValuesInRange(unit, raw[i] / 1.6, raw[i] * 1.6);
      return list.isNotEmpty ? list : [unit];
    });

    final cost = List<List<double>>.generate(
      n,
      (i) => List<double>.filled(candidates[i].length, double.infinity),
    );
    final from = List<List<int>>.generate(
      n,
      (i) => List<int>.filled(candidates[i].length, -1),
    );

    for (var c = 0; c < candidates[0].length; c++) {
      final v = candidates[0][c];
      final d = math.log(v / raw[0]);
      cost[0][c] = d * d;
    }

    for (var i = 1; i < n; i++) {
      for (var c = 0; c < candidates[i].length; c++) {
        final v = candidates[i][c];
        var best = double.infinity;
        var bestFrom = -1;
        for (var pc = 0; pc < candidates[i - 1].length; pc++) {
          final u = candidates[i - 1][pc];
          if (v <= u) continue;
          final prevCost = cost[i - 1][pc];
          if (!prevCost.isFinite) continue;
          final ratio = v / u;
          var penalty = 0.0;
          if (ratio > 2.0) {
            penalty = 5.0;
          } else if (ratio > 1.67) {
            penalty = 0.3 * (ratio - 1.67);
          }
          if (ratio < 1.15) penalty += 0.5;
          final logDist = math.log(v / raw[i]);
          final total = prevCost + logDist * logDist + penalty;
          if (total < best) {
            best = total;
            bestFrom = pc;
          }
        }
        cost[i][c] = best;
        from[i][c] = bestFrom;
      }
    }

    var lastBest = double.infinity;
    var lastIdx = -1;
    for (var c = 0; c < candidates[n - 1].length; c++) {
      if (cost[n - 1][c] < lastBest) {
        lastBest = cost[n - 1][c];
        lastIdx = c;
      }
    }
    if (lastIdx < 0 || !lastBest.isFinite) {
      return _dpSnapFallbackChain(raw, cminOfLevel, pinnedFirst: pinnedFirst);
    }

    final result = List<int>.filled(n, 0);
    var idx = lastIdx;
    for (var i = n - 1; i >= 0; i--) {
      result[i] = candidates[i][idx];
      final next = i > 0 ? from[i][idx] : -1;
      if (i > 0 && next < 0) {
        return _dpSnapFallbackChain(raw, cminOfLevel, pinnedFirst: pinnedFirst);
      }
      idx = next;
    }
    return result;
  }

  /// §F1.17 point 5 — always-correct fallback when the DP finds no
  /// end-to-end chain: walk forward taking the nearest payable nice value
  /// strictly above the previous level.
  static List<int> _dpSnapFallbackChain(
    List<double> raw,
    List<int> cminOfLevel, {
    int? pinnedFirst,
  }) {
    final n = raw.length;
    final result = List<int>.filled(n, 0);
    var prev = 0;
    for (var i = 0; i < n; i++) {
      final unit = math.max(1, 2 * cminOfLevel[i]);
      if (i == 0 && pinnedFirst != null) {
        result[i] = pinnedFirst;
        prev = pinnedFirst;
        continue;
      }
      var v = unit;
      while (v <= prev) {
        v += unit;
      }
      final nice = niceValuesInRange(unit, v.toDouble(), (v * 2).toDouble());
      result[i] = nice.isNotEmpty ? nice.first : v;
      prev = result[i];
    }
    return result;
  }

  /// Spec v3.1 §F1.6/§F1.17 `chooseSB` — the small blind for each level of
  /// a [dpSnapLadder]-produced [bbLadder].
  ///
  /// Normally the "natural" SB: BB/2 rounded to the nearest multiple of the
  /// level's own smallest chip, floored at that chip and capped below the
  /// BB. At a colour-up boundary — where this level's [cminOfLevel] is
  /// coarser than the previous level's — also considers HOLDING the
  /// previous level's SB unchanged, and picks whichever option's own growth
  /// ratio (candidate / previous SB) sits closer to the ladder's overall
  /// growth rate [g] in log space.
  ///
  /// Verified against §F1.16 step 9's colour-up boundary (level 10, cmin
  /// 1->5, g=1.5): natural = round(80/2/5)x5 = 40; holding 25 gives ratio
  /// 25/25=1 (log-distance from ln(1.5) is 0.405); natural gives ratio
  /// 40/25=1.6 (log-distance 0.065). 0.065 < 0.405, so natural wins — and
  /// the full ladder this produces, [1,2,3,4,5,6,10,15,25,40,60,75,125,200,
  /// 300,400], matches sbLadder exactly at every level.
  static List<int> chooseSBLadder({
    required List<int> bbLadder,
    required List<int> cminOfLevel,
    required double g,
  }) {
    final n = bbLadder.length;
    final sb = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final bb = bbLadder[i];
      final cmin = math.max(1, cminOfLevel[i]);
      var natural = (bb / 2 / cmin).round() * cmin;
      if (natural < cmin) natural = cmin;
      if (natural >= bb) natural = math.max(cmin, bb - cmin);

      if (i > 0 && cminOfLevel[i] > cminOfLevel[i - 1]) {
        final prevSB = sb[i - 1];
        final canHold = prevSB > 0 && prevSB % cmin == 0 && prevSB < bb;
        if (canHold) {
          final holdDist = math.log(g).abs();
          final naturalDist = (math.log(natural / prevSB) - math.log(g)).abs();
          sb[i] = naturalDist <= holdDist ? natural : prevSB;
          continue;
        }
      }
      sb[i] = natural;
    }
    return sb;
  }

  /// Spec v3.1 §F1.7/§F1.17 `colourUpPlan` — a standalone, spec-faithful
  /// companion to the in-place fix in [generate] above (which corrects only
  /// the trigger formula, since this codebase has no break-list to anchor
  /// retirement against). This version reproduces the FULL spec rule: a
  /// denomination is retired at the first scheduled break landing at or
  /// after (trigger level - 1), never before the previous denomination's own
  /// retirement break, and if no such break exists, that denomination AND
  /// every larger one stay in play for the rest of the night (iteration
  /// stops rather than skipping ahead).
  ///
  /// Verified against §F1.16 step 10: for [1, 5, 25, 100] against raw =
  /// [...level7=22.78...] and breaksAfterLevel=[5, 9] — trigger for 1->5 is
  /// raw>=4x5=20, first crossed at raw[6]=22.78, i.e. (1-indexed) level 7;
  /// the first break at or after level 7-1=6 is level 9, so the whites
  /// retire after level 9 (level 5 fails, since 5<6). For 5->25 (trigger
  /// raw>=100, first crossed at raw[10]=115.33, level 11): the first break
  /// at or after level 11-1=10 that is also >= the whites' own break (9)
  /// would have to be >=10, and breaksAfterLevel has none — so the reds
  /// never retire, matching the trace's "the 5s stay in play to the end".
  static ({List<int> cminByLevel, List<({int denomValue, int afterBreakLevel})> retirements})
  colourUpPlan({
    required List<double> raw,
    required List<int> dealtDenominationsAscending,
    required List<int> breaksAfterLevel,
  }) {
    final n = raw.length;
    final startCmin = dealtDenominationsAscending.isNotEmpty
        ? dealtDenominationsAscending.first
        : 1;
    final cmin = List<int>.filled(n, startCmin);
    final retirements = <({int denomValue, int afterBreakLevel})>[];
    var lastRetireBreak = 0;

    for (var d = 0; d < dealtDenominationsAscending.length - 1; d++) {
      final denom = dealtDenominationsAscending[d];
      final next = dealtDenominationsAscending[d + 1];
      if (denom <= 0 || next <= 0) continue;
      final trigIndex0 = raw.indexWhere((v) => v >= 4 * next);
      if (trigIndex0 < 0) break; // never reached -> this and all larger stay
      final trigLevel = trigIndex0 + 1; // 1-indexed
      int? chosenBreak;
      for (final b in breaksAfterLevel) {
        if (b >= trigLevel - 1 && b >= lastRetireBreak) {
          chosenBreak = b;
          break;
        }
      }
      if (chosenBreak == null) break; // no qualifying break -> stays forever
      retirements.add((denomValue: denom, afterBreakLevel: chosenBreak));
      lastRetireBreak = chosenBreak;
      for (var lvl = chosenBreak; lvl < n; lvl++) {
        cmin[lvl] = math.max(cmin[lvl], next);
      }
    }
    return (cminByLevel: cmin, retirements: retirements);
  }

  /// Spec v3.1 §F1.2/§F1.5/§F1.18 `PoissonQuantile` — the smallest k such
  /// that a Poisson(mean) draw is at or below k at least 90% of the time,
  /// used to size the bank reserve off a conservative tail rather than a
  /// bare average.
  ///
  /// Verified against §F1.16 step 2: `poissonQuantile90(3.5) == 6` (P(X<=5)
  /// = 0.8576 still short of 0.9; P(X<=6) = 0.9347 clears it).
  static int poissonQuantile90(double mean) {
    if (mean <= 0) return 0;
    final target = 0.9;
    var term = math.exp(-mean); // P(X = 0)
    var cdf = term;
    var k = 0;
    while (cdf < target && k < 1000) {
      k++;
      term *= mean / k; // P(X = k) from P(X = k-1)
      cdf += term;
    }
    return k;
  }

  /// Spec v3.1 §F1.10/§F1.17 `suggestRebuyClose` — the last level whose
  /// FRESH-STACK Harrington M (a brand-new stack's M at that level's own
  /// orbit cost, ignoring anyone's actual chips) still clears the style's
  /// M-floor, while also starting at or before 40% of the scheduled night
  /// has elapsed. [levels] must already carry any ante that will be live at
  /// each level — this codebase gives ante timing directly from the host's
  /// own `anteAfterLevel`, so unlike the spec's own bootstrap (which derives
  /// ante timing FROM the rebuy close, needing a two-pass placeholder), no
  /// bootstrap is needed here: ante timing and rebuy-close timing are
  /// independent inputs in this architecture, not a cycle.
  ///
  /// Verified against §F1.16 step 11: startingStack=200, levels 3/4/5 at
  /// (sb,bb) = (3,6)/(4,8)/(5,10), no ante yet live, L=20, T=270 ->
  /// freshM = 22.2 / 16.7 / 13.3, pctNight (using level-number x L) = 22.2% /
  /// 29.6% / 37.0% — all under the 40% cutoff — and with a style M-floor of
  /// 15 (standard), level 4 (M=16.7) is the LAST level clearing the floor,
  /// so suggested = 4, exactly as traced.
  static ({int suggested, List<({int level, double freshDepthBB, double freshM, double pctOfNightElapsed})> options})
  suggestRebuyClose({
    required int startingStack,
    required List<BlindLevel> levels,
    required int levelDurationMins,
    required int totalNightMinutes,
    required double mFloor,
    AnteStyle? anteStyle,
  }) {
    int computeAnteTotal(BlindLevel l) {
      final ante = l.ante ?? 0;
      if (ante <= 0) return 0;
      if (anteStyle == AnteStyle.bigBlind || (anteStyle == null && ante == l.bb)) {
        return l.bb;
      }
      return ante * 8;
    }

    final qualifying = <int>[]; // 0-indexed into levels
    for (var i = 0; i < levels.length; i++) {
      final l = levels[i];
      final orbitCost = l.sb + l.bb + computeAnteTotal(l);
      if (orbitCost <= 0) continue;
      final freshM = startingStack / orbitCost;
      final elapsedMins = (i + 1) * levelDurationMins;
      final pctNight = totalNightMinutes > 0 ? elapsedMins / totalNightMinutes : 0.0;
      if (freshM >= mFloor && pctNight <= 0.40) qualifying.add(i);
    }
    if (qualifying.isEmpty) return (suggested: 0, options: const []);

    final chosen = qualifying.last;
    final options = <({int level, double freshDepthBB, double freshM, double pctOfNightElapsed})>[];
    for (final idx in {chosen - 1, chosen, chosen + 1}) {
      if (idx < 0 || idx >= levels.length) continue;
      final l = levels[idx];
      final orbitCost = l.sb + l.bb + computeAnteTotal(l);
      final freshM = orbitCost > 0 ? startingStack / orbitCost : 0.0;
      final freshDepthBB = l.bb > 0 ? startingStack / l.bb : 0.0;
      final elapsedMins = (idx + 1) * levelDurationMins;
      final pctNight =
          totalNightMinutes > 0 ? elapsedMins / totalNightMinutes * 100 : 0.0;
      options.add((
        level: idx + 1,
        freshDepthBB: freshDepthBB,
        freshM: freshM,
        pctOfNightElapsed: pctNight,
      ));
    }
    options.sort((a, b) => a.level - b.level);
    return (suggested: chosen + 1, options: options);
  }

  /// Spec v3.1 §F1.12/§F1.17 `resolveAroundPins` — recomputes a blind ladder
  /// around host-fixed levels ("pins"), keeping each pin's own value exact
  /// and re-solving everything between and after them via [dpSnapLadder].
  ///
  /// Deliberately does NOT apply [chooseSBLadder]'s hold-at-colour-up
  /// smoothing inside a re-solved segment — every SB here is the plain
  /// BB/2-rounded value. This is a documented, spec-sanctioned divergence
  /// (§F1.12/§F1.17), not an oversight.
  static ({bool feasible, List<int> bbLadder, List<int> sbLadder, String? error})
  resolveAroundPins({
    required List<int> existingBB,
    required List<int> cminOfLevel,
    required List<PinnedLevel> pins,
    required double bbEnd,
  }) {
    final n = existingBB.length;
    if (pins.isEmpty) {
      return (
        feasible: true,
        bbLadder: existingBB,
        sbLadder: [for (final bb in existingBB) bb ~/ 2],
        error: null,
      );
    }

    final sortedPins = [...pins]..sort((a, b) => a.levelNum - b.levelNum);
    for (final p in sortedPins) {
      if (p.levelNum < 1 || p.levelNum > n) {
        return (
          feasible: false,
          bbLadder: existingBB,
          sbLadder: const [],
          error: 'Pin at level ${p.levelNum} is outside the structure.',
        );
      }
    }
    for (var i = 1; i < sortedPins.length; i++) {
      if (sortedPins[i].bb <= sortedPins[i - 1].bb) {
        return (
          feasible: false,
          bbLadder: existingBB,
          sbLadder: const [],
          error: 'Pins must be strictly increasing in big blind value '
              '(level ${sortedPins[i].levelNum} is not above level '
              '${sortedPins[i - 1].levelNum}).',
        );
      }
    }

    final resultBB = [...existingBB];

    // Between consecutive pins: geometric interpolation, then a DP snap over
    // just that segment with both ends pinned.
    for (var p = 0; p < sortedPins.length - 1; p++) {
      final a = sortedPins[p];
      final b = sortedPins[p + 1];
      final steps = b.levelNum - a.levelNum;
      if (steps <= 1) continue;
      final segRaw = <double>[
        for (var s = 0; s <= steps; s++)
          a.bb * math.pow(b.bb / a.bb, s / steps).toDouble(),
      ];
      final segCmin = cminOfLevel.sublist(a.levelNum - 1, b.levelNum);
      final snapped = dpSnapLadder(
        raw: segRaw,
        cminOfLevel: segCmin,
        pinnedFirst: a.bb,
        pinnedLast: b.bb,
      );
      for (var s = 0; s <= steps; s++) {
        resultBB[a.levelNum - 1 + s] = snapped[s];
      }
    }

    // After the last pin: retarget the remaining levels at bbEnd.
    final lastPin = sortedPins.last;
    if (lastPin.levelNum < n) {
      final tailStart = lastPin.levelNum; // 0-indexed first tail level
      final tailLen = n - tailStart;
      final seededFirst = niceBB(lastPin.bb * 1.15, cminOfLevel[tailStart]);
      final tailRaw = <double>[
        for (var s = 0; s < tailLen; s++)
          seededFirst *
              math
                  .pow(bbEnd / seededFirst, tailLen <= 1 ? 1.0 : s / (tailLen - 1))
                  .toDouble(),
      ];
      final tailCmin = cminOfLevel.sublist(tailStart);
      final snapped = dpSnapLadder(
        raw: tailRaw,
        cminOfLevel: tailCmin,
        pinnedFirst: math.max(seededFirst, lastPin.bb + 1),
      );
      for (var s = 0; s < tailLen; s++) {
        resultBB[tailStart + s] = snapped[s];
      }
    }

    // The pins' own exact values always win.
    for (final p in sortedPins) {
      resultBB[p.levelNum - 1] = p.bb;
    }

    for (var i = 1; i < resultBB.length; i++) {
      if (resultBB[i] <= resultBB[i - 1]) {
        return (
          feasible: false,
          bbLadder: resultBB,
          sbLadder: const [],
          error: 'Could not fully resolve: level ${i + 1} does not stay '
              'above level $i.',
        );
      }
    }

    final sbLadder = <int>[];
    for (var i = 0; i < resultBB.length; i++) {
      final cmin = math.max(1, cminOfLevel[i]);
      var sb = (resultBB[i] / 2 / cmin).round() * cmin;
      if (sb < cmin) sb = cmin;
      if (sb >= resultBB[i]) sb = math.max(cmin, resultBB[i] - cmin);
      sbLadder.add(sb);
    }

    return (feasible: true, bbLadder: resultBB, sbLadder: sbLadder, error: null);
  }

  // ── §F1.3 Pace mode — fitting a night to its finish time ────────────────
  //
  // The owner's model (2026-09-26): ONE level length all night — Turbo 15,
  // Regular 20, Deep 30. The climb per level is whatever reaches the finishing
  // blind by the finish time, capped at the pace's `gMax`.
  //
  // This is the Structuring Framework §6 ("Designing for a Fixed Finish Time")
  // made concrete. The Framework's four levers map exactly:
  //
  //   * level duration controls how fast time passes      → `L`
  //   * blind growth controls how fast depth disappears   → `g`
  //   * chip injections decide how much depth exists      → `C`, hence `BB_end`
  //   * breaks consume time                               → subtracted from `T`
  //
  // NOTE ON NOTATION. The Framework uses `L` for the NUMBER of levels and `t`
  // for the length of one. §F1 uses `L` for the LENGTH and `e` for the count.
  // This code follows §F1: `levelMinutes` is the length, `levels` is the
  // count. Getting these two the wrong way round produces a plausible-looking
  // structure that is wrong by a factor of the level count, so the names here
  // are spelled out rather than single letters.

  /// §F1.3 `solveUniformLevels(S, C, BB1, K, pace, P)`.
  ///
  /// [playMinutes] is `P` — the window with breaks and the settlement pause
  /// already removed. [endBB] is `BB_end = C / K`.
  static PaceSolveResult solveUniformLevels({
    required int openingBB,
    required double endBB,
    required PaceMode pace,
    required int playMinutes,
  }) {
    final levelMinutes = pace.levelMinutes;
    final gMax = pace.gMax;

    // `eFit` — the levels that fit the window at this pace. At least two: a
    // structure with one level has no growth to solve for.
    final eFit = math.max(2, playMinutes ~/ levelMinutes);

    // The whole climb, as a ratio. A target at or below the opening blind is
    // degenerate — a field so small the chips already sit deeper than the end
    // target — and there is nothing to solve.
    final ratio = endBB / math.max(1, openingBB);
    if (!ratio.isFinite || ratio <= 1) {
      return (
        levels: eFit,
        growth: kPaceGMin,
        levelMinutes: levelMinutes,
        fits: true,
        minutesNeeded: eFit * levelMinutes,
        overBy: 0,
      );
    }

    final lnRatio = math.log(ratio);

    // `gFit` — the growth that lands exactly on BB_end using every level that
    // fits.
    final gFit = math.pow(ratio, 1 / (eFit - 1)).toDouble();

    // The levels the climb needs when growth is pinned at the ceiling. This is
    // the shortest this pace can make the night.
    final levelsNeeded = 1 + lnRatio / math.log(gMax);
    final levelsAtGMax = math.max(2, levelsNeeded.ceil());

    // §F1.3: it fits if the needed growth is within the ceiling, OR if running
    // at the ceiling overshoots the window by no more than the 5-minute
    // tolerance. The test uses the FRACTIONAL `levelsNeeded`: rounding it up
    // first charged a whole extra level for a sliver and reported a night that
    // is within tolerance as running over.
    final fits = gFit <= gMax ||
        levelsNeeded * levelMinutes <= playMinutes + kPaceFitToleranceMins;

    // Below `kPaceGMin` the night just ends early, so there is no reason to
    // solve flatter than that.
    final growth =
        fits ? gFit.clamp(kPaceGMin, gMax).toDouble() : gMax;

    // When it fits, use the fewer of "levels that fit" and "levels the climb
    // actually needs at this growth" — a structure that reaches its end target
    // early should stop there rather than pad. When it does not fit, the count
    // is whatever the ceiling demands, and the night runs over.
    final levels = fits
        ? math.max(2, math.min(eFit, (1 + lnRatio / math.log(growth)).ceil()))
        : levelsAtGMax;

    final minutesNeeded = levels * levelMinutes;
    return (
      levels: levels,
      growth: growth,
      levelMinutes: levelMinutes,
      fits: fits,
      minutesNeeded: minutesNeeded,
      overBy: math.max(0, minutesNeeded - playMinutes),
    );
  }

  /// §F1.3 `paceOptions(inputs)` — runs the engine three times, once per pace,
  /// and reports what each would actually do.
  ///
  /// The recommendation rule is the spec's, and it is deliberately
  /// conservative: the **slowest of Deep, then Regular** that both fits and
  /// has a workable chip bank. **Turbo is never recommended** — it is offered
  /// only as an explicit escape when nothing else fits, because a turbo
  /// structure is a different game, not a slightly faster one.
  ///
  /// When nothing fits, this returns a `warning` and the three named
  /// `choices`, and recommends nothing. §E17 row 20: the host picks, and
  /// nothing is applied silently. That restraint is the Framework §16 point
  /// too — no formula can guarantee a finish minute, so the honest move is to
  /// show the overrun rather than quietly reshape the night around it.
  static PaceOptions paceOptions(TournamentParams params) {
    final options = <PaceOption>[];
    final structures = <PaceMode, TournamentStructure>{};

    for (final mode in PaceMode.values) {
      final TournamentStructure s;
      try {
        s = generate(params.copyWith(pace: mode));
      } on Exception {
        // A pace whose structure cannot be built at all is simply not offered,
        // rather than taking the whole menu down with it.
        continue;
      }
      structures[mode] = s;

      final opening = s.levels.isNotEmpty ? s.levels.first : null;
      options.add((
        pace: mode,
        openingBB: opening?.bb ?? 0,
        openingSB: opening?.sb ?? 0,
        startingDepthBB: (opening?.bb ?? 0) > 0
            ? s.startingStack / opening!.bb
            : 0,
        levels: s.effectivePlannedLevels,
        levelMinutes: s.levelDuration,
        fits: s.fits,
        overBy: s.paceOverByMins,
        finishMins: s.expectedFinishMins,
        // A structure the chip case cannot actually supply is not a real
        // option, however well it fits the clock.
        bankOk: s.feasible,
      ));
    }

    // Slowest first: Deep, then Regular. Turbo is not a candidate.
    PaceMode? recommended;
    for (final mode in const [PaceMode.deep, PaceMode.regular]) {
      final o = options.where((o) => o.pace == mode).firstOrNull;
      if (o != null && o.fits && o.bankOk) {
        recommended = mode;
        break;
      }
    }

    String? warning;
    var choices = const <String>[];
    if (recommended == null) {
      final regular = options.where((o) => o.pace == PaceMode.regular).firstOrNull;
      final needed = regular?.finishMins ?? params.effectiveTargetMinutes;
      final window = params.effectiveTargetMinutes;
      warning =
          'At a regular pace this field needs about ${_hhmm(needed)}; '
          'the night has ${_hhmm(window)}.';
      choices = [
        'later',
        if (params.addOn) 'noAddOn',
        'turbo',
      ];
    }

    return (
      options: options,
      recommended: recommended,
      warning: warning,
      choices: choices,
    );
  }

  /// §F1.3's warning copy is written with two-digit minutes in every case:
  /// "At a regular pace this field needs about 4h40; the night has 4h00."
  /// So a whole hour renders "4h00", not "4h".
  static String _hhmm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  /// §F1.3 `P` — minutes of actual play left in the window once the scheduled
  /// breaks and the format's settlement pause are taken out. Floored at 30, as
  /// the spec floors it: a window too short to play is still given a structure
  /// rather than an empty one.
  static int playMinutesFor({
    required int targetMinutes,
    required int scheduledBreakMins,
    required TournamentFormat format,
  }) =>
      math.max(
        30,
        targetMinutes - scheduledBreakMins - settlementPauseFor(format),
      );
}
