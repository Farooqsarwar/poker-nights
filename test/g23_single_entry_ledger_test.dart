import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/payment_record.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';

/// §G2.3 row 20 and §E17 row 80 — one entry, one add-on, and the rest are new
/// rows.
///
/// **Row 20** (spec `:5122`): "The ledger rejects a second buy-in or add-on for
/// the same player; rebuys are not a second buy-in".
///
/// **Row 80** (Addendum table, "Ledger") points at §E3/§E9: an entry is
/// `gameId:playerId:{buyIn|addOn}` and a repeat is rejected rather than
/// double-counted, while a rebuy or a re-entry is a new row.
///
/// Two different things are being asked of the provider, and conflating them
/// is the whole risk:
///
///   1. **Replay safety** — the same `idempotencyKey` arriving twice (a double
///      tap, a retry after a dropped connection) is ONE payment.
///   2. **Singularity** — a *different* key for a second buy-in is still a
///      second buy-in, and must be refused.
///
/// A guard that only did (1) would let a second buy-in through the moment the
/// key changed, which is exactly what a "Buy in again" path or a rebuilt sheet
/// produces. A guard that only did (2) would break the double-tap. The tests
/// below separate them deliberately, and each refusal asserts on the collected
/// total rather than on prose, because a refusal that logs an error but still
/// moves the money is the failure QA case PN-DPAY-007 is named for.
void main() {
  // The provider reaches for `ServicesBinding` on its first write, which a
  // plain `test()` has not set up.
  TestWidgetsFlutterBinding.ensureInitialized();

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
    expectedFinishMins: 225,
    prizes: [],
    prizePool: 0,
    organizerAmount: 0,
    colorUpInstructions: [],
    warnings: [],
  );

  /// Buy-in 15. `rebuyCost` and `addOnCost` are left null on purpose: the
  /// effective price then falls back to the buy-in, so a rebuy at 15 and an
  /// add-on at 15 are distinguishable from each other only by `purpose`. That
  /// is the point — the singularity guard keys on purpose, not on amount, so a
  /// free add-on must be refused exactly as a paid one would be.
  const settings = GameSettings(
    name: 'Friday',
    date: '2026-09-08',
    time: '20:00',
    location: 'Basement',
    players: 8,
    durationHours: 3.5,
    buyIn: 15,
    koEnabled: false,
    koAmount: 5,
    rebuys: true,
    rebuysCloseLevel: 6,
    addOn: true,
    anteEnabled: false,
    anteAfterLevel: 7,
    organizerPct: 0,
    chipSet: [],
    chipSetName: 'Home',
  );

  Player player(String id) => Player(
        id: id,
        name: id.toUpperCase(),
        isGuest: false,
        rsvp: Rsvp.going,
        checkedIn: true,
        confirmed: true,
        eliminated: false,
        rebuys: 0,
        hasAddOn: false,
        knockouts: 0,
        table: 1,
        seat: 1,
        active: true,
      );

  const host = AppUser(
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

  const fridayClub = Group(
    id: 'g1',
    name: 'Friday Poker Club',
    joinCode: 'FP2608',
    ownerId: 'u1',
    members: [host],
    games: [],
    chat: [],
    polls: [],
    notifications: [],
  );

  /// A live game on an authority device: the provider claims the editor role for
  /// whichever device loads it, so `_isGameAuthority` holds without a backend.
  AppProvider hostWithGame() => AppProvider()
    ..setUserForTesting(host)
    ..setCurrentGroupForTesting(fridayClub)
    ..setCurrentGame(
      LiveGame(
        id: 'game-1',
        groupId: 'g1',
        settings: settings,
        structure: structure,
        status: LiveGameStatus.running,
        publicCode: 'ABC123',
        tvCode: 'TV7890',
        currentLevel: 3,
        timerRunning: true,
        secondsRemaining: 600,
        players: [player('u1'), player('u2'), player('u3')],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 45000,
        pendingGuests: const [],
        finishOrder: const [],
      ),
    );

  /// A fresh key every time, which is what a rebuilt payment sheet produces.
  /// Tests that need a *specific* key pass one instead.
  String freshKey(String playerId, PaymentPurpose purpose) =>
      'pay-$playerId-${purpose.name}-${DateTime.now().microsecondsSinceEpoch}';

  List<PaymentRecord> ledger(AppProvider app) => app.currentGame!.payments;

  int collected(AppProvider app) => app.currentGame!.totalCollected;

  group('§G2.3 row 20 — the first entry', () {
    test('a buy-in is recorded, at the tournament\'s own price', () {
      final app = hostWithGame();

      final record = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: freshKey('u1', PaymentPurpose.buyIn),
      );

      expect(record, isNotNull);
      expect(record!.status, PaymentStatus.paid);
      expect(record.amount, 15, reason: 'the price is the host\'s, never the payer\'s');
      expect(ledger(app), hasLength(1));
      expect(collected(app), 15);
    });

    test('a payer stops being owed once the entry is on the ledger', () {
      final app = hostWithGame();
      expect(app.unpaidPlayers.map((p) => p.id), ['u1', 'u2', 'u3']);

      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: freshKey('u1', PaymentPurpose.buyIn),
      );

      expect(
        app.unpaidPlayers.map((p) => p.id),
        ['u2', 'u3'],
        reason: 'a paid player must drop off the host\'s unpaid list',
      );
      expect(app.owesBuyIn('u1'), isFalse);
    });
  });

  group('§G2.3 row 20 — a second buy-in is rejected', () {
    test('a fresh key does not get a second buy-in past the guard', () {
      // The load-bearing case. Replay protection alone would accept this,
      // because the key is new.
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'pay-u1-buyIn-first',
      );

      final second = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'pay-u1-buyIn-second',
      );

      expect(second, isNull);
      expect(ledger(app), hasLength(1), reason: 'no second ledger row');
      expect(collected(app), 15, reason: 'and no second 15 in the pot');
    });

    test('the refusal is reported in copy, not left as a silent null', () {
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'k1',
      );

      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'k2',
      );

      expect(app.lastRsvpError, 'Buy-in is already paid for this player.');
    });

    test('the rejection names the player\'s own entry, not the tournament\'s',
        () {
      // Two members both buying in must not lock each other out: the guard is
      // keyed on (player, purpose).
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'k1',
      );

      final other = app.recordPayment(
        playerId: 'u2',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'k2',
      );

      expect(other, isNotNull);
      expect(ledger(app), hasLength(2));
      expect(collected(app), 30);
    });

    test('a repeated buy-in is refused, not silently promoted to a rebuy', () {
      // The tempting fix for a "paid twice" bug is to treat the second attempt
      // as a rebuy so the money is not lost. That quietly doubles a player's
      // stack; the spec says reject.
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'k1',
      );

      final second = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'k2',
      );

      expect(second, isNull);
      expect(
        ledger(app).map((p) => p.purpose),
        [PaymentPurpose.buyIn],
        reason: 'no rebuy row smuggled in',
      );
      expect(
        ledger(app).where((p) => p.purpose == PaymentPurpose.rebuy),
        isEmpty,
      );
    });
  });

  group('§G2.3 row 20 — a second add-on is rejected', () {
    test('one add-on per player, on its own ledger row', () {
      final app = hostWithGame();

      final first = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.addOn,
        idempotencyKey: 'a1',
      );

      expect(first, isNotNull);
      expect(ledger(app).map((p) => p.purpose), [PaymentPurpose.addOn]);
      expect(collected(app), 15);
    });

    test('a second add-on for the same player is refused with its own copy', () {
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.addOn,
        idempotencyKey: 'a1',
      );

      final second = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.addOn,
        idempotencyKey: 'a2',
      );

      expect(second, isNull);
      expect(app.lastRsvpError, 'Add-on is already paid for this player.');
      expect(ledger(app), hasLength(1));
      expect(collected(app), 15);
    });

    test('a buy-in and an add-on are independent entitlements', () {
      // One of each is the normal combination, so the guard must not treat the
      // add-on as the player's second "singular" payment.
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'b1',
      );

      final addOn = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.addOn,
        idempotencyKey: 'a1',
      );

      expect(addOn, isNotNull);
      expect(ledger(app).map((p) => p.purpose), [
        PaymentPurpose.buyIn,
        PaymentPurpose.addOn,
      ]);
      expect(collected(app), 30);
    });
  });

  group('§G2.3 row 20 — rebuys and re-entries are new rows, not refusals', () {
    test('a player may rebuy repeatedly', () {
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'b1',
      );

      final r1 = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.rebuy,
        idempotencyKey: 'r1',
      );
      final r2 = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.rebuy,
        idempotencyKey: 'r2',
      );

      expect(r1, isNotNull);
      expect(r2, isNotNull);
      expect(r1!.id, isNot(r2!.id), reason: 'each rebuy is its own row');
      expect(ledger(app), hasLength(3));
      expect(collected(app), 45, reason: '15 buy-in + 15 + 15');
      expect(
        ledger(app).where((p) => p.purpose == PaymentPurpose.rebuy),
        hasLength(2),
      );
    });

    test('a rebuy is allowed even when the player never bought in', () {
      // A re-entry buys a fresh entry, so it is allowed too. Both are outside
      // the "singular" set, which is exactly buy-in and add-on.
      final app = hostWithGame();

      final reEntry = app.recordPayment(
        playerId: 'u2',
        purpose: PaymentPurpose.reEntry,
        idempotencyKey: 're1',
      );

      expect(reEntry, isNotNull);
      expect(reEntry!.amount, 15, reason: 'a re-entry costs a buy-in');
      expect(collected(app), 15);
    });

    test('the rebuy limit is not the ledger\'s job', () {
      // `rebuyLimit` is enforced where the chips are granted, not here. The
      // ledger records what the app was told; refusing at the payment step would
      // leave the money taken and the chips unissued.
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'b1',
      );

      for (var i = 1; i <= 4; i++) {
        expect(
          app.recordPayment(
            playerId: 'u1',
            purpose: PaymentPurpose.rebuy,
            idempotencyKey: 'r$i',
          ),
          isNotNull,
        );
      }

      expect(
        ledger(app).where((p) => p.purpose == PaymentPurpose.rebuy),
        hasLength(4),
      );
    });
  });

  group('§E17 row 80 — the same key is the same payment', () {
    test('a replayed key returns the existing record, not a new row', () {
      final app = hostWithGame();

      final first = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'same-key',
      );
      final replay = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'same-key',
      );

      expect(replay, isNotNull);
      expect(replay!.id, first!.id, reason: 'the very same record, returned again');
      expect(ledger(app), hasLength(1));
      expect(collected(app), 15);
    });

    test('a replay adds no audit line either', () {
      // A double tap that is correctly collapsed must not also claim twice in
      // the log, or the host's audit trail says the member paid twice.
      final app = hostWithGame();

      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'same-key',
      );
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'same-key',
      );

      expect(
        app.currentGame!.auditHistory.where((a) => a.type == 'payment_paid'),
        hasLength(1),
      );
    });

    test('FINDING — a key reused across purposes returns the FIRST record and '
        'files nothing', () {
      // The replay lookup matches on `idempotencyKey` alone, with no purpose in
      // the comparison, so a caller that reuses a key across purposes gets back
      // the earlier record: an add-on request answered with a buy-in record,
      // carrying the buy-in's amount, purpose and status. The second payment is
      // not recorded and the add-on is silently not taken.
      //
      // Not reachable from the app today: `showDummyPaymentSheet` builds
      // `pay-$playerId-${purpose.name}-$timestamp`, so a key cannot span two
      // purposes from the only production caller. Recorded here because the
      // guard is one comparison away from being right, and a second caller with
      // its own key scheme would inherit this.
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'shared',
      );

      final addOn = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.addOn,
        idempotencyKey: 'shared',
      );

      expect(addOn, isNotNull);
      expect(
        addOn!.purpose,
        PaymentPurpose.buyIn,
        reason: 'the replay is answered by the buy-in row, not the add-on',
      );
      expect(ledger(app), hasLength(1), reason: 'so the add-on is not filed');
      expect(collected(app), 15);
    });
  });

  group('§E17 row 80 — a failed attempt is recorded but never counts', () {
    test('a declined payment adds no money', () {
      final app = hostWithGame();

      final declined = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'f1',
        outcome: PaymentStatus.failed,
        failureReason: 'Declined (simulated)',
      );

      expect(declined, isNotNull);
      expect(ledger(app), hasLength(1), reason: 'the attempt is on file');
      expect(collected(app), 0, reason: 'but it is not money');
      expect(
        app.currentGame!.hasPaid('u1', PaymentPurpose.buyIn),
        isFalse,
      );
    });

    test('a declined attempt does not lock the player out of paying for real',
        () {
      // The bug this guards: a guard that checks "has this player got a row for
      // buy-in" rather than "have they PAID" leaves a member who was declined
      // permanently unable to enter. The real payment must go through.
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'f1',
        outcome: PaymentStatus.failed,
      );

      final paid = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'p1',
      );

      expect(paid, isNotNull);
      expect(ledger(app), hasLength(2));
      expect(collected(app), 15);
      expect(app.owesBuyIn('u1'), isFalse);
    });

    test('a cancelled attempt behaves like a declined one', () {
      final app = hostWithGame();

      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'c1',
        outcome: PaymentStatus.cancelled,
      );

      expect(collected(app), 0);
      expect(app.owesBuyIn('u1'), isTrue, reason: 'still owes their entry');
    });

    test('after a paid attempt, a later decline is recorded but adds nothing',
        () {
      // The singularity guard is skipped for non-paid outcomes, so this is
      // filed rather than refused — and it must not move the money.
      final app = hostWithGame();
      app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'p1',
      );

      final declined = app.recordPayment(
        playerId: 'u1',
        purpose: PaymentPurpose.buyIn,
        idempotencyKey: 'f1',
        outcome: PaymentStatus.failed,
      );

      expect(declined, isNotNull);
      expect(ledger(app), hasLength(2));
      expect(collected(app), 15);
    });
  });
}
