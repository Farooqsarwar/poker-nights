import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// PN-051 / Technical section 7.2 and 7.3 — a starting stack has to be
/// PLAYABLE, not merely worth the right amount.
///
/// The client reported being handed "seven blue chips" for a starting stack:
/// exact in value, and impossible to post a 25/50 blind from. That is what
/// greedy top-down filling does — it is optimal for chip count and pessimal
/// for payability. These tests pin the properties the scored enumeration is
/// there to guarantee.
void main() {
  const standard300 = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 20),
  ];

  const homeSet = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 5, quantity: 100),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 80),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 100, quantity: 60),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 30),
  ];

  TournamentParams params(
    List<ChipColor> chips,
    int players, {
    double hours = 4,
  }) => TournamentParams(
    players: players,
    durationHours: hours,
    buyIn: 20,
    chipSet: chips,
    rebuys: true,
    rebuysCloseLevel: 6,
    reEntry: false,
    addOn: true,
    anteEnabled: false,
    anteAfterLevel: 7,
    anteStyle: AnteStyle.bigBlind,
    koEnabled: false,
    koAmount: 0,
    organizerPct: 0,
  );

  group('the generated starting stack can post its own opening blind', () {
    for (final set in [
      (name: 'Standard 300', chips: standard300),
      (name: 'Home Set', chips: homeSet),
    ]) {
      for (final players in [4, 6, 8, 10, 12, 14, 18]) {
        test('${set.name} / $players players', () {
          final s = TournamentEngine.generate(params(set.chips, players));
          final sb = s.levels.first.sb;
          final plan = s.chipPlan;

          expect(plan, isNotEmpty);

          final value = plan.fold<int>(0, (a, e) => a + e.count * e.value);
          expect(
            value,
            s.startingStack,
            reason:
                'the stack must be worth exactly what the app tells everyone '
                'it is worth — the prize pool and colour-up are derived from it',
          );

          final shape = plan.map((e) => '${e.count}x${e.value}').join(' + ');

          // Home Set at 18 players allocates every chip in the box (925 is
          // the arithmetic maximum), so payability is bounded by the
          // inventory, not by the solver. The engine says so in `warnings`;
          // where it does, the ceiling is the inventory's, not a defect.
          final exhausted = s.warnings.any((w) => w.contains('cannot fund'));

          final payable = plan
              .where((e) => e.value <= sb)
              .fold<int>(0, (a, e) => a + e.count);
          if (!exhausted) {
            expect(
              payable,
              greaterThanOrEqualTo(6),
              reason:
                  'only $payable chips of $sb or less — the "seven blue '
                  'chips" stack. Plan was: $shape',
            );
          }

          // Making change requires a denomination strictly below the blind to
          // exist at all. When the cheapest chip IS the small blind, no stack
          // can hold one.
          final minChip = set.chips
              .map((c) => c.value)
              .reduce((a, b) => a < b ? a : b);
          if (minChip < sb && !exhausted) {
            final change = plan
                .where((e) => e.value < sb)
                .fold<int>(0, (a, e) => a + e.count);
            expect(
              change,
              greaterThanOrEqualTo(2),
              reason:
                  'a player must be able to MAKE change for the small blind, '
                  'not only pay it exactly. Plan was: $shape',
            );
          }
        });
      }
    }
  });

  group('the stack stays countable', () {
    for (final players in [6, 9, 12]) {
      test('Standard 300 / $players players is not a bucket of chips', () {
        final s = TournamentEngine.generate(params(standard300, players));
        final total = s.chipPlan.fold<int>(0, (a, e) => a + e.count);
        expect(
          total,
          lessThanOrEqualTo(TournamentEngine.maxChipsPerPlayer + 5),
          reason: 'excessive_chip_count — nobody wants to count this down',
        );
        expect(
          total,
          greaterThanOrEqualTo(8),
          reason: 'too few chips is the unplayable brick',
        );
      });
    }
  });

  group('rebuy stacks handed out mid-tournament are also postable', () {
    // Technical section 7.4 / 10-041: a rebuy keeps the same total value but
    // its composition follows the CURRENT blind, not level one's.
    test('a level-9 rebuy still contains change for the level-9 blind', () {
      final s = TournamentEngine.generate(params(standard300, 9));
      final level = s.levels.length >= 9 ? s.levels[8] : s.levels.last;
      final plan = TournamentEngine.chipPlanAtLevel(
        stack: s.rebuyStack,
        chips: standard300,
        currentBB: level.bb,
        playersRemaining: 6,
      );

      expect(plan, isNotEmpty);
      expect(
        plan.fold<int>(0, (a, e) => a + e.count * e.value),
        s.rebuyStack,
        reason: '23-002 — a rebuy is worth the same as a starting stack',
      );
      final payable = plan
          .where((e) => e.value <= level.sb)
          .fold<int>(0, (a, e) => a + e.count);
      expect(
        payable,
        greaterThanOrEqualTo(2),
        reason:
            'a player rebuying at level 9 must be able to post the level-9 '
            'blind out of the chips they were just handed',
      );
    });
  });

  group('the enumeration never loses to the plain greedy fill', () {
    // The all-zero reserve IS the greedy fill, and it is one of the
    // candidates, so the chosen plan is greedy-or-better by construction.
    // This checks the consequence that matters: exact coverage is never
    // sacrificed for prettier change.
    for (final stack in [800, 1000, 1500, 2000, 5000, 10000]) {
      test('$stack is covered exactly from Standard 300', () {
        final plan = TournamentEngine.chipPlanAtLevel(
          stack: stack,
          chips: standard300,
          currentBB: 50,
          playersRemaining: 1,
        );
        expect(
          plan.fold<int>(0, (a, e) => a + e.count * e.value),
          stack,
          reason: plan.map((e) => '${e.count}x${e.value}').join(' + '),
        );
      });
    }
  });
}
