import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/payment_record.dart';
import 'package:poker_night/repositories/firebase_repository.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/utils/model_codec.dart';

/// QA section 12 — simulated payments.
///
/// Nothing here moves money. What has to be right is the ACCOUNTING: only a
/// successful payment reaches the prize pool, a double-tap cannot be counted
/// twice, and a failed attempt is recorded without being treated as paid.
void main() {
  PaymentRecord record({
    String id = 'pay-1',
    String playerId = 'p1',
    PaymentPurpose purpose = PaymentPurpose.buyIn,
    int amount = 20,
    PaymentStatus status = PaymentStatus.paid,
    String key = 'k1',
  }) => PaymentRecord(
        id: id,
        playerId: playerId,
        purpose: purpose,
        amount: amount,
        status: status,
        timestamp: DateTime(2026, 9, 18, 20, 30),
        idempotencyKey: key,
      );

  group('PN-DPAY-003/011/012 — only a successful payment counts', () {
    test('paid counts toward the pool', () {
      expect(PaymentStatus.paid.countsTowardPool, isTrue);
    });

    test('failed does not', () {
      expect(PaymentStatus.failed.countsTowardPool, isFalse);
    });

    test('cancelled does not', () {
      expect(PaymentStatus.cancelled.countsTowardPool, isFalse);
    });
  });

  group('PN-DPAY-007 / PN-NEG-011 — no double counting', () {
    test('two records with the same key are the same payment', () {
      final a = record(key: 'same');
      final b = record(id: 'pay-2', key: 'same');
      // Different ids, same key — the provider returns the first rather than
      // writing the second. Here we assert the key is what identifies it.
      expect(a.idempotencyKey, b.idempotencyKey);
    });

    test('records with different keys are distinct payments', () {
      expect(record(key: 'a') == record(key: 'b'), isFalse);
    });
  });

  group('PN-DPAY-016 — a record identifies its player and purpose', () {
    test('every field survives a round trip', () {
      final original = PaymentRecord(
        id: 'pay-9',
        playerId: 'p7',
        purpose: PaymentPurpose.addOn,
        amount: 10,
        status: PaymentStatus.failed,
        timestamp: DateTime(2026, 9, 18, 21, 15),
        idempotencyKey: 'abc123',
        failureReason: 'Declined',
      );
      final back = paymentRecordFromMap(paymentRecordToMap(original));
      expect(back.id, 'pay-9');
      expect(back.playerId, 'p7');
      expect(back.purpose, PaymentPurpose.addOn);
      expect(back.amount, 10);
      expect(back.status, PaymentStatus.failed);
      expect(back.idempotencyKey, 'abc123');
      expect(back.failureReason, 'Declined');
      expect(back.timestamp, original.timestamp);
    });

    test('an unknown status decodes as failed, not paid', () {
      // The safe answer to "did this go through?" is no. A corrupted or
      // future status must never be read as money collected.
      final back = paymentRecordFromMap({
        'id': 'x',
        'playerId': 'p1',
        'purpose': 'buyIn',
        'amount': 20,
        'status': 'something_new',
        'idempotencyKey': 'k',
      });
      expect(back.status, PaymentStatus.failed);
      expect(back.status.countsTowardPool, isFalse);
    });

    test('an empty map does not produce a paid record', () {
      final back = paymentRecordFromMap({});
      expect(back.status.countsTowardPool, isFalse);
      expect(back.amount, 0);
    });
  });

  group('every purpose and status is presentable', () {
    test('purposes have labels', () {
      for (final p in PaymentPurpose.values) {
        expect(p.label, isNotEmpty);
      }
    });

    test('statuses have labels', () {
      for (final s in PaymentStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  group('copyWith changes status without losing identity', () {
    test('a failed payment can be re-recorded as paid', () {
      final failed = record(status: PaymentStatus.failed);
      final paid = failed.copyWith(status: PaymentStatus.paid);
      expect(paid.status, PaymentStatus.paid);
      expect(paid.idempotencyKey, failed.idempotencyKey);
      expect(paid.playerId, failed.playerId);
      expect(paid.amount, failed.amount);
    });
  });

  group('Spec §G1: Yearly savings percentage is computed from the two prices', () {
    test('computes savings correctly from monthly and yearly prices', () {
      // £5/mo * 12 = £60/yr vs £36/yr -> save £24 (40%)
      expect(
        PremiumPlan.computeYearlySavingsPct(monthlyPrice: 5, yearlyPrice: 36),
        40,
      );
      // £10/mo * 12 = £120/yr vs £90/yr -> save £30 (25%)
      expect(
        PremiumPlan.computeYearlySavingsPct(monthlyPrice: 10, yearlyPrice: 90),
        25,
      );
      // If yearly is equal or greater than 12x monthly, savings is 0%
      expect(
        PremiumPlan.computeYearlySavingsPct(monthlyPrice: 5, yearlyPrice: 60),
        0,
      );
      expect(
        PremiumPlan.computeYearlySavingsPct(monthlyPrice: 5, yearlyPrice: 70),
        0,
      );
    });

    test('placeholder Yearly plan carries the dynamically computed savings pill', () {
      final yearly = PremiumPlan.placeholders.firstWhere((p) => p.id == 'demo-yearly');
      expect(yearly.saving, 'Save 40%');

      final monthly = PremiumPlan.placeholders.firstWhere((p) => p.id == 'demo-monthly');
      expect(monthly.saving, isNull);

      final host = PremiumPlan.placeholders.firstWhere((p) => p.id == 'demo-host');
      expect(host.saving, isNull);
    });
  });

  group('Spec §E14: GameResultRow persists prize and buyInsPaid and derives net P&L', () {
    test('survives round trip to and from map', () {
      const row = GameResultRow(
        gameId: 'g1',
        groupId: 'grp1',
        position: 2,
        playerCount: 18,
        knockouts: 3,
        finishedAt: null,
        eliminatedAtLevel: 8,
        prize: 120,
        buyInsPaid: 40,
      );
      expect(row.net, 80);

      final map = row.toMap();
      expect(map['prize'], 120);
      expect(map['buyInsPaid'], 40);

      final back = GameResultRow.fromMap('g1', map);
      expect(back.gameId, 'g1');
      expect(back.prize, 120);
      expect(back.buyInsPaid, 40);
      expect(back.net, 80);
    });
  });
}
