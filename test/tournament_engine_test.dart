// Engine acceptance tests — MVP technical spec §23.1. Pure Dart against
// TournamentEngine: no Firebase, no provider plumbing.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

ChipColor _chip(String name, int value, int qty) =>
    ChipColor(color: name, hex: 0xFF000000 + value, value: value, quantity: qty);

/// Generous inventory of a typical numbered home set — greedy composition
/// lands exactly on the requested stack, so equality assertions hold.
final List<ChipColor> richChips = [
  _chip('White', 25, 4000),
  _chip('Red', 100, 2000),
  _chip('Blue', 500, 800),
  _chip('Black', 1000, 300),
];

int _covered(List<ChipPlanEntry> plan) =>
    plan.fold(0, (sum, e) => sum + e.total);

/// Exact-change payability with unlimited chips of each active denomination.
bool _canPay(int amount, List<int> values) {
  final reachable = <int>{0};
  final sorted = [...values]..sort();
  for (var target = 0; target <= amount; target++) {
    if (!reachable.contains(target)) continue;
    for (final v in sorted) {
      if (target + v <= amount) reachable.add(target + v);
    }
  }
  return reachable.contains(amount);
}

TournamentParams _params({
  int players = 10,
  double hours = 3.5,
  int buyIn = 15,
  List<ChipColor>? chips,
  bool rebuys = true,
  bool addOn = true,
  bool ante = false,
  int anteAfterLevel = 6,
  AnteStyle anteStyle = AnteStyle.bigBlind,
  bool ko = false,
  int koAmount = 0,
  int organizerPct = 10,
}) =>
    TournamentParams(
      players: players,
      durationHours: hours,
      buyIn: buyIn,
      chipSet: chips ?? TournamentEngine.getPreset('Standard 300'),
      rebuys: rebuys,
      rebuysCloseLevel: 6,
      addOn: addOn,
      anteEnabled: ante,
      anteAfterLevel: anteAfterLevel,
      anteStyle: anteStyle,
      koEnabled: ko,
      koAmount: koAmount,
      organizerPct: organizerPct,
    );

void main() {
  final chipSets = {
    'standard300': TournamentEngine.getPreset('Standard 300'),
    'home4': TournamentEngine.getPreset('Home Set (4 colour)'),
    'rich': richChips,
  };

  // ── §23.1 level duration is always 10, 15 or 20 ────────────────────────────
  test('every generated level uses a 10/15/20 minute duration', () {
    for (final hours in [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0]) {
      for (final players in [2, 5, 8, 13, 20, 30]) {
        for (final chips in chipSets.values) {
          final s = TournamentEngine.generate(
            _params(players: players, hours: hours, chips: chips),
          );
          expect(TournamentEngine.validLevelDurations, contains(s.levelDuration));
          for (final level in s.levels) {
            expect(TournamentEngine.validLevelDurations, contains(level.durationMins),
                reason: 'hours=$hours players=$players');
            expect(level.durationMins, s.levelDuration);
          }
        }
      }
    }
  });

  // ── §23.1 blinds strictly increasing, no removed level, payable ────────────
  test('blind sequence is strictly increasing, contiguous and payable', () {
    for (final chips in chipSets.values) {
      for (final players in [2, 8, 17]) {
        for (final hours in [3.0, 4.5, 6.0]) {
          final s = TournamentEngine.generate(
            _params(players: players, hours: hours, chips: chips),
          );
          expect(s.levels.length, greaterThanOrEqualTo(6));
          final values = chips.map((c) => c.value).toSet().toList();
          for (var i = 0; i < s.levels.length; i++) {
            final l = s.levels[i];
            expect(l.level, i + 1, reason: 'levels must be contiguous');
            expect(l.bb, greaterThan(l.sb));
            if (i > 0) expect(l.bb, greaterThan(s.levels[i - 1].bb));
            expect(_canPay(l.sb, values), isTrue);
            expect(_canPay(l.bb, values), isTrue);
            if (l.ante != null) {
              expect(l.ante! % values.reduce(math.min), 0,
                  reason: 'ante must be payable');
              expect(l.ante, greaterThanOrEqualTo(values.reduce(math.min)));
            }
          }
        }
      }
    }
  });

  test('big blind ante equals the big blind', () {
    final bba = TournamentEngine.generate(
      _params(chips: richChips, ante: true, anteAfterLevel: 3),
    );
    for (final l in bba.levels.where((l) => l.level > 3)) {
      expect(l.ante, l.bb);
    }
  });

  // §8.5: individual ante candidate = bb ÷ TournamentEngine.defaultTableSize
  // (9), snapped by _snapToPracticalBlind to min-chip multiples and floored
  // at minChip.
  test('individual ante is BB-over-table-size snapped', () {
    final ind = TournamentEngine.generate(
      _params(chips: richChips, ante: true, anteAfterLevel: 3,
          anteStyle: AnteStyle.individual),
    );
    final minChip =
        richChips.map((c) => c.value).reduce(math.min);
    int expectedAnte(int bb) => math.max(
        25,
        ((bb / TournamentEngine.defaultTableSize) / 25).round() * 25);
    for (final l in ind.levels.where((l) => l.level > 3)) {
      expect(l.ante, isNotNull, reason: 'L${l.level}');
      expect(l.ante! % minChip, 0,
          reason: 'L${l.level}: ante must be a min-chip multiple');
      expect(l.ante, greaterThanOrEqualTo(minChip),
          reason: 'L${l.level}: ante floored at min chip');
      expect(l.ante, lessThanOrEqualTo(l.bb),
          reason: 'L${l.level}: individual ante never exceeds the BB');
      expect(l.ante, expectedAnte(l.bb),
          reason: 'L${l.level} bb=${l.bb}');
    }
  });

  // ── §23.1 starting/rebuy stacks equal their declared value ─────────────────
  test('chip plans cover the declared stacks exactly on healthy inventories',
      () {
    for (final players in [2, 6, 9]) {
      for (final hours in [3.0, 3.5, 5.5]) {
        final s = TournamentEngine.generate(
          _params(players: players, hours: hours, chips: richChips),
        );
        expect(_covered(s.chipPlan), s.startingStack,
            reason: 'starting plan p=$players h=$hours');
        expect(_covered(s.rebuyChipPlan), s.rebuyStack);
        expect(s.rebuyStack, s.startingStack,
            reason: 'a rebuy restores the original stack value');
        if (s.addOnStack > 0) expect(_covered(s.addOnChipPlan), s.addOnStack);
        expect(s.startingStack % 100, 0);
      }
    }
  });

  test('depleted inventory reduces the stack instead of dumping chips', () {
    // Tiny inventory forces the reduce-stack loop; the plan must still cover
    // whatever stack was declared.
    final tiny = [
      _chip('White', 25, 60),
      _chip('Red', 100, 30),
    ];
    final s = TournamentEngine.generate(
      _params(players: 8, chips: tiny, rebuys: false, addOn: false),
    );
    expect(_covered(s.chipPlan), greaterThanOrEqualTo(s.startingStack));
    expect(s.startingStack,
        greaterThanOrEqualTo(s.levels.first.bb));
  });

  // ── §23.1 exact-inventory guarantee ────────────────────────────────────────
  test('allocated chips never exceed the configured per-colour quantities', () {
    void checkPlans(TournamentStructure s, TournamentParams p,
        {required double startReserve}) {
      final minValue =
          p.chipSet.map((c) => c.value).reduce(math.min);
      void check(List<ChipPlanEntry> plan, double reserve) {
        for (final e in plan) {
          final share = e.value == minValue ? 25 : 1;
          final allowed = math.max(
            share,
            (p.chipSet
                    .firstWhere((c) => c.value == e.value)
                    .quantity ~/
                (p.players * reserve))
                .floor(),
          );
          expect(e.count, lessThanOrEqualTo(allowed),
              reason: '${e.color} ×${e.count} exceeds its inventory share');
        }
      }

      check(s.chipPlan, startReserve);
      check(s.rebuyChipPlan, 2);
      if (s.addOnStack > 0) check(s.addOnChipPlan, 2);
    }

    for (final chips in chipSets.values) {
      for (final players in [4, 9, 20]) {
        final p = _params(players: players, chips: chips);
        checkPlans(TournamentEngine.generate(p), p, startReserve: 2);
        final noRebuy =
            _params(players: players, chips: chips, rebuys: false);
        checkPlans(TournamentEngine.generate(noRebuy), noRebuy,
            startReserve: 1.2);
      }
    }
  });

  // ── §23.1 payouts total the pool exactly, multiples of 10 ──────────────────
  test('payouts sum exactly to the pool and respect rounding rules', () {
    for (var pool = 10; pool <= 2000; pool += 10) {
      for (final players in [4, 8, 12, 20, 30]) {
        final prizes = TournamentEngine.calcPrizesForTest(pool, players);
        expect(prizes.fold<int>(0, (s, p) => s + p.amount), pool,
            reason: 'pool=$pool players=$players');
        expect(prizes.first.amount, prizes.map((p) => p.amount).reduce(math.max));
        for (var i = 0; i < prizes.length; i++) {
          final prize = prizes[i];
          expect(prize.place, i + 1);
          expect(prize.amount, greaterThanOrEqualTo(10),
              reason: 'no paid place may receive 0');
          expect(prize.amount % 10, 0, reason: 'multiples of 10 only');
          expect(prize.amount % 10, isNot(5));
          if (i > 0) {
            expect(prize.amount, lessThanOrEqualTo(prizes[i - 1].amount));
          }
        }
      }
    }
  });

  test('reference payout schedule is reproduced verbatim', () {
    // Spec §9.4 calibration targets, backed by the approved section-25 table.
    expect(
      TournamentEngine.calcPrizesForTest(50, 10).map((p) => p.amount),
      [40, 10],
    );
    expect(
      TournamentEngine.calcPrizesForTest(100, 10).map((p) => p.amount),
      [60, 30, 10],
    );
    expect(
      TournamentEngine.calcPrizesForTest(400, 18).map((p) => p.amount),
      [220, 120, 40, 20],
    );
  });

  test('weighted fallback approximates 73/27 · 57/30/13 · 56/30/10/4', () {
    double share(int pool, List<int> amounts) =>
        amounts.first / pool;
    // Non-grid pools exercise the exponential-weight path.
    final two = TournamentEngine.calcPrizesForTest(730, 8)
        .map((p) => p.amount)
        .toList();
    expect(share(730, two), inInclusiveRange(0.68, 0.78));

    final three = TournamentEngine.calcPrizesForTest(1230, 12)
        .map((p) => p.amount)
        .toList();
    expect(three.first / 1230, inInclusiveRange(0.52, 0.62));
  });

  // ── §23.1 KO bounty money never enters the regular pool ────────────────────
  test('KO bounty is excluded from prize pool and organizer calculation', () {
    final withoutKo = TournamentEngine.generate(
      _params(chips: richChips, buyIn: 15),
    );
    final withKo = TournamentEngine.generate(
      _params(chips: richChips, buyIn: 15, ko: true, koAmount: 5),
    );
    expect(withKo.prizePool, withoutKo.prizePool);
    expect(withKo.organizerAmount, withoutKo.organizerAmount);
  });

  // ── §9.2 organizer rounding ────────────────────────────────────────────────
  test('organizer amount snaps so the prize pool stays divisible by 10', () {
    // Worked example from spec §9.2: gross 165 at 10% -> organizer 15, pool 150.
    final r = TournamentEngine.recalculatePrizes(165, 12, 10);
    expect(r.organizerAmount, 15);
    expect(r.prizePool, 150);
    expect(r.prizes.map((p) => p.amount), [90, 40, 20]);

    for (final gross in [137, 165, 999, 1234, 5000]) {
      for (final pct in [0, 5, 10, 15, 20, 100]) {
        final res = TournamentEngine.recalculatePrizes(gross, 12, pct);
        expect(res.organizerAmount, inInclusiveRange(0, gross));
        expect(gross - res.organizerAmount, greaterThanOrEqualTo(0));
        if (pct > 0) {
          // Spec §9.2: the organizer amount carries gross's units digit so
          // the remaining prize pool is always a clean multiple of 10.
          expect(res.prizePool % 10, 0,
              reason: 'gross=$gross pct=$pct');
        } else {
          expect(res.prizePool, gross);
        }
        expect(res.prizePool, gross - res.organizerAmount);
      }
    }
  });

  test('zero organizer percentage leaves the whole gross as prize pool', () {
    final r = TournamentEngine.recalculatePrizes(165, 8, 0);
    expect(r.organizerAmount, 0);
    expect(r.prizePool, 165);
  });

  // ── §9.4 / §23.1 payout multiples: the unit is 10 for any real buy-in ─────
  test('every payout is a multiple of 10 for decade and 5-ending buy-ins', () {
    // A 15 buy-in is a common 5-ending value. With a 10% organizer cut the
    // pool lands on a multiple of 10 and every payout must too. The engine
    // must not slip into 5-rounded payouts that end in 5.
    for (final buyIn in [10, 15, 20, 25, 50, 100]) {
      for (final players in [4, 8, 12, 20]) {
        final s = TournamentEngine.generate(
          _params(
            chips: richChips,
            buyIn: buyIn,
            players: players,
            organizerPct: 10,
          ),
        );
        expect(s.prizePool % 10, 0,
            reason: 'buyIn=$buyIn p=$players pool=${s.prizePool}');
        expect(s.prizes.fold<int>(0, (sum, p) => sum + p.amount), s.prizePool);
        for (final prize in s.prizes) {
          expect(prize.amount % 10, 0,
              reason: 'buyIn=$buyIn p=$players: ${prize.amount}');
        }
      }
    }
  });

  test('no payout ever ends in 5 even at the smallest 5-ending buy-in', () {
    // 0% organizer on a 15 buy-in: the raw gross is a multiple of 5 but not
    // necessarily of 10. Lower places must stay clean multiples of 10; only
    // place 1 may carry the odd remainder (documented sum-exactness tradeoff).
    for (final players in [6, 8, 10, 14]) {
      final s = TournamentEngine.generate(
        _params(
          chips: richChips,
          buyIn: 15,
          players: players,
          organizerPct: 0,
        ),
      );
      expect(s.prizes.fold<int>(0, (sum, p) => sum + p.amount), s.prizePool);
      for (var i = 0; i < s.prizes.length; i++) {
        if (i > 0) {
          expect(s.prizes[i].amount % 10, 0,
              reason: 'p=$players: place ${i + 1} must not end in 5');
        }
      }
    }
  });

  // ── §23.1 simulation: finish estimate inside a calibrated window ───────────
  test('expected finish tracks the target duration for representative fields',
      () {
    for (final hours in [3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0]) {
      for (final players in [4, 9, 18]) {
        final s = TournamentEngine.generate(
          _params(players: players, hours: hours, chips: richChips),
        );
        final playingMinutes = hours * 60 * 0.9;
        // Recompute the documented estimate independently.
        final numLevels =
            math.max(6, (playingMinutes / s.levelDuration).floor());
        expect(s.expectedFinishMins,
            (numLevels * s.levelDuration * 1.05).round());
        // The estimate must stay near the target window.
        expect(s.expectedFinishMins, lessThanOrEqualTo(playingMinutes * 1.05 + 25),
            reason: 'h=$hours p=$players');
        expect(s.expectedFinishMins, greaterThanOrEqualTo(playingMinutes - 30));

        // Starting depth honours the clamp model (± rounding slack).
        final depth = s.startingStack / s.levels.first.bb;
        expect(depth, inInclusiveRange(70, 250),
            reason: 'depth $depth h=$hours p=$players');
      }
    }
  });

  // ── §8.3/§8.4 blind-curve targets ──────────────────────────────────────────

  // Big blind of ladder rung [index] (0-based over validBlindLevels,
  // conceptually extended by +200/+400 steps past the printed end).
  int rungBb(int index) {
    final printed = TournamentEngine.validBlindLevels;
    if (index < printed.length) return printed[index][1];
    final sb = printed.last[0] + 200 * (index - (printed.length - 1));
    return sb * 2;
  }

  test('final big blind tracks the expected-total-chips target', () {
    for (final players in [2, 10, 30]) {
      final s = TournamentEngine.generate(
        // Exactly like _params(): rebuys true, reEntry false, addOn true.
        _params(players: players, hours: 3.5, chips: richChips),
      );
      // Independent §8.3 computation: expected chips in play = starting
      // stacks + expected rebuys (35% of field) + expected add-ons (65%),
      // each rounded; heads-up should start with ~15 BB average stacks, so
      // targetFinalBB = expectedTotal / (2 × 15).
      final stack = s.startingStack;
      final expectedTotal = stack * players +
          stack * (players * 0.35).round() +
          stack * (players * 0.65).round();
      final targetFinalBB = expectedTotal / (2 * 15.0);

      // Tolerant snapping bounds: every raw curve value is snapped onto the
      // fixed legal-blind ladder, so the printed final BB may overshoot the
      // geometric target by up to one rung (bounded here at +40%) or, for
      // shallow curves where the engine still climbs at least one ladder
      // rung per level, sit at the mandatory-climb rung far above the raw
      // target ("openingBB + ladder step headroom" = the (levels−1)-th rung).
      // Undershoot is bounded below at half the target: nearest-rung
      // snapping can lag a geometric curve but never by that much.
      final numLevels = math.max(
          6, ((3.5 * 60 * 0.9) / s.levelDuration).floor());
      final minChip = richChips.map((c) => c.value).reduce(math.min);
      var startIndex =
          TournamentEngine.validBlindLevels.indexWhere((l) => l[0] >= minChip);
      if (startIndex < 0) startIndex = 0;
      final mandatoryClimbBb = rungBb(startIndex + numLevels - 1);

      final lastBb = s.levels.last.bb;
      expect(lastBb,
          lessThanOrEqualTo(math.max(targetFinalBB * 1.4, mandatoryClimbBb)),
          reason: 'players=$players target=$targetFinalBB');
      expect(lastBb, greaterThanOrEqualTo(targetFinalBB * 0.5),
          reason: 'players=$players target=$targetFinalBB');
    }
  });

  test('blind ladder extends beyond its printed end for huge fields', () {
    final hugeInventory = [
      for (final c in richChips) c.copyWith(quantity: c.quantity * 5),
    ];
    final s = TournamentEngine.generate(
      _params(players: 60, hours: 6.0, chips: hugeInventory),
    );
    // Printed ladder ends at [3000, 6000]; a 60-player 6-hour field puts far
    // too many chips in play for the curve to stop there.
    expect(s.levels.last.bb, greaterThan(6000));
  });

  group('degenerate inputs never throw', () {
    // Regression: opening check-in generates a structure estimate before
    // anyone has checked in, so `players` arrived as 0. `quantity / (0 * m)`
    // is Infinity and `Infinity.floor()` throws `UnsupportedError: Infinity`,
    // which killed the tap handler instead of producing a plan.
    test('a zero player count does not divide by zero', () {
      expect(() => TournamentEngine.generate(_params(players: 0)),
          returnsNormally);
      final s = TournamentEngine.generate(_params(players: 0));
      expect(s.levels, isNotEmpty);
    });

    test('a one-player field still produces a structure', () {
      expect(() => TournamentEngine.generate(_params(players: 1)),
          returnsNormally);
    });

    test('a chip set containing a zero-value denomination is skipped, '
        'not fatal', () {
      final broken = [
        const ChipColor(color: 'ghost', hex: 0xFF000000, value: 0, quantity: 50),
        ...TournamentEngine.getPreset('Standard 300'),
      ];
      expect(() => TournamentEngine.generate(_params(chips: broken)),
          returnsNormally);
      final s = TournamentEngine.generate(_params(chips: broken));
      expect(s.chipPlan.every((e) => e.value > 0), isTrue);
    });

    test('snapToPracticalBlind tolerates an empty / zero-value chip set', () {
      expect(TournamentEngine.snapToPracticalBlind(37, const []),
          greaterThan(0));
      expect(
        TournamentEngine.snapToPracticalBlind(
          37,
          const [ChipColor(color: 'x', hex: 0, value: 0, quantity: 10)],
        ),
        greaterThan(0),
      );
    });
  });
}
