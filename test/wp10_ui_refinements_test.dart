import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/clock_sequence.dart';
import 'package:poker_night/screens/public/tools_screen.dart';

void main() {
  group('WP10 UI & Free Tools Refinements', () {
    test('ClockSequence.build imports all levels when importAllLevels is true (F2 / #30)', () {
      final levels = List.generate(
        17,
        (i) => BlindLevel(
          level: i + 1,
          sb: (i + 1) * 25,
          bb: (i + 1) * 50,
          durationMins: 15,
          ante: 0,
        ),
      );
      final structure = TournamentStructure(
        startingStack: 5000,
        chipPlan: const [],
        rebuyStack: 5000,
        rebuyChipPlan: const [],
        addOnStack: 5000,
        addOnChipPlan: const [],
        levels: levels,
        levelDuration: 15,
        plannedLevels: 13, // planned is 13, total is 17
        expectedFinishMins: 13 * 15,
        prizes: const [],
        prizePool: 0,
        organizerAmount: 0,
        colorUpInstructions: const [],
        warnings: const [],
        breaks: const [],
      );

      // Default behavior (plannedLevels truncation)
      final defaultSegments = ClockSequence.build(structure);
      expect(defaultSegments.length, 13);

      // New importAllLevels behavior (no truncation per Dani F2)
      final allSegments = ClockSequence.build(structure, importAllLevels: true);
      expect(allSegments.length, 17);
    });

    testWidgets('ToolNextStepBar renders title, subtitle, and fires action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolNextStepBar(
              title: 'Next step: Tournament Clock',
              subtitle: 'Carry over all 17 levels with no truncation.',
              actionLabel: 'Open Clock',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Next step: Tournament Clock'), findsOneWidget);
      expect(find.text('Carry over all 17 levels with no truncation.'), findsOneWidget);
      expect(find.text('Open Clock'), findsOneWidget);

      await tester.tap(find.text('Open Clock'));
      expect(tapped, isTrue);
    });
  });
}
