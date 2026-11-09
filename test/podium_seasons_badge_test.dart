import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/result_podium_screen.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:provider/provider.dart';

import '../tool/board_fixtures.dart';

/// The seasons upsell on the result podium.
///
/// Season points ride on the shared result card only behind the seasons
/// entitlement, so a free-tier host would otherwise never learn they exist.
/// The podium carries the same PREMIUM/UNLOCKED tag convention as the
/// standings screen, and tapping the locked card opens the upgrade screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  Future<void> screen(
    WidgetTester tester,
    AppProvider app,
    Future<void> Function() body,
  ) async {
    final router = GoRouter(
      initialLocation: '/podium',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/podium',
          builder: (_, _) => const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: ResultPodiumScreen(),
          ),
        ),
        GoRoute(
          path: '/upgrade',
          builder: (_, _) =>
              const Scaffold(body: Text('UPGRADE-STUB')),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await tester.pump();
    }
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  group('seasons badge', () {
    testWidgets('free tier sees PREMIUM and reaches upgrade', (tester) async {
      final app = AppProvider();
      seedBoardProvider(app, game: LiveGameStatus.completed);

      await screen(tester, app, () async {
        expect(find.text('Season points'), findsOneWidget);
        expect(find.text('PREMIUM'), findsOneWidget);
        expect(find.text('UNLOCKED'), findsNothing);

        await tap(tester, find.text('Season points'));
        expect(find.text('UPGRADE-STUB'), findsOneWidget);
      });
    });

    testWidgets('premium tier sees UNLOCKED and stays put', (tester) async {
      final app = AppProvider();
      seedBoardProvider(app, game: LiveGameStatus.completed);
      app.premiumTier = PremiumTier.premium;

      await screen(tester, app, () async {
        expect(find.text('Season points'), findsOneWidget);
        expect(find.text('UNLOCKED'), findsOneWidget);
        expect(find.text('PREMIUM'), findsNothing);
      });
    });
  });
}
