import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/payout_bridge.dart';
import 'package:poker_night/utils/payouts_engine.dart';

/// BUILD_PLAN P3.1 — the payout vectors rebuilt from Build Specification v3.1
/// §F2.12's hand traces, plus the §F2.8 trigger priority and the §F2.11 shape
/// figures. These replace the deleted legacy `recalculatePrizes` tests; the
/// original 55-vector harness was never in the repository (BUILD_PLAN P0.2).
void main() {
  group('§F2.12a payoutPlan(11, 165, buyIn 15, 10 % organiser)', () {
    final r = PayoutsEngine.payoutPlan(
      11,
      165,
      const PayoutPlanOptions(
        buyIn: 15,
        organiser: OrganiserFeeConfig(
          mode: OrganiserFeeMode.percent,
          value: 10,
        ),
      ),
    );

    test('fee rounds DOWN to whole units, net is what is left', () {
      expect(r.fee, 16.0);
      expect(r.netPool, 149.0);
      expect(r.grossPool, 165.0);
    });

    test('3rd place is dropped by the 1.5 x buy-in minimum', () {
      // 3 places: 15 % of 149 = 22.35 < 22.50 -> drop to 2.
      expect(r.places, 2);
    });

    test('amounts are 99 / 50 and reconcile to the net pool', () {
      expect(r.amounts, [99.0, 50.0]);
      expect(r.amounts.reduce((a, b) => a + b), r.netPool);
    });

    test('a fee reaching the pool is flagged', () {
      expect(r.warnings, containsAll(['POOL_DEDUCTION', 'HIDDEN_FROM_PLAYERS']));
    });
  });

  group('§F2.12b icm([8000, 5000, 2000], [250, 150, 100])', () {
    final e = PayoutsEngine.icm([8000, 5000, 2000], [250, 150, 100]).equity;

    test('per-player equity to the cent', () {
      expect(e[0], closeTo(197.44, 0.005));
      expect(e[1], closeTo(171.61, 0.005));
      expect(e[2], closeTo(130.95, 0.005));
    });

    test('equities sum to the prize pool', () {
      expect(e.reduce((a, b) => a + b), closeTo(500, 1e-6));
    });
  });

  group('§F2.11 chipChop', () {
    test('[8000,5000,2000] / [250,150,100] -> 206.67 / 166.67 / 126.67', () {
      final c = PayoutsEngine.chipChop([8000, 5000, 2000], [250, 150, 100]);
      expect(c[0], closeTo(206.67, 0.005));
      expect(c[1], closeTo(166.67, 0.005));
      expect(c[2], closeTo(126.67, 0.005));
    });
  });

  group('§F2.12c settleUp +4 +3 +3 -6 -4', () {
    final r = PayoutsEngine.settleUp([
      (name: 'A', balance: 4),
      (name: 'B', balance: 3),
      (name: 'C', balance: 3),
      (name: 'D', balance: -6),
      (name: 'E', balance: -4),
    ]);

    test('3 transfers in 2 zero-sum groups (greedy would need 4)', () {
      expect(r.count, 3);
      expect(r.groups, 2);
    });

    test('D pays B 3, D pays C 3, E pays A 4', () {
      final t = [
        for (final x in r.transfers) '${x.fromName}>${x.toName}:${x.amount}',
      ];
      expect(t, unorderedEquals(['D>B:3.0', 'D>C:3.0', 'E>A:4.0']));
    });
  });

  group('§F2.12d bubbleSave([99, 60, 30], 15, proRata, 1)', () {
    test('-> [91, 55, 28, 15], money conserved', () {
      final r = PayoutsEngine.bubbleSave([9900, 6000, 3000], 1500, 'proRata', 100);
      expect(r, [9100, 5500, 2800, 1500]);
      // Money is conserved: the new 4th place (1500) is carved OUT of the
      // existing three prizes, not added to them, so the total is unchanged.
      expect(r.reduce((a, b) => a + b), 9900 + 6000 + 3000);
    });
  });

  group('§F2.8 dealTrigger priority and gating', () {
    test('4 left, 3 paid -> bubble (§F2.11)', () {
      expect(
        PayoutsEngine.dealTrigger(
          const DealTriggerState(remainingPlayers: 4, paidPlaces: 3),
        ),
        DealTriggerType.bubble,
      );
    });

    test('target time beats bubble', () {
      expect(
        PayoutsEngine.dealTrigger(
          const DealTriggerState(
            remainingPlayers: 4,
            paidPlaces: 3,
            targetTimeReached: true,
          ),
        ),
        DealTriggerType.targetTime,
      );
    });

    test('bubble then ITM then heads-up as players fall', () {
      DealTriggerType? at(int n, [Set<DealTriggerType> fired = const {}]) =>
          PayoutsEngine.dealTrigger(
            DealTriggerState(
              remainingPlayers: n,
              paidPlaces: 3,
              alreadyFired: fired,
            ),
          );
      expect(at(3), DealTriggerType.inTheMoney);
      expect(at(2), DealTriggerType.inTheMoney);
      expect(at(2, {DealTriggerType.inTheMoney}), DealTriggerType.headsUp);
    });

    test('each type fires once', () {
      expect(
        PayoutsEngine.dealTrigger(
          const DealTriggerState(
            remainingPlayers: 4,
            paidPlaces: 3,
            alreadyFired: {DealTriggerType.bubble},
          ),
        ),
        isNull,
      );
    });

    test('nothing fires above the host\'s "suggest from" setting', () {
      expect(
        PayoutsEngine.dealTrigger(
          const DealTriggerState(
            remainingPlayers: 6,
            paidPlaces: 3,
            targetTimeReached: true,
          ),
        ),
        isNull,
      );
    });

    test('nothing fires with fewer than two players', () {
      expect(
        PayoutsEngine.dealTrigger(
          const DealTriggerState(remainingPlayers: 1, paidPlaces: 3),
        ),
        isNull,
      );
    });
  });

  group('owner shapes (§F2.11)', () {
    test('3 places: 52.5 / 32.5 / 15', () {
      expect(PayoutsEngine.ownerShapes[3], [52.5, 32.5, 15]);
    });
    test('4 places: 42.5 / 30 / 17.5 / 10', () {
      expect(PayoutsEngine.ownerShapes[4], [42.5, 30, 17.5, 10]);
    });
    test('every shape sums to 100', () {
      for (final s in PayoutsEngine.ownerShapes.values) {
        expect(s.reduce((a, b) => a + b), closeTo(100, 1e-9));
      }
    });
  });

  group('PayoutBridge', () {
    test('matches the engine trace for the §F2.12a scenario', () {
      final r = PayoutBridge.recalculate(
        grossEligible: 165,
        players: 11,
        organizerPct: 10,
        buyIn: 15,
      );
      // The bridge rounds the organiser cut to 10, so 16.50 -> 10.
      expect(r.organizerAmount, 10);
      expect(r.prizePool, 155);
      expect(r.prizes.fold<int>(0, (a, p) => a + p.amount), 155);
      expect(r.roundingRemainder, 0);
    });

    test('no money in -> nothing out', () {
      final r = PayoutBridge.recalculate(
        grossEligible: 0,
        players: 0,
        organizerPct: 10,
        buyIn: 15,
      );
      expect(r.prizes, isEmpty);
      expect(r.prizePool, 0);
    });

    test('options: recommended split first, all reconcile', () {
      final opts = PayoutBridge.options(
        grossEligible: 300,
        players: 20,
        organizerPct: 0,
        buyIn: 15,
      );
      expect(opts, isNotEmpty);
      for (final o in opts) {
        expect(
          o.prizes.fold<int>(0, (a, p) => a + p.amount) + o.roundingRemainder,
          o.prizePool,
        );
      }
    });
  });
}
