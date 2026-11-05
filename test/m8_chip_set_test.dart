import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/chip_set_editor.dart';

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

  group('M8 & B16: Chip Set Editor & Presets', () {
    testWidgets('Displays total chip count, face value and Save as preset button', (tester) async {
      tester.view.physicalSize = const Size(400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final app = AppProvider()..setUserForTesting(_host);

      final chips = [
        const ChipColor(color: 'White', hex: 0xFFFFFFFF, value: 1, quantity: 100),
        const ChipColor(color: 'Red', hex: 0xFFFF0000, value: 5, quantity: 100),
        const ChipColor(color: 'Green', hex: 0xFF00FF00, value: 25, quantity: 50),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChipSetEditor(
                  initial: chips,
                  initialName: 'Custom',
                  onChanged: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total count: 100 + 100 + 50 = 250 chips
      expect(find.textContaining('250 chips'), findsOneWidget);

      // Face value: 100*1 + 100*5 + 50*25 = 100 + 500 + 1250 = 1,850
      expect(find.textContaining('1,850'), findsOneWidget);

      // "Save as preset" button exists
      final saveBtn = find.text('Save as preset');
      expect(saveBtn, findsOneWidget);

      // Tap Save as preset
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Preset was saved in appProvider
      expect(app.savedChipSets.any((s) => s.chips.length == 3), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      app.dispose();
    });

    testWidgets('C1: Chip set picker dialog lists chip values and counts', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_testGroup);

      final router = GoRouter(
        initialLocation: '/cash/start',
        routes: [
          GoRoute(
            path: '/cash/start',
            builder: (context, state) => const Scaffold(body: CashGameScreen()),
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

      // Tap on chip set selector row
      final chipSetTile = find.text('Standard set');
      expect(chipSetTile, findsOneWidget);
      await tester.tap(chipSetTile);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet opened
      expect(find.text('Select Chip Set'), findsOneWidget);

      // Verify chip values and counts are listed in subtitle (C1)
      expect(find.textContaining('1 (150)'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      app.dispose();
    });
  });
}
