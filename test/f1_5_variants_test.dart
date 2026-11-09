import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// §F1.5 point 5: depth is a HARD rule — "if none reaches the band, only the
/// closest ones do". The opening blind (hence the depth) comes from the
/// composition's smallest chip, so a stack must be judged on its best
/// composition FOR EACH smallest chip, not only its single best-scoring one.
///
/// The case that exposed it: base25, 20 players, freeze-out. A 4,000 stack is
/// dealable as 4×25 + 4×100 + 3×500 + 2×1000 (opens 25/50 = 80 BB), but the
/// best-scoring 4,000 composition is 5×100 + 3×500 + 2×1000 (no 25s), whose
/// smallest chip is 100 -> a 200 blind -> 20 BB. Judging the stack only on that
/// one composition threw 4,000 away and settled for 2,500 (50 BB).
void main() {
  const base25 = [
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 100),
    ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 80),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 50),
    ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 30),
  ];

  TournamentParams night({
    int players = 20,
    bool rebuy = false,
    BlindFamily family = BlindFamily.niceSpec,
  }) =>
      TournamentParams(
        players: players,
        durationHours: 4,
        buyIn: 20,
        chipSet: base25,
        blindFamily: family,
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
        expectedRebuyRate: rebuy ? 0.35 : 0,
        addOnMultiplier: 1.25,
        pace: PaceMode.regular,
      );

  group('solveChipPlanVariants — best composition per smallest dealt chip', () {
    final variants = TournamentEngine.solveChipPlanVariants(
      stack: 4000,
      chipSet: base25,
      draws: 20,
      players: 20,
      addOnStack: 0,
      bonusEach: 0,
      openingSB: 25,
    );

    test('4,000 on base25/20p has a variant that keeps the 25s', () {
      expect(variants.keys, containsAll([25, 100]));
      final with25 = variants[25]!;
      expect(with25.used.first.value, 25);
      expect(with25.used.first.count, greaterThanOrEqualTo(2));
      expect(with25.used.fold<int>(0, (a, u) => a + u.value * u.count), 4000);
    });

    test('the best-scoring variant is still what solveChipPlanBounded returns',
        () {
      final bounded = TournamentEngine.solveChipPlanBounded(
        stack: 4000,
        chipSet: base25,
        draws: 20,
        players: 20,
        addOnStack: 0,
        bonusEach: 0,
        openingSB: 25,
      )!;
      final best = variants.values.reduce((a, b) => a.score <= b.score ? a : b);
      expect(bounded.score, closeTo(best.score, 1e-9));
      expect(bounded.used.map((u) => '${u.count}x${u.value}').toList(),
          best.used.map((u) => '${u.count}x${u.value}').toList());
    });
  });

  group('generate — the deepest dealable stack wins when none reaches the band',
      () {
    test('base25, 20 players, freeze-out -> 4,000 at 25/50 (80 BB)', () {
      final s = TournamentEngine.generate(night());
      expect(s.feasible, isTrue);
      expect(s.startingStack, 4000);
      expect(s.levels.first.sb, 25);
      expect(s.levels.first.bb, 50);
      expect(s.startingStack / s.levels.first.bb, closeTo(80, 0.01));
      expect(s.chipPlan.first.value, 25,
          reason: 'the smallest dealt chip is the 25, so the blind can be 25/50');
    });

    test('the depth note states the true depth (80), not an understated one', () {
      final s = TournamentEngine.generate(night());
      expect(s.depthShortfallNote, isNotNull,
          reason: '80 BB is still short of the regular band [85, 130]');
      expect(s.depthShortfallNote, contains('80'));
    });

    test('a stack that already reaches the band is unaffected (base25 9p)', () {
      final s = TournamentEngine.generate(night(players: 9));
      expect(s.startingStack, 5000);
      expect(s.levels.first.bb, 50);
      expect(s.depthShortfallNote, isNull);
    });
  });
}
