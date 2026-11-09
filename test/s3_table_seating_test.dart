import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/poker_table_seating_visual.dart';
import 'package:provider/provider.dart';

const _chips = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
];

const _settings = GameSettings(
  name: 'Friday',
  date: '2026-12-18',
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
  stats: UserStats(played: 1, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

final _group = Group(
  id: 'g1',
  name: 'Group 1',
  joinCode: 'J1',
  ownerId: 'u1',
  members: const [_host],
  games: const [],
  chat: const [],
  polls: const [],
  notifications: const [],
);

Player _player(String id, String name, int table, int seat) => Player(
      id: id,
      name: name,
      isGuest: false,
      checkedIn: true,
      confirmed: true,
      eliminated: false,
      rebuys: 0,
      hasAddOn: false,
      knockouts: 0,
      table: table,
      seat: seat,
      active: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  testWidgets('S3 (T4): PokerTableSeatingCard renders visual table and seats', (tester) async {
    final players = [
      _player('p1', 'Alice', 1, 1),
      _player('p2', 'Bob', 1, 2),
      _player('p3', 'Charlie', 1, 3),
      _player('p4', 'David', 1, 4),
    ];

    final game = LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: _emptyStructure,
      status: LiveGameStatus.running,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: players,
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 4000,
      pendingGuests: const [],
      finishOrder: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group)
      ..setCurrentGameForTesting(game);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: Scaffold(
            body: SingleChildScrollView(
              child: PokerTableSeatingCard(
                table: 1,
                players: players,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify table title
    expect(find.text('Table 1'), findsWidgets);
    expect(find.text('4 players'), findsOneWidget);
    expect(find.text('Drag or tap players to move or swap seats'), findsOneWidget);

    // Verify seats are displayed
    expect(find.byType(PokerTableSeatingCard), findsOneWidget);
    expect(find.byType(Draggable<Player>), findsNWidgets(4));
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    app.dispose();
  });

  test('S3 (T4): swapPlayerSeats and movePlayerToTableAndSeat update game state correctly', () {
    final players = [
      _player('p1', 'Alice', 1, 1),
      _player('p2', 'Bob', 1, 2),
    ];

    final game = LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: _emptyStructure,
      status: LiveGameStatus.running,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: players,
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 2000,
      pendingGuests: const [],
      finishOrder: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group)
      ..setCurrentGameForTesting(game);

    // Swap seats
    final swapRes = app.swapPlayerSeats('p1', 'p2');
    expect(swapRes, isNull);

    final updatedP1 = app.currentGame!.players.firstWhere((p) => p.id == 'p1');
    final updatedP2 = app.currentGame!.players.firstWhere((p) => p.id == 'p2');

    expect(updatedP1.seat, 2);
    expect(updatedP2.seat, 1);

    // Move player to table 2 seat 5
    final moveRes = app.movePlayerToTableAndSeat('p1', 2, 5);
    expect(moveRes, isNull);
    final movedP1 = app.currentGame!.players.firstWhere((p) => p.id == 'p1');
    expect(movedP1.table, 2);
    expect(movedP1.seat, 5);

    app.dispose();
  });
}
