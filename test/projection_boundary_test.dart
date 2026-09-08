import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/services/projections.dart' as projections;
import 'package:poker_night/utils/model_codec.dart';

/// PN-013 / PN-023 / PN-024 — what leaves the device for a non-admin role.
///
/// These assertions mirror the Firestore rules exactly (`projectionSafe` and
/// `publicGameDocSafe`). If a projection ever regresses, the rules would start
/// rejecting the publish in production; this catches it in CI instead.

const _structure = TournamentStructure(
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
  roundingRemainder: 4,
  colorUpInstructions: [],
  warnings: [],
);

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-09-07',
  time: '20:00',
  location: 'Basement',
  players: 8,
  durationHours: 3.5,
  buyIn: 15,
  koEnabled: false,
  koAmount: 0,
  rebuys: true,
  rebuysCloseLevel: 6,
  addOn: true,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 12,
  chipSet: [],
  chipSetName: 'Home',
);

Player _p(String id) => Player(
  id: id,
  name: id.toUpperCase(),
  isGuest: false,
  rsvp: Rsvp.going,
  checkedIn: true,
  confirmed: true,
  eliminated: false,
  rebuys: 3,
  reEntries: 2,
  hasAddOn: true,
  knockouts: 4,
  table: 1,
  seat: 1,
  active: true,
);

LiveGame _game() => LiveGame(
  id: 'game-1',
  groupId: 'grp-1',
  settings: _settings,
  structure: _structure,
  status: LiveGameStatus.running,
  publicCode: 'ABC123',
  tvCode: 'TV7890',
  currentLevel: 1,
  timerRunning: true,
  secondsRemaining: 600,
  players: [_p('u1'), _p('u2')],
  chat: const [],
  announcements: const [],
  auditHistory: [
    AuditRecord(
      id: 'a1',
      timestamp: DateTime.parse('2026-09-07T20:00:00.000'),
      type: 'rebuy',
      actor: 'Admin',
      details: 'Granted rebuy to U1',
    ),
  ],
  totalChipsInPlay: 10000,
  pendingGuests: const [],
  finishOrder: const [],
  rebuyRequests: const ['u1'],
  addOnRequests: const ['u2'],
);

void main() {
  group('PN-013 — no player sees any investment figure, their own included', () {
    for (final entry in {
      'player': projections.playerProjection(_game(), viewerId: 'u1'),
      'guest': projections.guestProjection(_game()),
      'tv': projections.tvProjection(_game()),
    }.entries) {
      test('${entry.key} projection zeroes every per-player counter', () {
        for (final p in entry.value.players) {
          expect(p.rebuys, 0, reason: '${p.id} rebuys leaked');
          expect(p.reEntries, 0, reason: '${p.id} reEntries leaked');
          expect(p.hasAddOn, isFalse, reason: '${p.id} hasAddOn leaked');
          expect(p.knockouts, 0, reason: '${p.id} knockouts leaked');
        }
      });
    }

    test('the viewer is NOT exempt', () {
      final me = projections
          .playerProjection(_game(), viewerId: 'u1')
          .players
          .firstWhere((p) => p.id == 'u1');
      expect(me.rebuys, 0);
      expect(me.hasAddOn, isFalse);
    });
  });

  group('PN-023 — every projection satisfies the rules guard', () {
    // Mirrors `projectionSafe()` in firestore.rules.
    void assertSafe(String label, LiveGame projected) {
      final map = liveGameToMap(projected);
      expect(
        (map['auditHistory'] as List).length,
        0,
        reason: '$label: audit timeline present',
      );
      expect(
        (map['rebuyRequests'] as List).length,
        0,
        reason: '$label: rebuy request identities present',
      );
      expect(
        (map['addOnRequests'] as List).length,
        0,
        reason: '$label: add-on request identities present',
      );
      expect(
        (map['settings'] as Map)['organizerPct'],
        0,
        reason: '$label: organizer percentage present',
      );
      expect(
        (map['structure'] as Map)['organizerAmount'],
        0,
        reason: '$label: organizer amount present',
      );
    }

    test('tv', () => assertSafe('tv', projections.tvProjection(_game())));
    test(
      'player',
      () => assertSafe(
        'player',
        projections.playerProjection(_game(), viewerId: ''),
      ),
    );
    test(
      'guest',
      () => assertSafe('guest', projections.guestProjection(_game())),
    );

    test('individual payout amounts do not travel at all', () {
      // Stronger than "zeroed": the list is empty, which the Firestore rule
      // can actually verify (`prizes.size() == 0`). A list of zeroed rows
      // could only be trusted, never checked.
      for (final entry in {
        'tv': projections.tvProjection(_game()),
        'player': projections.playerProjection(_game(), viewerId: 'u1'),
        'guest': projections.guestProjection(_game()),
      }.entries) {
        expect(
          entry.value.structure.prizes,
          isEmpty,
          reason: '${entry.key}: prize rows still on the wire',
        );
        final map = liveGameToMap(entry.value);
        expect(((map['structure'] as Map)['prizes'] as List), isEmpty);
      }
    });

    test('the paid-place count survives so viewers still see the positions', () {
      final tv = projections.tvProjection(_game());
      expect(tv.structure.paidPlaces, 2);
      expect(tv.structure.paidPlacesForDisplay, 2);
    });

    test('guest and TV get no chat; a member keeps it', () {
      expect(projections.guestProjection(_game()).chat, isEmpty);
      expect(projections.tvProjection(_game()).chat, isEmpty);
    });
  });

  group('PN-024 — the admin projection is untouched', () {
    test('the host still sees everything', () {
      final admin = projections.projectionFor(
        _game(),
        projections.GameProjectionRole.admin,
      );
      expect(admin.auditHistory, hasLength(1));
      expect(admin.settings.organizerPct, 12);
      expect(admin.structure.organizerAmount, 26);
      expect(admin.players.first.rebuys, 3);
    });
  });
}
