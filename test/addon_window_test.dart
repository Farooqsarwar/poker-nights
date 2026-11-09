import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/model_codec.dart';

/// Addendum 2 A2-1 — the add-on window has two edges, and only one of them
/// could close itself before this.
///
/// The first is the host pressing Next, which has always worked. The second is
/// the window going into overtime: when the break ends before settlement step
/// 2 is done, the window closes by itself once **every** player from step 1
/// has either taken an add-on or declined one.
///
/// "Answered" needs both halves to be representable. Taking one already was.
/// Declining one was not: a player who said no was simply absent from the
/// selection set, which is exactly what a player who has not been asked yet
/// also looks like. So the overtime close could never tell who was still
/// outstanding, and the window stayed open for as long as the host left the
/// screen alone.
const _host = AppUser(
  id: 'u1',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(
    played: 20,
    wins: 3,
    podium: 8,
    avgFinish: 3.2,
    knockouts: 5,
  ),
);

const _group = Group(
  id: 'grp1',
  name: 'Friday Poker Club',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The recovery store is shared between AppProviders and writes into the real
  // project directory, which makes unrelated tests fail with a file lock.
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  const structure = TournamentStructure(
    startingStack: 5000,
    chipPlan: [],
    rebuyStack: 5000,
    rebuyChipPlan: [],
    addOnStack: 5000,
    addOnChipPlan: [],
    levels: [BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15)],
    levelDuration: 15,
    expectedFinishMins: 210,
    prizes: [Prize(place: 1, amount: 180), Prize(place: 2, amount: 60)],
    prizePool: 240,
    organizerAmount: 26,
    colorUpInstructions: [],
    warnings: [],
  );

  GameSettings settings({bool addOnOvertime = false}) => GameSettings(
        name: 'Friday',
        date: '2026-09-25',
        time: '20:00',
        location: 'Basement',
        players: 2,
        durationHours: 4,
        buyIn: 20,
        koEnabled: false,
        koAmount: 0,
        rebuys: true,
        rebuysCloseLevel: 6,
        addOn: true,
        addOnOvertime: addOnOvertime,
        anteEnabled: false,
        anteAfterLevel: 6,
        organizerPct: 0,
        chipSet: const [
          ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
        ],
        chipSetName: 'Home',
      );

  Player player(
    String id, {
    bool hasAddOn = false,
    bool eliminated = false,
    bool active = true,
  }) =>
      Player(
        id: id,
        name: id.toUpperCase(),
        isGuest: false,
        rsvp: Rsvp.going,
        checkedIn: true,
        confirmed: true,
        eliminated: eliminated,
        rebuys: 0,
        reEntries: 0,
        hasAddOn: hasAddOn,
        knockouts: 0,
        table: 1,
        seat: 1,
        active: active,
      );

  /// A game mid-break: three players, none of whom has taken an add-on yet,
  /// and the window already in overtime because the break ran out.
  LiveGame game({bool addOnOvertime = true}) => LiveGame(
        id: 'g1',
        groupId: 'grp1',
        settings: settings(addOnOvertime: addOnOvertime),
        structure: structure,
        status: LiveGameStatus.running,
        publicCode: 'ABC123',
        tvCode: 'TV7890',
        currentLevel: 6,
        timerRunning: false,
        secondsRemaining: 0,
        players: [player('u1'), player('u2'), player('u3')],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 15000,
        pendingGuests: const [],
        finishOrder: const [],
      );

  /// An AppProvider holding [g] as the current game, with the host signed in.
  AppProvider providerWith(LiveGame g) => AppProvider()
    ..setUserForTesting(_host)
    ..setCurrentGroupForTesting(_group)
    ..setCurrentGame(g);

  group('declines are representable', () {
    test('a decline is recorded and survives a round trip', () {
      final app = providerWith(game());
      app.declineAddOn('u2');

      expect(app.currentGame!.addOnDeclined, contains('u2'));

      // Persisted, or a second device on the same night would keep asking a
      // player who already said no.
      final restored = liveGameFromMap(liveGameToMap(app.currentGame!));
      expect(restored.addOnDeclined, contains('u2'));
    });

    test('declining twice is not two declines', () {
      final app = providerWith(game());
      app.declineAddOn('u2');
      app.declineAddOn('u2');
      expect(app.currentGame!.addOnDeclined.where((id) => id == 'u2'), hasLength(1));
    });

    test('taking an add-on withdraws an earlier decline', () {
      // The two must not contradict each other: a player who declined and then
      // ticked the box has taken one, and the overtime close has to see it that
      // way rather than counting them as both.
      final app = providerWith(game());
      app.declineAddOn('u2');
      app.undeclineAddOn('u2');
      expect(app.currentGame!.addOnDeclined, isEmpty);
    });

    test('"answered" is true for a decline and false for silence', () {
      final app = providerWith(game());
      expect(app.hasAnsweredAddOn('u1'), isFalse);
      app.declineAddOn('u1');
      expect(app.hasAnsweredAddOn('u1'), isTrue);
    });

    test('a player who already bought counts as answered', () {
      final app = providerWith(
        game().copyWith(players: [player('u1', hasAddOn: true)]),
      );
      expect(app.hasAnsweredAddOn('u1'), isTrue);
    });
  });

  group('the overtime close', () {
    test('closes once every player has either taken or declined', () {
      final app = providerWith(game());
      app.declineAddOn('u1');
      expect(app.currentGame!.addOnWindowClosed, isFalse,
          reason: 'u2 and u3 are still outstanding');

      app.declineAddOn('u2');
      expect(app.currentGame!.addOnWindowClosed, isFalse,
          reason: 'u3 is still outstanding');

      app.declineAddOn('u3');
      expect(app.currentGame!.addOnWindowClosed, isTrue);
      expect(app.currentGame!.settings.addOnOvertime, isFalse,
          reason: 'the badge must go when the window closes');
    });

    test('a take closes it too, not only declines', () {
      final app = providerWith(game());
      app
        ..declineAddOn('u1')
        ..declineAddOn('u2')
        ..declineAddOn('u3');
      expect(app.currentGame!.addOnWindowClosed, isTrue);
    });

    test('a window that is merely open does not close itself', () {
      // Not in overtime: the host is mid-step-2 and still deciding. Auto-closing
      // here would end the offer before anybody was asked.
      final app = providerWith(game(addOnOvertime: false));
      app
        ..declineAddOn('u1')
        ..declineAddOn('u2')
        ..declineAddOn('u3');
      expect(app.currentGame!.addOnWindowClosed, isFalse);
    });

    test('the audit record says the close was automatic', () {
      final app = providerWith(game());
      app
        ..declineAddOn('u1')
        ..declineAddOn('u2')
        ..declineAddOn('u3');
      final closed = app.currentGame!.auditHistory
          .where((a) => a.type == 'addon_window_closed')
          .toList();
      expect(closed, hasLength(1));
      expect(closed.single.details, contains('overtime'));
    });
  });

  group('C6 line 2204 — "every player from step 1"', () {
    // Step 1 is "Who's still in": one row per player, In or Busted, and
    // "Paused players are already Out". So the set that owes an answer is the
    // players still in, which is `activePlayers` and is what the step 1 screen
    // itself lists.

    test('a busted player does not hold the window open forever', () {
      // The regression. The close used to walk `game.players`, which is every
      // player who ever entered. A busted player can never take or decline, so
      // the window could never be fully answered and the prize pool stayed
      // locked -- the exact failure line 2204 exists to prevent.
      final app = providerWith(
        game().copyWith(players: [
          player('u1'),
          player('u2'),
          player('u3', eliminated: true),
        ]),
      );
      app
        ..declineAddOn('u1')
        ..declineAddOn('u2');
      expect(app.currentGame!.addOnWindowClosed, isTrue,
          reason: 'u3 is out and can never answer, so the window is done');
    });

    test('a player who is no longer active does not block the close', () {
      final app = providerWith(
        game().copyWith(players: [
          player('u1'),
          player('u2'),
          player('u3', active: false),
        ]),
      );
      app
        ..declineAddOn('u1')
        ..declineAddOn('u2');
      expect(app.currentGame!.addOnWindowClosed, isTrue);
    });

    test('a still-in player who has not answered still blocks the close', () {
      // The complement of the test above: the fix must not have turned the
      // close into "close as soon as anyone answers".
      final app = providerWith(
        game().copyWith(players: [
          player('u1'),
          player('u2', eliminated: true),
          player('u3'),
        ]),
      );
      app.declineAddOn('u1');
      expect(app.currentGame!.addOnWindowClosed, isFalse,
          reason: 'u3 is still in and silent');
    });

    test('a busted player is not asked at all', () {
      // Busted players stay off the add-on list, so nothing in the UI offers
      // them one and nothing in the rules waits for them.
      final app = providerWith(
        game().copyWith(players: [player('u1'), player('u2', eliminated: true)]),
      );
      expect(app.currentGame!.activePlayers.map((p) => p.id), ['u1']);
    });
  });

  group('taking an add-on is an answer', () {
    test('the last player taking one closes the overtime window', () {
      // The other regression: only `declineAddOn` triggered the close check, so
      // a table where everyone said yes stayed in overtime with nobody left to
      // ask. Line 2204 says "taken or declined".
      final app = providerWith(game());
      app
        ..declineAddOn('u1')
        ..declineAddOn('u2');
      expect(app.currentGame!.addOnWindowClosed, isFalse);

      app.grantAddOn('u3');
      expect(app.currentGame!.addOnWindowClosed, isTrue);
      expect(app.currentGame!.settings.addOnOvertime, isFalse);
    });

    test('a take before the last player does not close it early', () {
      final app = providerWith(game());
      app.grantAddOn('u1');
      expect(app.currentGame!.addOnWindowClosed, isFalse,
          reason: 'u2 and u3 have not answered');
    });

    test('a take outside overtime does not close the window', () {
      final app = providerWith(game(addOnOvertime: false));
      app
        ..grantAddOn('u1')
        ..grantAddOn('u2')
        ..grantAddOn('u3');
      expect(app.currentGame!.addOnWindowClosed, isFalse,
          reason: 'the host is still mid-step-2 and decides when to close');
    });
  });

  group('a closed window can re-open', () {
    test('withdrawing the last decline re-opens it', () {
      // The host ticking and unticking is a real sequence, and undoing the
      // final decline must not leave the window shut on a player who has
      // genuinely not answered.
      final app = providerWith(game());
      app
        ..declineAddOn('u1')
        ..declineAddOn('u2')
        ..declineAddOn('u3');
      expect(app.currentGame!.addOnWindowClosed, isTrue);

      app.undeclineAddOn('u3');
      expect(app.currentGame!.addOnWindowClosed, isFalse);
      expect(app.currentGame!.settings.addOnOvertime, isTrue);
    });
  });

  group('the manual edge is untouched', () {
    test('Next still closes the window whether or not anyone answered', () {
      final app = providerWith(game());
      app.closeAddOnWindow();
      expect(app.currentGame!.addOnWindowClosed, isTrue);
      expect(app.currentGame!.settings.addOnOvertime, isFalse);
    });

    test('closing twice is a no-op', () {
      final app = providerWith(game());
      app
        ..closeAddOnWindow()
        ..closeAddOnWindow();
      expect(
        app.currentGame!.auditHistory.where((a) => a.type == 'addon_window_closed'),
        hasLength(1),
      );
    });
  });
}
