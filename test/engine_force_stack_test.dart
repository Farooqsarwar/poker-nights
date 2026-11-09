import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// T9 — `forceStack` / `targetDepthBB` and `recalculate(params, pins)` (F2, F19).
void main() {
  const box500 = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 100),
  ];
  const base25 = [
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 100),
    ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 80),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 50),
    ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 30),
  ];

  TournamentParams base(
    List<ChipColor> chips, {
    int players = 9,
    bool rebuy = false,
    int? forceStack,
    int? targetDepthBB,
  }) =>
      TournamentParams(
        players: players,
        durationHours: 4,
        buyIn: 20,
        chipSet: chips,
        rebuys: rebuy,
        rebuysCloseLevel: 0,
        reEntry: false,
        addOn: rebuy,
        anteEnabled: true,
        anteAfterLevel: 6,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        format: rebuy ? TournamentFormat.rebuy : TournamentFormat.freezeOut,
        pace: PaceMode.regular,
        expectedRebuyRate: rebuy ? 0.35 : 0,
        addOnMultiplier: 1.25,
        forceStack: forceStack,
        targetDepthBB: targetDepthBB,
      );

  test('forced 2,000 on the 500-piece box (9p rebuy) → bankOk=false + shortfall',
      () {
    final s = TournamentEngine.generate(base(box500, rebuy: true, forceStack: 2000));
    expect(s.startingStack, 2000, reason: 'forced stack is returned exactly');
    expect(s.bankOk, isFalse, reason: '2,000 × a busy 9-player field exceeds the box');
    expect(s.bankShortfall, isNotEmpty);
  });

  test('forced 5,000 on base25 (9p freeze) → feasible at 25/50 (100 BB)', () {
    final s = TournamentEngine.generate(base(base25, forceStack: 5000));
    expect(s.startingStack, 5000);
    expect(s.levels.first.sb, 25);
    expect(s.levels.first.bb, 50);
    expect(s.startingStack / s.levels.first.bb, closeTo(100, 1));
    expect(s.bankOk, isTrue, reason: '45,000 in play ≤ 252,500 owned');
    expect(s.levels.first.sb, lessThan(s.levels.first.bb));
  });

  test('forced 40,000 on Home 25 names the real bank shortfall', () {
    final s = TournamentEngine.generate(base(base25, forceStack: 40000));

    expect(s.startingStack, 40000);
    expect(s.bankOk, isFalse);
    expect(s.feasible, isFalse);
    expect(s.bankShortfall, isNotEmpty);
    expect(s.bankShortfall.map((entry) => entry.colour), contains('Yellow'));
    expect(s.bankShortfall.firstWhere((entry) => entry.colour == 'Yellow').short,
        greaterThan(0));
  });

  test('unnumbered chip values are normalised and marked as assumed', () {
    const unnumbered = [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 0, quantity: 150),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 0, quantity: 100),
      ChipColor(color: 'Green', hex: 0xFF27AE60, value: 0, quantity: 80),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 0, quantity: 50),
    ];

    final s = TournamentEngine.generate(base(unnumbered));

    expect(s.chipSetAssumedValues, isTrue);
    expect(s.chipPlan, isNotEmpty);
    expect(s.chipPlan.every((entry) => entry.value > 0), isTrue);
  });

  test('targetDepthBB drives depth independently of pace', () {
    final shallow = TournamentEngine.generate(base(box500, targetDepthBB: 50));
    final deep = TournamentEngine.generate(base(box500, targetDepthBB: 150));
    final ds = shallow.startingStack / shallow.levels.first.bb;
    final dd = deep.startingStack / deep.levels.first.bb;
    expect(ds, closeTo(50, 12));
    expect(dd, closeTo(150, 25));
    expect(dd, greaterThan(ds));
  });

  // A deep, fine-chip case (has a 1-chip) so a 6,000 stack is dealable.
  const deepFine = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 2000),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 2000),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 1500),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 1500),
  ];

  test('home25 applies a 25-based ladder where the stack is deep enough (T3)', () {
    // Forced 6,000: spec opens at niceBB(60,1)=60; home25 prefers 50 (120 BB,
    // still inside the band), so every BB is a multiple of 50, SB of 25.
    final spec = TournamentEngine.generate(base(deepFine, forceStack: 6000));
    final home = TournamentEngine.generate(base(deepFine, forceStack: 6000)
        .copyWith(blindFamily: BlindFamily.home25));
    expect(spec.levels.first.bb, 60, reason: 'niceSpec opens at 60');
    expect(home.levels.first.bb, 50, reason: 'home25 prefers the 25-based 50');
    for (final l in home.levels) {
      expect(l.bb % 50, 0, reason: 'home25 BB ${l.bb} not a multiple of 50');
      expect(l.sb % 25, 0, reason: 'home25 SB ${l.sb} not a multiple of 25');
      expect(l.sb, lessThan(l.bb));
    }
  });

  test('home25 falls back to the spec ladder instead of making a night infeasible',
      () {
    // box500 9p rebuy is bank-limited to a ~400 stack: a 25-based BB (>= 50)
    // would be 8 BB deep. The first home25 cut called every such night
    // infeasible; the contract is a fallback to the spec's blinds.
    final spec = TournamentEngine.generate(base(box500, rebuy: true));
    final home = TournamentEngine.generate(
        base(box500, rebuy: true).copyWith(blindFamily: BlindFamily.home25));
    expect(spec.feasible, isTrue);
    expect(home.feasible, isTrue, reason: 'home25 must not break a dealable night');
    expect(home.startingStack, spec.startingStack);
    expect(home.levels.first.bb, spec.levels.first.bb);
  });

  test('a forced stack plus one pin survives recalc (stack + pin unchanged, tail rises)',
      () {
    final p = base(box500, forceStack: 3000);
    final s0 = TournamentEngine.generate(p);
    final mid = s0.levels.length ~/ 2;
    final pinnedBB = s0.levels[mid].bb + 2 * s0.levels[mid].sb; // a clear nudge up
    final pin = PinnedLevel(levelNum: mid + 1, sb: pinnedBB ~/ 2, bb: pinnedBB);
    final s = TournamentEngine.recalculate(p, [pin]);
    expect(s.startingStack, 3000, reason: 'forced stack survives recalc');
    expect(s.levels[mid].bb, pinnedBB, reason: 'the pin keeps its exact value');
    for (var i = 1; i < s.levels.length; i++) {
      expect(s.levels[i].bb, greaterThan(s.levels[i - 1].bb),
          reason: 'the tail still rises');
    }
  });
}
