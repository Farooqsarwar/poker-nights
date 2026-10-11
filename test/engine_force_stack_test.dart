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

  test('targetDepthBB drives depth independently of pace', () {
    final shallow = TournamentEngine.generate(base(box500, targetDepthBB: 50));
    final deep = TournamentEngine.generate(base(box500, targetDepthBB: 150));
    final ds = shallow.startingStack / shallow.levels.first.bb;
    final dd = deep.startingStack / deep.levels.first.bb;
    expect(ds, closeTo(50, 12));
    expect(dd, closeTo(150, 25));
    expect(dd, greaterThan(ds));
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
