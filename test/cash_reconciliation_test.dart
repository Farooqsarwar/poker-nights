import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/utils/model_codec.dart';

CashSessionSettings _settings({String name = 'Thursday Cash'}) {
  return CashSessionSettings(
    name: name,
    date: '2026-08-20',
    location: "Dave's Basement",
    smallBlind: 0.5,
    bigBlind: 1,
    minBuyIn: 20,
    maxBuyIn: 100,
    currency: '',
    maxPlayers: 9,
    rakePct: 0,
  );
}

/// §16.3 reconciliation math + §23.2 cash scenario.
///
/// A session reconciles when `difference == expectedInPlay - totalInPlay`
/// is zero: every chip issued (buy-ins + top-ups) is either still on the
/// table or has left with a player's cash-out.
void main() {
  group('§23.2 scenario: two buy-ins + one top-up + two cash-outs', () {
    // Alice: buy-in 100, top-up 50 -> totalBuyIns 150, still holding 150.
    // Bob:   buy-in 100, cashed out 130 (net +30).
    // Carol: buy-in 100, cashed out 70 (net -30).
    final session = CashSession(
      id: 'cash-1',
      settings: _settings(),
      startTime: DateTime(2026, 8, 20, 19),
      players: const [
        CashPlayer(
          id: 'alice',
          name: 'Alice',
          stack: 150,
          totalBuyIns: 150,
          buyInCount: 2,
          cashedOut: 0,
        ),
        CashPlayer(
          id: 'bob',
          name: 'Bob',
          stack: 0,
          totalBuyIns: 100,
          buyInCount: 1,
          cashedOut: 130,
        ),
        CashPlayer(
          id: 'carol',
          name: 'Carol',
          stack: 0,
          totalBuyIns: 100,
          buyInCount: 1,
          cashedOut: 70,
        ),
      ],
    );

    test('totals add up across all players', () {
      expect(session.totalBuyIns, 350);
      expect(session.totalCashedOut, 200);
      expect(session.totalInPlay, 150);
      expect(session.expectedInPlay, 150);
    });

    test('reconciles to zero difference', () {
      expect(session.difference, 0);
    });

    test('per-player nets cancel out once everyone leaves', () {
      // Alice's uncashed buy-in stays negative until she cashes out, so the
      // running net sum equals minus whatever is still on the table.
      final netSum =
          session.players.fold(0.0, (sum, p) => sum + p.net);
      expect(netSum, moreOrLessEquals(-session.expectedInPlay, epsilon: 1e-9));
      expect(netSum, -150);
      expect(session.players[1].net, 30); // Bob up
      expect(session.players[2].net, -30); // Carol down
      expect(session.players[0].net, -150); // Alice still in
    });

    test('cashed-out flags reflect who left', () {
      expect(session.players[0].isCashedOut, isFalse);
      expect(session.players[1].isCashedOut, isTrue);
      expect(session.players[2].isCashedOut, isTrue);
    });
  });

  group('mismatched session yields non-zero difference', () {
    test('overstated table stack drives the difference negative', () {
      // Same as the §23.2 scenario but Alice's stack was logged as 145:
      // expected in play is only 120, so 25 units are over-counted.
      final session = CashSession(
        id: 'cash-bad',
        settings: _settings(),
        startTime: DateTime(2026, 8, 20, 19),
        players: [
          CashPlayer(
            id: 'alice',
            name: 'Alice',
            stack: 145,
            totalBuyIns: 150,
            buyInCount: 2,
            cashedOut: 0,
          ),
          CashPlayer(
            id: 'bob',
            name: 'Bob',
            stack: 0,
            totalBuyIns: 100,
            buyInCount: 1,
            cashedOut: 130,
          ),
        ],
      );

      expect(session.expectedInPlay, 120); // 250 issued - 130 returned
      expect(session.totalInPlay, 145);
      expect(session.difference, -25);
    });

    test('understated table stack leaves a positive difference', () {
      final session = CashSession(
        id: 'cash-bad-3',
        settings: _settings(),
        startTime: DateTime(2026, 8, 20, 19),
        players: [
          CashPlayer(
            id: 'erin',
            name: 'Erin',
            stack: 90,
            totalBuyIns: 120,
            buyInCount: 1,
            cashedOut: 0,
          ),
        ],
      );

      // 30 units issued are unaccounted for on the table count.
      expect(session.expectedInPlay, 120);
      expect(session.totalInPlay, 90);
      expect(session.difference, 30);
    });

    test('overpaid cash-out drives the difference negative', () {
      final session = CashSession(
        id: 'cash-bad-2',
        settings: _settings(),
        startTime: DateTime(2026, 8, 20, 19),
        players: [
          CashPlayer(
            id: 'dave',
            name: 'Dave',
            stack: 0,
            totalBuyIns: 50,
            buyInCount: 1,
            cashedOut: 60,
          ),
        ],
      );

      expect(session.expectedInPlay, -10);
      expect(session.difference, -10);
    });
  });

  group('invariant: difference == (totalReturned - totalIssued) sign form', () {
    // Documented invariant: difference == totalBuyIns - totalCashedOut -
    // totalInPlay. Checked across several fixed cases mixing balanced and
    // broken sessions, including fractional amounts.
    final cases = <String, List<CashPlayer>>{
      'balanced with fractions': [
        const CashPlayer(
          id: 'p1',
          name: 'P1',
          stack: 37.5,
          totalBuyIns: 12.5,
          buyInCount: 1,
          cashedOut: 0,
        ),
        const CashPlayer(
          id: 'p2',
          name: 'P2',
          stack: 0,
          totalBuyIns: 40,
          buyInCount: 1,
          cashedOut: 52.5,
        ),
      ],
      'balanced zero-sum table': [
        const CashPlayer(
          id: 'p1',
          name: 'P1',
          stack: 80,
          totalBuyIns: 60,
          buyInCount: 1,
          cashedOut: 0,
        ),
        const CashPlayer(
          id: 'p2',
          name: 'P2',
          stack: 0,
          totalBuyIns: 60,
          buyInCount: 1,
          cashedOut: 55,
        ),
        const CashPlayer(
          id: 'p3',
          name: 'P3',
          stack: 15,
          totalBuyIns: 20,
          buyInCount: 1,
          cashedOut: 5,
        ),
      ],
      'missing chips': [
        const CashPlayer(
          id: 'p1',
          name: 'P1',
          stack: 90.25,
          totalBuyIns: 100,
          buyInCount: 1,
          cashedOut: 0,
        ),
      ],
      'everyone cashed out': [
        const CashPlayer(
          id: 'p1',
          name: 'P1',
          stack: 0,
          totalBuyIns: 33.33,
          buyInCount: 1,
          cashedOut: 41.21,
        ),
        const CashPlayer(
          id: 'p2',
          name: 'P2',
          stack: 0,
          totalBuyIns: 33.34,
          buyInCount: 1,
          cashedOut: 25.46,
        ),
      ],
      'nobody has bought in yet': [
        const CashPlayer(
          id: 'p1',
          name: 'P1',
          stack: 0,
          totalBuyIns: 0,
          buyInCount: 0,
          cashedOut: 0,
        ),
      ],
    };

    cases.forEach((label, players) {
      test(label, () {
        final session = CashSession(
          id: 'inv-$label',
          settings: _settings(name: label),
          startTime: DateTime(2026, 8, 20, 19),
          players: players,
        );

        final manualIssued =
            players.fold(0.0, (sum, p) => sum + p.totalBuyIns);
        final manualReturned =
            players.fold(0.0, (sum, p) => sum + p.cashedOut);
        final manualInPlay = players.fold(0.0, (sum, p) => sum + p.stack);

        expect(session.totalBuyIns, moreOrLessEquals(manualIssued, epsilon: 1e-9));
        expect(
          session.totalCashedOut,
          moreOrLessEquals(manualReturned, epsilon: 1e-9),
        );
        expect(session.totalInPlay, moreOrLessEquals(manualInPlay, epsilon: 1e-9));
        expect(
          session.difference,
          moreOrLessEquals(
            (manualIssued - manualReturned) - manualInPlay,
            epsilon: 1e-9,
          ),
        );
      });
    });
  });

  group('cash session codec round-trip', () {
    test('preserves doubles exactly through map encode/decode', () {
      final original = CashSession(
        id: 'cash-rt',
        settings: _settings(name: 'Round Trip'),
        startTime: DateTime(2026, 8, 20, 19),
        isCompleted: true,
        unresolvedNote: 'one stack short of 12.5',
        players: [
          const CashPlayer(
            id: 'p1',
            name: 'P1',
            stack: 12.5,
            totalBuyIns: 25,
            buyInCount: 2,
            cashedOut: 0,
          ),
          const CashPlayer(
            id: 'p2',
            name: 'P2',
            stack: 0.1,
            totalBuyIns: 20,
            buyInCount: 1,
            cashedOut: 19.9,
          ),
        ],
      );

      final restored = cashSessionFromMap(cashSessionToMap(original));

      expect(restored.id, original.id);
      expect(restored.isCompleted, isTrue);
      expect(restored.startTime, original.startTime);
      expect(restored.unresolvedNote, original.unresolvedNote);

      expect(restored.settings.name, 'Round Trip');
      expect(restored.settings.smallBlind, 0.5);
      expect(restored.settings.bigBlind, 1);
      expect(restored.settings.minBuyIn, 20);
      expect(restored.settings.maxBuyIn, 100);

      expect(restored.players.length, 2);
      expect(restored.players[0].stack, 12.5);
      expect(restored.players[0].totalBuyIns, 25);
      expect(restored.players[0].buyInCount, 2);
      expect(restored.players[1].stack, 0.1);
      expect(restored.players[1].cashedOut, 19.9);

      expect(restored.totalInPlay, moreOrLessEquals(original.totalInPlay, epsilon: 1e-9));
      expect(restored.difference, moreOrLessEquals(original.difference, epsilon: 1e-9));
    });

    test('tolerates absent optional fields when decoding', () {
      final restored = cashSessionFromMap({
        'id': 'cash-min',
        'settings': <String, Object?>{
          'name': 'Bare Settings',
        },
        'players': <Object?>[
          {'id': 'p1'},
        ],
      });

      expect(restored.isCompleted, isFalse);
      expect(restored.unresolvedNote, isNull);
      expect(restored.settings.name, 'Bare Settings');
      expect(restored.players.single.id, 'p1');
      expect(restored.players.single.stack, 0);
    });
  });
}
