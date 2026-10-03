import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/payment_record.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
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
  // A2-1: the fixture must actually carry the flag, or the assertion below is
  // asserting a default rather than a scrub.
  addOnOvertime: true,
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
  // A2-1: u1 took theirs, u2 said no. Both halves must not travel.
  addOnDeclined: const ['u2'],
  // A game that ended on an agreed deal rather than by busts.
  dealAmounts: const [180.0, 120.0],
  payments: [
    PaymentRecord(
      id: 'pay-1',
      playerId: 'u1',
      purpose: PaymentPurpose.buyIn,
      amount: 20,
      status: PaymentStatus.paid,
      timestamp: DateTime.parse('2026-09-07T19:45:00.000'),
      idempotencyKey: 'k1',
    ),
    PaymentRecord(
      id: 'pay-2',
      playerId: 'u2',
      purpose: PaymentPurpose.rebuy,
      amount: 20,
      status: PaymentStatus.paid,
      timestamp: DateTime.parse('2026-09-07T20:15:00.000'),
      idempotencyKey: 'k2',
    ),
  ],
);

void main() {
  group('PN-013 — Spec E6 projection boundaries', () {
    for (final entry in {
      'player': projections.playerProjection(_game(), viewerId: 'u1'),
      'guest': projections.guestProjection(_game()),
      'tv': projections.tvProjection(_game()),
    }.entries) {
      test('${entry.key} projection hides add-ons and re-entries per Spec E6', () {
        for (final p in entry.value.players) {
          expect(p.reEntries, 0, reason: '${p.id} reEntries leaked');
          expect(p.hasAddOn, isFalse, reason: '${p.id} hasAddOn leaked');
        }
      });
    }

    test('rebuys and knockouts are preserved for standings per Spec E6', () {
      final me = projections
          .playerProjection(_game(), viewerId: 'u1')
          .players
          .firstWhere((p) => p.id == 'u1');
      expect(me.rebuys, 3);
      expect(me.knockouts, 4);
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
      // A2-1: who declined an add-on is per-person financial intent, and the
      // overtime flag says the host is behind on settlement. `projectionSafe()`
      // checks both as ZEROED, which is the convention for this payload -- the
      // game doc on `games/{gameId}` is the one that requires absence.
      expect(
        (map['addOnDeclined'] as List).length,
        0,
        reason: '$label: declined add-on identities present',
      );
      expect(
        (map['settings'] as Map)['addOnOvertime'],
        isFalse,
        reason: '$label: add-on overtime flag present',
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

    test('the rules actually enforce what this mirror checks', () {
      // The mirror above existed before the rules checked these two fields, so
      // a projection could have leaked a declined add-on or the overtime flag
      // with every test still green. These assertions exist to stop the two
      // drifting apart again.
      final rules = File('firestore.rules').readAsStringSync();
      final start = rules.indexOf('function projectionSafe(key)');
      expect(start, greaterThan(-1), reason: 'projectionSafe() is gone');
      final body = rules.substring(
        start,
        rules.indexOf('function publicProjectionsSafe()'),
      );

      expect(
        body,
        contains("payload.get('addOnDeclined', []).size() == 0"),
        reason: 'a declined add-on could reach a world-readable projection',
      );
      expect(
        body,
        contains("get('addOnOvertime', false) == false"),
        reason: 'the overtime flag could reach a world-readable projection',
      );
      // And they must stay ZEROED here. `publicGameDocSafe()` on
      // `games/{gameId}` uses absence, which is correct for that document --
      // but this payload is a fixed-key map, so an absence check would reject
      // every publish.
      expect(
        body,
        isNot(contains("hasAny(['addOnOvertime'])")),
        reason: 'absence is wrong for a fixed-key projection payload',
      );
    });

    test('the game doc still requires absence, the projection requires zero', () {
      // The two documents have different shapes and therefore different
      // conventions, and swapping them would either leak or break publishing.
      final rules = File('firestore.rules').readAsStringSync();
      final start = rules.indexOf('function publicGameDocSafe()');
      final body = rules.substring(
        start,
        rules.indexOf('function publicGameDocSafe()') + 4000,
      );
      expect(
        body,
        contains("hasAny(['addOnOvertime'])"),
        reason: 'the game doc is stripped by the client, so absence is enforceable',
      );
    });

    test('D2: the payout ladder is visible to everyone, organiser take is not', () {
      // D2: "Everyone - players, guests, the TV - sees the prize pool and the
      // payouts. Only the host's organiser contribution stays hidden." The
      // organiser's amount is checked as zero by every Firestore rule above,
      // and stays zeroed here; the ladder itself must survive to the wire.
      final ladder = _game().structure.prizes;
      expect(ladder, isNotEmpty, reason: 'fixture needs a real ladder');

      for (final entry in {
        'tv': projections.tvProjection(_game()),
        'player': projections.playerProjection(_game(), viewerId: 'u1'),
        'guest': projections.guestProjection(_game()),
      }.entries) {
        expect(
          entry.value.structure.prizes.map((p) => p.amount),
          ladder.map((p) => p.amount),
          reason: '${entry.key}: every player sees every paid place',
        );
        final map = liveGameToMap(entry.value);
        expect(
          (map['structure'] as Map)['organizerAmount'],
          0,
          reason: '${entry.key}: organiser contribution still hidden',
        );
        expect(
          (map['structure'] as Map)['prizes'] as List,
          isNotEmpty,
          reason: '${entry.key}: ladder must actually reach Firestore',
        );
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

  group('section 23 — the payment ledger never leaves the host', () {
    // The player rows are already scrubbed of rebuys, re-entries and add-ons
    // because section 23 forbids members seeing "rebuy/add-on totals". The
    // ledger hands all three back — plus "gross collected" — to anybody who
    // sums it, which would defeat that scrubbing entirely.
    for (final entry in {
      'guest': projections.guestProjection(_game()),
      'tv': projections.tvProjection(_game()),
    }.entries) {
      test('${entry.key} receives no payment records', () {
        expect(
          entry.value.payments,
          isEmpty,
          reason: 'summing the ledger yields rebuy totals, add-on totals and '
              'gross collected — every one of them named in section 23 as '
              'hidden from members and guests',
        );
      });

      test('${entry.key} cannot derive the gross', () {
        expect(entry.value.totalCollected, 0);
        expect(entry.value.collected(PaymentPurpose.rebuy), 0);
        expect(entry.value.collected(PaymentPurpose.addOn), 0);
      });

      test('${entry.key} is not told who has paid', () {
        expect(entry.value.hasPaid('u1', PaymentPurpose.buyIn), isFalse);
      });
    }

    test('player receives only own payment records per Spec E6', () {
      final projected = projections.playerProjection(_game(), viewerId: 'u1');
      expect(projected.payments.length, 1);
      expect(projected.payments.first.playerId, 'u1');
      expect(projected.hasPaid('u2', PaymentPurpose.rebuy), isFalse);
    });

    test('the ledger survives serialization for the host', () {
      // Stripping it from the projection must not mean losing it on the way
      // to storage — the host's own copy carries the records.
      final back = liveGameFromMap(liveGameToMap(_game()));
      expect(back.payments, hasLength(2));
      expect(back.totalCollected, 40);
    });

    test('the deal survives serialization for the host', () {
      final back = liveGameFromMap(liveGameToMap(_game()));
      expect(back.dealAmounts, [180.0, 120.0]);
    });
  });

  group('C-deal - agreed amounts stay with the host', () {
    // The payout LADDER is public ("everyone sees the prize pool and the
    // payouts"). What each named person actually received is not, and this
    // is the same decision the results screen makes when it gates individual
    // amounts behind `showAmounts = app.isAdmin`.
    for (final role in [
      projections.GameProjectionRole.player,
      projections.GameProjectionRole.guest,
      projections.GameProjectionRole.tv,
    ]) {
      test('${role.name} receives no agreed amounts', () {
        final projected = projections.projectionFor(_game(), role);
        expect(
          projected.dealAmounts,
          isNull,
          reason: 'the deal is what each named person was actually paid, which '
              'is the host-only figure — not the public ladder',
        );
      });
    }

    test('clearing a deal is possible, and a game without one is null', () {
      // `dealAmounts: null` alone cannot express "remove it" — a null
      // parameter means "keep what is there" — so the clear flag is what the
      // projection relies on, and it is worth pinning.
      final cleared = _game().copyWith(clearDealAmounts: true);
      expect(cleared.dealAmounts, isNull);

      // A night that ended by busts never had a deal in the first place, and
      // must read as absent rather than as an empty list: an empty list would
      // claim the table agreed a deal that paid nobody.
      final byBusts = _game().copyWith(clearDealAmounts: true);
      expect(byBusts.dealAmounts, isNull);
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
      expect(admin.payments, hasLength(2));
      expect(admin.totalCollected, 40);
      expect(admin.dealAmounts, [180.0, 120.0]);
    });
  });

  group('structural GameSettings fields ride through to every role', () {
    // `publicSettings` used to be a manual `GameSettings(...)` reconstruction
    // naming every field individually — anything NOT named silently dropped
    // to null/default for every non-admin viewer. `format` was the field that
    // got caught doing this. The fix (`game.settings.copyWith(...)`, only
    // naming the two genuinely private fields) makes that whole bug class
    // structural rather than a list someone has to remember to update, so
    // this test picks fields spanning the file's whole history — one from
    // day one (`breaks`), one from a recent round (`pace`), and the
    // one that actually broke (`format`) — rather than re-testing the same
    // field three times.
    final withStructuralFields = _game().copyWith(
      settings: _settings.copyWith(
        format: TournamentFormat.shootout,
        shootoutTables: 3,
        breaks: const [ScheduledBreak(afterLevel: 4, durationMins: 10)],
        pace: PaceMode.deep,
        levelDurationMins: 20,
      ),
    );

    for (final role in [
      projections.GameProjectionRole.player,
      projections.GameProjectionRole.guest,
      projections.GameProjectionRole.tv,
    ]) {
      test('${role.name}: format/breaks/pace/levelDurationMins survive', () {
        final projected =
            projections.projectionFor(withStructuralFields, role);
        expect(projected.settings.format, TournamentFormat.shootout);
        expect(projected.settings.shootoutTables, 3);
        expect(projected.settings.breaks, hasLength(1));
        expect(projected.settings.pace, PaceMode.deep);
        expect(projected.settings.levelDurationMins, 20);
      });

      test('${role.name}: organizerPct and forcePaidPlaces are still stripped', () {
        final withPrivateFields = _game().copyWith(
          settings: _settings.copyWith(forcePaidPlaces: 4),
        );
        final projected = projections.projectionFor(withPrivateFields, role);
        expect(projected.settings.organizerPct, 0);
        expect(projected.settings.forcePaidPlaces, isNull);
      });
    }
  });
}
