import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/pace_cards.dart';
import 'package:poker_night/widgets/structure_feasibility_card.dart';

/// C1 step 4's pace cards (§F1.3) and the §F1.5 point 7 blocking card.
void main() {
  PaceOption option({
    PaceMode pace = PaceMode.regular,
    bool fits = true,
    bool bankOk = true,
    int overBy = 0,
  }) =>
      (
        pace: pace,
        openingBB: 10,
        openingSB: 5,
        startingDepthBB: 120,
        levels: 14,
        levelMinutes: pace.levelMinutes,
        fits: fits,
        overBy: overBy,
        finishMins: 270,
        bankOk: bankOk,
      );

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
    );
  }

  group('pace cards', () {
    testWidgets('shows every pace with its own numbers', (tester) async {
      await pump(
        tester,
        PaceCards(
          options: (
            options: [
              option(pace: PaceMode.turbo),
              option(pace: PaceMode.regular),
              option(pace: PaceMode.deep),
            ],
            recommended: PaceMode.regular,
            warning: null,
            choices: const [],
          ),
          selected: null,
          onSelected: (_) {},
        ),
      );

      expect(find.text('Turbo'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Deep'), findsOneWidget);
      expect(find.text('15-min levels'), findsOneWidget);
      expect(find.text('20-min levels'), findsOneWidget);
      expect(find.text('30-min levels'), findsOneWidget);
      expect(find.text('120 BB'), findsNWidgets(3));
    });

    testWidgets('only the recommended pace is badged', (tester) async {
      await pump(
        tester,
        PaceCards(
          options: (
            options: [
              option(pace: PaceMode.turbo),
              option(pace: PaceMode.regular),
              option(pace: PaceMode.deep),
            ],
            recommended: PaceMode.deep,
            warning: null,
            choices: const [],
          ),
          selected: null,
          onSelected: (_) {},
        ),
      );
      expect(find.text('SUGGESTED'), findsOneWidget);
    });

    testWidgets('tapping a card reports that pace and nothing else',
        (tester) async {
      final picked = <PaceMode>[];
      await pump(
        tester,
        PaceCards(
          options: (
            options: [option(pace: PaceMode.turbo), option(pace: PaceMode.deep)],
            recommended: PaceMode.deep,
            warning: null,
            choices: const [],
          ),
          selected: null,
          onSelected: picked.add,
        ),
      );
      await tester.tap(find.text('Turbo'));
      expect(picked, [PaceMode.turbo]);
    });

    testWidgets('a pace that does not fit says how far over it runs',
        (tester) async {
      await pump(
        tester,
        PaceCards(
          options: (
            options: [option(fits: false, overBy: 45)],
            recommended: null,
            warning: null,
            choices: const [],
          ),
          selected: null,
          onSelected: (_) {},
        ),
      );
      expect(find.text('Runs 45 min over'), findsOneWidget);
    });

    testWidgets('a pace the chip case cannot fund says so', (tester) async {
      await pump(
        tester,
        PaceCards(
          options: (
            options: [option(bankOk: false)],
            recommended: null,
            warning: null,
            choices: const [],
          ),
          selected: null,
          onSelected: (_) {},
        ),
      );
      expect(find.text('Chip case too small'), findsOneWidget);
    });

    testWidgets('when nothing fits it warns and offers the named choices',
        (tester) async {
      var later = 0;
      var dropped = 0;
      final picked = <PaceMode>[];
      await pump(
        tester,
        PaceCards(
          options: (
            options: [option(pace: PaceMode.regular, fits: false, overBy: 20)],
            recommended: null,
            warning: 'At a regular pace this field needs about 4h50; '
                'the night has 4h30.',
            choices: const ['later', 'noAddOn', 'turbo'],
          ),
          selected: null,
          onSelected: picked.add,
          onChooseLater: () => later++,
          onDropAddOn: () => dropped++,
        ),
      );

      expect(find.text('No pace fits this night'), findsOneWidget);
      expect(find.textContaining('4h50'), findsOneWidget);

      await tester.tap(find.text('Finish later'));
      await tester.tap(find.text('Drop the add-on'));
      await tester.tap(find.text('Play turbo'));
      expect(later, 1);
      expect(dropped, 1);
      // §F1.3: turbo is available as an explicit escape, never as a default.
      expect(picked, [PaceMode.turbo]);
    });

    testWidgets('a choice the inputs do not allow is not offered',
        (tester) async {
      // No add-on on the event, so `noAddOn` is absent from `choices` and the
      // button must not appear.
      await pump(
        tester,
        PaceCards(
          options: (
            options: [option(fits: false, overBy: 20)],
            recommended: null,
            warning: 'nothing fits',
            choices: const ['later', 'turbo'],
          ),
          selected: null,
          onSelected: (_) {},
          onChooseLater: () {},
        ),
      );
      expect(find.text('Drop the add-on'), findsNothing);
      expect(find.text('Finish later'), findsOneWidget);
    });

    testWidgets('no options renders nothing at all', (tester) async {
      await pump(
        tester,
        PaceCards(
          options: (
            options: const [],
            recommended: null,
            warning: null,
            choices: const [],
          ),
          selected: null,
          onSelected: (_) {},
        ),
      );
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('feasibility card', () {
    TournamentStructure structure({
      bool feasible = true,
      bool fits = true,
      int overBy = 0,
      int? maxPlayers,
      String? note,
    }) =>
        TournamentStructure(
          startingStack: 1000,
          chipPlan: const [],
          rebuyStack: 1000,
          rebuyChipPlan: const [],
          addOnStack: 1000,
          addOnChipPlan: const [],
          levels: const [],
          levelDuration: 20,
          expectedFinishMins: 240,
          prizes: const [],
          prizePool: 0,
          organizerAmount: 0,
          colorUpInstructions: const [],
          warnings: const [],
          feasible: feasible,
          fits: fits,
          paceOverByMins: overBy,
          maxPlayersSupported: maxPlayers,
          depthShortfallNote: note,
        );

    testWidgets('silent when the structure is fine', (tester) async {
      await pump(
        tester,
        StructureFeasibilityCard(structure: structure(), players: 10),
      );
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('blocks when the chip case is too small', (tester) async {
      await pump(
        tester,
        StructureFeasibilityCard(
          structure: structure(feasible: false, maxPlayers: 8),
          players: 14,
          onEditChips: () {},
          onFewerRebuys: () {},
          onPlayFreezeOut: () {},
        ),
      );
      expect(find.text('Your chip case is too small for this field'),
          findsOneWidget);
      // §F1.5 point 7's three named buttons.
      expect(find.text('Edit chips'), findsOneWidget);
      expect(find.text('Fewer rebuys'), findsOneWidget);
      expect(find.text('Play a freeze-out'), findsOneWidget);
    });

    testWidgets('prefers the engine\'s own sentence when it produced one',
        (tester) async {
      await pump(
        tester,
        StructureFeasibilityCard(
          structure: structure(feasible: false, note: 'Engine said this.'),
          players: 14,
        ),
      );
      expect(find.text('Engine said this.'), findsOneWidget);
    });

    testWidgets('warns, but does not block, when it only runs over',
        (tester) async {
      await pump(
        tester,
        StructureFeasibilityCard(
          structure: structure(fits: false, overBy: 90),
          players: 10,
        ),
      );
      expect(find.text('This structure runs past your finish time'),
          findsOneWidget);
      expect(find.textContaining('1h30'), findsOneWidget);
      // The chip-case buttons belong to the blocking case only.
      expect(find.text('Play a freeze-out'), findsNothing);
    });

    testWidgets('offers the field reduction only when the engine sized it',
        (tester) async {
      await pump(
        tester,
        StructureFeasibilityCard(
          structure: structure(feasible: false, maxPlayers: 9),
          players: 14,
          onReduceField: () {},
        ),
      );
      expect(find.text('Reduce to 9 players'), findsOneWidget);
    });
  });
}
