import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';

/// "A bust is idempotent too" - Technical section, "Sync":
///
///   "A bust is idempotent too: its action carries
///    `idempotencyKey = gameId:playerId:bust:{entryNo}`; a second bust for a
///    player who is already `out` is a no-op - no second bounty, no second
///    place."
///
/// The revision-derived key in `_claimIdempotency` does not deliver this. It
/// folds the *expected next* revision into the key, so a second tap off the
/// same screen lands on a fresh revision and reads as a NEW action rather than
/// a replay: it only ever catches the identical write arriving twice over the
/// wire, never a second tap.
///
/// What that cost, before the guard in [AppProvider.eliminatePlayer]:
///   * `eliminationPos` was recomputed from the survivors, so the player who
///     had gone home was re-seated at a worse finish;
///   * the knockout bounty was paid a second time to whoever knocked them out;
///   * a second audit line claimed a second elimination happened.
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
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

/// Knockouts ON, so a duplicated bust has a second, countable consequence.
const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-08',
  time: '20:00',
  location: 'Basement',
  players: 8,
  durationHours: 3.5,
  buyIn: 15,
  koEnabled: true,
  koAmount: 500,
  rebuys: true,
  rebuysCloseLevel: 6,
  addOn: true,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 0,
  chipSet: [],
  chipSetName: 'Home',
);

Player _player(String id) => Player(
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

/// A live game on an authority device: the provider claims the editor role for
/// whichever device loads it, so `_isGameAuthority` is satisfied without a
/// backend (`_syncGameToCloud` returns early when `_backendUp` is false).
AppProvider _hostWithGame() {
  final app = AppProvider()
    ..setUserForTesting(_host)
    ..setCurrentGroupForTesting(_group)
    ..setCurrentGame(
      LiveGame(
        id: 'game-1',
        groupId: 'g1',
        settings: _settings,
        structure: _structure,
        status: LiveGameStatus.running,
        publicCode: 'ABC123',
        tvCode: 'TV7890',
        currentLevel: 3,
        timerRunning: true,
        secondsRemaining: 600,
        players: [
          _player('u1'),
          _player('u2'),
          _player('u3'),
          _player('u4'),
        ],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 20000,
        pendingGuests: const [],
        finishOrder: const [],
      ),
    );
  return app;
}

Player _find(AppProvider app, String id) =>
    app.currentGame!.players.firstWhere((p) => p.id == id);

/// Counted on the record's `type`, not its prose: the wording of an audit line
/// is copy, and a test that greps for it breaks when the sentence is reworded.
int _elimsInAudit(AppProvider app) =>
    app.currentGame!.auditHistory.where((a) => a.type == 'elimination').length;

void main() {
  // The provider reaches for `ServicesBinding` on its first write (announcement
  // plumbing), which a plain `test()` has not set up.
  TestWidgetsFlutterBinding.ensureInitialized();

  // These are pure state assertions about the local game object. The provider
  // also mirrors an admin's game to the crash-recovery store on every change,
  // which is real filesystem I/O keyed to the process working directory -
  // leaving it on made concurrent instances fight over one file. Nothing here
  // depends on it, so it is off for the duration.
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  group('a second bust for a player who is already out is a no-op', () {
    test('the first bust takes the place and pays the bounty', () {
      final app = _hostWithGame();

      app.eliminatePlayer('u4', koRecipientId: 'u3');

      final out = _find(app, 'u4');
      expect(out.eliminated, isTrue);
      expect(out.eliminationPos, 4, reason: 'last of four standing');
      expect(_find(app, 'u3').knockouts, 1, reason: 'bounty paid once');
      expect(_elimsInAudit(app), 1);
    });

    test('a second tap changes nothing at all', () {
      final app = _hostWithGame();
      app.eliminatePlayer('u4', koRecipientId: 'u3');

      final afterFirst = _find(app, 'u4');
      final posAfterFirst = afterFirst.eliminationPos;
      final koAfterFirst = _find(app, 'u3').knockouts;
      final auditAfterFirst = _elimsInAudit(app);
      final revisionAfterFirst = app.currentGame!.revision;

      // The same action again, exactly as a double tap produces it.
      app.eliminatePlayer('u4', koRecipientId: 'u3');

      final afterSecond = _find(app, 'u4');
      expect(
        afterSecond.eliminationPos,
        posAfterFirst,
        reason: 'no second place - the position must not be recomputed',
      );
      expect(
        afterSecond.eliminated,
        isTrue,
        reason: 'still out, just not twice',
      );
      expect(
        _find(app, 'u3').knockouts,
        koAfterFirst,
        reason: 'no second bounty for one bust',
      );
      expect(
        _elimsInAudit(app),
        auditAfterFirst,
        reason: 'no second elimination written to the log',
      );
      expect(
        app.currentGame!.revision,
        revisionAfterFirst,
        reason: 'a no-op must not burn a revision',
      );
    });

    test('a bust with no explicit key is still ignored the second time', () {
      // The caller that forgot to pass an `idempotencyKey` is the ordinary
      // case, and the case the revision-derived key silently failed.
      final app = _hostWithGame();
      app.eliminatePlayer('u4', koRecipientId: 'u3');
      final pos = _find(app, 'u4').eliminationPos;
      final ko = _find(app, 'u3').knockouts;

      app.eliminatePlayer('u4', koRecipientId: 'u3');

      expect(_find(app, 'u4').eliminationPos, pos);
      expect(_find(app, 'u3').knockouts, ko);
    });

    test('a second KO recipient is not paid either', () {
      // The guard keys on the target being out, not on which knocker-out was
      // named, so a retry aimed at a different player is equally inert.
      final app = _hostWithGame();
      app.eliminatePlayer('u4', koRecipientId: 'u3');

      app.eliminatePlayer('u4', koRecipientId: 'u2');

      expect(
        _find(app, 'u2').knockouts,
        0,
        reason: 'the second tap must not pay a different knocker-out',
      );
      expect(_find(app, 'u3').knockouts, 1);
    });

    test('an unknown player id is still ignored', () {
      final app = _hostWithGame();
      app.eliminatePlayer('u4', koRecipientId: 'u3');
      final revision = app.currentGame!.revision;

      app.eliminatePlayer('does-not-exist');

      expect(app.currentGame!.revision, revision);
    });
  });
}
