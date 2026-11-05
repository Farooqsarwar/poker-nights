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
import 'package:poker_night/screens/tournament/player_live_screen.dart';
import 'package:poker_night/widgets/dashboard_level_edit_dialog.dart';
import 'package:provider/provider.dart';

const _chips = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 25, quantity: 100),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 100, quantity: 100),
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
  anteEnabled: true,
  anteAfterLevel: 1,
  organizerPct: 10,
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

TournamentStructure _makeStructure() {
  return TournamentStructure(
    startingStack: 1000,
    chipPlan: const [
      ChipPlanEntry(value: 25, count: 8, color: 'White', hex: 0xFFE8E4D9),
      ChipPlanEntry(value: 100, count: 8, color: 'Red', hex: 0xFFC0392B),
    ],
    rebuyStack: 1000,
    rebuyChipPlan: [],
    addOnStack: 1000,
    addOnChipPlan: [],
    levels: [
      const BlindLevel(level: 1, sb: 25, bb: 50, ante: 50, durationMins: 15),
      const BlindLevel(level: 2, sb: 50, bb: 100, ante: 100, durationMins: 15),
      const BlindLevel(level: 3, sb: 75, bb: 150, ante: 150, durationMins: 15),
      const BlindLevel(level: 4, sb: 100, bb: 200, ante: 200, durationMins: 15),
      const BlindLevel(level: 5, sb: 150, bb: 300, ante: 300, durationMins: 15),
    ],
    levelDuration: 15,
    expectedFinishMins: 75,
    prizes: [],
    prizePool: 0,
    organizerAmount: 0,
    colorUpInstructions: [],
    warnings: [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  test('S4 (T5): editSingleDashboardLevel "this level only" modifies only the target level', () {
    final game = LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: _makeStructure(),
      status: LiveGameStatus.running,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 6000,
      pendingGuests: const [],
      finishOrder: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group)
      ..setCurrentGameForTesting(game);

    // Edit level 2 only
    app.editSingleDashboardLevel(
      levelNumber: 2,
      sb: 60,
      bb: 120,
      ante: 120,
      durationMins: 20,
      recalculateAfter: false,
    );

    final levels = app.currentGame!.structure.levels;
    // Level 1 untouched
    expect(levels[0].sb, 25);
    expect(levels[0].bb, 50);

    // Level 2 edited
    expect(levels[1].sb, 60);
    expect(levels[1].bb, 120);
    expect(levels[1].ante, 120);
    expect(levels[1].durationMins, 20);

    // Level 3 untouched
    expect(levels[2].sb, 75);
    expect(levels[2].bb, 150);

    app.dispose();
  });

  test('S4 (T5): editSingleDashboardLevel "recalculate after this" recalculates subsequent levels smoothly', () {
    final game = LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: _makeStructure(),
      status: LiveGameStatus.running,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 6000,
      pendingGuests: const [],
      finishOrder: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group)
      ..setCurrentGameForTesting(game);

    // Edit level 2 and recalculate after
    app.editSingleDashboardLevel(
      levelNumber: 2,
      sb: 75,
      bb: 150,
      ante: 150,
      durationMins: 15,
      recalculateAfter: true,
    );

    final levels = app.currentGame!.structure.levels;
    // Level 1 untouched
    expect(levels[0].sb, 25);
    expect(levels[0].bb, 50);

    // Level 2 has the edited values
    expect(levels[1].sb, 75);
    expect(levels[1].bb, 150);

    // Level 3 scaled up from 150 BB (e.g. 200 BB) and ante matches BB
    expect(levels[2].bb, greaterThan(150));
    expect(levels[2].ante, equals(levels[2].bb));

    // Level 4 scaled up from level 3
    expect(levels[3].bb, greaterThan(levels[2].bb));
    expect(levels[3].ante, equals(levels[3].bb));

    app.dispose();
  });

  testWidgets('S4 (T5): LevelsTableCard displays edit pens when onEditLevel is provided', (tester) async {
    final game = LiveGame(
      id: 'game-1',
      groupId: 'g1',
      settings: _settings,
      structure: _makeStructure(),
      status: LiveGameStatus.running,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 6000,
      pendingGuests: const [],
      finishOrder: const [],
    );

    BlindLevel? tappedLevel;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LevelsTableCard(
              game: game,
              onEditLevel: (l) => tappedLevel = l,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 5 edit buttons exist (for 5 levels)
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(5));

    // Tap first edit button
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pump();

    expect(tappedLevel, isNotNull);
    expect(tappedLevel!.level, 1);
  });
}
