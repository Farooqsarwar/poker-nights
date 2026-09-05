import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/model_codec.dart';

/// Regression coverage for the member-RSVP propagation bugs: a member's RSVP
/// (and guest-slot) write must survive
///   1. a Firestore dot-path `.update()` round-trip,
///   2. the admin's concurrent whole-document `.set()` (via
///      [mergeMemberOwnedFields]), and
///   3. reach the admin's screen — which requires every path that rebuilds the
///      admin's current game from a server document to produce an identical
///      result (via [restoreAdminPrivateFields]), otherwise the content
///      signature flips on every group-bundle emit, the admin stays
///      permanently "dirty" and stops adopting remote snapshots.

const _structure = TournamentStructure(
  startingStack: 5000,
  chipPlan: [],
  rebuyStack: 0,
  rebuyChipPlan: [],
  addOnStack: 0,
  addOnChipPlan: [],
  levels: [BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15)],
  levelDuration: 15,
  expectedFinishMins: 120,
  prizes: [],
  prizePool: 0,
  organizerAmount: 0,
  colorUpInstructions: [],
  warnings: [],
);

const _settings = GameSettings(
  name: 'Friday Night',
  date: '2026-08-21',
  time: '19:00',
  location: '',
  players: 6,
  durationHours: 3,
  buyIn: 20,
  koEnabled: false,
  koAmount: 0,
  rebuys: false,
  rebuysCloseLevel: 0,
  rebuyLimit: 0,
  reEntry: false,
  addOn: false,
  addOnCloseLevel: 0,
  anteEnabled: false,
  anteAfterLevel: 0,
  anteStyle: AnteStyle.bigBlind,
  antePreference: AntePreference.recommend,
  organizerPct: 0,
  chipSet: [],
  chipSetName: '',
  announceEliminations: true,
  forcePaidPlaces: null,
  rebuyCost: 0,
  addOnCost: 0,
  locationPrivate: false,
);

Player _member(String id, {Rsvp? rsvp, bool confirmed = false}) => Player(
      id: id,
      name: id.toUpperCase(),
      isGuest: false,
      rsvp: rsvp,
      checkedIn: false,
      confirmed: confirmed,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 0,
      seat: 0,
      active: true,
    );

LiveGame _game({
  required List<Player> players,
  List<GuestSlot> guestSlots = const [],
}) =>
    LiveGame(
      id: 'game-1',
      groupId: 'grp-1',
      settings: _settings,
      structure: _structure,
      status: LiveGameStatus.published,
      publicCode: 'ABC123',
      tvCode: 'TV789',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: players,
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 0,
      pendingGuests: const [],
      finishOrder: const [],
      speedRecommendation: null,
      guestSlots: guestSlots,
    );

void main() {
  group('member RSVP dot-path survives a Firestore round-trip', () {
    test('players.<uid>.rsvp update decodes back to the written value', () {
      final doc = liveGameToFirestoreDoc(
        _game(players: [_member('admin'), _member('u2')]),
      );
      // Simulate `.update({'players.u2.rsvp': 'goingPlus2'})` against the
      // map-keyed players collection.
      (doc['players'] as Map)['u2']['rsvp'] = Rsvp.goingPlus2.name;

      final restored = liveGameFromFirestoreDoc(doc);
      expect(
        restored.players.firstWhere((p) => p.id == 'u2').rsvp,
        Rsvp.goingPlus2,
      );
      // The admin's row is untouched.
      expect(restored.players.firstWhere((p) => p.id == 'admin').rsvp, isNull);
    });

    test('a member row created by a first-time RSVP is not lost on decode', () {
      final doc = liveGameToFirestoreDoc(_game(players: [_member('admin')]));
      // `.update({'players.late.rsvp': ...})` / whole-row write.
      (doc['players'] as Map)['late'] = {
        ...playerToMap(_member('late', rsvp: Rsvp.going)),
        'orderIndex': 1,
      };

      final restored = liveGameFromFirestoreDoc(doc);
      expect(restored.players.map((p) => p.id), containsAll(['admin', 'late']));
      expect(restored.players.firstWhere((p) => p.id == 'late').rsvp, Rsvp.going);
    });
  });

  group('mergeMemberOwnedFields — admin whole-doc save must not clobber', () {
    test('adopts another member\'s newer server RSVP', () {
      final local = _game(players: [
        _member('admin'),
        _member('u2'), // admin still sees u2 with no RSVP
      ]);
      final remote = _game(players: [
        _member('admin'),
        _member('u2', rsvp: Rsvp.going), // u2 just RSVPd on the server
      ]);

      final merged = mergeMemberOwnedFields(local, remote, adminId: 'admin');
      expect(merged.players.firstWhere((p) => p.id == 'u2').rsvp, Rsvp.going);
    });

    test('keeps the admin\'s own local RSVP even if the server differs', () {
      final local = _game(players: [_member('admin', rsvp: Rsvp.going)]);
      final remote = _game(players: [_member('admin', rsvp: Rsvp.cant)]);

      final merged = mergeMemberOwnedFields(local, remote, adminId: 'admin');
      expect(
          merged.players.firstWhere((p) => p.id == 'admin').rsvp, Rsvp.going);
    });

    test('appends a server-only member row the admin never had locally', () {
      final local = _game(players: [_member('admin')]);
      final remote = _game(players: [
        _member('admin'),
        _member('late', rsvp: Rsvp.maybe),
      ]);

      final merged = mergeMemberOwnedFields(local, remote, adminId: 'admin');
      expect(merged.players.map((p) => p.id), containsAll(['admin', 'late']));
      expect(
          merged.players.firstWhere((p) => p.id == 'late').rsvp, Rsvp.maybe);
    });

    test('never drops a local row that is absent on the server', () {
      final local = _game(players: [
        _member('admin'),
        _member('u2', rsvp: Rsvp.going, confirmed: true),
      ]);
      final remote = _game(players: [_member('admin')]);

      final merged = mergeMemberOwnedFields(local, remote, adminId: 'admin');
      final u2 = merged.players.firstWhere((p) => p.id == 'u2');
      expect(u2.rsvp, Rsvp.going);
      expect(u2.confirmed, isTrue);
    });

    test('takes the server guest-slot list when it differs', () {
      final local = _game(players: [_member('admin'), _member('u2')]);
      final remote = _game(
        players: [_member('admin'), _member('u2', rsvp: Rsvp.goingPlus1)],
        guestSlots: const [
          GuestSlot(
            id: 'slot-a',
            inviterId: 'u2',
            slot: 1,
            guestName: 'Dana',
            status: GuestSlotStatus.reserved,
          ),
        ],
      );

      final merged = mergeMemberOwnedFields(local, remote, adminId: 'admin');
      expect(merged.guestSlots, hasLength(1));
      expect(merged.guestSlots.single.guestName, 'Dana');
    });

    test('is a no-op when nothing member-owned changed', () {
      final g = _game(players: [_member('admin'), _member('u2', rsvp: Rsvp.going)]);
      final merged = mergeMemberOwnedFields(g, g, adminId: 'admin');
      expect(identical(merged, g), isTrue);
    });
  });

  group('restoreAdminPrivateFields — admin sees member RSVPs in real time', () {
    /// The admin holds private figures the public game doc does not carry.
    LiveGame adminLocal() => _game(
          players: [
            _member('admin').copyWith(rebuys: 2, knockouts: 3),
            _member('u2'),
          ],
        ).copyWith(
          settings: _settings.copyWith(organizerPct: 10),
          structure: _structure.copyWith(
            prizes: const [Prize(place: 1, amount: 120)],
            organizerAmount: 15,
          ),
        );

    /// What both the game-doc stream and the group-bundle query actually
    /// deliver: the scrubbed public document — here carrying u2's new RSVP.
    LiveGame serverScrubbed() => _game(
          players: [_member('admin'), _member('u2', rsvp: Rsvp.going)],
        );

    test('re-attaches organizer cut, prizes and player financials', () {
      final restored = restoreAdminPrivateFields(serverScrubbed(), adminLocal());
      expect(restored.settings.organizerPct, 10);
      expect(restored.structure.organizerAmount, 15);
      expect(restored.structure.prizes.single.amount, 120);
      final admin = restored.players.firstWhere((p) => p.id == 'admin');
      expect(admin.rebuys, 2);
      expect(admin.knockouts, 3);
    });

    test('does not mask the member RSVP the server just delivered', () {
      final restored = restoreAdminPrivateFields(serverScrubbed(), adminLocal());
      expect(restored.players.firstWhere((p) => p.id == 'u2').rsvp, Rsvp.going);
    });

    test(
        'both refresh paths yield an identical content signature — the '
        'invariant that keeps the admin from being permanently "dirty"', () {
      final local = adminLocal();
      final server = serverScrubbed();

      // Path 1: the game-doc snapshot stream.
      final viaDocStream = restoreAdminPrivateFields(server, local);
      // Path 2: the group-bundle games query, which additionally carries the
      // admin's local clock fields across.
      final viaBundle = restoreAdminPrivateFields(server, local).copyWith(
        secondsRemaining: local.secondsRemaining,
        timerRunning: local.timerRunning,
        levelEndTime: local.levelEndTime,
      );

      String sig(LiveGame g) => jsonEncode(liveGameToMap(g));
      expect(sig(viaBundle), sig(viaDocStream));
    });

    test('an UNrestored bundle copy would flip the signature (the old bug)',
        () {
      final local = adminLocal();
      final server = serverScrubbed();
      String sig(LiveGame g) => jsonEncode(liveGameToMap(g));
      // Guards the regression: skipping the restore on one of the two paths is
      // exactly what made every bundle emit look like a local edit.
      expect(sig(server), isNot(sig(restoreAdminPrivateFields(server, local))));
    });

    test('leaves a game for a different id untouched', () {
      final other = serverScrubbed().copyWith(id: 'game-2');
      expect(identical(restoreAdminPrivateFields(other, adminLocal()), other),
          isTrue);
    });
  });
}
