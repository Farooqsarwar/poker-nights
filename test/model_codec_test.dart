import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/app_notification.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_preset.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/utils/model_codec.dart';

const _t0 = '2026-08-20T18:00:00.000';

LiveGame _fixture() {
  const structure = TournamentStructure(
    startingStack: 5000,
    chipPlan: [ChipPlanEntry(color: 'white', hex: 0xFFFFFFFF, value: 25, count: 8)],
    rebuyStack: 3000,
    rebuyChipPlan: [],
    addOnStack: 2000,
    addOnChipPlan: [
      ChipPlanEntry(color: 'green', hex: 0xFF00FF00, value: 100, count: 4),
    ],
    levels: [
      BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
      BlindLevel(level: 2, sb: 50, bb: 100, ante: 50, durationMins: 20),
    ],
    levelDuration: 15,
    expectedFinishMins: 210,
    prizes: [Prize(place: 1, amount: 100), Prize(place: 2, amount: 50)],
    prizePool: 150,
    organizerAmount: 15,
    colorUpInstructions: ['Race off white chips at L5'],
    warnings: ['Short stack warning'],
  );
  const settings = GameSettings(
    name: 'Friday Night',
    date: '2026-08-21',
    time: '19:00',
    location: 'Mike\'s basement',
    players: 6,
    durationHours: 3.5,
    buyIn: 15,
    koEnabled: true,
    koAmount: 5,
    rebuys: true,
    rebuysCloseLevel: 6,
    rebuyLimit: 2,
    reEntry: true,
    addOn: true,
    addOnCloseLevel: 6,
    anteEnabled: true,
    anteAfterLevel: 3,
    anteStyle: AnteStyle.bigBlind,
    antePreference: AntePreference.recommend,
    organizerPct: 10,
    chipSet: [
      ChipColor(color: 'white', hex: 0xFFFFFFFF, value: 25, quantity: 100),
    ],
    chipSetName: 'Home Set',
    announceEliminations: true,
    forcePaidPlaces: 2,
    rebuyCost: 10,
    addOnCost: 12,
    locationPrivate: true,
  );
  return LiveGame(
    id: 'game-1',
    groupId: 'grp-1',
    settings: settings,
    structure: structure,
    status: LiveGameStatus.running,
    publicCode: 'ABC123',
    tvCode: 'TV789',
    currentLevel: 2,
    timerRunning: true,
    secondsRemaining: 600,
    players: const [
      Player(
        id: 'u1',
        name: 'Alice',
        isGuest: false,
        rsvp: Rsvp.goingPlus2,
        checkedIn: true,
        confirmed: true,
        eliminated: false,
        eliminationPos: null,
        rebuys: 1,
        reEntries: 0,
        hasAddOn: false,
        knockouts: 2,
        table: 1,
        seat: 3,
        active: true,
      ),
      Player(
        id: 'g9',
        name: 'Bob (guest)',
        isGuest: true,
        inviterId: 'u1',
        guestSlot: 2,
        rsvp: Rsvp.going,
        checkedIn: false,
        confirmed: false,
        eliminated: true,
        eliminationPos: 5,
        rebuys: 0,
        reEntries: 1,
        hasAddOn: true,
        knockouts: 0,
        table: 0,
        seat: 0,
        active: false,
      ),
    ],
    chat: [
      ChatMessage(
        id: 'msg-1',
        authorId: 'u1',
        authorName: 'Alice',
        body: 'Who is in?',
        timestamp: DateTime.parse(_t0),
        deleted: false,
        pinned: true,
        gameId: 'game-1',
      ),
    ],
    announcements: [
      Announcement(
        id: 'ann-1',
        text: 'Tournament starts.',
        timestamp: DateTime.parse(_t0),
      ),
    ],
    auditHistory: [
      AuditRecord(
        id: 'audit-1',
        timestamp: DateTime.parse(_t0),
        type: 'publish',
        actor: 'Alice',
        details: 'Published Friday Night.',
      ),
    ],
    totalChipsInPlay: 33000,
    pendingGuests: const [
      Player(
        id: 'g9',
        name: 'Bob (guest)',
        isGuest: true,
        inviterId: 'u1',
        guestSlot: 2,
        rsvp: Rsvp.going,
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
    finishOrder: const ['g9', 'u1'],
    speedRecommendation: SpeedRecommendation.slowDown,
    settlementConfirmed: true,
    seatingConfirmed: true,
    checkInClosed: true,
    structureConfirmed: true,
    dealerPlayerId: 'u1',
    guestSlots: const [
      GuestSlot(
        id: 'slot-1',
        inviterId: 'u1',
        slot: 1,
        guestName: 'Carl',
        status: GuestSlotStatus.checkedIn,
      ),
      GuestSlot(
        id: 'slot-2',
        inviterId: 'u1',
        slot: 2,
        guestName: null,
        status: GuestSlotStatus.unclaimed,
      ),
    ],
    originalLevels: const [
      BlindLevel(level: 1, sb: 25, bb: 50, ante: null, durationMins: 15),
    ],
    rebuyRequests: const ['u1'],
    addOnRequests: const ['g9'],
    levelEndTime: DateTime.parse('2026-08-21T19:15:00.000'),
  );
}

void main() {
  group('liveGame codec', () {
    test('map round-trip preserves every field', () {
      final game = _fixture();
      final map = liveGameToMap(game);
      final restored = liveGameFromMap(map);
      expect(liveGameToMap(restored), map);

      // Spot-check decoded values that have no operator==.
      expect(restored.status, LiveGameStatus.running);
      expect(restored.players[1].rsvp, Rsvp.going);
      expect(restored.players[0].eliminationPos, isNull);
      expect(restored.chat.first.gameId, 'game-1');
      expect(restored.chat.first.timestamp, DateTime.parse(_t0));
      expect(restored.auditHistory.single.type, 'publish');
      expect(restored.checkInClosed, isTrue);
      expect(restored.structureConfirmed, isTrue);
      expect(restored.rebuyRequests, ['u1']);
      expect(restored.addOnRequests, ['g9']);
      expect(restored.levelEndTime, DateTime.parse('2026-08-21T19:15:00.000'));
      expect(restored.settings.rebuyLimit, 2);
      expect(restored.settings.durationHours, 3.5);
      expect(restored.structure.levels[1].ante, 50);
      expect(restored.guestSlots[1].status, GuestSlotStatus.unclaimed);
      expect(restored.speedRecommendation, SpeedRecommendation.slowDown);
    });

    test('nullable fields survive a round-trip', () {
      final map = liveGameToMap(_fixture());
      // Strip every optional field on the wire format to simulate a minimal
      // game document (the model's copyWith cannot null-out fields).
      void strip(String key) => map[key] = null;
      strip('speedRecommendation');
      strip('dealerPlayerId');
      strip('originalLevels');
      strip('levelEndTime');
      map['rebuyRequests'] = <String>[];
      map['addOnRequests'] = <String>[];
      final settings = Map<String, dynamic>.from(map['settings'] as Map)
        ..['forcePaidPlaces'] = null
        ..['rebuyCost'] = null
        ..['addOnCost'] = null
        ..['rebuyLimit'] = null;
      map['settings'] = settings;

      final restored = liveGameFromMap(map);
      expect(liveGameToMap(restored), map);
      expect(restored.speedRecommendation, isNull);
      expect(restored.dealerPlayerId, isNull);
      expect(restored.originalLevels, isNull);
      expect(restored.levelEndTime, isNull);
      expect(restored.settings.forcePaidPlaces, isNull);
      expect(restored.settings.rebuyCost, isNull);
    });

    test('history lists are capped keeping the newest entries', () {
      var game = _fixture();
      final extraAnnouncements = List.generate(
        kMaxEncodedAnnouncements + 50,
        (i) => Announcement(id: 'a$i', text: 'm$i', timestamp: DateTime.now()),
      );
      final extraAudit = List.generate(
        kMaxEncodedAuditRecords + 50,
        (i) => AuditRecord(
          id: 'r$i',
          timestamp: DateTime.now(),
          type: 'x',
          actor: 'a',
          details: 'd$i',
        ),
      );
      game = game.copyWith(
        announcements: [...game.announcements, ...extraAnnouncements],
        auditHistory: [...game.auditHistory, ...extraAudit],
      );
      final map = liveGameToMap(game);
      expect((map['announcements'] as List).length, kMaxEncodedAnnouncements);
      expect((map['auditHistory'] as List).length, kMaxEncodedAuditRecords);
      // Newest entry must be the last encoded one.
      expect(
        ((map['announcements'] as List).last as Map)['text'],
        'm${extraAnnouncements.length - 1}',
      );
    });

    test('unknown enum strings fall back safely', () {
      final map = liveGameToMap(_fixture());
      map['status'] = 'not-a-status';
      map['speedRecommendation'] = 'nope';
      (map['players'] as List).first['rsvp'] = 'bogus';
      final restored = liveGameFromMap(map);
      expect(restored.status, LiveGameStatus.draft);
      expect(restored.players.first.rsvp, Rsvp.maybe);
    });

    test('guest slot checkInRequested status round-trips by name', () {
      const slot = GuestSlot(
        id: 'slot-3',
        inviterId: 'u1',
        slot: 3,
        guestName: null,
        status: GuestSlotStatus.checkInRequested,
      );
      final map = guestSlotToMap(slot);
      expect(map['status'], 'checkInRequested');
      final restored = guestSlotFromMap(map);
      expect(restored.status, GuestSlotStatus.checkInRequested);
      expect(guestSlotToMap(restored), map);

      // And through the embedded LiveGame wire format.
      final gameMap = liveGameToMap(_fixture());
      (gameMap['guestSlots'] as List).first['status'] =
          GuestSlotStatus.checkInRequested.name;
      expect(
        liveGameFromMap(gameMap).guestSlots.first.status,
        GuestSlotStatus.checkInRequested,
      );
    });

    test('unknown guest slot status string falls back to unclaimed', () {
      final map = guestSlotToMap(_fixture().guestSlots.first)
        ..['status'] = 'not-a-status';
      expect(guestSlotFromMap(map).status, GuestSlotStatus.unclaimed);
    });

    test('firestore doc variant keeps player ordering', () {
      final game = _fixture();
      final doc = liveGameToFirestoreDoc(game);
      expect(doc['players'], isA<Map>());

      // Simulate Firestore key-ordering instability by reversing insertion.
      final players = Map<String, dynamic>.from(doc['players'] as Map);
      doc['players'] = players.entries.toList().reversed.fold<Map<String, dynamic>>({}, (m, e) => m..[e.key] = e.value);

      final restored = liveGameFromFirestoreDoc(doc);
      expect(
        restored.players.map((p) => p.id).toList(),
        game.players.map((p) => p.id).toList(),
      );
      expect(
        restored.pendingGuests.map((p) => p.id).toList(),
        game.pendingGuests.map((p) => p.id).toList(),
      );
      // And the full payload still matches the plain-map representation.
      expect(liveGameToMap(restored), liveGameToMap(game));
    });
  });

  group('cash session codec', () {
    test('round-trips with double precision', () {
      const settings = CashSessionSettings(
          name: 'Home cash',
          date: '2026-08-21',
          location: 'Den',
          smallBlind: 0.5,
          bigBlind: 1,
          minBuyIn: 20,
          maxBuyIn: 100,
          currency: '',
          maxPlayers: 9,
          rakePct: 2.5);
      final session = CashSession(
        id: 'cash-1',
        settings: settings,
        isCompleted: true,
        startTime: DateTime.parse(_t0),
        players: [
          CashPlayer(
            id: 'cp-1',
            name: 'Dan',
            stack: 12.5,
            totalBuyIns: 40,
            buyInCount: 2,
            cashedOut: 52.5,
          ),
        ],
        unresolvedNote: 'Chips on the table',
      );
      final restored = cashSessionFromMap(cashSessionToMap(session));
      expect(cashSessionToMap(restored), cashSessionToMap(session));
      expect(restored.players.single.stack, 12.5);
      expect(restored.settings.rakePct, 2.5);
    });
  });

  group('preset / notification / poll / group codecs', () {
    test('tournament preset round-trip', () {
      const preset = TournamentPreset(
        id: 'pr-1',
        name: 'Deep Stack',
        buyIn: 25,
        koEnabled: true,
        koAmount: 10,
        rebuys: false,
        rebuysCloseLevel: 5,
        reEntry: false,
        addOn: false,
        durationHours: 5,
        anteEnabled: true,
        anteAfterLevel: 5,
        organizerPct: 0,
        chipSetName: 'Standard 500',
        chipSet: [ChipColor(color: 'red', hex: 0xFFFF0000, value: 5, quantity: 100)],
        rebuyCost: null,
        addOnCost: 30,
      );
      final restored =
          tournamentPresetFromMap(tournamentPresetToMap(preset));
      expect(tournamentPresetToMap(restored), tournamentPresetToMap(preset));
    });

    test('notification round-trip', () {
      final n = AppNotification(
        id: 'n-1',
        title: 'Check-in open',
        body: 'Check in now',
        type: NotificationType.game,
        link: '/invitation',
        read: false,
        timestamp: DateTime.parse(_t0),
      );
      final restored =
          appNotificationFromMap(appNotificationToMap(n));
      expect(appNotificationToMap(restored), appNotificationToMap(n));
    });

    test('poll votes map round-trip', () {
      final poll = Poll(
        id: 'poll-1',
        question: 'What buy-in?',
        options: const ['10', '15', '25'],
        votes: const {
          'u1': ['15'],
          'u2': ['15', '25'],
        },
        closed: false,
        createdAt: DateTime.parse(_t0),
        multi: true,
      );
      final restored = pollFromMap(pollToMap(poll));
      expect(pollToMap(restored), pollToMap(poll));
      expect(restored.optionCounts()['15'], 2);
    });

    test('group round-trip embeds nested models', () {
      final group = Group(
        id: 'grp-1',
        name: 'Friday Club',
        joinCode: 'JOIN1',
        ownerId: 'u1',
        members: const [
          AppUser(
            id: 'u1',
            name: 'Alice',
            email: 'a@x.io',
            isAdmin: true,
            stats: UserStats(played: 3, wins: 1, podium: 2, avgFinish: 2.5, knockouts: 7),
          ),
        ],
        games: [_fixture()],
        chat: [
          ChatMessage(
            id: 'm1',
            authorId: 'u1',
            authorName: 'Alice',
            body: 'hi',
            timestamp: DateTime.parse(_t0),
            deleted: false,
          ),
        ],
        polls: const [],
        notifications: const [],
        icon: '🃏',
        pinned: true,
      );
      final restored = groupFromMap(groupToMap(group));
      expect(groupToMap(restored), groupToMap(group));
      expect(restored.games.single.id, 'game-1');
      expect(restored.members.single.stats.avgFinish, 2.5);
    });

    test('user stats round-trip', () {
      const user = AppUser(
        id: 'u1',
        name: 'Alice',
        email: 'a@x.io',
        isAdmin: false,
        stats: UserStats(played: 1, wins: 0, podium: 1, avgFinish: 1, knockouts: 0),
      );
      final restored = appUserFromMap(appUserToMap(user));
      expect(appUserToMap(restored), appUserToMap(user));
    });
  });
}
