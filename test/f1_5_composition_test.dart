import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// T5 — §F1.5 / §F1.16 composition solver, validated against the demo night's
/// worked trace numbers (the new hard control).
void main() {
  const demoChips = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 120),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
    ChipColor(color: 'Green', hex: 0xFF27AE60, value: 25, quantity: 80),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 40),
  ];

  test('scoreComposition([5×1,9×5,2×25,1×100], 17) == 71.25 (§F1.16 step 3)', () {
    final s = TournamentEngine.scoreComposition([5, 9, 2, 1], [1, 5, 25, 100], 17);
    expect(s, closeTo(71.25, 0.001));
  });

  test('S_max for the demo night == 230.92 (§F1.16 step 2)', () {
    // bankValue 6,870; draws = 10 + poisson90(3.5)=6 = 16; +1.25×10 +0.125×10.
    final bankValue = demoChips.fold<int>(0, (a, c) => a + c.value * c.quantity);
    expect(bankValue, 6870);
    final draws = 10 + TournamentEngine.poissonQuantile90(3.5);
    expect(draws, 16);
    final s = TournamentEngine.sMax(
      bankValue: bankValue,
      draws: draws,
      players: 10,
      addOnMult: 1.25,
      bonusPct: 0.125,
    );
    expect(s, closeTo(230.924, 0.01));
  });

  test('candidateStacks(230.92) is the spec\'s 21 nice values, deepest first', () {
    final c = TournamentEngine.candidateStacks(230.924);
    expect(
      c,
      [200, 150, 120, 100, 80, 60, 50, 40, 30, 25, 20, 15, 12, 10, 8, 6, 5, 4, 3, 2, 1],
    );
  });

  test('solveChipPlanBounded(200) → 5×1,9×5,2×25,1×100, score 83.25', () {
    final r = TournamentEngine.solveChipPlanBounded(
      stack: 200,
      chipSet: demoChips,
      draws: 16,
      players: 10,
      addOnStack: 250, // 1.25 × 200
      bonusEach: 25, // 0.125 × 200
      openingSB: 1, // niceBB(200/100,1)=2 → SB 1
    );
    expect(r, isNotNull);
    expect(r!.score, closeTo(83.25, 0.001));
    expect(
      {for (final u in r.used) u.value: u.count},
      {1: 5, 5: 9, 25: 2, 100: 1},
    );
  });
}
