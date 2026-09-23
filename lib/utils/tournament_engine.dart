import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/chip_color.dart';
import '../models/tournament.dart';

/// Thrown when a chip set contains two colours with the same value
/// (spec User Flow §12.4 — duplicates are rejected, not warned).
class DuplicateChipValueException implements Exception {
  const DuplicateChipValueException(this.message);
  final String message;
  @override
  String toString() => message;
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
  static const String engineVersion = '2.1.0';

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
    [5, 10],
    [10, 20],
    [20, 40],
    [20, 50],
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

  /// Level durations offered as one-tap presets.
  ///
  /// No longer the only values a structure may use — [TournamentParams
  /// .levelDurationMins] accepts anything in [kMinLevelDurationMins] ..
  /// [kMaxLevelDurationMins]. Bucketing to 10/15/20 meant the level LENGTH was
  /// fixed before the level COUNT was known, so a 4-hour target could only ever
  /// be approximated: 16 levels of 15 is 4h00 by luck, 3h30 is not reachable at
  /// all. Choosing the length directly is what lets the two line up.
  static const List<int> validLevelDurations = [10, 15, 20];

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
  static const int settlementBreakMins = 15;

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

  /// Opening-depth band the solver will accept, in big blinds.
  ///
  /// The v11 addendum's style table spans Turbo (~40-60) to Deep (~120-200+)
  /// and is explicit that these are "style guidance, never hard constraints"
  /// -- guidance for what the engine MAY choose, not depths it must be able
  /// to produce on demand.
  ///
  /// The floor stays at 80 deliberately. Dropping it to 40 to "reach Turbo"
  /// was tried and made structures worse, not more flexible: with Standard 300
  /// at 9 players over 4 hours the solver stopped targeting ~136 BB and took a
  /// 65 BB stack that was down to 16 BB by level three. Nothing asked for that
  /// -- it simply became legal, and won.
  ///
  /// Turbo and Fast are unreachable for a different and correct reason: the
  /// shortest duration the product offers is 3 hours, and 3 hours of play
  /// properly wants ~110 BB. Those bands describe events this app does not
  /// schedule. If short-format events are ever added, lower the floor WITH a
  /// shorter duration option, not on its own.
  ///
  /// The ceiling did move: 240 overshot even Deep's ~200.
  /// The widest depth any tournament may target, spanning the addendum's whole
  /// style table -- Turbo's ~40 at one end, Deep's ~200+ at the other.
  ///
  /// These are NOT a starting-stack rule. Acceptance criterion 1 forbids
  /// hard-coding one ("no hard 50-100 BB rule"), and an 80 BB floor applied to
  /// every event was exactly that: it made Turbo and Fast unreachable however
  /// short the night, which contradicts section 2's own table.
  ///
  /// What replaces it is [admissibleDepthBand]: a band derived from the depth
  /// THIS tournament is targeting, so the constraint follows the event instead
  /// of being imposed on all of them.
  static const int kMinTargetBBDepth = 40;
  static const int kMaxTargetBBDepth = 220;

  /// The depths acceptable for a tournament aiming at [target] big blinds.
  ///
  /// The measured failure a universal floor was protecting against is worth
  /// restating, because this must not reintroduce it: Standard 300 at 9
  /// players over 4 hours targets ~136 BB, and when any low depth was legal
  /// the solver took a 65 BB stack that was down to 16 BB by level three.
  ///
  /// A band that tracks the target prevents that structurally rather than by
  /// blanket prohibition. That event targets 136, lands in Deep, and cannot
  /// take 65 -- while a genuinely short, crowded night targets low, lands in
  /// Turbo, and may. The old floor could not tell those two apart.
  ///
  /// Each band is the addendum's own figure with enough tolerance for the
  /// chip solver to find a countable stack inside it.
  static ({double min, double max}) admissibleDepthBand(double target) =>
      switch (TournamentStyle.fromBigBlinds(target)) {
        TournamentStyle.turbo => (min: 40, max: 70),
        TournamentStyle.fast => (min: 55, max: 90),
        TournamentStyle.standard => (min: 70, max: 140),
        TournamentStyle.deep => (min: 100, max: 220),
      };

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
  /// So: big-blind ante for anything but the smallest fields, individual for
  /// short-handed games where the per-hand cost of collecting is small and the
  /// fairness is more noticeable. Very short events skip antes entirely --
  /// there is not enough runway for them to matter before the blinds do the
  /// work anyway.
  static AnteRecommendation recommendAnte({
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
    if (players <= 6) {
      return const AnteRecommendation(
        enabled: true,
        style: AnteStyle.individual,
        reason: 'Short-handed, so an individual ante is quick to collect and '
            'spreads the cost evenly.',
      );
    }
    return const AnteRecommendation(
      enabled: true,
      style: AnteStyle.bigBlind,
      reason: 'One payment per hand from the big blind — faster at a full '
          'table than collecting from everybody.',
    );
  }

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
    // A bigger field takes longer to reduce, so a slightly later cutoff is
    // tolerable before the late game loses its pressure.
    var ceilingFraction = 0.55;
    if (players >= 18) ceilingFraction = 0.60;
    if (players >= 40) ceilingFraction = 0.65;

    // ── Level length + duration ──────────────────────────────────────────
    // Section 6 forbids a fixed clock rule ("rebuys always end after two
    // hours"), but level LENGTH still matters: eight 10-minute levels and
    // eight 20-minute levels are not the same tournament. The ceiling stays
    // expressed in levels, then is sanity-checked against the SHARE of the
    // night it covers -- a proportion of whatever was asked for, never a
    // fixed number of minutes.
    var ceiling = math.max(2, (plannedLevels * ceilingFraction).floor());
    if (levelDurationMins > 0 && durationHours > 0) {
      final maxWindowMins = durationHours * 60 * ceilingFraction;
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

  /// Plain-language explanation of the depth this structure landed on.
  ///
  /// Addendum section 2: "If the engine chooses an unusual depth, explain why
  /// in plain language." Naming the style is half of it; saying why it is not
  /// the default is the half that actually helps.
  static String _styleNarrative({
    required TournamentStyle style,
    required double depth,
    required bool inventoryLimited,
    required double durationHours,
  }) {
    final rounded = depth.round();
    final base = '${style.label} — $rounded big blinds to start, '
        '${style.purpose}.';
    if (style == TournamentStyle.standard) return base;
    if (inventoryLimited) {
      return '$base Your chips could not fund a deeper start, so the '
          'structure opens shorter than usual.';
    }
    if (style == TournamentStyle.deep) {
      return '$base Chosen because ${durationHours}h leaves room for '
          'post-flop play.';
    }
    return '$base Chosen to finish near your ${durationHours}h target.';
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
  /// DOCUMENTED DEVIATION (section 25 preamble, 14-028, 25-001…25-066).
  ///
  /// Where the place COUNT agrees, the split matches the section-25 reference
  /// table exactly — 0 deviations across all 67 reference pools. The counts
  /// themselves differ for one reason: three places begin at 10 unique
  /// players here, where the table starts them at 8. An 8-player game with a
  /// 110 pool therefore pays 90/20 rather than 70/30/10, and 184 of 396
  /// tested field x pool combinations differ from the table on that basis
  /// alone.
  ///
  /// The justification section 25 asks for: Technical section 9.3 sets the
  /// target at "around 15-25% of unique players, subject to a meaningful
  /// lowest prize". Three places out of 8 is 37.5% of the field — well above
  /// that band — and at typical home buy-ins the third prize lands at or near
  /// the 10 minimum, which is less than the buy-in and so pays a player less
  /// than they staked. Two places out of 8 is 25%, at the top of the band,
  /// and keeps every paid place meaningful. Three places start at 10 players,
  /// where 30% is closer to the band and the pool can carry a real third
  /// prize.
  ///
  /// This is a calibration choice, not a defect. If the client would rather
  /// match the reference table exactly, change the `players >= 10` threshold
  /// below to `players >= 8` — nothing else needs to move.
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
    int players, {
    int? forcePaidPlaces,
    int roundingUnit = 10,
    PayoutShape shape = PayoutShape.standard,
  }) {
    if (prizePool <= 0) return const [];

    var paidPlaces = forcePaidPlaces ?? _paidPlacesFor(prizePool, players);
    if (paidPlaces <= 1) {
      return [Prize(place: 1, amount: prizePool)];
    }

    // Reference style wins whenever the field size allows the same number of
    // places the schedule intends for this pool (14-028). It is the STANDARD
    // shape written out longhand, so a host who asked for a different curve
    // must not be handed it — that would silently ignore their choice.
    final reference = shape == PayoutShape.standard
        ? _referencePayouts[prizePool]
        : null;
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
    final poolIsRound = prizePool % roundingUnit == 0;

    // Distribution weights approximating the section-25 reference style.
    // Index 0 is place 1 (largest). Chosen per place count:
    //   2 places ~ 73/27, 3 places ~ 57/30/13, 4 places ~ 56/30/10/4.
    /// Descending payout weights for [n] places, normalised to 1.
    ///
    /// The `default` branch used to return a FOUR-element list for every
    /// n > 4, so `_calcPrizes` then read `weights[i]` past the end and threw a
    /// RangeError for 5+ paid places — reachable straight from the shipped
    /// 1-10 dropdowns (14-027, 12-087). Beyond 4 places we fall back to the
    /// spec's own curve: Technical section 9.4, `weight_i = exp(-lambda * i)`,
    /// normalised to the pool.
    ///
    /// A non-standard [shape] replaces all of it with a plain geometric curve
    /// — each place takes `ratio` times the one above, normalised to the pool.
    /// The rounding, the per-place minimum and the descending check below are
    /// shared, so every guarantee the standard shape carries holds for the
    /// other two as well; only the starting proportions differ.
    List<double> weightsFor(int n) {
      if (shape != PayoutShape.standard) {
        final raw = [
          for (var i = 0; i < n; i++) math.pow(shape.ratio, i).toDouble(),
        ];
        final total = raw.reduce((a, b) => a + b);
        return [for (final w in raw) w / total];
      }
      switch (n) {
        case 2:
          return [0.73, 0.27];
        case 3:
          return [0.57, 0.30, 0.13];
        case 4:
          return [0.56, 0.30, 0.10, 0.04];
        default:
          const lambda = 0.7;
          final raw = [for (var i = 0; i < n; i++) math.exp(-lambda * i)];
          final total = raw.reduce((a, b) => a + b);
          return [for (final w in raw) w / total];
      }
    }

    while (paidPlaces >= 2) {
      final weights = weightsFor(paidPlaces);
      final amounts = List<int>.filled(paidPlaces, 0);

      // Floor every lower place (2..N) to a multiple of 10, enforcing the
      // per-place minimum of 10 so no paid place is ever 0.
      var allocatedToLower = 0;
      for (var i = paidPlaces - 1; i >= 1; i--) {
        var amt =
            ((weights[i] * prizePool) / roundingUnit).floor() * roundingUnit;
        if (amt < roundingUnit) amt = roundingUnit;
        amounts[i] = amt;
        allocatedToLower += amt;
      }

      // Place 1 absorbs the exact remainder so the total is always [prizePool].
      amounts[0] = prizePool - allocatedToLower;

      // When the pool is round, place 1 is already a multiple of 10 — but a 5
      // digit can still surface if a lower place absorbed odd units. Fix it by
      // transferring 5 to/from place 2, preserving the sum.
      if (roundingUnit == 10 && poolIsRound && amounts[0] % 10 == 5) {
        if (amounts[1] >= 15) {
          amounts[0] += 5;
          amounts[1] -= 5;
        } else if (amounts[0] >= 15) {
          amounts[0] -= 5;
          amounts[1] += 5;
        }
      }

      // Validate all guarantees; drop a place and retry if any fails. When the
      // pool is not round, place 1 is exempt from the multiple-of-unit check
      // (the documented tradeoff — sum-exactness wins).
      var valid = amounts[0] >= amounts[1] && amounts[0] > 0;
      for (var i = 1; i < paidPlaces - 1 && valid; i++) {
        if (amounts[i] < amounts[i + 1]) valid = false;
      }
      for (var i = 0; i < paidPlaces && valid; i++) {
        if (amounts[i] <= 0) valid = false;
        final mustBeRound = i != 0 || poolIsRound;
        if (mustBeRound && amounts[i] % roundingUnit != 0) valid = false;
        // §9.4: no payout ends in 5. Only reachable at the smallest (5) unit;
        // place 1 stays exempt so the exact-sum guarantee wins.
        if (roundingUnit == 5 && i != 0 && amounts[i] % 10 == 5) valid = false;
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
  static List<Prize> calcPrizesForTest(
    int prizePool,
    int players, {
    PayoutShape shape = PayoutShape.standard,
  }) =>
      _calcPrizes(prizePool, players, roundingUnit: 10, shape: shape);

  /// Recalculates the organizer amount, final prize pool, and prize distribution.
  /// This is used dynamically when late players join or rebuys/add-ons are taken.
  /// The unit that payouts are rounded to for this buy-in.
  ///
  /// The MVP spec demands every displayed payout is a multiple of 10 and
  /// never ends in 5 (§9.4, §23.1). With an organizer cut > 0 the pool is
  /// always snapped to a multiple of 10 (§9.2), so any buy-in of 10+ can
  /// safely round payouts on 10 and every place stays clean. Sub-10 buy-ins
  /// (e.g. a 5 or 7 game) fall back to unit 1 so sums stay exact; a 5-unit
  /// would let payouts end in 5, which §9.4 forbids.
  /// Always 10. Payouts must be multiples of 10 and must never end in 5
  /// (14-022 / 14-023, Technical section 9.4), and that holds regardless of
  /// buy-in size. This used to drop to 1 for sub-10 buy-ins "so sums stay
  /// exact", which permitted amounts like 27; exactness is now preserved by
  /// carrying the sub-10 residue out of the pool as
  /// [TournamentStructure.roundingRemainder] instead.
  static int roundingUnitFor(int buyIn) => 10;

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

  /// Several ways to split the pool, for the organizer to choose between
  /// (specification sections 18 and 25).
  ///
  /// The engine's own recommendation — `_paidPlacesFor`, which weighs field
  /// size against pool size — comes first and is the default. Around it sit
  /// the neighbouring shapes, so a host who wants to pay one more or one fewer
  /// place can see exactly what that costs the winner before deciding.
  ///
  /// Options that cannot produce a meaningful lowest prize are dropped rather
  /// than offered: paying a fourth place 10 out of a 200 pool is worse than
  /// not paying it.
  static List<PayoutOption> payoutOptions(
    int grossEligible,
    int players,
    int organizerPct, {
    int roundingUnit = 10,
    PayoutShape shape = PayoutShape.standard,
  }) {
    final recommended = recalculatePrizes(
      grossEligible,
      players,
      organizerPct,
      roundingUnit: roundingUnit,
      shape: shape,
    );
    final defaultPlaces = recommended.prizes.length;
    if (defaultPlaces == 0) return const [];

    // The recommendation, then one fewer, then more — capped at 5 places
    // (section 18's own example range) and at what the field can support.
    final candidates = <int>{
      defaultPlaces,
      defaultPlaces - 1,
      defaultPlaces + 1,
      defaultPlaces + 2,
    }.where((n) => n >= 1 && n <= 5 && n <= players).toList()
      ..sort();

    final options = <PayoutOption>[];
    for (final places in candidates) {
      final r = recalculatePrizes(
        grossEligible,
        players,
        organizerPct,
        forcePaidPlaces: places,
        roundingUnit: roundingUnit,
        shape: shape,
      );
      if (r.prizes.length != places) continue;
      if (r.prizes.any((p) => p.amount <= 0)) continue;
      // Drop shapes where the tail is meaningless. Rounding to clean amounts
      // can leave three or more places sharing the same minimum award
      // (measured: 90/30/10/10/10 from a 150 pool), which pays nobody
      // anything worth collecting and is not a real alternative to offer.
      if (places >= 3) {
        final lowest = r.prizes.last.amount;
        final atLowest = r.prizes.where((p) => p.amount == lowest).length;
        if (atLowest >= 3) continue;
      }
      options.add(
        PayoutOption(
          paidPlaces: places,
          prizes: r.prizes,
          prizePool: r.prizePool,
          roundingRemainder: r.roundingRemainder,
          rationale: _payoutRationale(places, defaultPlaces),
        ),
      );
    }
    return options;
  }

  static String _payoutRationale(int places, int recommended) {
    if (places == recommended) return 'Recommended for this field and pool';
    if (places == 1) return 'Winner takes all';
    if (places < recommended) return 'Top-heavy — bigger first prize';
    return 'Flatter — more players get paid';
  }

  static ({
    int organizerAmount,
    int prizePool,
    List<Prize> prizes,
    int roundingRemainder,
  })
  recalculatePrizes(
    int grossEligible,
    int players,
    num organizerPct, {
    int? forcePaidPlaces,
    int roundingUnit = 10,
    PayoutShape shape = PayoutShape.standard,
  }) {
    // Organizer cut: computed in integer cents to avoid floating-point drift.
    // targetOrganizer = grossEligible * organizerPct / 100, rounded half-up.
    // The amount is then snapped to the nearest multiple of 10 that preserves
    // the same units digit as grossEligible (so the remaining prize pool is
    // always a clean multiple of 10 — spec §9.2).
    final targetOrganizer = (grossEligible * organizerPct + 50) ~/ 100;
    final mod = grossEligible % roundingUnit;
    var organizerAmount = 0;

    if (organizerPct > 0) {
      // Two candidates that carry the correct units digit mod 10, bracketing
      // the target. Pick the closer one; ties broken toward the smaller value.
      //
      // `best` is nullable on purpose. It used to be seeded at 0 and that seed
      // was then treated as "unset" (`organizerAmount == 0 && c >= 0` accepted
      // ANY candidate), so whenever 0 was the nearest valid amount the loop
      // still took the upper candidate: gross 100 at 1% retained 10 against a
      // target of 1. Technical section 9.2 wants the NEAREST amount, ties
      // broken downward, and 14-016 prefers retaining less.
      int? best;
      final baseUnits = (targetOrganizer - mod).toDouble();
      final floorCandidate = (baseUnits / roundingUnit).floor() * roundingUnit + mod;
      final ceilCandidate = floorCandidate + roundingUnit;
      for (final c in [floorCandidate, ceilCandidate]) {
        if (c < 0 || c > grossEligible) continue;
        if (best == null) {
          best = c;
          continue;
        }
        final d = (targetOrganizer - c).abs();
        final bestD = (targetOrganizer - best).abs();
        if (d < bestD || (d == bestD && c < best)) best = c;
      }
      organizerAmount = best ?? 0;
    }

    var prizePool = grossEligible - organizerAmount;
    if (prizePool < 0) prizePool = 0;

    // Carry any sub-10 residue OUT of the pool (14-022 / 14-023). A pool that
    // is not a multiple of 10 cannot be split into payouts that are all
    // multiples of 10, so with a 0% organizer cut — the documented default in
    // Technical section 6.1, i.e. the common case — an 11 x 15 game produced
    // 105/40/20 and 105 ends in 5. The residue is NOT an organizer cut and is
    // reported separately so it is never labelled as one (14-010, 14-011).
    final roundingRemainder = prizePool % roundingUnit;
    prizePool -= roundingRemainder;

    final prizes = _calcPrizes(
      prizePool,
      players,
      forcePaidPlaces: forcePaidPlaces,
      roundingUnit: roundingUnit,
      shape: shape,
    );
    return (
      organizerAmount: organizerAmount,
      prizePool: prizePool,
      prizes: prizes,
      roundingRemainder: roundingRemainder,
    );
  }

  static TournamentStructure generate(TournamentParams params) {
    final dupValues = params.chipSet.map((c) => c.value).toList();
    if (dupValues.toSet().length != dupValues.length) {
      throw const DuplicateChipValueException(
        'Two chip colours cannot share the same value.',
      );
    }

    final warnings = <String>[];
    // The host's choice wins; the duration-derived bucket is the fallback for
    // every tournament that never made one.
    final levelDuration = params.levelDurationMins
            ?.clamp(kMinLevelDurationMins, kMaxLevelDurationMins) ??
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
    final playingMinutes =
        math.max(60.0, params.durationHours * 60 - scheduledBreakMins);
    // Levels that actually fit the target. Everything that models PACE uses
    // this; the spare tail below is overtime insurance, not part of the plan.
    final plannedLevels = math.max(6, (playingMinutes / levelDuration).ceil());
    final numLevels = plannedLevels + _spareLevels;

    // Duration pushes depth up, field size pulls it down: more players means
    // more chips on the table and a longer night for the same schedule.
    final targetBBDepth = math.min(
      kMaxTargetBBDepth.toDouble(),
      math.max(
        kMinTargetBBDepth.toDouble(),
        125 +
            28 * (params.durationHours - 3.5) -
            2.5 * math.max(0, params.players - 8),
      ),
    );

    // The band this particular tournament must land in. Derived, not imposed.
    final depthBand = admissibleDepthBand(targetBBDepth);

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
    final reserveTiers = <int>{
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
        if (chosen == null || chosenPlan == null) continue;
        final candidate = chosen;

        final depth = candidate / bb;
        if (depth < depthBand.min || depth > depthBand.max) {
          continue;
        }

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
        'These chips cannot fund an 80 big-blind starting stack for '
        '${params.players} players. Add more low-denomination chips, or '
        'reduce the field, for a deeper start.',
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
        final fallbackFloor = 20 * bb;
        List<ChipPlanEntry>? plan;
        while (candidate >= fallbackFloor) {
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
    // behaviour matches the spec.) Heads-up should begin with
    // the average stack around [targetHeadsUpAverageBB] big blinds, so:
    //   targetFinalBB = expectedTotalChips / (2 × targetHeadsUpAverageBB)
    //   rawBB(i)      = openingBB × growthFactor^i
    //   growthFactor  = (targetFinalBB / openingBB)^(1 / max(1, levels − 1))
    // Every raw value is snapped to a legal, easy-to-post amount from the
    // blind ladder, the sequence stays strictly monotonically increasing, and
    // the ladder itself extends in practical +200/+400 steps if a very large
    // field needs blinds beyond its printed end.
    final expectedTotalChips =
        stack * params.players +
        rebuyStack * expectedRebuysTotal +
        math.max(0, reEntryStack - stack) * expectedReEntriesTotal +
        addOnStack * expectedAddOnsTotal;
    final targetFinalBB = expectedTotalChips / (2 * targetHeadsUpAverageBB);
    // Technical section 8.4: the exponent is `1 / max(1, plannedLevels - 1)`.
    // Using `numLevels` here spread the curve across the spare tail as well,
    // so blinds grew ~30% slower per level than the formula intends and the
    // big blind at the target finish came in around 2.5x too shallow — about
    // an hour of extra play. The same factor simply continues through the
    // spare levels, which is what you want if the game does run long.
    final growthFactor = math
        .pow(
          math.max(targetFinalBB, openingBB.toDouble()) / openingBB,
          1 / math.max(1, plannedLevels - 1),
        )
        .toDouble();

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
            (ladder[cursor + 1][1] - raw).abs() <
                (raw - ladder[cursor][1]).abs()) {
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
                    snapToPracticalBlind(bb / defaultTableSize, sortedChips),
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
      2,
      smallBlind: openingSb,
    );
    final addOnChipPlan = _buildChipPlan(
      addOnStack,
      params.chipSet,
      params.players,
      2,
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
    // Determines which multiples payouts must be rounded to. The reference
    // schedule below (§4.1 — see §9.4/§23.1) is keyed on pools divisible by
    // 10, so decade buy-ins stay on unit 10 even when the pool is odd.
    final int roundingUnit = roundingUnitFor(params.buyIn);

    final recalculated = recalculatePrizes(
      grossEligible,
      params.players,
      params.organizerPct,
      roundingUnit: roundingUnit,
      shape: params.payoutShape,
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
    // `settlementBreakMins` is a DIFFERENT thing -- the post-rebuy settlement
    // pause -- so the two are summed separately rather than conflated.
    final expectedFinishMins =
        plannedMins + settlementBreakMins + scheduledBreakMins;

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
            durationHours: params.durationHours,
          );

    if (params.players < 4) {
      warnings.add('Very small field — consider a shorter structure.');
    }

    return TournamentStructure(
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
    );
  }
}
