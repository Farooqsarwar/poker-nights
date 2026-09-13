import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/utils/icm.dart';

/// The Independent Chip Model (§2's public ICM Calculator).
///
/// ICM's whole purpose is that chips are not money: a player with half the
/// chips is not worth half the pool, because they can still bust. These
/// assertions pin that behaviour rather than the arithmetic, because the
/// arithmetic is only interesting insofar as it produces it.
void main() {
  double sum(List<double> xs) => xs.fold(0.0, (a, b) => a + b);

  group('the whole pool is always distributed', () {
    test('two players, one prize', () {
      final e = Icm.equity(stacks: [6000, 4000], payouts: [100]);
      expect(sum(e), closeTo(100, 0.001));
    });

    test('three players, three prizes', () {
      final e = Icm.equity(stacks: [5000, 3000, 2000], payouts: [50, 30, 20]);
      expect(sum(e), closeTo(100, 0.001));
    });

    test('nine players, five prizes', () {
      final e = Icm.equity(
        stacks: [9000, 8000, 7000, 6000, 5000, 4000, 3000, 2000, 1000],
        payouts: [400, 250, 150, 120, 80],
      );
      expect(sum(e), closeTo(1000, 0.01));
    });

    test('more players than prizes still distributes exactly the pool', () {
      final e = Icm.equity(stacks: [4000, 3000, 2000, 1000], payouts: [70, 30]);
      expect(sum(e), closeTo(100, 0.001));
    });
  });

  group('chips are not money — the point of the model', () {
    test('the chip leader is worth LESS than their chip share', () {
      // Half the chips, three prizes: the leader cannot win more than first
      // place, so their equity is capped well below half the pool.
      final e = Icm.equity(stacks: [5000, 2500, 2500], payouts: [50, 30, 20]);
      final chipShare = 100 * 5000 / 10000; // 50
      expect(
        e.first,
        lessThan(chipShare),
        reason: 'ICM exists precisely because this is true. Equity '
            '${e.first.toStringAsFixed(2)} should be under $chipShare',
      );
    });

    test('the short stack is worth MORE than their chip share', () {
      final e = Icm.equity(stacks: [5000, 2500, 2500], payouts: [50, 30, 20]);
      final chipShare = 100 * 2500 / 10000; // 25
      expect(
        e.last,
        greaterThan(chipShare),
        reason: 'a short stack still has ladder equity — that is the other '
            'half of why ICM matters',
      );
    });

    test('equal stacks are worth equal money', () {
      final e = Icm.equity(stacks: [3000, 3000, 3000], payouts: [50, 30, 20]);
      expect(e[0], closeTo(e[1], 0.001));
      expect(e[1], closeTo(e[2], 0.001));
    });

    test('a bigger stack is never worth less than a smaller one', () {
      final e = Icm.equity(
        stacks: [8000, 5000, 3000, 2000],
        payouts: [50, 30, 20],
      );
      for (var i = 0; i + 1 < e.length; i++) {
        expect(e[i], greaterThanOrEqualTo(e[i + 1] - 0.001));
      }
    });
  });

  group('a player out of the money still holds equity', () {
    test('fourth of four with two prizes is worth something', () {
      final e = Icm.equity(stacks: [4000, 3000, 2000, 1000], payouts: [70, 30]);
      expect(
        e.last,
        greaterThan(0),
        reason: 'they can still climb — a chip count would say zero, which is '
            'exactly the mistake ICM corrects',
      );
    });

    test('a busted player is worth nothing', () {
      final e = Icm.equity(stacks: [5000, 5000, 0], payouts: [70, 30]);
      expect(e.last, 0);
      expect(sum(e), closeTo(100, 0.001));
    });
  });

  group('edge cases do not explode', () {
    test('no players', () {
      expect(Icm.equity(stacks: [], payouts: [100]), isEmpty);
    });

    test('no payouts', () {
      expect(Icm.equity(stacks: [100, 200], payouts: []), [0.0, 0.0]);
    });

    test('every stack is zero', () {
      final e = Icm.equity(stacks: [0, 0], payouts: [100]);
      expect(sum(e), 0);
    });

    test('one player, one prize', () {
      expect(Icm.equity(stacks: [1000], payouts: [100]).first, 100);
    });
  });

  group('large fields fall back rather than hang', () {
    test('ten players returns promptly and still totals the pool', () {
      final stacks = List<int>.generate(10, (i) => 1000 * (i + 1));
      expect(Icm.isExact(stacks), isFalse);
      final e = Icm.equity(stacks: stacks, payouts: [50, 30, 20]);
      expect(sum(e), closeTo(100, 0.01));
    });

    test('nine is still exact', () {
      expect(Icm.isExact(List<int>.filled(9, 1000)), isTrue);
    });
  });

  group('rounding never invents or loses money', () {
    test('three equal equities over a pool of 100', () {
      final rounded = Icm.roundPreservingTotal([33.4, 33.3, 33.3], 100);
      expect(rounded.fold<int>(0, (a, b) => a + b), 100);
    });

    test('the largest remainder gets the odd unit', () {
      final rounded = Icm.roundPreservingTotal([50.6, 49.4], 100);
      expect(rounded.fold<int>(0, (a, b) => a + b), 100);
      expect(rounded.first, greaterThan(rounded.last));
    });

    test('an empty list rounds to nothing', () {
      expect(Icm.roundPreservingTotal([], 100), isEmpty);
    });
  });
}
