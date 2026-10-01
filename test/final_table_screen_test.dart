import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/final_table_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    RecoveryService.enabled = false;
  });

  tearDown(() {
    RecoveryService.enabled = true;
  });

  testWidgets('FinalTableScreen renders 03_07_final_table.png layout and controls', (tester) async {
    const stats = UserStats(
      played: 10,
      wins: 2,
      podium: 4,
      avgFinish: 3.5,
      knockouts: 5,
    );

    const host = AppUser(
      id: 'u1',
      name: 'Host User',
      email: 'host@test.com',
      isAdmin: true,
      stats: stats,
    );

    final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi', 'Ivan'];
    final players = [
      for (var i = 0; i < names.length; i++)
        Player(
          id: 'u${i + 1}',
          name: names[i],
          isGuest: false,
          rsvp: Rsvp.going,
          checkedIn: true,
          confirmed: true,
          eliminated: false,
          eliminationPos: null,
          rebuys: 0,
          hasAddOn: false,
          knockouts: 0,
          table: i.isEven ? 1 : 2,
          seat: i + 1,
          stack: 25000,
          active: true,
        ),
    ];

    final settings = GameSettings(
      name: 'Friday Night Freezeout',
      date: 'Fri, Mar 14',
      time: '8:00 PM',
      location: "Marcus's place",
      durationHours: 4,
      players: 9,
      buyIn: 100,
      chipSet: MockData.defaultChipSet,
      chipSetName: 'Home set',
      koEnabled: false,
      koAmount: 0,
      rebuys: true,
      rebuysCloseLevel: 6,
      addOn: false,
      addOnCloseLevel: 8,
      anteEnabled: true,
      anteAfterLevel: 4,
      organizerPct: 0,
      breaks: const [],
    );

    final structure = TournamentEngine.generate(
      TournamentParams(
        players: 9,
        durationHours: 4,
        buyIn: 100,
        chipSet: MockData.defaultChipSet,
        rebuys: true,
        rebuysCloseLevel: 6,
        addOn: false,
        anteEnabled: true,
        anteAfterLevel: 4,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
      ),
    );

    final game = LiveGame(
      id: 'live1',
      groupId: 'g1',
      settings: settings,
      structure: structure,
      status: LiveGameStatus.finaltable,
      publicCode: 'FP2608',
      tvCode: 'TV4821',
      currentLevel: 5,
      timerRunning: false,
      secondsRemaining: 800,
      players: players,
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 225000,
      pendingGuests: const [],
      finishOrder: const [],
    );

    final group = Group(
      id: 'g1',
      name: 'Friday Poker Club',
      joinCode: 'FP2608',
      ownerId: 'u1',
      members: const [host],
      games: [game],
      chat: const [],
      polls: const [],
      notifications: const [],
    );

    final app = AppProvider()
      ..setUserForTesting(host)
      ..setCurrentGroupForTesting(group)
      ..setCurrentGame(game);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: FinalTableScreen()),
        ),
        GoRoute(
          path: RoutePaths.hostDashboard,
          builder: (_, _) => const Scaffold(body: Text('Host Dashboard')),
        ),
      ],
    );

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Verify Eyebrow badge: FINAL TABLE
    expect(find.text('FINAL TABLE'), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_outlined), findsWidgets);

    // Verify Title: Redraw the seats
    expect(find.text('Redraw the seats'), findsOneWidget);

    // Verify Subtitle: 9 players remain
    expect(find.text('9 players remain'), findsOneWidget);

    // Verify Center table text: Seat 1–9
    expect(find.text('Seat 1–9'), findsOneWidget);

    // Verify Buttons from mockup:
    // "Assign seats & continue"
    expect(find.text('Assign seats & continue'), findsOneWidget);
    // "Shuffle again"
    expect(find.text('Shuffle again'), findsOneWidget);

    // Verify tapping "Shuffle again" reshuffles
    await tester.ensureVisible(find.text('Shuffle again'));
    await tester.tap(find.text('Shuffle again'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Seat 1–9'), findsOneWidget);

    // Tap "Assign seats & continue" confirms the final table
    await tester.ensureVisible(find.text('Assign seats & continue'));
    await tester.tap(find.text('Assign seats & continue'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Final Table Set!'), findsOneWidget);

    // Pump past the 1500ms navigation timer
    await tester.pump(const Duration(milliseconds: 1600));

    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
}
