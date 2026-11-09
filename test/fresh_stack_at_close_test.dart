import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/event_settings_form.dart';

/// Decision (WP1 review): the rebuy-close M floor is NOT changed. When the host
/// picks a close level, show them what a fresh stack is worth there:
/// "Fresh stack at L{n}: {x} BB, M {m}" — so the trade-off is visible, and the
/// suggestion is never silently overridden.
///
/// The numbers are the spec's own: §F1.16 step 8 lists, for the demo night
/// (stack 200, no ante yet at L3-L5), freshM 22.2 / 16.7 / 13.3 and fresh depth
/// 33.3 / 25.0 / 20.0 BB at L3 / L4 / L5.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppColors.currentPalette = ThemePalettes.forId('red'));

  const demoChips = [
    ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 120),
    ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
    ChipColor(color: 'Green', hex: 0xFF27AE60, value: 25, quantity: 80),
    ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 40),
  ];

  TournamentStructure demo({bool rebuy = true}) => TournamentEngine.generate(
        TournamentParams(
          players: 10,
          durationHours: 4.5,
          buyIn: 50,
          chipSet: demoChips,
          rebuys: rebuy,
          rebuysCloseLevel: 4,
          addOn: rebuy,
          anteEnabled: true,
          anteAfterLevel: 5,
          koEnabled: false,
          koAmount: 0,
          organizerPct: 0,
          format: rebuy ? TournamentFormat.rebuy : TournamentFormat.freezeOut,
          startTime: '20:00',
          endBy: '00:30',
          pace: PaceMode.regular,
          expectedRebuyRate: rebuy ? 0.35 : 0,
          addOnMultiplier: 1.25,
          addOnTakeUpRate: 0.7,
          earlyArrivalBonusEnabled: true,
          earlyArrivalBonusPctOverride: 0.125,
        ),
      );

  group('TournamentStructure.freshStackAt — the spec\'s §F1.16 step 8 numbers', () {
    final s = demo();

    test('the demo night deals 200 and opens 1/2 (the control)', () {
      expect(s.startingStack, 200);
      expect(s.levels.first.bb, 2);
    });

    test('L3 / L4 / L5 -> M 22.2 / 16.7 / 13.3 and 33.3 / 25.0 / 20.0 BB', () {
      final l3 = s.freshStackAt(3)!;
      final l4 = s.freshStackAt(4)!;
      final l5 = s.freshStackAt(5)!;
      expect(l3.m, closeTo(22.2, 0.05));
      expect(l4.m, closeTo(16.7, 0.05));
      expect(l5.m, closeTo(13.3, 0.05));
      expect(l3.depthBB, closeTo(33.3, 0.05));
      expect(l4.depthBB, closeTo(25.0, 0.05));
      expect(l5.depthBB, closeTo(20.0, 0.05));
    });

    test('the ante is NOT counted at the level asked about (§F1.8: it starts '
        'the level after the close)', () {
      // In the final ladder the ante begins at L5 (close at L4), so L5 carries
      // a BB ante of 10 — yet the spec's table reads L5 as 13.3 (= 200 / 15):
      // a stack bought at the close level meets the blinds alone.
      expect(s.levels[4].ante, 10);
      expect(s.freshStackAt(5)!.m, closeTo(13.3, 0.05));
      expect(s.freshStackAt(6)!.m, closeTo(200 / 18, 0.05)); // 6/12, no ante
    });

    test('anteLive: true counts a running ante (BB ante = one BB per orbit)', () {
      final withAnte = FreshStack.at(
        startingStack: s.startingStack,
        levels: s.levels,
        level: 6,
        anteLive: true,
      )!;
      expect(withAnte.m, closeTo(200 / (6 + 12 + 12), 0.05)); // 6.7
    });

    test('an individual ante is read as 8 payers', () {
      const levels = [
        BlindLevel(level: 1, sb: 5, bb: 10, ante: 4, durationMins: 20),
      ];
      final m = FreshStack.at(
        startingStack: 200,
        levels: levels,
        level: 1,
        anteLive: true,
      )!
          .m;
      expect(m, closeTo(200 / (5 + 10 + 4 * 8), 0.01));
    });

    test('out-of-range levels have no answer rather than a wrong one', () {
      expect(s.freshStackAt(0), isNull);
      expect(s.freshStackAt(-3), isNull);
      expect(s.freshStackAt(s.levels.length + 1), isNull);
    });

    test('the label reads "Fresh stack at L{n}: {x} BB, M {m}"', () {
      expect(s.freshStackAt(4)!.label, 'Fresh stack at L4: 25 BB, M 16.7');
    });
  });

  group('explain[] carries it for the close the structure uses', () {
    test('a rebuy night explains the close with the fresh-stack numbers', () {
      final s = demo();
      final e = s.explanationFor('rebuyClose');
      expect(e, isNotNull);
      expect(s.rebuysCloseLevel, 4);
      expect(e!.text, contains('L4'));
      expect(e.text, contains('25 BB'));
      expect(e.text, contains('M 16.7'));
      expect(e.numbers['level'], 4);
      expect(e.numbers['m'], closeTo(16.7, 0.05));
    });

    test('a freeze-out has no rebuy close to explain', () {
      expect(demo(rebuy: false).explanationFor('rebuyClose'), isNull);
    });
  });

  group('the host\'s close-level picker shows it', () {
    final s = demo();

    GameSettings settings() => GameSettings(
          name: 'Friday',
          date: '2026-10-12',
          time: '20:00',
          location: 'Basement',
          players: 10,
          durationHours: 4,
          buyIn: 20,
          koEnabled: false,
          koAmount: 0,
          rebuys: true,
          rebuysCloseLevel: 6,
          addOn: true,
          anteEnabled: true,
          anteAfterLevel: 6,
          organizerPct: 0,
          chipSet: demoChips,
          chipSetName: 'Demo',
          pace: PaceMode.regular,
        );

    Future<void> pump(
      WidgetTester t, {
      FreshStack? Function(int level)? lookup,
    }) async {
      await t.binding.setSurfaceSize(const Size(700, 3000));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EventSettingsForm(
              initial: settings(),
              sections: const {EventFormSection.rebuys},
              onChanged: (_) {},
              freshStackAt: lookup,
            ),
          ),
        ),
      ));
      await t.pump();
    }

    testWidgets('shows the fresh stack at the level currently picked (L6)',
        (t) async {
      await pump(t, lookup: s.freshStackAt);
      expect(find.text(s.freshStackAt(6)!.label), findsOneWidget);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('picking another level updates it, and nothing else decides',
        (t) async {
      await pump(t, lookup: s.freshStackAt);
      await t.tap(find.text('End L4').first); // the rebuy picker, not add-on's
      await t.pump();
      expect(find.text(s.freshStackAt(4)!.label), findsOneWidget);
      expect(find.text(s.freshStackAt(6)!.label), findsNothing);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('no lookup supplied -> no line (the form stays self-contained)',
        (t) async {
      await pump(t);
      expect(find.textContaining('Fresh stack at'), findsNothing);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('a level the structure doesn\'t reach shows no line', (t) async {
      await pump(t, lookup: (_) => null);
      expect(find.textContaining('Fresh stack at'), findsNothing);
      await t.binding.setSurfaceSize(null);
    });
  });
}
