import '../models/app_notification.dart';
import '../models/cash_game.dart';
import '../models/chip_color.dart';
import '../models/game.dart';
import '../models/group.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../models/user.dart';
import '../utils/tournament_engine.dart';

/// Static demo data mirroring the web app's seed data. UI only.
class MockData {
  MockData._();

  static const demoUser = AppUser(
    id: 'u1',
    name: 'Daniel',
    email: 'daniel@example.com',
    isAdmin: true,
    stats: UserStats(played: 14, wins: 3, podium: 7, avgFinish: 2.8, knockouts: 22),
  );

  static const members = <AppUser>[
    demoUser,
    AppUser(
      id: 'u2',
      name: 'Sarah',
      email: 'sarah@example.com',
      isAdmin: false,
      stats: UserStats(played: 12, wins: 2, podium: 5, avgFinish: 3.1, knockouts: 18),
    ),
    AppUser(
      id: 'u3',
      name: 'Marcus',
      email: 'marcus@example.com',
      isAdmin: false,
      stats: UserStats(played: 10, wins: 1, podium: 4, avgFinish: 3.6, knockouts: 12),
    ),
    AppUser(
      id: 'u4',
      name: 'Elena',
      email: 'elena@example.com',
      isAdmin: false,
      stats: UserStats(played: 11, wins: 2, podium: 6, avgFinish: 2.9, knockouts: 15),
    ),
    AppUser(
      id: 'u5',
      name: 'James',
      email: 'james@example.com',
      isAdmin: false,
      stats: UserStats(played: 9, wins: 0, podium: 3, avgFinish: 4.2, knockouts: 8),
    ),
    AppUser(
      id: 'u6',
      name: 'Priya',
      email: 'priya@example.com',
      isAdmin: false,
      stats: UserStats(played: 13, wins: 4, podium: 8, avgFinish: 2.4, knockouts: 25),
    ),
  ];

  static const defaultChipSet = <ChipColor>[
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
    ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 60),
    ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 40),
  ];

  static GameSettings get demoSettings => const GameSettings(
        name: 'Friday Poker',
        date: '2026-08-07',
        time: '20:00',
        location: "Daniel's Place",
        players: 8,
        durationHours: 3.5,
        buyIn: 15,
        koEnabled: false,
        koAmount: 0,
        rebuys: true,
        rebuysCloseLevel: 6,
        addOn: true,
        anteEnabled: true,
        anteAfterLevel: 6,
        organizerPct: 10,
        chipSet: defaultChipSet,
        chipSetName: 'Standard 500',
      );

  static TournamentStructure get demoStructure => TournamentEngine.generate(
        const TournamentParams(
          players: 8,
          durationHours: 3.5,
          buyIn: 15,
          chipSet: defaultChipSet,
          rebuys: true,
          rebuysCloseLevel: 6,
          addOn: true,
          anteEnabled: true,
          anteAfterLevel: 6,
          koEnabled: false,
          koAmount: 0,
          organizerPct: 10,
        ),
      );

  static List<Player> get demoPlayers => const [
        Player(
          id: 'u1', name: 'Daniel', isGuest: false, rsvp: Rsvp.goingPlus2,
          checkedIn: true, confirmed: true, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 1, seat: 1, active: true,
        ),
        Player(
          id: 'u2', name: 'Sarah', isGuest: false, rsvp: Rsvp.going,
          checkedIn: true, confirmed: true, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 1, seat: 2, active: true,
        ),
        Player(
          id: 'u3', name: 'Marcus', isGuest: false, rsvp: Rsvp.goingPlus1,
          checkedIn: true, confirmed: true, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 1, seat: 3, active: true,
        ),
        Player(
          id: 'u4', name: 'Elena', isGuest: false, rsvp: Rsvp.going,
          checkedIn: true, confirmed: true, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 1, seat: 4, active: true,
        ),
        Player(
          id: 'u5', name: 'James', isGuest: false, rsvp: Rsvp.going,
          checkedIn: true, confirmed: true, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 1, seat: 5, active: true,
        ),
        Player(
          id: 'u6', name: 'Priya', isGuest: false, rsvp: Rsvp.going,
          checkedIn: true, confirmed: true, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 1, seat: 6, active: true,
        ),
        Player(
          id: 'g1', name: "Marcus's Guest", isGuest: true, inviterId: 'u3',
          guestSlot: 1, rsvp: Rsvp.going,
          checkedIn: false, confirmed: false, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 1, seat: 7, active: true,
        ),
        Player(
          id: 'g2', name: '', isGuest: true, inviterId: 'u3', guestSlot: 2,
          rsvp: null, checkedIn: false, confirmed: false, eliminated: false,
          rebuys: 0, hasAddOn: false, knockouts: 0, table: 0, seat: 0, active: false,
        ),
      ];

  static LiveGame get demoGame => LiveGame(
        id: 'g1',
        groupId: 'grp1',
        settings: demoSettings,
        structure: demoStructure,
        status: LiveGameStatus.checkin,
        publicCode: 'FP2608',
        tvCode: 'TV-FP',
        currentLevel: 1,
        timerRunning: false,
        secondsRemaining: 15 * 60,
        players: demoPlayers,
        chat: [
          ChatMessage(
            id: 'cm1', authorId: 'u2', authorName: 'Sarah',
            body: "Can't wait for tonight! 🃏",
            timestamp: _chatTime1, deleted: false,
          ),
          ChatMessage(
            id: 'cm2', authorId: 'u6', authorName: 'Priya',
            body: 'Bringing snacks 👌',
            timestamp: _chatTime2, deleted: false,
          ),
          ChatMessage(
            id: 'cm3', authorId: 'u3', authorName: 'Marcus',
            body: 'My friend is coming too — sent them the code',
            timestamp: _chatTime3, deleted: false,
          ),
        ],
        announcements: const [],
        totalChipsInPlay: demoStructure.startingStack * 8,
        pendingGuests: const [],
        finishOrder: const [],
        speedRecommendation: null,
      );

  static final _chatTime1 = DateTime.utc(2026, 8, 5, 18, 0);
  static final _chatTime2 = DateTime.utc(2026, 8, 5, 18, 30);
  static final _chatTime3 = DateTime.utc(2026, 8, 5, 18, 45);

  static List<LiveGame> get demoPastGames {
    final base = demoGame;
    final players1 = List<Player>.generate(6, (i) {
      final p = base.players[i];
      final eliminated = i < 5;
      return p.copyWith(
        eliminated: eliminated,
        eliminationPos: eliminated ? 6 - i : null,
      );
    });
    final players2 = List<Player>.from(base.players);
    return [
      base.copyWith(
        id: 'pg1',
        settings: GameSettings(
          name: 'Monthly Championship',
          date: '2026-07-04',
          time: base.settings.time,
          location: base.settings.location,
          players: base.settings.players,
          durationHours: base.settings.durationHours,
          buyIn: base.settings.buyIn,
          koEnabled: base.settings.koEnabled,
          koAmount: base.settings.koAmount,
          rebuys: base.settings.rebuys,
          rebuysCloseLevel: base.settings.rebuysCloseLevel,
          addOn: base.settings.addOn,
          anteEnabled: base.settings.anteEnabled,
          anteAfterLevel: base.settings.anteAfterLevel,
          anteStyle: base.settings.anteStyle,
          organizerPct: base.settings.organizerPct,
          chipSet: base.settings.chipSet,
          chipSetName: base.settings.chipSetName,
        ),
        status: LiveGameStatus.completed,
        publicCode: 'MC0704',
        tvCode: 'TV-MC',
        currentLevel: 12,
        timerRunning: false,
        secondsRemaining: 0,
        players: players1,
        announcements: const [],
        totalChipsInPlay: 0,
        finishOrder: const ['u6', 'u1', 'u4', 'u2', 'u3', 'u5'],
      ),
      base.copyWith(
        id: 'pg2',
        settings: GameSettings(
          name: 'Friday Poker',
          date: '2026-06-13',
          time: base.settings.time,
          location: base.settings.location,
          players: base.settings.players,
          durationHours: base.settings.durationHours,
          buyIn: base.settings.buyIn,
          koEnabled: base.settings.koEnabled,
          koAmount: base.settings.koAmount,
          rebuys: base.settings.rebuys,
          rebuysCloseLevel: base.settings.rebuysCloseLevel,
          addOn: base.settings.addOn,
          anteEnabled: base.settings.anteEnabled,
          anteAfterLevel: base.settings.anteAfterLevel,
          anteStyle: base.settings.anteStyle,
          organizerPct: base.settings.organizerPct,
          chipSet: base.settings.chipSet,
          chipSetName: base.settings.chipSetName,
        ),
        status: LiveGameStatus.completed,
        publicCode: 'FP1306',
        tvCode: 'TV-FP2',
        currentLevel: 10,
        timerRunning: false,
        secondsRemaining: 0,
        players: players2,
        announcements: const [],
        totalChipsInPlay: 0,
        finishOrder: const ['u1', 'u4', 'u2', 'u6', 'u5', 'u3'],
      ),
    ];
  }

  static List<Poll> get demoPolls => [
        Poll(
          id: 'p1',
          question: 'What buy-in for August?',
          options: ['10', '15', '20', '25'],
          votes: {'u1': '15', 'u2': '15', 'u3': '20', 'u4': '15', 'u6': '20'},
          closed: false,
          createdAt: _pollCreated,
        ),
      ];

  static final _pollCreated = DateTime.utc(2026, 8, 4, 18, 0);

  static List<AppNotification> get demoNotifications => [
        AppNotification(
          id: 'n1',
          title: 'RSVP Open',
          body: 'Friday Poker is open for RSVP',
          type: NotificationType.invite,
          link: '/invitation',
          read: false,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        AppNotification(
          id: 'n2',
          title: 'New poll',
          body: 'New poll: What buy-in for August?',
          type: NotificationType.chat,
          link: '/group',
          read: false,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
        AppNotification(
          id: 'n3',
          title: 'Guest check-in request',
          body: "Marcus's Guest has requested check-in",
          type: NotificationType.admin,
          link: '/check-in',
          read: true,
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
        AppNotification(
          id: 'n4',
          title: 'Tournament result',
          body: 'Monthly Championship is complete — view results',
          type: NotificationType.result,
          link: '/result-podium',
          read: true,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

  static Group get demoGroup {
    final game = demoGame;
    return Group(
      id: 'grp1',
      name: 'Friday Poker Club',
      joinCode: 'FRIDAY7',
      ownerId: 'u1',
      members: members,
      games: [game, ...demoPastGames],
      chat: game.chat,
      polls: demoPolls,
      notifications: demoNotifications,
      icon: '♠️',
      pinned: true,
    );
  }

  /// A second group used to exercise the multi-group sidebar (my groups list).
  static Group get demoGroup2 {
    final game = demoGame;
    return Group(
      id: 'grp2',
      name: 'Weekend Crew',
      joinCode: 'WEEKEND1',
      ownerId: 'u2',
      members: [members[1], members[3], members[5]],
      games: [game.copyWith(id: 'g1-copy', groupId: 'grp2')],
      chat: const [],
      polls: const [],
      notifications: const [],
      icon: '🃏',
      pinned: false,
    );
  }

  /// Demo cash game session data.
  static CashSessionSettings get cashSettings => const CashSessionSettings(
        name: 'Friday Cash Game',
        date: '2026-08-05',
        location: "Daniel's place",
        smallBlind: 1,
        bigBlind: 2,
        minBuyIn: 20,
        maxBuyIn: 200,
        currency: r'$',
        maxPlayers: 10,
        rakePct: 0,
      );

  static CashPlayer get _cashPlayer1 => const CashPlayer(
        id: 'cp-0',
        name: 'Daniel',
        stack: 20,
        totalBuyIns: 20,
        buyInCount: 1,
        cashedOut: 0,
      );

  static CashPlayer get _cashPlayer2 => const CashPlayer(
        id: 'cp-1',
        name: 'Marcus',
        stack: 20,
        totalBuyIns: 20,
        buyInCount: 1,
        cashedOut: 0,
      );

  static CashPlayer get _cashPlayer3 => const CashPlayer(
        id: 'cp-2',
        name: 'Sophia',
        stack: 20,
        totalBuyIns: 20,
        buyInCount: 1,
        cashedOut: 0,
      );

  static CashSession get demoCashSession => CashSession(
        id: 'cash-1',
        settings: cashSettings,
        isCompleted: false,
        startTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 24)),
        players: [_cashPlayer1, _cashPlayer2, _cashPlayer3],
      );
}
