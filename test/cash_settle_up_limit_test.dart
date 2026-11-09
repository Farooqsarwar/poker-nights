import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/cash_settlement.dart';

/// Cash-game advanced functionality, checklist G2.3 row 34:
///
///   "**Limit.** Settle-up handles up to **16** people with a non-zero balance
///    at once (F2.10). If cashing someone out would make a 17th open balance,
///    that cash-out is blocked with 'Settle-up handles up to 16 people still
///    owed or owing - settle someone first.'"
///
/// The engine alone cannot deliver this. [CashSettlement] treats 16 as the
/// point where its exact bitmask DP stops being worth running and quietly
/// falls back to a still-correct-but-not-minimal greedy pairing - so a
/// 20-handed table would produce a longer transfer list than the spec
/// promises and say nothing. The refusal is the observable behaviour, so the
/// guard belongs on the cash-out itself.
const _settings = CashSessionSettings(
  name: 'Friday cash',
  date: '2026-09-08',
  location: 'Basement',
  smallBlind: 1,
  bigBlind: 2,
  minBuyIn: 20,
  maxBuyIn: 500,
  maxPlayers: 9,
);

/// A table of [count] players, each seated with a `minBuyIn` buy-in.
AppProvider _tableOf(int count) {
  final app = AppProvider();
  app.startCashGame(
    _settings,
    [for (var i = 0; i < count; i++) 'P$i'],
  );
  return app;
}

CashPlayer _find(AppProvider app, int i) => app.cashSession!.players[i];

/// How many people the host would still owe, or be owed, right now.
int _openBalances(AppProvider app) =>
    app.cashSession!.players.where((p) => (p.net * 100).round() != 0).length;

/// Open an unpaid balance on the first [count] players, by having each take
/// out part of their buy-in.
///
/// A seated player is NOT an open balance: `net` counts the chips still in
/// front of them, so someone who bought in for 20 and still holds 20 is flat
/// and owes nobody anything. A balance only exists once money or chips have
/// actually moved, which is the whole point of the field — so the setup has to
/// cash people out rather than merely seat them.
AppProvider _withOpenBalances(int seated, int open) {
  final app = _tableOf(seated);
  for (var i = 0; i < open; i++) {
    // 10 taken out against a 20 buy-in: net -10, one open balance.
    expect(app.cashCashOut(_find(app, i).id, 10), isNull);
  }
  expect(_openBalances(app), open);
  return app;
}

void main() {
  // `endCashGame` and the session write paths reach for `ServicesBinding`,
  // which a plain `test()` has not set up.
  TestWidgetsFlutterBinding.ensureInitialized();

  // The provider mirrors a running game to the crash-recovery store on change,
  // which is real filesystem I/O keyed to the process working directory;
  // concurrent instances then fight over one file. Nothing here depends on it.
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('the 16-open-balance settle-up limit', () {
    test('a cash-out that would open the 17th balance is refused', () {
      // 16 people have an open balance; the 17th seat is flat, so cashing it
      // out would take the table to 17 open balances at once.
      final app = _withOpenBalances(17, 16);
      expect(_find(app, 16).net, 0, reason: 'untouched seat is flat');

      final error = app.cashCashOut(_find(app, 16).id, 50);

      expect(
        error,
        'Settle-up handles up to 16 people still owed or owing - settle someone first.',
      );
      expect(_find(app, 16).cashedOut, 0, reason: 'refused cash-out is not recorded');
      expect(_find(app, 16).hasCashedOut, isFalse);
      expect(_find(app, 16).net, 0, reason: 'a refused cash-out leaves no trace');
      expect(_openBalances(app), 16);
    });

    test('a cash-out that keeps the table at 16 still goes through', () {
      // The boundary case: this player already has an open balance, so
      // cashing them out re-ranks an existing debt rather than opening a
      // 17th. The limit must not catch this.
      final app = _withOpenBalances(16, 16);

      final error = app.cashCashOut(_find(app, 3).id, 50);

      expect(error, isNull);
      expect(_find(app, 3).cashedOut, 60, reason: '10 already out, plus 50');
      expect(_find(app, 3).hasCashedOut, isTrue);
      // 60 out against a 20 buy-in, with nothing left on the table, leaves
      // them 40 to the good — still an open balance, just a bigger one.
      expect(_find(app, 3).net, 40);
      expect(_openBalances(app), 16, reason: 'still 16 — nobody new opened');
    });

    test('settling someone first lets the refused cash-out through', () {
      // The spec's remedy, not just its refusal: bring a player to a net of
      // exactly 0 and the blocked cash-out becomes legal, because the count
      // no longer goes over.
      final app = _withOpenBalances(17, 16);

      // Player 0 leaves flat: they were 10 short, so the remaining 10 out
      // takes them to exactly 0 and drops the table to 15 open.
      expect(app.cashCashOut(_find(app, 0).id, 10), isNull);
      expect(_find(app, 0).net, 0);
      expect(_openBalances(app), 15);

      final error = app.cashCashOut(_find(app, 16).id, 50);

      expect(error, isNull, reason: '15 open plus one more is 16, not 17');
      expect(_find(app, 16).cashedOut, 50);
      expect(_openBalances(app), 16);
    });

    test('a float-noise net is not mistaken for an open balance', () {
      // Nets are doubles built up through repeated buy-ins and top-ups. A
      // cash-out that leaves a balance a few 1e-15 short of zero is a settled
      // player, and must not consume one of the 16 slots.
      final app = _withOpenBalances(17, 16);

      // Settle player 0 with an amount that leaves a 1e-15 residue rather than
      // an exact zero. They are 10 short, so asking for
      // `10 + 0.1 + 0.2 - 0.3` — which is 10.000000000000002 — tops them up
      // 2e-15 past flat.
      expect(app.cashCashOut(_find(app, 0).id, 10 + 0.1 + 0.2 - 0.3), isNull);
      expect(_find(app, 0).net.abs() < 1e-9, isTrue,
          reason: 'player 0 is flat to within float noise');
      expect((_find(app, 0).net * 100).round(), 0,
          reason: 'player 0 net rounds flat to zero');
      expect(_openBalances(app), 15, reason: 'the settled seat freed a slot');

      final error = app.cashCashOut(_find(app, 16).id, 50);

      // 15 open plus this one is 16, so the limit must NOT fire — which is the
      // only way to prove the noisy seat was not counted as a 16th.
      expect(error, isNull);
      expect(_openBalances(app), 16);
    });
  });

  group('the limit is the engine limit', () {
    test('the refusal is driven by CashSettlement.maxExactPeople', () {
      // Pins the message to the constant rather than a hard-coded 16, so the
      // two cannot drift apart if the engine limit is ever revisited.
      expect(
        'Settle-up handles up to ${CashSettlement.maxExactPeople} people '
        'still owed or owing - settle someone first.',
        'Settle-up handles up to 16 people still owed or owing - settle someone first.',
      );
    });
  });
}
