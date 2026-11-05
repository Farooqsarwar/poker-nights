import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/shell/standings_screen.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:provider/provider.dart';

const _chips = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
];

const _settings = GameSettings(
  name: 'Friday Poker Night',
  date: '2026-11-01',
  time: '20:00',
  location: 'Kitchen table',
  players: 6,
  durationHours: 4,
  buyIn: 20,
  chipSet: _chips,
  chipSetName: 'Standard 200',
  koEnabled: false,
  koAmount: 0,
  rebuys: false,
  rebuysCloseLevel: 6,
  addOn: false,
  anteEnabled: false,
  anteAfterLevel: 7,
  organizerPct: 10,
);

const _structure = TournamentStructure(
  startingStack: 1000,
  chipPlan: [],
  rebuyStack: 1000,
  rebuyChipPlan: [],
  addOnStack: 1000,
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

const _host = AppUser(
  id: 'u1',
  name: 'Alex Morgan',
  email: 'alex@poker.night',
  isAdmin: true,
  stats: UserStats(played: 1, wins: 1, podium: 1, avgFinish: 1, knockouts: 2),
);

const _member = AppUser(
  id: 'u2',
  name: 'Bob Ross',
  email: 'bob@poker.night',
  isAdmin: false,
  stats: UserStats(played: 1, wins: 0, podium: 1, avgFinish: 2, knockouts: 0),
);

Player _player(String id, String name, int seat) => Player(
      id: id,
      name: name,
      isGuest: false,
      checkedIn: true,
      confirmed: true,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: 1,
      seat: seat,
      active: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  testWidgets('S6 (T15): StandingsScreen shows "How points work" panel with last game example', (tester) async {
    final players = [
      _player('u1', 'Alex Morgan', 1),
      _player('u2', 'Bob Ross', 2),
      _player('u3', 'Charlie Brown', 3),
      _player('u4', 'David Hassel', 4),
    ];

    final completedGame = LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: _structure,
      status: LiveGameStatus.completed,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 0,
      players: players,
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 4000,
      pendingGuests: const [],
      finishOrder: const ['u1', 'u2', 'u3', 'u4'], // 1st: u1, 2nd: u2, 3rd: u3, 4th: u4
    );

    final group = Group(
      id: 'g1',
      name: 'Friday Club',
      joinCode: 'J1',
      ownerId: 'u1',
      members: const [_host, _member],
      games: [completedGame],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(group);
    app.premiumTier = PremiumTier.premium; // Unlock season table

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: const Scaffold(
            body: StandingsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify "How points work" panel is visible
    expect(find.text('How points work'), findsOneWidget);

    // Verify it refers to the last game
    expect(find.textContaining('Friday Poker Night (4 players)'), findsOneWidget);

    // In a 4-player game with field-size formula (10 * sqrt(4/finish)):
    // 1st place: 10 * sqrt(4/1) = 20.0 pts
    // 2nd place: 10 * sqrt(4/2) = 14.1 pts
    // 4th place (last): 10 * sqrt(4/4) = 10.0 pts
    expect(find.textContaining('1st (Alex Morgan): 20.0 pts'), findsOneWidget);
    expect(find.textContaining('2nd (Bob Ross): 14.1 pts'), findsOneWidget);
    expect(find.textContaining('Last place (4): 10.0 pts'), findsOneWidget);

    app.dispose();
  });
}
