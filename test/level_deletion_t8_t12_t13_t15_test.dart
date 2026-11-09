import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/admin_dashboard_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/widgets/structure_editor.dart';
import 'package:poker_night/widgets/dashboard_level_edit_dialog.dart';
import 'package:poker_night/screens/tournament/player_live_screen.dart' show LevelsTableCard;
import 'package:poker_night/widgets/app_modal.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:poker_night/app/typography.dart';
import 'package:poker_night/constants/app_constants.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/utils/tournament_engine.dart';

void main() {
  group('Structure editor level deletion and breaks (T8, T9, T10, T12, T13, T15)', () {
    List<BlindLevel> makeLevels(int count) {
      // Pick exactly from validBlindLevels starting at 25/50 (index 9)
      const validStartingIndex = 9; // [25, 50]
      return List.generate(
        count,
        (i) {
          final pair = TournamentEngine.validBlindLevels[validStartingIndex + i];
          return BlindLevel(
            level: i + 1,
            sb: pair[0],
            bb: pair[1],
            ante: pair[1],
            durationMins: 15,
          );
        },
      );
    }

    final testStructure = TournamentStructure(
      startingStack: 10000,
      chipPlan: const [
        ChipPlanEntry(value: 25, count: 8, color: 'White', hex: 0xFFFFFFFF),
      ],
      rebuyStack: 10000,
      rebuyChipPlan: const [],
      addOnStack: 10000,
      addOnChipPlan: const [],
      levels: makeLevels(12),
      breaks: const [
        ScheduledBreak(afterLevel: 4, durationMins: 10),
      ],
      levelDuration: 15,
      expectedFinishMins: 180,
      prizes: const [],
      prizePool: 100,
      organizerAmount: 0,
      colorUpInstructions: const [],
      warnings: const [],
    );

    testWidgets('T13: Deleting level 8 renumbers following levels dynamically', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      List<BlindLevel>? appliedLevels;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructureEditor(
                structure: testStructure,
                currentLevel: 4,
                anteStyle: AnteStyle.bigBlind,
                onSpeedUp: () {},
                onSlowDown: () {},
                onApply: (levels) => appliedLevels = levels,
                onApplyWithBreaks: (levels, breaks) {
                  appliedLevels = levels;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Level 8 exists
      expect(find.byKey(const Key('delete-level-8')), findsOneWidget);

      // Tap delete on level 8
      await tester.ensureVisible(find.byKey(const Key('delete-level-8')));
      await tester.tap(find.byKey(const Key('delete-level-8')));
      await tester.pumpAndSettle();

      // Find Apply changes button and tap
      final applyFinder = find.text('Apply & close');
      await tester.ensureVisible(applyFinder);
      await tester.tap(applyFinder);
      await tester.pumpAndSettle();

      expect(appliedLevels, isNotNull);
      expect(appliedLevels!.length, 7); // 8 future levels minus 1 deleted = 7 future levels

      // Explicitly assert that following levels are dynamically renumbered in appliedLevels (5..11)
      for (var i = 0; i < appliedLevels!.length; i++) {
        expect(appliedLevels![i].level, i + 5);
      }

      // Check that the blind amounts (sb, bb) match the shifted sequence:
      // Original levels 5, 6, 7 (indices 4, 5, 6 in testStructure.levels) remain at indices 0, 1, 2
      expect(appliedLevels![0].sb, testStructure.levels[4].sb);
      expect(appliedLevels![0].bb, testStructure.levels[4].bb);
      expect(appliedLevels![1].sb, testStructure.levels[5].sb);
      expect(appliedLevels![1].bb, testStructure.levels[5].bb);
      expect(appliedLevels![2].sb, testStructure.levels[6].sb);
      expect(appliedLevels![2].bb, testStructure.levels[6].bb);

      // Deleted level 8 causes levels previously 9, 10, 11, 12 (indices 8, 9, 10, 11)
      // to dynamically become 8, 9, 10, 11 (indices 3, 4, 5, 6 in appliedLevels)
      expect(appliedLevels![3].sb, testStructure.levels[8].sb);
      expect(appliedLevels![3].bb, testStructure.levels[8].bb);
      expect(appliedLevels![4].sb, testStructure.levels[9].sb);
      expect(appliedLevels![4].bb, testStructure.levels[9].bb);
      expect(appliedLevels![5].sb, testStructure.levels[10].sb);
      expect(appliedLevels![5].bb, testStructure.levels[10].bb);
      expect(appliedLevels![6].sb, testStructure.levels[11].sb);
      expect(appliedLevels![6].bb, testStructure.levels[11].bb);
    });

    testWidgets('T10: The active/running level cannot be deleted', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructureEditor(
                structure: testStructure,
                currentLevel: 4,
                anteStyle: AnteStyle.bigBlind,
                onSpeedUp: () {},
                onSlowDown: () {},
                onApply: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Active/running level is 4; delete button must NOT exist for level 4
      expect(find.byKey(const Key('delete-level-4')), findsNothing);
      expect(find.byTooltip('Delete level 4'), findsNothing);
      expect(find.bySemanticsLabel('Delete level 4'), findsNothing);

      // Verify in widget tree that active level 4 is not in the editable list
      expect(find.byKey(const Key('level-row-4')), findsNothing);
      expect(find.byKey(const Key('level-label-4')), findsNothing);

      // UI text explicitly indicates active and completed levels are locked
      expect(
        find.textContaining('Adjust future levels. Active and completed levels are locked.'),
        findsOneWidget,
      );

      // Future levels (5 onwards) are present and have delete buttons
      expect(find.byKey(const Key('delete-level-5')), findsOneWidget);
      expect(find.byTooltip('Delete level 5'), findsOneWidget);
    });

    testWidgets('T15: Insert and delete break below a future level', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      List<ScheduledBreak>? appliedBreaks;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructureEditor(
                structure: testStructure,
                currentLevel: 4,
                anteStyle: AnteStyle.bigBlind,
                onSpeedUp: () {},
                onSlowDown: () {},
                onApply: (_) {},
                onApplyWithBreaks: (levels, breaks) {
                  appliedBreaks = breaks;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Insert break below level 6
      final insertBreakKey = const Key('insert-break-6');
      await tester.ensureVisible(find.byKey(insertBreakKey));
      await tester.tap(find.byKey(insertBreakKey));
      await tester.pumpAndSettle();

      // Delete break key for level 6 should now exist
      final deleteBreakKey = const Key('delete-break-6');
      expect(find.byKey(deleteBreakKey), findsOneWidget);

      // Now delete it
      await tester.tap(find.byKey(deleteBreakKey));
      await tester.pumpAndSettle();

      // Apply
      final applyFinder = find.text('Apply & close');
      await tester.ensureVisible(applyFinder);
      await tester.tap(applyFinder);
      await tester.pumpAndSettle();

      expect(appliedBreaks, isNotNull);
      // Only the original break after level 4 remains
      expect(appliedBreaks!.any((b) => b.afterLevel == 6), isFalse);
    });

    testWidgets('T9: Running level cannot be deleted', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructureEditor(
                structure: testStructure,
                currentLevel: 4,
                anteStyle: AnteStyle.bigBlind,
                onSpeedUp: () {},
                onSlowDown: () {},
                onApply: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Running level is 4; delete button must NOT exist for level 4
      expect(find.byKey(const Key('delete-level-4')), findsNothing);
      // Past levels < 4 must NOT have delete buttons
      expect(find.byKey(const Key('delete-level-1')), findsNothing);
      expect(find.byKey(const Key('delete-level-2')), findsNothing);
      expect(find.byKey(const Key('delete-level-3')), findsNothing);
      // Future levels >= 5 DO have delete buttons
      expect(find.byKey(const Key('delete-level-5')), findsOneWidget);
    });

    testWidgets('T8/T12: Played level locked in DashboardLevelEditDialog with isPlayed: true', (tester) async {
      final mockGame = LiveGame(
        id: 'game1',
        groupId: 'g1',
        settings: const GameSettings(
          name: 'Friday Game',
          date: '2026-12-18',
          time: '20:00',
          location: 'Kitchen table',
          players: 6,
          durationHours: 4,
          buyIn: 20,
          chipSet: [],
          chipSetName: 'Standard',
          koEnabled: false,
          koAmount: 0,
          rebuys: true,
          rebuysCloseLevel: 6,
          addOn: true,
          anteEnabled: true,
          anteAfterLevel: 1,
          organizerPct: 10,
        ),
        structure: testStructure,
        status: LiveGameStatus.running,
        publicCode: 'CODE1',
        tvCode: 'TV1',
        currentLevel: 4,
        timerRunning: false,
        secondsRemaining: 600,
        players: const [],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 6000,
        pendingGuests: const [],
        finishOrder: const [],
      );

      final playedLevel = testStructure.levels[0]; // Level 1 is played (1 < 4)

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardLevelEditDialog(
              game: mockGame,
              level: playedLevel,
              isPlayed: true,
              onApply: ({
                required int sb,
                required int bb,
                int? ante,
                required int durationMins,
                required bool recalculateAfter,
              }) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Recalculation option is hidden when isPlayed: true
      expect(find.text('Recalculation option'), findsNothing);
      expect(find.text('Recalculate after this'), findsNothing);
    });

    testWidgets('T13: LevelsTableCard reflects dynamically renumbered sequence', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      // Structure with 6 levels: 1..6
      final initialLevels = makeLevels(6);
      final structure6 = testStructure.copyWith(levels: initialLevels);

      final game6 = LiveGame(
        id: 'g6',
        groupId: 'grp1',
        settings: const GameSettings(name: 'Test', date: '2026-11-01', time: '19:00', location: 'Home', players: 6, durationHours: 3, buyIn: 20, chipSet: [], chipSetName: 'Std', koEnabled: false, koAmount: 0, rebuys: true, rebuysCloseLevel: 4, addOn: false, anteEnabled: false, anteAfterLevel: 1, organizerPct: 0),
        structure: structure6,
        status: LiveGameStatus.running,
        publicCode: 'C6',
        tvCode: 'TV6',
        currentLevel: 2,
        timerRunning: true,
        secondsRemaining: 600,
        players: const [],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 6000,
        pendingGuests: const [],
        finishOrder: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LevelsTableCard(game: game6, onEditLevel: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All 6 levels are present
      for (int i = 1; i <= 6; i++) {
        expect(find.bySemanticsLabel('Edit Level $i'), findsOneWidget);
      }

      // Now simulate deleting Level 4: levels 5 and 6 become levels 4 and 5
      final renumbered = <BlindLevel>[
        initialLevels[0],
        initialLevels[1],
        initialLevels[2],
        initialLevels[4].copyWith(level: 4),
        initialLevels[5].copyWith(level: 5),
      ];
      final gameRenumbered = game6.copyWith(
        structure: structure6.copyWith(levels: renumbered),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LevelsTableCard(game: gameRenumbered, onEditLevel: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Levels 1..5 are present sequentially without gaps
      for (int i = 1; i <= 5; i++) {
        expect(find.bySemanticsLabel('Edit Level $i'), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Edit Level 6'), findsNothing);
    });

    testWidgets('T8/T12: Played level modal gate blocks deletion and warns host', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      bool editFormOpened = false;
      bool wasPlayedPassed = false;

      void showLevelEdit(BuildContext context, LiveGame game, BlindLevel level) {
        if (level.level < game.currentLevel) {
          showAppModal(
            context: context,
            title: 'Played level',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'L${level.level} was already played. Edit it only to correct the record — the clock won\'t replay it, and it can\'t be deleted.',
                  style: AppTypography.bodySm,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: () {
                    Navigator.pop(context);
                    editFormOpened = true;
                    wasPlayedPassed = true;
                  },
                  child: const Text('Correct the record'),
                ),
              ],
            ),
          );
          return;
        }
        editFormOpened = true;
        wasPlayedPassed = false;
      }

      final mockGame = LiveGame(
        id: 'game1',
        groupId: 'g1',
        settings: const GameSettings(
          name: 'Friday Game',
          date: '2026-12-18',
          time: '20:00',
          location: 'Kitchen table',
          players: 6,
          durationHours: 4,
          buyIn: 20,
          chipSet: [],
          chipSetName: 'Standard',
          koEnabled: false,
          koAmount: 0,
          rebuys: true,
          rebuysCloseLevel: 6,
          addOn: true,
          anteEnabled: true,
          anteAfterLevel: 1,
          organizerPct: 10,
        ),
        structure: testStructure,
        status: LiveGameStatus.running,
        publicCode: 'CODE1',
        tvCode: 'TV1',
        currentLevel: 4,
        timerRunning: false,
        secondsRemaining: 600,
        players: const [],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 6000,
        pendingGuests: const [],
        finishOrder: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => LevelsTableCard(
                game: mockGame,
                onEditLevel: (l) => showLevelEdit(context, mockGame, l),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Level 2 (2 < 4 => played level)
      await tester.tap(find.bySemanticsLabel('Edit Level 2'));
      await tester.pumpAndSettle();

      // Verify the Played level warning modal is shown
      expect(find.text('Played level'), findsOneWidget);
      expect(
        find.textContaining('was already played. Edit it only to correct the record — the clock won\'t replay it, and it can\'t be deleted.'),
        findsOneWidget,
      );

      // Tap 'Correct the record'
      await tester.tap(find.text('Correct the record'));
      await tester.pumpAndSettle();

      expect(editFormOpened, isTrue);
      expect(wasPlayedPassed, isTrue);
    });

    testWidgets('T8/T12: AdminDashboardScreen shows Played level modal gate when tapping played level', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RecoveryService.enabled = false;
      addTearDown(() => RecoveryService.enabled = true);

      final adminUser = const AppUser(
        id: 'admin_1',
        name: 'Admin Host',
        email: 'host@test.com',
        isAdmin: true,
        stats: UserStats(
          played: 0,
          wins: 0,
          podium: 0,
          avgFinish: 0,
          knockouts: 0,
        ),
      );

      final dashboardGame = LiveGame(
        id: 'game_dash',
        groupId: 'g_dash',
        settings: const GameSettings(
          name: 'Dashboard Tournament',
          date: '2026-12-18',
          time: '20:00',
          location: 'Main Room',
          players: 4,
          durationHours: 3,
          buyIn: 25,
          chipSet: [],
          chipSetName: 'Standard',
          koEnabled: false,
          koAmount: 0,
          rebuys: true,
          rebuysCloseLevel: 4,
          addOn: false,
          anteEnabled: false,
          anteAfterLevel: 1,
          organizerPct: 0,
        ),
        structure: testStructure,
        status: LiveGameStatus.running,
        publicCode: 'DASH1',
        tvCode: 'TVDASH',
        currentLevel: 3,
        timerRunning: false,
        secondsRemaining: 500,
        players: const [
          Player(
            id: 'admin_1',
            name: 'Admin Host',
            isGuest: false,
            checkedIn: true,
            confirmed: true,
            eliminated: false,
            rebuys: 0,
            hasAddOn: false,
            knockouts: 0,
            table: 1,
            seat: 1,
            active: true,
          ),
        ],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 4000,
        pendingGuests: const [],
        finishOrder: const [],
      );

      final group = Group(
        id: 'g_dash',
        name: 'Dashboard Group',
        joinCode: 'DASHG',
        ownerId: adminUser.id,
        members: [adminUser],
        games: [dashboardGame],
        chat: const [],
        polls: const [],
        notifications: const [],
      );

      final app = AppProvider()
        ..setUserForTesting(adminUser)
        ..setCurrentGroupForTesting(group)
        ..setCurrentGameForTesting(dashboardGame);

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: AdminDashboardScreen()),
          ),
          GoRoute(
            path: '/rebuy-settlement',
            builder: (_, _) => const Scaffold(body: Text('SETTLEMENT')),
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

      // Tap on 'Levels' tab in tab strip
      final levelsTab = find.text('Levels');
      expect(levelsTab, findsWidgets);
      await tester.ensureVisible(levelsTab.first);
      await tester.tap(levelsTab.first);
      await tester.pumpAndSettle();

      // Find Edit Level 1 (1 < 3 => played level)
      final editL1 = find.bySemanticsLabel('Edit Level 1');
      await tester.ensureVisible(editL1);
      await tester.tap(editL1);
      await tester.pumpAndSettle();

      // Modal gate appears
      expect(find.text('Played level'), findsOneWidget);
      expect(find.textContaining('Edit it only to correct the record'), findsOneWidget);

      // Tap Correct the record
      await tester.tap(find.text('Correct the record'));
      await tester.pumpAndSettle();

      // Modal gate closes, DashboardLevelEditDialog opens with isPlayed: true
      expect(find.text('Played level'), findsNothing);
      expect(find.byType(DashboardLevelEditDialog), findsOneWidget);
      expect(find.text('Edit Level 1'), findsWidgets);
      expect(find.text('Recalculate after this'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      app.dispose();
    });
  });
}
