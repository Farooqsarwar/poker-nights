import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/permissions.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/model_codec.dart';

/// `LiveGame.organizerIds` is the client-side name for the specification's
/// per-game `coHostUids`: "copied from the group's co-hosts at posting" (E4,
/// spec line 2874). It is what makes a co-host the operator of ONE night.
///
/// The bug these pin: the field existed, round-tripped, and was never written.
/// `Permissions.actorFor` checks `group.members.any(isAdmin)` and never
/// `isCoAdmin`, so a co-host (`isAdmin: false`) fell through to `Actor.member`,
/// `canRunCurrentGame` was false, and a co-host was never the single writer for
/// a game whose clock they had taken over — which §E9 grants them and which
/// `firestore.rules`' `isTournamentOrganizer` reads this very field for.
const _chips = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
];

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-18',
  time: '20:00',
  location: 'Kitchen table',
  players: 6,
  durationHours: 4,
  buyIn: 20,
  chipSet: _chips,
  chipSetName: 'Standard 200',
  koEnabled: false,
  koAmount: 0,
  rebuys: true,
  rebuysCloseLevel: 6,
  addOn: true,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 10,
);

const _emptyStructure = TournamentStructure(
  startingStack: 0,
  chipPlan: [],
  rebuyStack: 0,
  rebuyChipPlan: [],
  addOnStack: 0,
  addOnChipPlan: [],
  levels: [],
  levelDuration: 15,
  expectedFinishMins: 0,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

LiveGame _game({List<String> organizerIds = const []}) => LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: _emptyStructure,
      status: LiveGameStatus.published,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 0,
      pendingGuests: const [],
      finishOrder: const [],
      organizerIds: organizerIds,
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

const _coHost = AppUser(
  id: 'u2',
  name: 'Marco Silva',
  email: 'marco@poker.night',
  isAdmin: false,
  isCoAdmin: true,
  stats: UserStats(
    played: 21,
    wins: 4,
    podium: 8,
    avgFinish: 3.9,
    knockouts: 9,
  ),
);

/// The same person as [_coHost], after being demoted: still in the group, no
/// longer able to run a night. Kept as a separate constant rather than built by
/// `copyWith` at the call site so the demotion is visible next to the promotion
/// it is contrasted with.
const _demoted = AppUser(
  id: 'u2',
  name: 'Marco Silva',
  email: 'marco@poker.night',
  isAdmin: false,
  isCoAdmin: false,
  stats: UserStats(
    played: 21,
    wins: 4,
    podium: 8,
    avgFinish: 3.9,
    knockouts: 9,
  ),
);

const _member = AppUser(
  id: 'u3',
  name: 'Nina Kowalski',
  email: 'nina@poker.night',
  isAdmin: false,
  stats: UserStats(
    played: 12,
    wins: 2,
    podium: 4,
    avgFinish: 4.1,
    knockouts: 3,
  ),
);

Group _groupWith(List<AppUser> members) => Group(
      id: 'g1',
      name: 'Friday Poker Club',
      joinCode: 'FP2608',
      ownerId: 'u1',
      members: members,
      games: const [],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

const _rostered = [_host, _coHost, _member];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  AppProvider provider({required List<AppUser> members, AppUser? as}) {
    final app = AppProvider()
      ..setUserForTesting(as ?? _host)
      ..setCurrentGroupForTesting(_groupWith(members));
    return app;
  }

  group('the codec round-trips organizerIds', () {
    test('present -> present', () {
      final game = _game(organizerIds: ['u2', 'u4']);
      expect(liveGameToMap(game)['organizerIds'], ['u2', 'u4']);
      expect(liveGameFromMap(liveGameToMap(game)).organizerIds, ['u2', 'u4']);
    });

    test('absent -> empty', () {
      expect(_game().organizerIds, isEmpty);
      expect(liveGameToMap(_game())['organizerIds'], isEmpty);
    });

    test('present -> present through the Firestore document shape', () {
      // This is the shape `saveGame` actually writes: `liveGameToFirestoreDoc`
      // re-keys players/guestSlots as id maps, and the rules read organizerIds
      // off this document. Round-tripping the other function only would not
      // prove the field survives the real write.
      final doc = liveGameToFirestoreDoc(_game(organizerIds: ['u2', 'u4']));
      expect(doc['organizerIds'], ['u2', 'u4']);
      expect(
        liveGameFromFirestoreDoc(doc).organizerIds,
        ['u2', 'u4'],
      );
    });

    test('a stored game written before the field existed still decodes', () {
      // Backward compatibility, both ways: the key is simply not there, and it
      // must read as "no co-hosts" rather than throwing. A throw here would
      // lose the whole game, not just this field.
      final legacy = liveGameToMap(_game(organizerIds: ['u2']))..remove(
        'organizerIds',
      );
      expect(legacy.containsKey('organizerIds'), isFalse);
      expect(liveGameFromMap(legacy).organizerIds, isEmpty);

      final legacyDoc =
          liveGameToFirestoreDoc(_game(organizerIds: ['u2']))
            ..remove('organizerIds');
      expect(liveGameFromFirestoreDoc(legacyDoc).organizerIds, isEmpty);
    });

    test('an explicitly empty list stays empty rather than becoming null', () {
      expect(liveGameToMap(_game())['organizerIds'], isNotNull);
      expect(liveGameFromMap(liveGameToMap(_game())).organizerIds, isEmpty);
    });

    test('the encoder copies rather than aliasing the caller\'s list', () {
      // `List<String>.from`, not a pass-through: a caller mutating the list it
      // handed the encoder must not retroactively change a stored document's
      // meaning, and `organizerWriteSafe` compares the stored list for equality.
      final ids = ['u2'];
      final map = liveGameToMap(_game(organizerIds: ids));
      ids.add('u9');
      expect(map['organizerIds'], ['u2']);
    });

    test('copyWith replaces the list and defaults to keeping it', () {
      final game = _game(organizerIds: ['u2']);
      expect(game.copyWith(organizerIds: ['u4']).organizerIds, ['u4']);
      expect(game.copyWith(status: LiveGameStatus.cancelled).organizerIds,
          ['u2']);
    });

    test('isOrganizer only answers for a uid on the list', () {
      final game = _game(organizerIds: ['u2']);
      expect(game.isOrganizer('u2'), isTrue);
      expect(game.isOrganizer('u1'), isFalse);
      expect(game.isOrganizer(null), isFalse);
      expect(_game().isOrganizer('u2'), isFalse);
    });
  });

  group('the list is derived from the group roster, not edited', () {
    test('creating an event seeds it with the co-hosts', () {
      final app = provider(members: _rostered);
      try {
        final game = app.createGame(_settings);
        expect(game.organizerIds, ['u2']);
      } finally {
        app.dispose();
      }
    });

    test('the host is not listed — they are already the host', () {
      // `actorFor` resolves `group.ownerId` to `Actor.host` first, so an entry
      // here would buy nothing and would make the rules treat the host as one
      // of their own co-hosts.
      final app = provider(members: _rostered);
      try {
        final game = app.createGame(_settings);
        expect(game.organizerIds, isNot(contains(_host.id)));
        expect(game.organizerIds, isNot(contains(_member.id)));
      } finally {
        app.dispose();
      }
    });

    test('a group with no co-host produces no list', () {
      final app = provider(members: [_host, _member]);
      try {
        expect(app.createGame(_settings).organizerIds, isEmpty);
      } finally {
        app.dispose();
      }
    });

    test('posting re-derives it, so a co-host promoted since creation runs '
        'this night', () {
      // E4: "copied from the group's co-hosts at POSTING".
      final app = provider(members: [_host, _member]);
      try {
        final game = app.createGame(_settings);
        expect(game.organizerIds, isEmpty);

        app.setCurrentGroupForTesting(_groupWith(_rostered));
        app.publishGame(announce: false);

        expect(app.currentGame!.status, LiveGameStatus.published);
        expect(app.currentGame!.organizerIds, ['u2']);
      } finally {
        app.dispose();
      }
    });

    test('the derived list reaches the group copy, not just the live game', () {
      // `_syncGroupGame` is what the hub's list and the reload read, so a value
      // that only lived on `_currentGame` would evaporate on the next load.
      final app = provider(members: _rostered);
      try {
        app.createGame(_settings);
        app.publishGame(announce: false);
        final inGroup =
            app.currentGroup.games.firstWhere((g) => g.id == app.currentGame!.id);
        expect(inGroup.organizerIds, ['u2']);
      } finally {
        app.dispose();
      }
    });

    test('every co-host is listed, not just the first', () {
      const second = AppUser(
        id: 'u4',
        name: 'Ana Reis',
        email: 'ana@poker.night',
        isAdmin: false,
        isCoAdmin: true,
        stats: UserStats(
          played: 9,
          wins: 1,
          podium: 3,
          avgFinish: 4.4,
          knockouts: 2,
        ),
      );
      final app = provider(members: [_host, _coHost, second, _member]);
      try {
        expect(app.createGame(_settings).organizerIds, ['u2', 'u4']);
      } finally {
        app.dispose();
      }
    });
  });

  group('the whole point: a co-host can now run the night', () {
    test('a co-host is an operator of the game they were copied onto', () {
      final app = provider(members: _rostered, as: _coHost);
      try {
        final game = app.createGame(_settings);
        expect(game.isOrganizer(_coHost.id), isTrue);
        expect(app.currentActor, Actor.organizer);
        expect(app.canRunCurrentGame, isTrue);
      } finally {
        app.dispose();
      }
    });

    test('an ordinary member still cannot run it', () {
      final app = provider(members: _rostered, as: _member);
      try {
        app.createGame(_settings);
        expect(app.currentActor, Actor.member);
        expect(app.canRunCurrentGame, isFalse);
      } finally {
        app.dispose();
      }
    });

    test('the host keeps every right, and is not demoted by the list', () {
      final app = provider(members: _rostered, as: _host);
      try {
        app.createGame(_settings);
        expect(app.currentActor, Actor.host);
        for (final c in Capability.values) {
          expect(Permissions.can(c, Actor.host), isTrue, reason: c.name);
        }
      } finally {
        app.dispose();
      }
    });

    test('it is tournament-scoped: co-host one night, member the next', () {
      // E6: "The same person can host Tuesday and play Friday."
      //
      // `organizerIds` is snapshotted onto a game from the roster when the game
      // is created, so the two halves of this are different claims and both have
      // to hold: Tuesday keeps the assignment even after the demotion, and
      // Friday - created from a roster where the person is no longer a co-host -
      // does not get it at all.
      final app = provider(members: _rostered, as: _coHost);
      try {
        final tuesday = app.createGame(_settings);
        expect(app.canRunCurrentGame, isTrue);

        // Demoted to a plain member: still in the group, no longer a co-host.
        // A guest would not test E6 at all, since a guest was never able to run
        // a night in the first place.
        app.setCurrentGroupForTesting(
          _groupWith([_host, _demoted, _member]),
        );
        expect(tuesday.organizerIds, ['u2'], reason: 'Tuesday is a snapshot');
        // `currentActor` still says organizer, and correctly so: the game in
        // progress is still Tuesday's, and the person still holds that
        // assignment. The demotion takes effect on the NEXT game.
        expect(app.currentActor, Actor.organizer);

        final friday = app.createGame(_settings);
        expect(friday.organizerIds, isEmpty);
        expect(app.currentActor, Actor.member);
        expect(app.canRunCurrentGame, isFalse);
      } finally {
        app.dispose();
      }
    });

    test('dropping them from the roster makes them a guest, not a member', () {
      // The neighbouring state, pinned because the two look alike from outside
      // and carry very different rights: off the roster is a guest, on it as a
      // non-co-host is a member.
      final app = provider(members: _rostered, as: _coHost);
      try {
        expect(app.createGame(_settings).organizerIds, ['u2']);
        app.setCurrentGroupForTesting(_groupWith([_host, _member]));
        // A new game first: `currentActor` describes the game in progress, and
        // Tuesday's snapshot would still make them its organizer.
        expect(app.createGame(_settings).organizerIds, isEmpty);
        expect(app.currentActor, Actor.guest);
      } finally {
        app.dispose();
      }
    });
  });
}
