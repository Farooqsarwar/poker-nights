import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/screens/cash/cash_game_live_screen.dart';
import 'package:poker_night/services/recovery_service.dart';

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

void main() {
  setUp(() {
    RecoveryService.enabled = false;
  });

  tearDown(() {
    RecoveryService.enabled = true;
  });

  Future<(AppProvider, GoRouter)> mountTestWidget(
    WidgetTester tester, {
    required Widget child,
    AppProvider? provider,
  }) async {
    final app = provider ?? (AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_testGroup));

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: RoutePaths.cashGameLive,
          builder: (_, _) => const Scaffold(body: CashGameLiveScreen()),
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
    return (app, router);
  }

  Future<void> unmount(WidgetTester tester, AppProvider app, GoRouter router) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    app.dispose();
  }

  group('M6 & C2-C5: Cash Game Setup & Live', () {
    testWidgets('C2 & M6: Blinds ladder includes 0.20/0.40 and defaults Min to 40 and Max to 100', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final (app, router) = await mountTestWidget(tester, child: const CashGameScreen());

      // C2: Must say "Blinds", not "Stakes"
      expect(find.text('Blinds'), findsOneWidget);
      expect(find.text('Stakes'), findsNothing);

      // M6: Blind ladder includes 0.20 / 0.40
      expect(find.text('0.20 / 0.40'), findsOneWidget);

      // Tap 0.20 / 0.40
      await tester.tap(find.text('0.20 / 0.40'));
      await tester.pumpAndSettle();

      // By default with single Buy-in, buy-in is 100 BB = 40
      expect(find.widgetWithText(TextField, '40'), findsWidgets);

      // Toggle "Set minimum and maximum"
      final toggleFinder = find.text('Set minimum and maximum');
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Min buy-in = 40, Max buy-in = 100 (250 * 0.40)
      expect(find.text('Min buy-in'), findsOneWidget);
      expect(find.text('Max buy-in'), findsOneWidget);
      expect(find.widgetWithText(TextField, '40'), findsWidgets);
      expect(find.widgetWithText(TextField, '100'), findsWidgets);

      await unmount(tester, app, router);
    });

    testWidgets('C3: Dynamic chip value example text is displayed', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final (app, router) = await mountTestWidget(tester, child: const CashGameScreen());

      // Check dynamic live example text exists
      expect(find.textContaining('Example: At 1 chip ='), findsOneWidget);

      await unmount(tester, app, router);
    });

    testWidgets('C4: Optional "Who is playing?" pre-seeds players on start', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final (app, router) = await mountTestWidget(tester, child: const CashGameScreen());

      // Find "Who is playing?" input
      final playerInputFinder = find.byKey(const Key('cash_who_is_playing_input'));
      expect(playerInputFinder, findsOneWidget);

      await tester.enterText(playerInputFinder, 'Alice, Bob');
      await tester.pumpAndSettle();

      // Start session
      await tester.tap(find.text('Start session'));
      await tester.pumpAndSettle();

      expect(app.cashSession, isNotNull);
      expect(app.cashSession!.players.length, 2);
      expect(app.cashSession!.players[0].name, 'Alice');
      expect(app.cashSession!.players[1].name, 'Bob');

      await unmount(tester, app, router);
    });

    testWidgets('C2, C4, C5: Live screen header shows blinds, shows money in and avg stack, + Rebuy button, and Undo', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_testGroup);

      final now = DateTime.now();
      app.setCashSessionForTesting(
        CashSession(
          id: 'test-cash',
          settings: const CashSessionSettings(
            name: 'Friday Cash',
            date: '2026-11-05',
            location: 'Home',
            smallBlind: 0.20,
            bigBlind: 0.40,
            minBuyIn: 40,
            maxBuyIn: 100,
            maxPlayers: 10,
            chipValue: 1,
          ),
          startTime: now,
          players: [
            const CashPlayer(
              id: 'p1',
              name: 'Alice',
              stack: 40,
              totalBuyIns: 40,
              buyInCount: 1,
              cashedOut: 0,
            ),
            const CashPlayer(
              id: 'p2',
              name: 'Bob',
              stack: 60,
              totalBuyIns: 60,
              buyInCount: 1,
              cashedOut: 0,
            ),
          ],
        ),
      );

      final (_, router) = await mountTestWidget(
        tester,
        child: const CashGameLiveScreen(),
        provider: app,
      );

      // C2: Header must show chosen blinds 0.2 / 0.4
      expect(find.textContaining('0.2 / 0.4'), findsOneWidget);

      // C4: Metrics show "money in" and "avg stack"
      expect(find.text('money in'), findsOneWidget);
      expect(find.text('avg stack'), findsOneWidget);

      // C5: + Rebuy button on Alice's row
      final rebuyFinder = find.text('+ Rebuy');
      expect(rebuyFinder, findsWidgets);

      // Tap + Rebuy on Alice
      await tester.tap(rebuyFinder.first);
      await tester.pumpAndSettle();

      // Top-up (rebuy) modal open
      expect(find.text('Top-up (rebuy)'), findsOneWidget);

      // Enter 25 top-up and submit
      final amountField = find.widgetWithText(TextField, '40'); // preset with minBuyIn 40
      expect(amountField, findsOneWidget);
      await tester.enterText(amountField, '25');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Alice's totalBuyIns is now 40 + 25 = 65
      expect(app.cashSession!.players.firstWhere((p) => p.id == 'p1').totalBuyIns, 65);

      // Undo button should now be visible
      final undoFinder = find.byTooltip('Undo last action');
      expect(undoFinder, findsOneWidget);

      // Tap Undo
      await tester.tap(undoFinder);
      await tester.pumpAndSettle();

      // Reverted to 40
      expect(app.cashSession!.players.firstWhere((p) => p.id == 'p1').totalBuyIns, 40);

      await unmount(tester, app, router);
    });
  });
}
