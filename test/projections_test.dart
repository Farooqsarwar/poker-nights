import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/services/projections.dart';

LiveGame _fixture() {
  const chipSet = <ChipColor>[
    ChipColor(color: 'white', hex: 0xFFF5F5F5, value: 1, quantity: 20),
    ChipColor(color: 'red', hex: 0xFFD32F2F, value: 5, quantity: 20),
    ChipColor(color: 'blue', hex: 0xFF1976D2, value: 10, quantity: 10),
  ];

  const settings = GameSettings(
    name: 'Friday Night Deepstack',
    date: '2026-08-28',
    time: '20:00',
    location: "Dave's Basement",
    players: 8,
    durationHours: 4,
    buyIn: 15,
    koEnabled: true,
    koAmount: 5,
    rebuys: true,
    rebuysCloseLevel: 6,
    reEntry: true,
    addOn: true,
    anteEnabled: false,
    anteAfterLevel: 8,
    organizerPct: 10,
    chipSet: chipSet,
    chipSetName: 'Standard Set',
    rebuyCost: 15,
    addOnCost: 15,
    locationPrivate: true,
  );

  const structure = TournamentStructure(
    startingStack: 10000,
    chipPlan: [
      ChipPlanEntry(color: 'white', hex: 0xFFF5F5F5, value: 1, count: 20),
      ChipPlanEntry(color: 'red', hex: 0xFFD32F2F, value: 5, count: 20),
      ChipPlanEntry(color: 'blue', hex: 0xFF1976D2, value: 10, count: 60),
    ],
    rebuyStack: 10000,
    rebuyChipPlan: [
      ChipPlanEntry(color: 'blue', hex: 0xFF1976D2, value: 10, count: 100),
    ],
    addOnStack: 10000,
    addOnChipPlan: [
      ChipPlanEntry(color: 'blue', hex: 0xFF1976D2, value: 10, count: 100),
    ],
    levels: [
      BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 20),
      BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 20),
    ],
    levelDuration: 20,
    expectedFinishMins: 240,
    prizes: [
      Prize(place: 1, amount: 90),
      Prize(place: 2, amount: 40),
      Prize(place: 3, amount: 20),
    ],
    prizePool: 150,
    organizerAmount: 15,
    colorUpInstructions: ['Colour up white chips at level 5'],
    warnings: [],
  );

  final players = [
    const Player(
      id: 'u1',
      name: 'Viewer One',
      isGuest: false,
      rsvp: Rsvp.going,
      checkedIn: true,
      confirmed: true,
      eliminated: false,
      rebuys: 2,
      reEntries: 1,
      hasAddOn: true,
      knockouts: 1,
      table: 1,
      seat: 3,
      active: true,
    ),
    const Player(
      id: 'u2',
      name: 'Player Two',
      isGuest: false,
      rsvp: Rsvp.goingPlus1,
      checkedIn: true,
      confirmed: true,
      eliminated: true,
      eliminationPos: 5,
      rebuys: 3,
      reEntries: 2,
      hasAddOn: true,
      knockouts: 2,
      table: 1,
      seat: 4,
      active: true,
    ),
    const Player(
      id: 'u3',
      name: 'Player Three',
      isGuest: false,
      checkedIn: true,
      confirmed: true,
      eliminated: false,
      rebuys: 1,
      hasAddOn: false,
      knockouts: 4,
      table: 2,
      seat: 1,
      active: true,
    ),
    const Player(
      id: 'g9',
      name: 'Guest of u2',
      isGuest: true,
      inviterId: 'u2',
      guestSlot: 1,
      checkedIn: true,
      confirmed: true,
      eliminated: false,
      rebuys: 1,
      hasAddOn: true,
      knockouts: 1,
      table: 2,
      seat: 2,
      active: true,
    ),
  ];

  final chat = [
    ChatMessage(
      id: 'c1',
      authorId: 'u1',
      authorName: 'Viewer One',
      body: 'Running late',
      timestamp: DateTime(2026, 8, 28, 19, 30),
      deleted: false,
    ),
    ChatMessage(
      id: 'c2',
      authorId: 'u2',
      authorName: 'Player Two',
      body: 'Bringing snacks',
      timestamp: DateTime(2026, 8, 28, 19, 45),
      deleted: false,
    ),
    ChatMessage(
      id: 'c3',
      authorId: 'u3',
      authorName: 'Player Three',
      body: 'See you there',
      timestamp: DateTime(2026, 8, 28, 19, 50),
      deleted: false,
      gameId: 'game-1',
    ),
  ];

  final auditHistory = [
    AuditRecord(
      id: 'a1',
      timestamp: DateTime(2026, 8, 24, 14, 5),
      type: 'edit',
      actor: 'admin',
      details: 'buy-in 15 -> 20',
    ),
    AuditRecord(
      id: 'a2',
      timestamp: DateTime(2026, 8, 24, 15, 0),
      type: 'publish',
      actor: 'system',
      details: 'game published',
    ),
  ];

  return LiveGame(
    id: 'game-1',
    groupId: 'group-1',
    settings: settings,
    structure: structure,
    status: LiveGameStatus.running,
    publicCode: 'AB12CD',
    tvCode: 'TV99XY',
    currentLevel: 2,
    timerRunning: true,
    secondsRemaining: 600,
    players: players,
    chat: chat,
    announcements: [
      Announcement(
        id: 'n1',
        text: 'Blinds going up in 10 minutes',
        timestamp: DateTime(2026, 8, 28, 20, 40),
      ),
    ],
    auditHistory: auditHistory,
    totalChipsInPlay: 55000,
    pendingGuests: [
      const Player(
        id: 'pending-g1',
        name: 'Walk-in Guest',
        isGuest: true,
        inviterId: 'u1',
        guestSlot: 2,
        checkedIn: false,
        confirmed: false,
        eliminated: false,
        rebuys: 0,
        hasAddOn: false,
        knockouts: 0,
        table: 0,
        seat: 0,
        active: false,
      ),
    ],
    finishOrder: const ['u2'],
    dealerPlayerId: 'u3',
    guestSlots: const [
      GuestSlot(
        id: 'slot-1',
        inviterId: 'u2',
        slot: 1,
        status: GuestSlotStatus.checkedIn,
        guestName: 'Guest of u2',
      ),
      GuestSlot(id: 'slot-2', inviterId: 'u1', slot: 1, status: GuestSlotStatus.unclaimed),
    ],
    originalLevels: const [
      BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 20),
      BlindLevel(level: 2, sb: 50, bb: 100, ante: null, durationMins: 20),
    ],
    rebuyRequests: const ['u1', 'u2'],
    addOnRequests: const ['u2'],
    changeLog: const ['2026-08-24 14:05 - buy-in 15 -> 20'],
  );
}

/// §23.2 TV privacy + §5.2 projections: private financial data, chat and
/// audit trails must never reach the TV/guest surface; the player projection
/// keeps the viewer's own rows visible; admin gets the full object.
void main() {
  group('tvProjection (TV privacy, §23.2)', () {
    final tv = projectionFor(_fixture(), GameProjectionRole.tv);
    final tvViaHelper = tvProjection(_fixture());

    test('strips organizer cut from settings and structure', () {
      expect(tv.settings.organizerPct, 0);
      expect(tv.structure.organizerAmount, 0);
    });

    test('zeroes every prize amount but preserves positions', () {
      expect(tv.structure.prizes.map((p) => p.place), [1, 2, 3]);
      for (final prize in tv.structure.prizes) {
        expect(prize.amount, 0, reason: 'prize place ${prize.place} leaked');
      }
    });

    test('keeps the public prize-pool total of 150', () {
      expect(tv.structure.prizePool, 150);
    });

    test('drops chat entirely', () {
      expect(tv.chat, isEmpty);
    });

    test('drops audit history entirely', () {
      expect(tv.auditHistory, isEmpty);
    });

    test('drops pending guests entirely', () {
      expect(tv.pendingGuests, isEmpty);
    });

    test('zeroes other players\u2019 private counters but keeps identities/seats', () {
      final byId = {for (final p in tv.players) p.id: p};
      expect(byId.length, 4);

      for (final p in tv.players) {
        expect(p.rebuys, 0, reason: '${p.id} rebuys leaked to TV');
        expect(p.reEntries, 0, reason: '${p.id} reEntries leaked to TV');
        expect(p.hasAddOn, isFalse, reason: '${p.id} add-on leaked to TV');
        expect(p.knockouts, 0, reason: '${p.id} knockouts leaked to TV');
      }

      // Non-financial fields survive so the TV can still render tables.
      expect(byId['u1']!.name, 'Viewer One');
      expect(byId['u1']!.table, 1);
      expect(byId['u2']!.eliminated, isTrue);
      expect(byId['g9']!.isGuest, isTrue);
    });

    test('preserves guestSlots for downstream claim UIs', () {
      expect(tv.guestSlots.length, 2);
      expect(tv.guestSlots[0].id, 'slot-1');
      expect(tv.guestSlots[0].guestName, 'Guest of u2');
      expect(tv.guestSlots[1].status, GuestSlotStatus.unclaimed);
      expect(tv.availableGuestSlots.length, 1);
    });

    test('keeps announcements visible on the TV feed', () {
      expect(tv.announcements.length, 1);
      expect(tv.announcements.first.text, contains('Blinds'));
    });

    test('helper function matches role-based call', () {
      expect(tvViaHelper.structure.prizePool, tv.structure.prizePool);
      expect(tvViaHelper.chat, isEmpty);
      expect(tvViaHelper.settings.organizerPct, 0);
    });
  });

  group('guestProjection (§23.2)', () {
    final guest = guestProjection(_fixture());

    test('strips organizer cut from settings and structure', () {
      expect(guest.settings.organizerPct, 0);
      expect(guest.structure.organizerAmount, 0);
    });

    test('zeroes every prize amount but preserves positions', () {
      expect(guest.structure.prizes.map((p) => p.place), [1, 2, 3]);
      expect(guest.structure.prizes.every((p) => p.amount == 0), isTrue);
    });

    test('keeps the public prize-pool total of 150', () {
      expect(guest.structure.prizePool, 150);
    });

    test('drops chat, audit history and pending guests', () {
      expect(guest.chat, isEmpty);
      expect(guest.auditHistory, isEmpty);
      expect(guest.pendingGuests, isEmpty);
    });

    test('zeroes every player\u2019s private counters (no viewer exemption)', () {
      for (final p in guest.players) {
        expect(p.rebuys, 0, reason: '${p.id} rebuys leaked to guest');
        expect(p.knockouts, 0, reason: '${p.id} knockouts leaked to guest');
        expect(p.hasAddOn, isFalse, reason: '${p.id} add-on leaked to guest');
        expect(p.reEntries, 0, reason: '${p.id} reEntries leaked to guest');
      }
    });

    test('preserves guestSlots', () {
      expect(guest.guestSlots.length, 2);
      expect(guest.guestSlots[0].inviterId, 'u2');
    });

    test('hides all rebuy/add-on requests from guests', () {
      expect(guest.rebuyRequests, isEmpty);
      expect(guest.addOnRequests, isEmpty);
    });
  });

  group('playerProjection(viewerId: \u0027u1\u0027)', () {
    final mine = playerProjection(_fixture(), viewerId: 'u1');

    test('preserves chat for members', () {
      expect(mine.chat.length, 3);
      expect(mine.chat[0].body, 'Running late');
      expect(mine.chat[2].gameId, 'game-1');
    });

    test('keeps the viewer\u2019s own row fully intact', () {
      final u1 = mine.players.firstWhere((p) => p.id == 'u1');
      expect(u1.rebuys, 2);
      expect(u1.reEntries, 1);
      expect(u1.knockouts, 1);
      expect(u1.hasAddOn, isTrue);
      expect(u1.name, 'Viewer One');
    });

    test('zeroes other players\u2019 private counters', () {
      final others = mine.players.where((p) => p.id != 'u1').toList();
      expect(others.length, 3);
      for (final p in others) {
        expect(p.rebuys, 0, reason: '${p.id} rebuys leaked to viewer');
        expect(p.reEntries, 0, reason: '${p.id} reEntries leaked to viewer');
        expect(p.knockouts, 0, reason: '${p.id} knockouts leaked to viewer');
        expect(p.hasAddOn, isFalse, reason: '${p.id} add-on leaked to viewer');
      }
    });

    test('filters request queues down to the viewer\u2019s own ids', () {
      expect(mine.rebuyRequests, ['u1']);
      expect(mine.addOnRequests, isEmpty);
    });

    test('strips organizer cut and individual prize amounts', () {
      expect(mine.settings.organizerPct, 0);
      expect(mine.structure.organizerAmount, 0);
      expect(mine.structure.prizes.every((p) => p.amount == 0), isTrue);
      expect(mine.structure.prizes.map((p) => p.place), [1, 2, 3]);
    });

    test('still hides chat-level secrets: no audit history or pending guests', () {
      expect(mine.auditHistory, isEmpty);
      expect(mine.pendingGuests, isEmpty);
    });

    test('keeps the public prize-pool total of 150', () {
      expect(mine.structure.prizePool, 150);
    });
  });

  group('admin projection', () {
    test('returns the identical full object', () {
      final game = _fixture();
      final admin = projectionFor(game, GameProjectionRole.admin);
      expect(identical(admin, game), isTrue);
    });

    test('exposes private fields untouched', () {
      final game = _fixture();
      final admin = projectionFor(game, GameProjectionRole.admin);
      expect(admin.settings.organizerPct, 10);
      expect(admin.structure.organizerAmount, 15);
      expect(admin.structure.prizes.map((p) => p.amount), [90, 40, 20]);
      expect(admin.chat.length, 3);
      expect(admin.auditHistory.length, 2);
      expect(admin.pendingGuests.length, 1);
      expect(admin.rebuyRequests, ['u1', 'u2']);
      expect(admin.addOnRequests, ['u2']);
    });
  });

  group('source immutability', () {
    test('projections never mutate the underlying game', () {
      final game = _fixture();
      projectionFor(game, GameProjectionRole.tv);
      guestProjection(game);
      playerProjection(game, viewerId: 'u1');

      expect(game.settings.organizerPct, 10);
      expect(game.structure.organizerAmount, 15);
      expect(game.structure.prizes.map((p) => p.amount), [90, 40, 20]);
      expect(game.chat.length, 3);
      expect(game.auditHistory.length, 2);
      expect(game.players.firstWhere((p) => p.id == 'u1').rebuys, 2);
      expect(game.players.firstWhere((p) => p.id == 'u2').knockouts, 2);
      expect(game.pendingGuests.length, 1);
      expect(game.rebuyRequests, ['u1', 'u2']);
    });
  });
}
