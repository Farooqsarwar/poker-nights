import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:poker_night/widgets/structure_builder.dart';

void main() {
  group('M2: Stack first with a real shortfall message (B8)', () {
    test('Home Set (4 colour) with 10 players rebuy at 525 stack reports shortfall', () {
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final c = StructureBuilderController(
        mode: BuilderMode.quick,
        chipSet: chipSet,
        players: 10,
        durationHours: 4,
        format: TournamentFormat.rebuy,
      );

      c.setStack(525);

      expect(c.structure.feasible, isFalse,
          reason: '525 stack on 10p rebuy with Home Set must be infeasible');
      expect(c.structure.isBlocked, isTrue);
      expect(c.structure.bankShortfall, isNotEmpty,
          reason: 'Must report which chip is short');

      final shortColors = c.structure.bankShortfall.map((s) => s.colour).toList();
      expect(shortColors, contains('White'));
      expect(shortColors, contains('Blue'));
    });

    testWidgets('525 stack on Home Set: Approve disabled, shortfall shown, one-tap fix available',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final c = StructureBuilderController(
        mode: BuilderMode.quick,
        chipSet: chipSet,
        players: 10,
        durationHours: 4,
        format: TournamentFormat.rebuy,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructureBuilder(
                controller: c,
                confirmLabel: 'Confirm',
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      // Advance from inputs step to stack step
      final nextButton = find.byKey(const Key('builder-next'));
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Enter 525 into the stack field
      final stackField = find.byKey(const Key('stack-field'));
      expect(stackField, findsOneWidget);
      await tester.ensureVisible(stackField);
      await tester.enterText(stackField, '525');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // 1. Approve stack is disabled
      final approveFinder = find.byKey(const Key('approve-stack'));
      await tester.ensureVisible(approveFinder);
      final approveButton = tester.widget<AppButton>(approveFinder);
      expect(approveButton.onPressed, isNull,
          reason: 'Approve stack must be disabled when chips are short (B8 / M2)');

      // 2. Shortfall message says which chip is short and by how much
      expect(find.textContaining('Short'), findsWidgets);
      expect(find.textContaining('White'), findsWidgets);
      expect(find.textContaining('Blue'), findsWidgets);

      // 3. One-tap fix is offered: "Play a freeze-out" or "Fewer rebuys"
      final fixButton = find.text('Play a freeze-out');
      expect(fixButton, findsOneWidget);

      // Tapping the one-tap fix restores format/feasibility
      await tester.ensureVisible(fixButton);
      await tester.tap(fixButton);
      await tester.pumpAndSettle();

      expect(c.format, equals(TournamentFormat.freezeOut));
    });

    testWidgets('typing 525 and tapping Approve without enter gives feedback, never advances',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 3000));
      final chipSet = TournamentEngine.getPreset('Home Set (4 colour)');
      final c = StructureBuilderController(
        mode: BuilderMode.quick,
        chipSet: chipSet,
        players: 10,
        durationHours: 4,
        format: TournamentFormat.rebuy,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructureBuilder(
                controller: c,
                confirmLabel: 'Confirm',
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      // Advance from inputs step to stack step
      final nextButton = find.byKey(const Key('builder-next'));
      await tester.ensureVisible(nextButton);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Type 525 without pressing done/enter
      final stackField = find.byKey(const Key('stack-field'));
      await tester.ensureVisible(stackField);
      await tester.enterText(stackField, '525');
      // No receiveAction!

      // Tap Approve stack directly
      final approveFinder = find.byKey(const Key('approve-stack'));
      await tester.ensureVisible(approveFinder);
      await tester.tap(approveFinder);
      await tester.pumpAndSettle();

      // Must NOT advance to structure step (step-levels)
      expect(find.byKey(const Key('builder-step-levels')), findsNothing,
          reason: 'Cannot advance to levels when typed stack causes shortfall');
      // Must now show shortfall
      expect(find.textContaining('Short'), findsWidgets);
    });
  });
}
