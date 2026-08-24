// Tests for MoneyUtils — exact integer-cent arithmetic with zero floating-point drift.
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/money_utils.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // toCents / toDollars round-trips
  // ─────────────────────────────────────────────────────────────────────────
  group('toCents', () {
    test('exact values round-trip without drift', () {
      expect(MoneyUtils.toCents(150.00), 15000);
      expect(MoneyUtils.toCents(0.05), 5);
      expect(MoneyUtils.toCents(0.01), 1);
      expect(MoneyUtils.toCents(0.0), 0);
      expect(MoneyUtils.toCents(999.99), 99999);
    });

    test('rounds half-up on 0.5 cent boundary', () {
      // $149.995 should round to 15000 cents (i.e. $150.00)
      expect(MoneyUtils.toCents(149.995), 15000);
      expect(MoneyUtils.toCents(0.005), 1); // rounds up
      expect(MoneyUtils.toCents(0.004), 0); // rounds down
    });

    test('large amounts', () {
      // 700 players × $20 buy-in = $14,000
      expect(MoneyUtils.toCents(14000.00), 1400000);
    });
  });

  group('toDollars', () {
    test('exact conversion', () {
      expect(MoneyUtils.toDollars(15000), 150.0);
      expect(MoneyUtils.toDollars(0), 0.0);
      expect(MoneyUtils.toDollars(1), 0.01);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // percentOf — integer arithmetic
  // ─────────────────────────────────────────────────────────────────────────
  group('percentOf', () {
    test('10% of 165 (spec §9.2 worked example)', () {
      // $165 × 10% = $16.50 = 1650 cents
      // But the engine works in dollar prize pools, so: 165 × 10% = 16 (int dollars)
      // At cent level: 16500 cents × 10% = 1650 cents
      expect(MoneyUtils.percentOf(16500, 10), 1650);
    });

    test('10% of 15000 cents = 1500 cents', () {
      expect(MoneyUtils.percentOf(15000, 10), 1500);
    });

    test('0%', () {
      expect(MoneyUtils.percentOf(15000, 0), 0);
    });

    test('100%', () {
      expect(MoneyUtils.percentOf(15000, 100), 15000);
    });

    test('rounds half-up', () {
      // 1 cent × 50% = 0.5 → rounds to 1
      expect(MoneyUtils.percentOf(1, 50), 1);
      // 3 cents × 33% = 0.99 → rounds to 1
      expect(MoneyUtils.percentOf(3, 33), 1);
    });

    test('zero amount', () {
      expect(MoneyUtils.percentOf(0, 10), 0);
      expect(MoneyUtils.percentOf(0, 0), 0);
    });

    test('large pool — 700 players x 20 = 14000 at 10%', () {
      // 1,400,000 cents × 10% = 140,000 cents = $1,400
      expect(MoneyUtils.percentOf(1400000, 10), 140000);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // splitEvenly
  // ─────────────────────────────────────────────────────────────────────────
  group('splitEvenly', () {
    test('splits 150 cents evenly into 3 parts', () {
      final parts = MoneyUtils.splitEvenly(150, 3);
      expect(parts, [50, 50, 50]);
      expect(parts.fold(0, (a, b) => a + b), 150);
    });

    test('distributes remainder into first parts', () {
      // 100 cents ÷ 3 = 33 remainder 1 → [34, 33, 33]
      final parts = MoneyUtils.splitEvenly(100, 3);
      expect(parts, [34, 33, 33]);
      expect(parts.fold(0, (a, b) => a + b), 100);
    });

    test('odd cents across 3 places sums exactly', () {
      for (var total = 1; total <= 200; total++) {
        for (var n = 1; n <= 5; n++) {
          final parts = MoneyUtils.splitEvenly(total, n);
          expect(parts.length, n);
          expect(parts.fold(0, (a, b) => a + b), total,
              reason: 'split($total, $n) must sum to $total');
        }
      }
    });

    test('empty split', () {
      expect(MoneyUtils.splitEvenly(100, 0), isEmpty);
    });

    test('single part', () {
      expect(MoneyUtils.splitEvenly(100, 1), [100]);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // formatCurrency
  // ─────────────────────────────────────────────────────────────────────────
  group('formatCurrency', () {
    test('standard amounts', () {
      expect(MoneyUtils.formatCurrency(15000), r'$150.00');
      expect(MoneyUtils.formatCurrency(0), r'$0.00');
      expect(MoneyUtils.formatCurrency(5), r'$0.05');
      expect(MoneyUtils.formatCurrency(1), r'$0.01');
      expect(MoneyUtils.formatCurrency(100), r'$1.00');
    });

    test('large amounts', () {
      expect(MoneyUtils.formatCurrency(1400000), r'$14000.00');
    });

    test('zero is formatted correctly', () {
      expect(MoneyUtils.formatCurrency(0), r'$0.00');
    });
  });

  group('formatSigned', () {
    test('positive', () {
      expect(MoneyUtils.formatSigned(2000), r'+$20.00');
    });
    test('negative', () {
      expect(MoneyUtils.formatSigned(-500), r'-$5.00');
    });
    test('zero', () {
      expect(MoneyUtils.formatSigned(0), r'+$0.00');
    });
  });
}
