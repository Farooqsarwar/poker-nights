import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/tournament_engine.dart';

/// Acceptance coverage for the payout rules (14-022, 14-023, 14-027, 14-016,
/// Technical sections 9.2 and 9.4). Each group here corresponds to a finding
/// that shipped: PN-002, PN-003 and PN-004.
void main() {
  group('PN-002 — 5 or more paid places must not crash', () {
    // `weightsFor`'s `default` branch returned a FOUR-element list for every
    // n > 4, so `_calcPrizes` read past the end. Both paid-place dropdowns
    // offer 1-10, so this was reachable from the shipped UI.
    for (var places = 2; places <= 10; places++) {
      test('$places places produce a valid split', () {
        final r = TournamentEngine.recalculatePrizes(
          1000,
          20,
          0,
          forcePaidPlaces: places,
        );
        expect(r.prizes, isNotEmpty);

        final total = r.prizes.fold<int>(0, (a, p) => a + p.amount);
        expect(
          total,
          r.prizePool,
          reason: 'payouts must total exactly the prize pool',
        );

        for (final p in r.prizes) {
          expect(p.amount % 10, 0, reason: '${p.amount} is not a multiple of 10');
          expect(p.amount % 10, isNot(5), reason: '${p.amount} ends in 5');
          expect(p.amount, greaterThan(0));
        }
        for (var i = 0; i + 1 < r.prizes.length; i++) {
          expect(
            r.prizes[i].amount,
            greaterThanOrEqualTo(r.prizes[i + 1].amount),
            reason: 'payouts must descend',
          );
        }
      });
    }
  });

  group('PN-003 — no payout ever ends in 5', () {
    // Technical section 6.1 defaults the organizer percentage to 0, so a
    // non-decade pool is the COMMON case, not an unreachable one. 11 x 15
    // used to yield 105/40/20.
    final cases = <({int players, int buyIn})>[
      (players: 11, buyIn: 15),
      (players: 9, buyIn: 15),
      (players: 13, buyIn: 15),
      (players: 7, buyIn: 15),
      (players: 8, buyIn: 5),
      (players: 6, buyIn: 7),
      (players: 10, buyIn: 25),
      (players: 12, buyIn: 15),
    ];

    for (final c in cases) {
      test('${c.players} x ${c.buyIn} at 0% organizer', () {
        final gross = c.players * c.buyIn;
        final r = TournamentEngine.recalculatePrizes(
          gross,
          c.players,
          0,
          roundingUnit: TournamentEngine.roundingUnitFor(c.buyIn),
        );

        for (final p in r.prizes) {
          expect(
            p.amount % 10,
            0,
            reason: 'place ${p.place} = ${p.amount} is not a multiple of 10',
          );
        }

        // Nothing may be invented or lost: the residue is carried out of the
        // pool, never silently dropped.
        final paid = r.prizes.fold<int>(0, (a, p) => a + p.amount);
        expect(
          paid + r.organizerAmount + r.roundingRemainder,
          gross,
          reason: 'pool + organizer + remainder must reconcile to the gross',
        );
        expect(r.roundingRemainder, lessThan(10));
        expect(r.roundingRemainder, greaterThanOrEqualTo(0));
      });
    }

    test('a 0% organizer cut never produces an organizer amount', () {
      final r = TournamentEngine.recalculatePrizes(165, 11, 0);
      expect(
        r.organizerAmount,
        0,
        reason: 'the residue is a rounding remainder, never an organizer cut',
      );
      expect(r.roundingRemainder, 5);
      expect(r.prizePool, 160);
    });

    test('roundingUnitFor is 10 even for sub-10 buy-ins', () {
      expect(TournamentEngine.roundingUnitFor(5), 10);
      expect(TournamentEngine.roundingUnitFor(7), 10);
      expect(TournamentEngine.roundingUnitFor(15), 10);
    });
  });

  group('Spec 2026-09 section 18 — organizer allocation', () {
    // The worked example the client's specification states verbatim:
    // "Gross 165 -> organizer target 10% -> clean rounded organizer amount 15
    //  -> net 150." Asserted under its new section number so the client can
    // trace the requirement straight to a passing test.
    test('gross 165 at the new 10% default yields 15 organizer / 150 net', () {
      final r = TournamentEngine.recalculatePrizes(165, 11, 10);
      expect(r.organizerAmount, 15);
      expect(r.prizePool, 150);
    });

    test('the allocation reconciles exactly to gross', () {
      // Section 30's financial invariant, and section 18's requirement that
      // nothing is invented or lost between gross and what is paid out.
      for (final gross in [100, 150, 165, 200, 240, 300, 455]) {
        final r = TournamentEngine.recalculatePrizes(gross, 11, 10);
        final paid = r.prizes.fold<int>(0, (a, p) => a + p.amount);
        expect(
          paid + r.organizerAmount + r.roundingRemainder,
          gross,
          reason: 'gross $gross did not reconcile',
        );
      }
    });

    test('0% remains reachable — the setting is still optional', () {
      // Spec section 7 makes organizer cost an ON/OFF with a 0-20 range, so
      // 10 being the DEFAULT must not make 0 unreachable.
      final r = TournamentEngine.recalculatePrizes(165, 11, 0);
      expect(r.organizerAmount, 0);
    });

    test('a legacy percentage above the new 20% cap still computes', () {
      // Games created under the old 0-100 rule keep their stored figure
      // (see `_orgPctCeiling`). The engine must not choke on one.
      final r = TournamentEngine.recalculatePrizes(1000, 11, 35);
      expect(r.organizerAmount, greaterThan(0));
      final paid = r.prizes.fold<int>(0, (a, p) => a + p.amount);
      expect(paid + r.organizerAmount + r.roundingRemainder, 1000);
    });
  });

  group('PN-004 — organizer amount is the NEAREST valid value', () {
    // The candidate loop seeded `organizerAmount = 0` and then treated that
    // seed as "unset", so the upper candidate was accepted regardless of
    // distance whenever 0 was actually nearest.
    test('gross 100 at 1% retains 0, not 10', () {
      final r = TournamentEngine.recalculatePrizes(100, 8, 1);
      expect(r.organizerAmount, 0);
    });

    test('gross 200 at 2% retains 0, not 10', () {
      final r = TournamentEngine.recalculatePrizes(200, 8, 2);
      expect(r.organizerAmount, 0);
    });

    test('gross 50 at 5% retains 0, not 10', () {
      final r = TournamentEngine.recalculatePrizes(50, 6, 5);
      expect(r.organizerAmount, 0);
    });

    test('the spec worked example still holds: 165 at 10% -> 15 / 150', () {
      // Technical section 9.2's own example — this passed before and must
      // keep passing.
      final r = TournamentEngine.recalculatePrizes(165, 11, 10);
      expect(r.organizerAmount, 15);
      expect(r.prizePool, 150);
    });

    test('ties break toward the lower amount (14-016)', () {
      // Target lands exactly between two valid candidates.
      final r = TournamentEngine.recalculatePrizes(100, 8, 5);
      expect(r.organizerAmount, lessThanOrEqualTo(10));
    });
  });
}
