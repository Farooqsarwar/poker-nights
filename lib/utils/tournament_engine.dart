import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/chip_color.dart';
import '../models/tournament.dart';

/// Tournament structure engine — a faithful Dart port of the web app's
/// `src/engine/tournament.ts`. Used to generate mock structures for the UI.
///
/// Engine version is tracked for deterministic structure regeneration and
/// future compatibility (tech spec §4.1 — shared, versioned module).
class TournamentEngine {
  TournamentEngine._();

  /// Semantic version of this engine implementation. Persisted with each
  /// generated structure so the UI can detect engine upgrades.
  static const String engineVersion = '2.0.0';

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

  /// Valid blind levels as [smallBlind, bigBlind] pairs.
  ///
  /// Client constraint: 25/50, 50/100, 75/150, 100/200, then small blinds in
  /// multiples of 50 up to 300 and 100-step jumps after (150/300, 200/400,
  /// 250/500, 300/600, 400/800, …). The big blind is always 2x the small.
  static const List<List<int>> validBlindLevels = [
    [25, 50],
    [50, 100],
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

  /// Valid level durations in minutes.
  static const List<int> validLevelDurations = [10, 15, 20];

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
  static const double targetHeadsUpAverageBB = 15;

  static int _snapToPracticalBlind(double raw, List<ChipColor> chips) {
    final values = chips.map((c) => c.value).toList()..sort();
    final minChip = values.first;
    final rounded = (raw / minChip).round() * minChip;
    return math.max(rounded, minChip);
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

  static List<ChipPlanEntry> _buildChipPlan(
    int targetStack,
    List<ChipColor> chips,
    int playerCount,
    double reserveMultiplier,
  ) {
    final sorted = [...chips]..sort((a, b) => a.value - b.value);
    final plan = <ChipPlanEntry>[];
    var remaining = targetStack;

    final reversed = sorted.reversed.toList();
    for (final chip in reversed) {
      final maxPerPlayer = (chip.quantity / (playerCount * reserveMultiplier))
          .floor();
      final need = remaining ~/ chip.value;
      final use = math.min(
        need,
        math.min(math.max(1, maxPerPlayer), maxChipsPerPlayer),
      );
      if (use > 0) {
        plan.add(
          ChipPlanEntry(
            color: chip.color,
            hex: chip.hex,
            value: chip.value,
            count: use,
          ),
        );
        remaining -= use * chip.value;
      }
    }

    if (remaining > 0 && sorted.isNotEmpty) {
      final small = sorted.first;
      final index = plan.indexWhere((p) => p.color == small.color);
      final existing = index >= 0 ? plan[index].count : 0;
      final extra = math.min(
        (remaining / small.value).ceil(),
        math.max(0, maxChipsPerPlayer - existing),
      );
      if (extra > 0) {
        if (index >= 0) {
          plan[index] = ChipPlanEntry(
            color: small.color,
            hex: small.hex,
            value: small.value,
            count: plan[index].count + extra,
          );
        } else {
          plan.add(
            ChipPlanEntry(
              color: small.color,
              hex: small.hex,
              value: small.value,
              count: extra,
            ),
          );
        }
      }
    }

    plan.sort((a, b) => b.value - a.value);
    return plan;
  }

  /// Decides how many places get paid.
  ///
  /// Depends on BOTH the size of the field AND the prize pool (checklist
  /// 14-019 / 14-027):
  ///  * base tier from unique player count: >=6 -> 2, >=10 -> 3, >=18 -> 4;
  ///  * clamped to the reference-style pool thresholds (section 25): never pay
  ///    3+ places under a 100 pool, never pay 4 under a 400 pool;
  ///  * finally capped so every paid place can still receive at least the
  ///    minimum award of 10 (`paidPlaces <= prizePool ~/ 10`), which prevents a
  ///    "paid" place from ever landing on 0.
  static int _paidPlacesFor(int prizePool, int players) {
    var places = 1;
    if (players >= 6) places = 2;
    if (players >= 10) places = 3;
    if (players >= 18) places = 4;

    // Clamp to the reference payout style: small pools simply do not spread
    // across many places.
    if (prizePool < 100 && places > 2) places = 2;
    if (prizePool < 400 && places > 3) places = 3;

    // Never promise more places than can each clear the 10 minimum.
    final maxByPool = prizePool ~/ 10;
    if (places > maxByPool) places = maxByPool;
    if (places < 1) places = prizePool > 0 ? 1 : 0;

    return places;
  }

  /// Splits [prizePool] across the paid places.
  ///
  /// Guarantees (checklist section 14):
  ///  * 14-022 every award is a multiple of 10;
  ///  * 14-023 no award ends in 5;
  ///  * 14-024 the awards sum EXACTLY to [prizePool] — this is absolute;
  ///  * 14-025 place 1 is the largest;
  ///  * 14-026 amounts are monotonic non-increasing down the places;
  ///  * no paid place pays 0 (paidPlaces is reduced until every place clears
  ///    the 10 minimum).
  ///
  /// Approach: compute weighted amounts for places 2..N as multiples of 10,
  /// assign place 1 the remainder, then fix any place-1 digit that lands on 5
  /// by transferring 5 to/from an adjacent place while preserving the sum and
  /// monotonicity.
  ///
  /// Tradeoff (documented): the split is computed on [prizePool] directly. The
  /// caller normally hands us a pool that is already a multiple of 10 (the
  /// organizer cut is snapped to a multiple of 10 before the pool is derived),
  /// so every place comes out a clean multiple of 10. Should [prizePool] ever
  /// carry a units digit (i.e. `prizePool % 10 != 0`), sum-exactness (14-024)
  /// is honoured absolutely: places 2..N stay multiples of 10 and the leftover
  /// — including the stray units — lands on place 1, which then cannot be a
  /// multiple of 10. In that (production-unreachable) case the multiple-of-10
  /// and no-5 rules necessarily bend for place 1 alone; the sum stays exact.
  /// The approved reference payout schedule (checklist section 25, 25-001 …
  /// 25-066): pool -> award for place 1, 2, … This is the intended style
  /// (14-028); the engine uses it verbatim whenever the computed place count
  /// matches, and falls back to the weighted approximation for pools that fall
  /// outside the 50..700 grid or fields too small to unlock all places.
  static const Map<int, List<int>> _referencePayouts = {
    50: [40, 10],
    60: [40, 20],
    70: [50, 20],
    80: [50, 30],
    90: [60, 30],
    100: [60, 30, 10],
    110: [70, 30, 10],
    120: [70, 40, 10],
    130: [80, 40, 10],
    140: [80, 40, 20],
    150: [90, 40, 20],
    160: [90, 50, 20],
    170: [100, 50, 20],
    180: [110, 50, 20],
    190: [110, 60, 20],
    200: [110, 60, 30],
    210: [120, 60, 30],
    220: [130, 60, 30],
    230: [130, 70, 30],
    240: [140, 70, 30],
    250: [140, 80, 30],
    260: [150, 80, 30],
    270: [150, 80, 40],
    280: [160, 80, 40],
    290: [160, 90, 40],
    300: [170, 90, 40],
    310: [180, 90, 40],
    320: [180, 100, 40],
    330: [190, 100, 40],
    340: [190, 100, 50],
    350: [200, 100, 50],
    360: [200, 110, 50],
    370: [210, 110, 50],
    380: [210, 120, 50],
    390: [220, 120, 50],
    400: [220, 120, 40, 20],
    410: [230, 120, 40, 20],
    420: [240, 120, 40, 20],
    430: [240, 130, 40, 20],
    440: [250, 130, 40, 20],
    450: [250, 140, 40, 20],
    460: [260, 140, 40, 20],
    470: [260, 140, 50, 20],
    480: [270, 140, 50, 20],
    490: [270, 150, 50, 20],
    500: [280, 150, 50, 20],
    510: [290, 150, 50, 20],
    520: [290, 160, 50, 20],
    530: [300, 160, 50, 20],
    540: [300, 160, 60, 20],
    550: [310, 160, 60, 20],
    560: [310, 170, 60, 20],
    570: [320, 170, 60, 20],
    580: [320, 180, 60, 20],
    590: [330, 180, 60, 20],
    600: [330, 180, 70, 20],
    610: [340, 180, 70, 20],
    620: [340, 190, 70, 20],
    630: [350, 190, 70, 20],
    640: [350, 190, 80, 20],
    650: [360, 190, 80, 20],
    660: [360, 200, 80, 20],
    670: [370, 200, 80, 20],
    680: [370, 210, 80, 20],
    690: [380, 210, 80, 20],
    700: [390, 210, 80, 20],
  };

  static List<Prize> _calcPrizes(
    int prizePool,
    int players, [
    int? forcePaidPlaces,
  ]) {
    if (prizePool <= 0) return const [];

    var paidPlaces = forcePaidPlaces ?? _paidPlacesFor(prizePool, players);
    if (paidPlaces <= 1) {
      return [Prize(place: 1, amount: prizePool)];
    }

    // Reference style wins whenever the field size allows the same number of
    // places the schedule intends for this pool (14-028).
    final reference = _referencePayouts[prizePool];
    if (forcePaidPlaces == null &&
        reference != null &&
        reference.length == paidPlaces) {
      return [
        for (var i = 0; i < reference.length; i++)
          Prize(place: i + 1, amount: reference[i]),
      ];
    }

    // Whether every place can, in principle, be a multiple of 10. Only false
    // for the rare non-round pool; drives how strictly we validate below.
    final poolIsRound = prizePool % 10 == 0;

    // Distribution weights approximating the section-25 reference style.
    // Index 0 is place 1 (largest). Chosen per place count:
    //   2 places ~ 73/27, 3 places ~ 57/30/13, 4 places ~ 56/30/10/4.
    List<double> weightsFor(int n) {
      switch (n) {
        case 2:
          return [0.73, 0.27];
        case 3:
          return [0.57, 0.30, 0.13];
        default:
          return [0.56, 0.30, 0.10, 0.04];
      }
    }

    while (paidPlaces >= 2) {
      final weights = weightsFor(paidPlaces);
      final amounts = List<int>.filled(paidPlaces, 0);

      // Floor every lower place (2..N) to a multiple of 10, enforcing the
      // per-place minimum of 10 so no paid place is ever 0.
      var allocatedToLower = 0;
      for (var i = paidPlaces - 1; i >= 1; i--) {
        var amt = ((weights[i] * prizePool) / 10).floor() * 10;
        if (amt < 10) amt = 10;
        amounts[i] = amt;
        allocatedToLower += amt;
      }

      // Place 1 absorbs the exact remainder so the total is always [prizePool].
      amounts[0] = prizePool - allocatedToLower;

      // When the pool is round, place 1 is already a multiple of 10 — but a 5
      // digit can still surface if a lower place absorbed odd units. Fix it by
      // transferring 5 to/from place 2, preserving the sum.
      if (poolIsRound && amounts[0] % 10 == 5) {
        if (amounts[1] >= 15) {
          amounts[0] += 5;
          amounts[1] -= 5;
        } else if (amounts[0] >= 15) {
          amounts[0] -= 5;
          amounts[1] += 5;
        }
      }

      // Validate all guarantees; drop a place and retry if any fails. When the
      // pool is not round, place 1 is exempt from the multiple-of-10 check (the
      // documented tradeoff — sum-exactness wins).
      var valid = amounts[0] >= amounts[1] && amounts[0] > 0;
      for (var i = 1; i < paidPlaces - 1 && valid; i++) {
        if (amounts[i] < amounts[i + 1]) valid = false;
      }
      for (var i = 0; i < paidPlaces && valid; i++) {
        if (amounts[i] <= 0) valid = false;
        final mustBeRound = i != 0 || poolIsRound;
        if (mustBeRound && amounts[i] % 10 != 0) valid = false;
      }
      if (!valid) {
        paidPlaces--;
        continue;
      }

      final prizes = <Prize>[
        for (var i = 0; i < paidPlaces; i++)
          Prize(place: i + 1, amount: amounts[i]),
      ];
      prizes.sort((a, b) => a.place - b.place);
      return prizes;
    }

    // Fell through to a single payout.
    return [Prize(place: 1, amount: prizePool)];
  }

  /// Test-only wrapper exposing [_calcPrizes] for the payout acceptance tests.
  @visibleForTesting
  static List<Prize> calcPrizesForTest(int prizePool, int players) =>
      _calcPrizes(prizePool, players);

  /// Recalculates the organizer amount, final prize pool, and prize distribution.
  /// This is used dynamically when late players join or rebuys/add-ons are taken.
  static ({int organizerAmount, int prizePool, List<Prize> prizes})
  recalculatePrizes(
    int grossEligible,
    int players,
    num organizerPct, {
    int? forcePaidPlaces,
  }) {
    // Organizer cut: computed in integer cents to avoid floating-point drift.
    // targetOrganizer = grossEligible * organizerPct / 100, rounded half-up.
    // The amount is then snapped to the nearest multiple of 10 that preserves
    // the same units digit as grossEligible (so the remaining prize pool is
    // always a clean multiple of 10 — spec §9.2).
    final targetOrganizer = (grossEligible * organizerPct + 50) ~/ 100;
    final mod = grossEligible % 10;
    var organizerAmount = 0;

    if (organizerPct > 0) {
      // Two candidates that carry the correct units digit mod 10, bracketing
      // the target. Pick the closer one; ties broken toward the smaller value.
      final baseUnits = (targetOrganizer - mod);
      final floorCandidate = (baseUnits ~/ 10) * 10 + mod;
      final ceilCandidate = floorCandidate + 10;
      for (final c in [floorCandidate, ceilCandidate]) {
        if (c < 0 || c > grossEligible) continue;
        final d = (targetOrganizer - c).abs();
        final bestD = (targetOrganizer - organizerAmount).abs();
        if (organizerAmount == 0 && c >= 0 ||
            d < bestD ||
            (d == bestD && c < organizerAmount)) {
          organizerAmount = c;
        }
      }
    }

    var prizePool = grossEligible - organizerAmount;
    if (prizePool < 0) prizePool = 0;

    final prizes = _calcPrizes(prizePool, players, forcePaidPlaces);
    return (
      organizerAmount: organizerAmount,
      prizePool: prizePool,
      prizes: prizes,
    );
  }

  static TournamentStructure generate(TournamentParams params) {
    final warnings = <String>[];
    final levelDuration = _levelDurationFor(params.durationHours);
    final playingMinutes = params.durationHours * 60 * 0.9;
    final numLevels = math.max(6, (playingMinutes / levelDuration).floor());

    final targetBBDepth = math.min(
      240,
      math.max(
        80,
        125 +
            28 * (params.durationHours - 3.5) -
            2.5 * math.max(0, params.players - 8),
      ),
    );

    final sortedChips = [...params.chipSet]..sort((a, b) => a.value - b.value);
    final minChip = sortedChips.isNotEmpty ? sortedChips.first.value : 1;
    int startIndex = validBlindLevels.indexWhere(
      (level) => level[0] >= minChip,
    );
    if (startIndex < 0) startIndex = validBlindLevels.length - 1;
    final openingLevel = validBlindLevels[startIndex];
    final openingBB = openingLevel[1];

    final startingStack = math.max(
      openingBB,
      ((targetBBDepth * openingBB) / 100).round() * 100,
    );

    // The chip plan must never hand a player an absurd number of chips. If the
    // inventory can't cover the target stack, reduce the stack (rounding to the
    // nearest 100, never below one opening blind) until it fits. This keeps the
    // starting stack and the chip plan consistent instead of piling ~1000 small
    // chips onto a single colour.
    var stack = startingStack;
    List<ChipPlanEntry> chipPlan;
    while (true) {
      chipPlan = _buildChipPlan(
        stack,
        params.chipSet,
        params.players,
        params.rebuys ? 2 : 1.2,
      );
      final covered = chipPlan.fold<int>(0, (s, e) => s + e.count * e.value);
      if (covered >= stack || stack <= openingBB) break;
      final newStack = math.max(openingBB, ((stack - 100) ~/ 100) * 100);
      if (newStack == stack) break;
      stack = newStack;
    }

    final addOnStack = params.addOn ? stack : 0;
    final rebuyStack = stack;

    // Expected additional money-chip volume (tech spec §6.3 step 4): rebuys,
    // re-entries and add-ons inflate total chips in play and therefore the
    // final blind target. Computed here so the blind curve can use them.
    final expectedRebuysTotal = params.rebuys
        ? (params.players * 0.35).round()
        : 0;
    final expectedReEntriesTotal = params.reEntry
        ? (params.players * 0.20).round()
        : 0;
    final expectedAddOnsTotal = params.addOn
        ? (params.players * 0.65).round()
        : 0;

    // ── Blind curve (tech spec §8.3 / §8.4) ─────────────────────────────────
    // The final big blind is derived from the total chips that will actually
    // be in play: starting stacks plus expected rebuys, re-entries and
    // add-ons. Heads-up should begin with the average stack around
    // [targetHeadsUpAverageBB] big blinds, so:
    //   targetFinalBB = expectedTotalChips / (2 × targetHeadsUpAverageBB)
    //   rawBB(i)      = openingBB × growthFactor^i
    //   growthFactor  = (targetFinalBB / openingBB)^(1 / max(1, levels − 1))
    // Every raw value is snapped to a legal, easy-to-post amount from the
    // blind ladder, the sequence stays strictly monotonically increasing, and
    // the ladder itself extends in practical +200/+400 steps if a very large
    // field needs blinds beyond its printed end.
    final expectedTotalChips =
        stack * params.players +
        stack * expectedRebuysTotal +
        stack * expectedReEntriesTotal +
        addOnStack * expectedAddOnsTotal;
    final targetFinalBB =
        expectedTotalChips / (2 * targetHeadsUpAverageBB);
    final growthFactor = math.pow(
      math.max(targetFinalBB, openingBB.toDouble()) / openingBB,
      1 / math.max(1, numLevels - 1),
    ).toDouble();

    final ladder = [...validBlindLevels];
    final levels = <BlindLevel>[];
    var cursor = startIndex;
    var prevBB = openingBB;

    for (var i = 0; i < numLevels; i++) {
      final int sb;
      final int bb;
      if (i == 0) {
        sb = ladder[startIndex][0];
        bb = openingBB;
      } else {
        final raw = openingBB * math.pow(growthFactor, i);

        // Extend the ladder for huge fields once the printed end is reached.
        if (cursor >= ladder.length - 1 && raw > prevBB) {
          final lastSb = ladder.last[0];
          ladder.add([lastSb + 200, (lastSb + 200) * 2]);
        }

        // First ladder entry strictly above the previous big blind keeps the
        // curve monotonically increasing even when growth is nearly flat.
        while (cursor < ladder.length - 1 && ladder[cursor][1] <= prevBB) {
          cursor++;
        }
        // Then track the raw curve: advance whenever the next entry sits
        // closer to the raw target than the current one.
        while (cursor < ladder.length - 1 &&
            ladder[cursor + 1][1] > prevBB &&
            (ladder[cursor + 1][1] - raw).abs() < (raw - ladder[cursor][1]).abs()) {
          cursor++;
        }
        sb = ladder[cursor][0];
        bb = ladder[cursor][1];
      }
      prevBB = bb;

      final useAnte = params.anteEnabled && i >= params.anteAfterLevel;
      // Big blind ante = one ante per table equal to the big blind (the
      // recommended default). Individual ante = big blind divided by the
      // expected table size, snapped to a practical chip value (tech spec
      // §8.5) so each player can post it with chips actually in play.
      final ante = useAnte
          ? (params.anteStyle == AnteStyle.individual
                ? math.max(
                    minChip,
                    _snapToPracticalBlind(
                      bb / defaultTableSize,
                      sortedChips,
                    ),
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

    final rebuyChipPlan = _buildChipPlan(
      rebuyStack,
      params.chipSet,
      params.players,
      2,
    );
    final addOnChipPlan = _buildChipPlan(
      addOnStack,
      params.chipSet,
      params.players,
      2,
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
        // The chip is played out once the BB is at least 20x its value.
        final level = levels.indexWhere((l) => l.bb >= chip.value * 20);
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
    final recalculated = recalculatePrizes(
      grossEligible,
      params.players,
      params.organizerPct,
    );
    final organizerAmount = recalculated.organizerAmount;
    final prizePool = recalculated.prizePool;
    final prizes = recalculated.prizes;

    final expectedFinishMins = (numLevels * levelDuration * 1.05).round();

    final values = params.chipSet.map((c) => c.value).toList();
    if (values.toSet().length != values.length) {
      warnings.add(
        'Duplicate chip values detected. Two colours should not share the same value.',
      );
    }

    if (params.players < 4) {
      warnings.add('Very small field — consider a shorter structure.');
    }
    if (stack < openingBB * 50) {
      warnings.add(
        'Short starting depth — players will be short-stacked early.',
      );
    }

    return TournamentStructure(
      startingStack: stack,
      chipPlan: chipPlan,
      rebuyStack: rebuyStack,
      rebuyChipPlan: rebuyChipPlan,
      addOnStack: addOnStack,
      addOnChipPlan: addOnChipPlan,
      levels: levels,
      levelDuration: levelDuration,
      expectedFinishMins: expectedFinishMins,
      prizes: prizes,
      prizePool: prizePool,
      organizerAmount: organizerAmount,
      colorUpInstructions: colorUpInstructions,
      warnings: warnings,
    );
  }
}
