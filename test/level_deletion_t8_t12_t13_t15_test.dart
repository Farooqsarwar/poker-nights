import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/widgets/structure_editor.dart';
import 'package:poker_night/widgets/dashboard_level_edit_dialog.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/utils/tournament_engine.dart';

void main() {
  group('Structure editor level deletion and breaks (T8, T9, T12, T13, T15)', () {
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
  });
}
