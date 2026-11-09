import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  testWidgets('free blind tool remains stack-first', (tester) async {
    tester.view.physicalSize = const Size(800, 4800);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(const MaterialApp(home: ToolBlindsScreen()));
    await tester.pump();

    expect(find.byKey(const Key('builder-step-inputs')), findsOneWidget);
    expect(find.byKey(const Key('level-row-1')), findsNothing);

    final next = find.byKey(const Key('builder-next'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump();

    expect(find.byKey(const Key('builder-step-stack')), findsOneWidget);
    expect(find.byKey(const Key('stack-value')), findsOneWidget);
    expect(
      find.byKey(const Key('level-row-1')),
      findsNothing,
      reason: 'levels must stay hidden until the stack is approved',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.reset();
  });

  testWidgets('custom cash stakes accept typing and reject SB at least BB', (
    tester,
  ) async {
    final app = AppProvider();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: CashGameScreen()),
        ),
        GoRoute(
          path: RoutePaths.cashGameLive,
          builder: (_, _) => const Scaffold(body: Text('CASH LIVE')),
        ),
      ],
    );
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    for (final label in ['10 / 20', '15 / 30', '20 / 40', '25 / 50']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Custom'));
    await tester.pump();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(5));

    await tester.enterText(fields.at(0), '3');
    await tester.enterText(fields.at(1), '2');
    final start = find.text('Start session');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();

    expect(app.cashSession, isNull);
    expect(
      find.text('Small blind must be less than big blind.'),
      findsOneWidget,
    );

    await tester.enterText(fields.at(0), '0.75');
    await tester.enterText(fields.at(1), '1.5');
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.text('CASH LIVE'), findsOneWidget);
    expect(app.cashSession?.settings.smallBlind, 0.75);
    expect(app.cashSession?.settings.bigBlind, 1.5);

    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    app.dispose();
    tester.view.reset();
  });

  testWidgets(
    'ICM names the pool, remaining players and each stack at 320 px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1600);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(const MaterialApp(home: ToolIcmScreen()));
      await tester.pump();

      expect(find.text('Total pool'), findsOneWidget);
      expect(find.text('Players remaining'), findsOneWidget);
      expect(find.text('Each stack'), findsOneWidget);
      expect(find.text('Player 1 stack'), findsOneWidget);
      expect(find.bySemanticsLabel('Players remaining: 3'), findsOneWidget);

      final addPlayer = find.text('Add player');
      await tester.ensureVisible(addPlayer);
      await tester.tap(addPlayer);
      await tester.pump();
      expect(find.bySemanticsLabel('Players remaining: 4'), findsOneWidget);
      expect(find.text('Player 4 stack'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.reset();
    },
  );
}
