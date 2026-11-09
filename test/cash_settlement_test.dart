import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/utils/cash_settlement.dart';

/// Settling a cash game (§3's "Advanced cash-game functionality").
///
/// The properties that matter at a real table: nobody is asked to pay more
/// than they lost, every winner is made whole to the penny, and the list is
/// short enough to actually work through while people are putting coats on.
void main() {
  CashPlayer player(
    String name, {
    required double buyIns,
    double stack = 0,
    double? cashedOut,
  }) =>
      CashPlayer(
        id: name,
        name: name,
        stack: stack,
        totalBuyIns: buyIns,
        buyInCount: 1,
        cashedOut: cashedOut ?? 0,
        hasCashedOut: cashedOut != null,
      );

  double paid(List<CashTransfer> ts, String name) => ts
      .where((t) => t.fromName == name)
      .fold(0.0, (a, t) => a + t.amount);

  double received(List<CashTransfer> ts, String name) => ts
      .where((t) => t.toName == name)
      .fold(0.0, (a, t) => a + t.amount);

  group('everybody ends up square', () {
    test('one winner, one loser', () {
      final ts = CashSettlement.settle([
        player('Ann', buyIns: 100, stack: 160),
        player('Ben', buyIns: 100, stack: 40),
      ]);
      expect(ts.length, 1);
      expect(ts.first.fromName, 'Ben');
      expect(ts.first.toName, 'Ann');
      expect(ts.first.amount, closeTo(60, 0.001));
    });

    test('three players, one big winner', () {
      final players = [
        player('Ann', buyIns: 100, stack: 250),
        player('Ben', buyIns: 100, stack: 30),
        player('Cal', buyIns: 100, stack: 20),
      ];
      final ts = CashSettlement.settle(players);
      expect(received(ts, 'Ann'), closeTo(150, 0.001));
      expect(paid(ts, 'Ben'), closeTo(70, 0.001));
      expect(paid(ts, 'Cal'), closeTo(80, 0.001));
    });

    test('nobody pays more than they lost', () {
      final players = [
        player('Ann', buyIns: 200, stack: 500),
        player('Ben', buyIns: 100, stack: 0),
        player('Cal', buyIns: 100, stack: 60),
        player('Dee', buyIns: 300, stack: 140),
      ];
      final ts = CashSettlement.settle(players);
      for (final s in CashSettlement.standings(players)) {
        if (s.net < 0) {
          expect(
            paid(ts, s.name),
            closeTo(-s.net, 0.011),
            reason: '${s.name} lost ${-s.net} but is asked for '
                '${paid(ts, s.name)}',
          );
        }
      }
    });

    test('every winner is made whole', () {
      final players = [
        player('Ann', buyIns: 50, stack: 130),
        player('Ben', buyIns: 50, stack: 95),
        player('Cal', buyIns: 100, stack: 0),
        player('Dee', buyIns: 100, stack: 75),
      ];
      final ts = CashSettlement.settle(players);
      for (final s in CashSettlement.standings(players)) {
        if (s.net > 0) {
          expect(received(ts, s.name), closeTo(s.net, 0.011));
        }
      }
    });
  });

  group('the list is short enough to use', () {
    test('at most one payment fewer than there are players', () {
      final players = [
        for (var i = 0; i < 9; i++)
          player('P$i', buyIns: 100, stack: (i * 25).toDouble()),
      ];
      final ts = CashSettlement.settle(players);
      expect(
        ts.length,
        lessThanOrEqualTo(players.length - 1),
        reason: 'a settlement nobody can work through is not a settlement',
      );
    });

    test('an all-square table needs no payments at all', () {
      final ts = CashSettlement.settle([
        player('Ann', buyIns: 100, stack: 100),
        player('Ben', buyIns: 100, stack: 100),
      ]);
      expect(ts, isEmpty);
    });
  });

  group('pennies do not go missing', () {
    test('thirds of a pot settle exactly', () {
      // 100 split three ways is the classic place a float loses a cent.
      final players = [
        player('Ann', buyIns: 100, stack: 133.33),
        player('Ben', buyIns: 100, stack: 133.33),
        player('Cal', buyIns: 100, stack: 33.34),
      ];
      final ts = CashSettlement.settle(players);
      final moved = ts.fold<double>(0, (a, t) => a + t.amount);
      final won = CashSettlement.standings(players)
          .where((s) => s.net > 0)
          .fold<double>(0, (a, s) => a + s.net);
      expect(moved, closeTo(won, 0.011));
    });

    test('every amount is positive', () {
      final ts = CashSettlement.settle([
        player('Ann', buyIns: 100, stack: 0),
        player('Ben', buyIns: 100, stack: 200),
      ]);
      expect(ts.every((t) => t.amount > 0), isTrue);
    });

    test('nobody pays themselves', () {
      final ts = CashSettlement.settle([
        player('Ann', buyIns: 100, stack: 150),
        player('Ben', buyIns: 100, stack: 50),
      ]);
      expect(ts.every((t) => t.fromName != t.toName), isTrue);
    });
  });

  group('a player who has cashed out is counted on what they took', () {
    test('cashed out beats the stack they left behind', () {
      final players = [
        player('Ann', buyIns: 100, stack: 0, cashedOut: 180),
        player('Ben', buyIns: 100, stack: 20),
      ];
      final standings = CashSettlement.standings(players);
      expect(standings.first.name, 'Ann');
      expect(standings.first.net, closeTo(80, 0.001));
    });

    test('mid-session, the chips in front of you are what you are worth', () {
      // Before cashing out, `cashedOut` is zero -- reading net from it would
      // report every seated player as having lost their whole buy-in.
      final players = [player('Ann', buyIns: 100, stack: 250)];
      expect(
        CashSettlement.standings(players).first.net,
        closeTo(150, 0.001),
        reason: 'a player sitting on 250 is not down 100',
      );
    });
  });

  group('the money is checked, not assumed', () {
    test('a balanced table balances', () {
      final r = CashSettlement.reconcile([
        player('Ann', buyIns: 100, stack: 150),
        player('Ben', buyIns: 100, stack: 50),
      ]);
      expect(r.balances, isTrue);
      expect(r.totalBuyIns, closeTo(200, 0.001));
    });

    test('an unrecorded buy-in shows as a gap', () {
      // 300 of chips on a table that only 200 was paid into.
      final r = CashSettlement.reconcile([
        player('Ann', buyIns: 100, stack: 200),
        player('Ben', buyIns: 100, stack: 100),
      ]);
      expect(r.balances, isFalse);
      expect(r.difference, closeTo(-100, 0.001));
    });

    test('cashed-out money still counts as accounted for', () {
      final r = CashSettlement.reconcile([
        player('Ann', buyIns: 100, stack: 0, cashedOut: 160),
        player('Ben', buyIns: 100, stack: 40),
      ]);
      expect(r.balances, isTrue);
      expect(r.totalCashedOut, closeTo(160, 0.001));
      expect(r.totalOnTable, closeTo(40, 0.001));
    });
  });

  test('an empty table settles to nothing rather than throwing', () {
    expect(CashSettlement.settle(const []), isEmpty);
    expect(CashSettlement.standings(const []), isEmpty);
    expect(CashSettlement.reconcile(const []).balances, isTrue);
  });
}
