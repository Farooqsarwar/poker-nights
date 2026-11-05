import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/rebuy_settlement_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';

const _host = AppUser(
  id: 'host-1',
  name: 'Host User',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

const _testGroup = Group(
  id: 'g1',
  name: 'Home Game',
  joinCode: 'HOME1',
  ownerId: 'host-1',
  members: [],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

Player _player(int index) => Player(
  id: 'p$index',
  name: 'Player $index',
  isGuest: false,
  rsvp: null,
  checkedIn: true,
  confirmed: true,
  eliminated: false,
  rebuys: 0,
  hasAddOn: false,
  knockouts: 0,
  table: 1,
  seat: index,
  active: true,
);

void main() {
  setUp(() {
    RecoveryService.enabled = false;
  });

  tearDown(() {
    RecoveryService.enabled = true;
  });

  group('M7: Unlimited Rebuys Plan & Re-plan', () {
    test('replanRemainingLevels: does not change levels if within 15% of plan', () {
      final chipSet = MockData.defaultChipSet;
      final params = TournamentParams(
        players: 8,
        buyIn: 20,
        chipSet: chipSet,
        durationHours: 3.0,
        rebuys: true,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        rebuysCloseLevel: 4,
        rebuyLimit: 0, // unlimited
      );

      final structure = TournamentEngine.generate(params);
      expect(structure.expectedTotalChips, greaterThan(0));

      // 5% increase in chips (within 15%)
      final actualChips = (structure.expectedTotalChips * 1.05).round();
      final replanned = TournamentEngine.replanRemainingLevels(
        structure: structure,
        actualChips: actualChips,
        rebuysCloseLevel: 4,
        anteEnabled: false,
        anteStyle: AnteStyle.bigBlind,
        chipSet: chipSet,
      );

      // Levels should remain identical
      for (var i = 0; i < structure.levels.length; i++) {
        expect(replanned.levels[i].bb, structure.levels[i].bb);
      }
    });

    test('replanRemainingLevels: re-plans remaining levels when chips differ by > 15%', () {
      final chipSet = MockData.defaultChipSet;
      final params = TournamentParams(
        players: 8,
        buyIn: 20,
        chipSet: chipSet,
        durationHours: 3.0,
        rebuys: true,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 3,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        rebuysCloseLevel: 4,
        rebuyLimit: 0, // unlimited
      );

      final structure = TournamentEngine.generate(params);
      expect(structure.expectedTotalChips, greaterThan(0));

      // 80% increase in chips (heavy rebuys)
      final actualChips = (structure.expectedTotalChips * 1.80).round();
      final replanned = TournamentEngine.replanRemainingLevels(
        structure: structure,
        actualChips: actualChips,
        rebuysCloseLevel: 4,
        anteEnabled: false,
        anteStyle: AnteStyle.bigBlind,
        chipSet: chipSet,
      );

      // Levels 1..4 (index 0..3) are unchanged (pinned)
      for (var i = 0; i < 4; i++) {
        expect(replanned.levels[i].bb, structure.levels[i].bb);
      }

      // Remaining levels are adjusted upward for the bigger chip volume
      expect(replanned.levels.last.bb, greaterThan(structure.levels.last.bb));
    });

    testWidgets('Settlement screen warns when average stack at close < 30 BB', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_testGroup);

      // Create a game where average stack at close is < 30 BB
      // E.g. startingStack 500, players 4, BB at close is 50 -> 2000 / 4 = 500 avg stack -> 10 BB (< 30 BB)
      const gameSettings = GameSettings(
        name: 'Turbo Night',
        date: '2026-11-05',
        time: '20:00',
        location: 'Home',
        players: 4,
        durationHours: 2,
        buyIn: 20,
        koEnabled: false,
        koAmount: 0,
        rebuys: true,
        rebuysCloseLevel: 2,
        addOn: false,
        anteEnabled: false,
        anteAfterLevel: 3,
        organizerPct: 0,
        chipSet: [],
        chipSetName: 'Default',
      );

      const structure = TournamentStructure(
        startingStack: 500,
        chipPlan: [],
        rebuyStack: 500,
        rebuyChipPlan: [],
        addOnStack: 250,
        addOnChipPlan: [],
        levels: [
          BlindLevel(level: 1, sb: 10, bb: 20, ante: null, durationMins: 15),
          BlindLevel(level: 2, sb: 25, bb: 50, ante: null, durationMins: 15),
          BlindLevel(level: 3, sb: 50, bb: 100, ante: null, durationMins: 15),
        ],
        levelDuration: 15,
        expectedFinishMins: 45,
        prizes: [],
        prizePool: 80,
        organizerAmount: 0,
        colorUpInstructions: [],
        warnings: [],
        rebuysCloseLevel: 2,
        expectedTotalChips: 2000,
      );

      final liveGame = LiveGame(
        id: 'turbo-1',
        groupId: 'g1',
        settings: gameSettings,
        structure: structure,
        status: LiveGameStatus.rebuypause,
        currentLevel: 2,
        secondsRemaining: 600,
        publicCode: 'CODE1',
        tvCode: 'TV1',
        timerRunning: false,
        players: [_player(1), _player(2), _player(3), _player(4)],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 2000,
        pendingGuests: const [],
        finishOrder: const [],
      );

      app.setCurrentGameForTesting(liveGame);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: RebuySettlementScreen()),
          ),
          GoRoute(
            path: RoutePaths.hostDashboard,
            builder: (_, _) => const Scaffold(body: Text('Host Dashboard')),
          ),
          GoRoute(
            path: RoutePaths.invitation,
            builder: (_, _) => const Scaffold(body: Text('Invitation')),
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Warning banner must be visible
      expect(
        find.textContaining('Average stack at close is under 30 BB'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      app.dispose();
    });
  });
}
