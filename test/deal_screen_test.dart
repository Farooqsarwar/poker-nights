import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/result_podium_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/utils/payouts_engine.dart';
import 'package:provider/provider.dart';

/// Spec C-deal — ICM / chip chop / equal chop and the agreed amounts the host
/// confirms to end the tournament.
///
/// The clauses this covers are the ones that can silently do the wrong thing:
/// the guard's exact wording (a host must be able to recognise the message as
/// the one the spec promises), the requirement that the agreed amounts add up
/// EXACTLY, and the requirement that a night which ended by busts records no
/// deal at all.
const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-08',
  time: '20:00',
  location: 'Basement',
  players: 4,
  durationHours: 3.5,
  buyIn: 15,
  koEnabled: false,
  koAmount: 0,
  rebuys: false,
  rebuysCloseLevel: 6,
  addOn: false,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

/// 250 / 150 / 100 across the top three places — the F2.6 worked example's
/// shape, so the three splits are the ones the spec already pins down.
const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 5000,
  rebuyChipPlan: [],
  addOnStack: 5000,
  addOnChipPlan: [],
  levels: [BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15)],
  levelDuration: 15,
  expectedFinishMins: 225,
  prizes: [
    Prize(place: 1, amount: 25000),
    Prize(place: 2, amount: 15000),
    Prize(place: 3, amount: 10000),
  ],
  prizePool: 50000,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

Player _player(
  String id,
  int stack, {
  bool eliminated = false,
  int? eliminationPos,
  String? name,
}) =>
    Player(
      id: id,
      name: name ?? id.toUpperCase(),
      isGuest: false,
      rsvp: Rsvp.going,
      checkedIn: true,
      confirmed: true,
      eliminated: eliminated,
      eliminationPos: eliminationPos,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 1,
      seat: 1,
      active: !eliminated,
      stack: stack,
    );

/// The three players already out of a six-handed night, in the order they
/// busted. `eliminationPos` is the place the provider stamps at the bust — the
/// number of players still in at that moment — so the first one out finished
/// 6th, the second 5th and the third 4th.
List<Player> _threeAlreadyOut() => [
      _player('e6', 0, eliminated: true, eliminationPos: 6, name: 'FIRST OUT'),
      _player('e5', 0, eliminated: true, eliminationPos: 5, name: 'SECOND OUT'),
      _player('e4', 0, eliminated: true, eliminationPos: 4, name: 'THIRD OUT'),
    ];

/// The same night with that evening already behind it, dealt and completed.
AppProvider _hostAfterDealing() {
  final app = _hostWithGame(extra: _threeAlreadyOut());
  final error = app.confirmDealAndEnd(
    amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
  );
  expect(error, isNull);
  return app;
}

const _host = AppUser(
  id: 'u1',
  name: 'Alex Morgan',
  email: 'alex@poker.night',
  isAdmin: true,
  stats: UserStats(
    played: 34,
    wins: 6,
    podium: 11,
    avgFinish: 3.2,
    knockouts: 18,
  ),
);

const _group = Group(
  id: 'g1',
  name: 'Friday Poker Club',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

/// A live game on an authority device, with three players still in holding
/// 8000 / 5000 / 2000 — the F2.6 worked example's stacks.
AppProvider _hostWithGame({
  List<Player> extra = const [],
  bool completed = false,
}) {
  final app = AppProvider()
    ..setUserForTesting(_host)
    ..setCurrentGroupForTesting(_group)
    ..setCurrentGame(
      LiveGame(
        id: 'game-1',
        groupId: 'g1',
        settings: _settings,
        structure: _structure,
        status: completed ? LiveGameStatus.completed : LiveGameStatus.running,
        publicCode: 'ABC123',
        tvCode: 'TV7890',
        currentLevel: 3,
        timerRunning: !completed,
        secondsRemaining: 600,
        players: [
          ...extra,
          _player('u1', 8000),
          _player('u2', 5000),
          _player('u3', 2000),
        ],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 15000,
        pendingGuests: const [],
        finishOrder: const [],
      ),
    );
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  /// Pumps the results screen, runs [body], then always unmounts and disposes.
  ///
  /// The cleanup is not optional bookkeeping: AppProvider starts a periodic
  /// ticker in its constructor, and the framework checks for pending timers
  /// after the test body but *before* any tearDown, so a provider left running
  /// fails with "A Timer is still pending" — an error that says nothing about
  /// the screen. `try/finally` keeps that from masking a real assertion
  /// failure.
  Future<void> screen(
    WidgetTester tester,
    AppProvider app,
    Future<void> Function() body,
  ) async {
    final router = GoRouter(
      initialLocation: '/result-podium',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/result-podium',
          builder: (_, _) => const ResultPodiumScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    }
  }

  group('dealAmountsError — C-deal item 4', () {
    test('is null when the agreed amounts add up exactly', () {
      expect(PayoutsEngine.dealAmountsError(500, 500), isNull);
    });

    test('reproduces the specified sentence, with bare whole numbers', () {
      expect(
        PayoutsEngine.dealAmountsError(185, 189),
        'The agreed amounts add up to 185, but 189 is left to pay. '
        'Fix them first.',
      );
    });

    test('names the agreed total first and the pot second', () {
      // The two numbers are the whole content of the message, so a swap
      // produces a sentence that is still grammatical and still wrong.
      final msg = PayoutsEngine.dealAmountsError(189, 185)!;
      expect(msg, contains('add up to 189'));
      expect(msg, contains('185 is left to pay'));
    });

    test('tolerates a half-cent of float drift', () {
      // 0.1 + 0.2 style drift is real: the host's figures arrive as doubles
      // summed in a fold, and a split that is visibly correct must not be
      // refused over 0.0000001 of representation error.
      expect(PayoutsEngine.dealAmountsError(100 + 0.1 + 0.2, 100.3), isNull);
    });

    test('still refuses a whole unit short', () {
      expect(PayoutsEngine.dealAmountsError(184, 189), isNotNull);
    });

    test('shows cents only when the figure has cents', () {
      // "185.00" would read as a different number than the "185" the host
      // typed, so a whole amount must not gain a decimal.
      expect(PayoutsEngine.dealAmountsError(185, 185.5)!, contains('185,'));
      expect(PayoutsEngine.dealAmountsError(185, 185.5)!, contains('185.50'));
    });
  });

  group('compareDeals — C-deal item 3', () {
    test('matches the F2.6 worked example for the three splits', () {
      final cmp = PayoutsEngine.compareDeals(
        [8000, 5000, 2000],
        [250, 150, 100],
      );
      expect(cmp.icm[0], closeTo(197.44, 0.01));
      expect(cmp.icm[1], closeTo(171.61, 0.01));
      expect(cmp.icm[2], closeTo(130.95, 0.01));
      expect(cmp.chip[0], closeTo(206.67, 0.01));
      expect(cmp.equal.every((v) => (v - 500 / 3).abs() < 0.01), isTrue);
    });

    test('every split totals the same pot', () {
      // The alternatives are only alternatives if they pay the same money —
      // a difference here means the host is being shown splits that are not
      // comparable at all.
      final cmp = PayoutsEngine.compareDeals([8000, 5000, 2000], [250, 150, 100]);
      for (final split in [cmp.icm, cmp.chip, cmp.equal]) {
        expect(split.fold<double>(0, (s, v) => s + v), closeTo(500, 0.01));
      }
    });

    test('chip chop never pays the shortest stack more than the longest', () {
      // §F2.6: "nobody gets more than 1st". A min-cash-first chop that
      // overpaid a small stack would be a rule violation, not a rounding one.
      final cmp = PayoutsEngine.compareDeals([8000, 5000, 2000], [250, 150, 100]);
      expect(cmp.chip[2], lessThanOrEqualTo(cmp.chip[0]));
    });
  });

  group('roundDeal — the agreed-amounts seed', () {
    test('adds up to the pot exactly, at whole units', () {
      // The spec's pre-fill requirement: whole numbers that add up exactly.
      final raw = [19744, 17161, 13095];
      final rounded = PayoutsEngine.roundDeal(raw, 100, 50000, 19744);
      expect(rounded.fold<int>(0, (s, v) => s + v), 50000);
      expect(rounded.every((v) => v % 100 == 0), isTrue);
    });

    test('never pushes the leader above the cap', () {
      // The v3.1 fix: sub-unit residue must not raise the largest amount past
      // the cap, which is the prize the leader is entitled to.
      final raw = [10050, 9990, 9960];
      final rounded = PayoutsEngine.roundDeal(raw, 100, 30000, 10050);
      expect(rounded.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(10050));
    });
  });

  group('dealAmounts on the game', () {
    test('round-trips through the codec', () {
      final game = _hostWithGame().currentGame!
          .copyWith(dealAmounts: const [250.0, 150.0, 100.0]);
      final back = liveGameFromMap(liveGameToMap(game));
      expect(back.dealAmounts, [250.0, 150.0, 100.0]);
    });

    test('stays null on a night that ended by busts', () {
      // An empty list here would read as "the table agreed a deal that paid
      // nobody", which is a different and wrong claim.
      final game = _hostWithGame(completed: true).currentGame!;
      expect(game.dealAmounts, isNull);
      final back = liveGameFromMap(liveGameToMap(game));
      expect(back.dealAmounts, isNull);
    });
  });

  group('confirmDealAndEnd — C-deal item 5', () {
    test('records the agreed amounts and completes the game', () {
      final app = _hostWithGame();
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
      );
      expect(error, isNull);
      expect(app.currentGame!.status, LiveGameStatus.completed);
      // Indexed to `finishOrder`, which is first-out-first, so the leader's
      // figure is LAST in the list.
      expect(app.currentGame!.dealAmounts, [100.0, 150.0, 250.0]);
    });

    test('puts the leader LAST in the finish order', () {
      // A place is `finishOrder.length - index`, so the first name in the list
      // is the WORST finisher. Getting this backwards shows the chip leader
      // on the bottom of the results.
      final app = _hostWithGame();
      app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
      );
      final order = app.currentGame!.finishOrder;
      expect(order.first, 'u3', reason: 'shortest stack finished last');
      expect(order.last, 'u1', reason: '8000 on chips is 1st, so last in the list');
    });

    test('keeps an earlier bust on the results', () {
      // A table that deals after somebody is already out must still record
      // them. The results screen builds the whole podium from `finishOrder`,
      // so dropping them would erase their finish.
      // `eliminationPos` is the FINISHING PLACE, not an out-order: with three
      // still in, the survivors take 1-3, so the first person out is 4th.
      final app = _hostWithGame(
        extra: [
          _player('u0', 0, eliminated: true, eliminationPos: 4),
        ],
      );
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
      );
      expect(error, isNull);
      final order = app.currentGame!.finishOrder;
      expect(order.first, 'u0', reason: 'first-out-first');
      expect(order, hasLength(4));
      // 4th is outside this ladder, so they were paid nothing at elimination.
      expect(app.currentGame!.dealAmounts!.first, 0.0);
    });

    test('refuses a split that does not add up, and changes nothing', () {
      final app = _hostWithGame();
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 95},
      );
      expect(error, contains('add up to 495'));
      expect(error, contains('500 is left to pay'));
      // The refusal must leave the game running — a host who mistypes a figure
      // must not have ended the tournament on the way to fixing it.
      expect(app.currentGame!.status, LiveGameStatus.running);
      expect(app.currentGame!.dealAmounts, isNull);
    });

    test('refuses a player left out of the deal', () {
      // 500 still balances if one player is skipped entirely, so the sum check
      // alone would let a pot silently vanish.
      final app = _hostWithGame();
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 350, 'u2': 150},
      );
      expect(error, contains('No agreed amount for U3'));
      expect(app.currentGame!.status, LiveGameStatus.running);
    });

    test('refuses a figure for someone who already busted', () {
      final app = _hostWithGame(
        extra: [
          _player('u0', 0, eliminated: true, eliminationPos: 4),
        ],
      );
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {
          'u0': 100, 'u1': 200, 'u2': 100, 'u3': 100,
        },
      );
      expect(error, 'The deal covers only the players still at the table.');
      expect(app.currentGame!.status, LiveGameStatus.running);
    });

    test('refuses a second deal on a finished game', () {
      final app = _hostWithGame(completed: true);
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
      );
      expect(error, 'This game is already over.');
    });
  });

  group('confirmDealAndEnd — three players already out', () {
    // The other cases in this file only ever have ONE player out, where "first
    // out" and "worst place" are the same name and the two sort directions are
    // indistinguishable. Three of them is where the reading shows.
    test('leads the finish order with the player who went out first', () {
      final app = _hostAfterDealing();
      // `eliminationPos` is the finishing PLACE, so the biggest of them busted
      // first and is the worst finisher — the slot a first-out-first list
      // opens with. Ascending would put THIRD OUT (4th) on the bottom of the
      // results and call the first player out the winner of the busted pack.
      expect(app.currentGame!.finishOrder.first, 'e6');
      expect(app.currentGame!.finishOrder, [
        'e6', 'e5', 'e4', // first out, second out, third out
        'u3', 'u2', 'u1', // then the table by chips, leader last
      ]);
    });

    test('places every player where they actually finished', () {
      final app = _hostAfterDealing();
      final order = app.currentGame!.finishOrder;
      // The reading the results screen, the share card and the standings all
      // share: a place is `finishOrder.length - index`.
      final places = {
        for (var i = 0; i < order.length; i++) order[i]: order.length - i,
      };
      expect(places, {
        'e6': 6, // out of a six-handed field, in the first hand
        'e5': 5,
        'e4': 4, // the best of the three, but still out of the money
        'u3': 3, // 2000 chips
        'u2': 2, // 5000
        'u1': 1, // 8000 — the chip leader wins the night
      });
    });

    test('leaves each agreed figure beside its own player', () {
      // `dealAmounts` is indexed to `finishOrder` and the results screen reads
      // it by the same index, so an order that is wrong about who finished
      // where pays the leader's figure to the wrong player.
      final app = _hostAfterDealing();
      expect(app.currentGame!.dealAmounts, [0.0, 0.0, 0.0, 100.0, 150.0, 250.0]);
    });

    testWidgets('the results screen ranks the eliminated players first-out',
        (tester) async {
      final app = _hostAfterDealing();

      await screen(tester, app, () async {
        // The chip leader is the host's own player, so the screen's "your
        // result" banner reports the winner's own place.
        expect(find.text('Winner!'), findsOneWidget);
        // The three who busted are outside the top three, so the full results
        // table labels them with a plain place number instead of a medal.
        final places = tester
            .widgetList<Text>(
              find.byWidgetPredicate(
                (w) => w is Text && (w.data ?? '').startsWith('#'),
              ),
            )
            .map((t) => t.data)
            .toList();
        expect(places, ['#6', '#5', '#4'], reason: 'worst finisher first');
        // And they are the same three names, in the same order.
        final names = tester
            .widgetList<Text>(
              find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    const ['FIRST OUT', 'SECOND OUT', 'THIRD OUT']
                        .contains(w.data),
              ),
            )
            .map((t) => t.data)
            .toList();
        expect(names, ['FIRST OUT', 'SECOND OUT', 'THIRD OUT']);
      });
    });
  });

  group('confirmDealAndEnd — undo', () {
    test('one press puts the night back exactly as it was', () {
      final app = _hostWithGame();
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
      );
      expect(error, isNull);

      app.undoLast();
      // Not merely "the tournament is running again": a snapshot taken after
      // the amounts were written would restore a game that still carries the
      // deal, and one taken after the completion would leave the deal on a
      // game the host never finished.
      expect(app.currentGame!.status, LiveGameStatus.running);
      expect(app.currentGame!.dealAmounts, isNull);
      expect(app.currentGame!.finishOrder, isEmpty);
    });

    test('one tap leaves one entry, not two', () {
      final app = _hostWithGame();
      app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
      );
      // `undoLast` says which it found: an entry is popped, or there is
      // nothing there. Two entries for one tap means the second press is the
      // one that actually gets the host back to the night they were playing.
      app.undoLast();
      expect(app.currentGame!.announcements.last.text, 'Last action undone.');
      app.undoLast();
      expect(
        app.currentGame!.announcements.last.text,
        'Nothing to undo.',
        reason: 'the deal was one action, so it is one entry',
      );
    });

    test('a refused completion leaves no undo entry behind', () {
      // An eliminated player with no recorded place is refused by the §4.17
      // validator, so `recordFinishOrder` fails and the deal is rolled back.
      final app = _hostWithGame(
        extra: [_player('e0', 0, eliminated: true)],
      );
      final error = app.confirmDealAndEnd(
        amountsByPlayerId: const {'u1': 250, 'u2': 150, 'u3': 100},
      );
      expect(error, contains('no recorded finish position'));
      expect(app.currentGame!.status, LiveGameStatus.running);
      expect(app.currentGame!.dealAmounts, isNull);

      app.undoLast();
      expect(
        app.currentGame!.announcements.last.text,
        'Nothing to undo.',
        reason: 'a refused deal is not an action to reverse',
      );
    });
  });

  group('dealTotalLeftToPay — C-deal item 2', () {
    test('sums the prizes the places on the table pay', () {
      expect(_hostWithGame().dealTotalLeftToPay(), 500);
    });

    test('is 0 when the structure has no payout ladder', () {
      // A projection ships an EMPTY prizes list on purpose, so "no ladder"
      // must read as nothing owed rather than as a crash on `.first`.
      final app = _hostWithGame();
      app.setCurrentGame(
        app.currentGame!.copyWith(
          structure: _structure.copyWith(prizes: const []),
        ),
      );
      expect(app.dealTotalLeftToPay(), 0);
    });
  });
}
