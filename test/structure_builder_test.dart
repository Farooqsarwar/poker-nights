import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/screens/tournament/quick_start_screen.dart';
import 'package:poker_night/screens/tournament/structure_review_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/utils/structure_builder_controller.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:poker_night/widgets/structure_builder.dart';
import 'package:provider/provider.dart';

/// WP2: the shared stack-first StructureBuilder, from the controller up to the
/// three entry points (quick game, Create structure, free blind generator).
const _host = AppUser(
  id: 'u1',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);
const _group = Group(
  id: 'grp1',
  name: 'Friday',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

List<ChipColor> get _homeSet => TournamentEngine.getPreset('Home Set (4 colour)');

StructureBuilderController _ctl({
  TournamentFormat format = TournamentFormat.freezeOut,
  int players = 8,
  List<ChipColor>? chips,
  bool synthetic = false,
}) =>
    StructureBuilderController(
      mode: BuilderMode.tool,
      chipSet: chips ?? kToolChipSets.values.first,
      syntheticBank: synthetic,
      players: players,
      durationHours: 4,
      format: format,
    );

GameSettings _eventSettings({
  int players = 10,
  bool rebuys = true,
  int? forceStack,
  List<LevelPin> pins = const [],
}) =>
    GameSettings(
      name: 'Friday',
      date: '2026-10-12',
      time: '20:00',
      location: 'Basement',
      players: players,
      durationHours: 4,
      buyIn: 20,
      koEnabled: false,
      koAmount: 0,
      rebuys: rebuys,
      rebuysCloseLevel: 0,
      addOn: rebuys,
      anteEnabled: true,
      anteAfterLevel: 6,
      organizerPct: 0,
      chipSet: _homeSet,
      chipSetName: 'Home Set',
      pace: PaceMode.regular,
      forceStack: forceStack,
      levelPins: pins,
    );

LiveGame _eventGame(GameSettings s) => LiveGame(
      id: 'g1',
      groupId: 'grp1',
      settings: s,
      structure: TournamentEngine.generate(TournamentParams(
        players: s.players,
        durationHours: 4,
        buyIn: 20,
        chipSet: s.chipSet,
        rebuys: s.rebuys,
        rebuysCloseLevel: 0,
        reEntry: false,
        addOn: s.addOn,
        anteEnabled: true,
        anteAfterLevel: 6,
        koEnabled: false,
        koAmount: 0,
        organizerPct: 0,
        pace: PaceMode.regular,
      )),
      status: LiveGameStatus.ready,
      publicCode: 'ABC123',
      tvCode: 'TV7890',
      currentLevel: 1,
      timerRunning: false,
      secondsRemaining: 900,
      players: [
        for (var i = 0; i < s.players; i++)
          Player(
            id: 'p$i',
            name: 'P$i',
            isGuest: false,
            rsvp: Rsvp.going,
            checkedIn: true,
            confirmed: true,
            eliminated: false,
            rebuys: 0,
            reEntries: 0,
            hasAddOn: false,
            knockouts: 0,
            table: 1,
            seat: i + 1,
            active: true,
          ),
      ],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 0,
      pendingGuests: const [],
      finishOrder: const [],
      seatingConfirmed: true,
    );

AppProvider _eventApp(GameSettings s) => AppProvider()
  ..setUserForTesting(_host)
  ..setCurrentGroupForTesting(_group)
  ..setCurrentGame(_eventGame(s));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    RecoveryService.enabled = false;
    AppColors.currentPalette = ThemePalettes.forId('red');
  });
  tearDown(() => RecoveryService.enabled = true);

  Future<void> mount(
    WidgetTester t,
    Widget screen, {
    AppProvider? app,
    ValueChanged<Object?>? onClock,
  }) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            Scaffold(backgroundColor: Colors.transparent, body: screen),
      ),
      GoRoute(
        path: '/tools/clock',
        builder: (_, state) {
          onClock?.call(state.extra);
          return const Scaffold(body: Text('CLOCK'));
        },
      ),
      GoRoute(
          path: '/invitation',
          builder: (_, _) => const Scaffold(body: Text('INVITATION'))),
    ]);
    await t.binding.setSurfaceSize(const Size(800, 4800));
    final tree = MaterialApp.router(routerConfig: router);
    await t.pumpWidget(app == null
        ? tree
        : ChangeNotifierProvider<AppProvider>.value(value: app, child: tree));
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> unmount(WidgetTester t, [AppProvider? app]) async {
    await t.pumpWidget(const SizedBox.shrink());
    app?.dispose();
    await t.pump();
    await t.binding.setSurfaceSize(null);
  }

  Future<void> tapKey(WidgetTester t, String key) async {
    final f = find.byKey(Key(key));
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pump(const Duration(milliseconds: 100));
  }

  group('stack step comes before any level, at every entry point', () {
    Future<void> walk(WidgetTester t) async {
      expect(find.byKey(const Key('builder-step-inputs')), findsOneWidget);
      expect(find.byKey(const Key('level-row-1')), findsNothing);
      await tapKey(t, 'builder-next');
      expect(find.byKey(const Key('builder-step-stack')), findsOneWidget);
      expect(find.byKey(const Key('stack-value')), findsOneWidget);
      final chipDistribution = find.byKey(const Key('stack-chips'));
      expect(chipDistribution, findsOneWidget,
          reason: 'the per-player chip distribution is visible before approval');
      expect(t.widget<Text>(chipDistribution).data, isNot(isEmpty),
          reason: 'the distribution describes the chips per player');
      expect(find.byKey(const Key('approve-stack')), findsOneWidget);
      expect(find.byKey(const Key('level-row-1')), findsNothing,
          reason: 'no level is shown before the stack is approved');
      await tapKey(t, 'approve-stack');
      expect(find.byKey(const Key('builder-step-structure')), findsOneWidget);
      expect(find.byKey(const Key('level-row-1')), findsOneWidget);
    }

    testWidgets('quick game (/quick)', (t) async {
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group);
      await mount(t, const QuickStartScreen(), app: app);
      await walk(t);
      await unmount(t, app);
    });

    testWidgets('Create structure (from an event)', (t) async {
      final app = _eventApp(_eventSettings());
      await mount(t, const StructureReviewScreen(), app: app);
      await walk(t);
      await unmount(t, app);
    });

    testWidgets('free blind generator (/tools/blinds)', (t) async {
      await mount(t, const ToolBlindsScreen());
      await walk(t);
      await unmount(t);
    });
  });

  group('ante: no "Recommended" control', () {
    testWidgets('Yes/No then Big blind / Individual only', (t) async {
      await mount(t, const ToolBlindsScreen());
      // The tool opens with antes off; turn them on to see the style choice.
      await t.tap(find.text('Yes').last);
      await t.pump();
      expect(find.text('Big blind'), findsOneWidget);
      expect(find.text('Individual'), findsOneWidget);
      expect(find.textContaining('Recommend'), findsNothing);
      await unmount(t);
    });
  });

  group('the stack is edited first, and survives', () {
    test('editing the stack forces it and re-runs the engine', () {
      final c = _ctl();
      final engine = c.structure.startingStack;
      c.setStack(engine + c.roundUnit * 2);
      expect(c.structure.startingStack, engine + c.roundUnit * 2);
      expect(c.forceStack, engine + c.roundUnit * 2);
      c.clearForcedStack();
      expect(c.structure.startingStack, engine);
    });

    testWidgets(
      'Home 25 forced to 40,000 shows its colour shortfall and blocks approval',
      (t) async {
        const home25 = [
          ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 100),
          ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 100),
          ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 80),
          ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 50),
          ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 30),
        ];
        final c = _ctl(chips: home25, players: 9)..setStack(40000);
        await t.binding.setSurfaceSize(const Size(800, 4800));
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StructureBuilder(
                  controller: c,
                  confirmLabel: 'Go',
                  onConfirm: (_) => fail('an underfunded stack cannot confirm'),
                ),
              ),
            ),
          ),
        );

        await tapKey(t, 'builder-next');
        expect(find.text('Your chips fall short for this night.'), findsOneWidget);
        expect(find.textContaining('Yellow'), findsWidgets);
        expect(find.textContaining(RegExp(r'Short \d+× Yellow')), findsWidgets);
        expect(
          t.widget<AppButton>(find.byKey(const Key('approve-stack'))).onPressed,
          isNull,
        );
        await unmount(t);
      },
    );

    testWidgets('unnumbered chips show the assumed-values note on the stack step', (
      t,
    ) async {
      const unnumbered = [
        ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 0, quantity: 150),
        ChipColor(color: 'Red', hex: 0xFFC0392B, value: 0, quantity: 100),
        ChipColor(color: 'Green', hex: 0xFF27AE60, value: 0, quantity: 80),
        ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 0, quantity: 50),
      ];
      final c = _ctl(chips: unnumbered, players: 8);
      await t.binding.setSurfaceSize(const Size(800, 4800));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StructureBuilder(
                controller: c,
                confirmLabel: 'Go',
                onConfirm: (_) {},
              ),
            ),
          ),
        ),
      );

      await tapKey(t, 'builder-next');
      expect(find.byKey(const Key('stack-assumed-values')), findsOneWidget);
      expect(find.textContaining('values were assumed'), findsOneWidget);
      await unmount(t);
    });

    test('the controller depth maps tournament types and the custom stepper', () {
      final c = _ctl();
      expect(c.depthBB, 100);
      c.setType(TournamentType.turbo);
      expect(c.depthBB, 75);
      c.setType(TournamentType.deep);
      expect(c.depthBB, 150);
      c.useCustomDepth();
      expect(c.customDepth, isTrue);
      c.setCustomDepth(175);
      expect(c.depthBB, 175);
      c.setCustomDepth(10);
      expect(c.depthBB, kCustomDepthMin);
      c.setCustomDepth(999);
      expect(c.depthBB, kCustomDepthMax);
      expect(c.params.targetDepthBB, kCustomDepthMax);
    });

    test('a stack edit survives Recalculate AND reopening', () {
      final base = _eventSettings(rebuys: false, players: 8);
      final c = StructureBuilderController.fromSettings(base);
      final engine = c.structure.startingStack;
      final forced = engine + c.roundUnit * 4;
      c.setStack(forced);
      final app = _eventApp(base);
      final game = app.currentGame!;
      expect(app.applyBuilderResult(c.applyTo(game.settings), c.resolved()),
          isTrue);
      expect(app.currentGame!.structure.startingStack, forced);

      // Recalculate rebuilds from the saved settings: the stack must stay.
      app.recalculateStructure();
      expect(app.currentGame!.structure.startingStack, forced);
      expect(app.currentGame!.settings.forceStack, forced);

      // Reopen: a new controller reads the same night back from the event.
      final reopened =
          StructureBuilderController.fromSettings(app.currentGame!.settings);
      expect(reopened.forceStack, forced);
      expect(reopened.structure.startingStack, forced);

      // And it survives the codec (a different device / a relaunch).
      final round = gameSettingsFromMap(gameSettingsToMap(app.currentGame!.settings));
      expect(round.forceStack, forced);
      app.dispose();
    });

    testWidgets('the event screen saves the stack as it is changed', (t) async {
      final app = _eventApp(_eventSettings(rebuys: false, players: 8));
      await mount(t, const StructureReviewScreen(), app: app);
      await tapKey(t, 'builder-next');
      await tapKey(t, 'stack-plus');
      final forced = app.currentGame!.settings.forceStack;
      expect(forced, isNotNull, reason: 'persisted without leaving the screen');
      expect(app.currentGame!.structure.startingStack, forced);

      // Leave the screen and reopen it: the same stack is shown first.
      await t.pumpWidget(const SizedBox.shrink());
      await mount(t, const StructureReviewScreen(), app: app);
      await tapKey(t, 'builder-next');
      expect(find.text('${_grouped(forced!)} chips'), findsOneWidget);
      await unmount(t, app);
    });
  });

  group('pinned rows and "Recalculate around this"', () {
    test('an edited row is pinned; only UNPINNED levels change on recalculate', () {
      final c = _ctl(format: TournamentFormat.rebuy, players: 8);
      c.approveStack();
      final before = c.structure.levels;
      final l5 = before[4];
      final typedBb = l5.bb + 2 * c.roundUnit;
      expect(c.editLevel(5, sb: typedBb ~/ 2, bb: typedBb, mins: l5.durationMins),
          isNull);
      expect(c.isPinned(5), isTrue);
      expect(c.hasPendingPins, isTrue);

      // Before the calculator: only the edited row moves on screen.
      final shown = c.levels;
      for (var i = 0; i < shown.length; i++) {
        if (i == 4) continue;
        expect((shown[i].sb, shown[i].bb), (before[i].sb, before[i].bb),
            reason: 'L${i + 1} is untouched until Recalculate');
      }
      expect(shown[4].bb, typedBb);

      c.recalculateAround();
      expect(c.hasPendingPins, isFalse);
      final after = c.structure.levels;
      expect(after[4].bb, typedBb, reason: 'the pinned row keeps its value');
      expect(after[4].sb, typedBb ~/ 2);
      expect(after[4].manuallyEdited, isTrue);
      var changed = 0;
      for (var i = 0; i < after.length; i++) {
        if (i == 4) continue;
        if (after[i].bb != before[i].bb || after[i].sb != before[i].sb) changed++;
      }
      expect(changed, greaterThan(0),
          reason: 'the unpinned levels are re-solved around the pin');
      // Levels before the pin stay strictly below it, after stay above.
      for (var i = 0; i < 4; i++) {
        expect(after[i].bb, lessThan(typedBb));
      }
      for (var i = 5; i < after.length; i++) {
        expect(after[i].bb, greaterThan(typedBb));
      }
    });

    test('an invalid edit is refused and pins nothing', () {
      final c = _ctl();
      c.approveStack();
      final err = c.editLevel(3, sb: 50, bb: 10, mins: 20);
      expect(err, isNotNull);
      expect(c.isPinned(3), isFalse);
      expect(c.editLevel(3, sb: 5, bb: 10, mins: 1), isNotNull);
    });

    test('typed minutes ride on the pinned row', () {
      final c = _ctl();
      final l2 = c.structure.levels[1];
      c.editLevel(2, sb: l2.sb, bb: l2.bb, mins: 30);
      c.recalculateAround();
      expect(c.structure.levels[1].durationMins, 30);
    });

    test('pins survive Recalculate and the codec', () {
      final c = StructureBuilderController.fromSettings(
          _eventSettings(rebuys: false, players: 8));
      final l4 = c.structure.levels[3];
      final bb = l4.bb + c.roundUnit;
      c.editLevel(4, sb: bb ~/ 2, bb: bb, mins: l4.durationMins);
      c.recalculateAround();
      final app = _eventApp(_eventSettings(rebuys: false, players: 8));
      app.applyBuilderResult(c.applyTo(app.currentGame!.settings), c.resolved());
      app.recalculateStructure();
      final lv = app.currentGame!.structure.levels[3];
      expect((lv.sb, lv.bb), (bb ~/ 2, bb));
      final round = gameSettingsFromMap(gameSettingsToMap(app.currentGame!.settings));
      expect(round.levelPins, [LevelPin(level: 4, sb: bb ~/ 2, bb: bb, durationMins: l4.durationMins)]);
      app.dispose();
    });

    testWidgets(
      'free blind tool edits a row and recalculates before confirmation',
      (t) async {
        await mount(t, const ToolBlindsScreen());
        await tapKey(t, 'builder-next');
        await tapKey(t, 'approve-stack');

        await tapKey(t, 'edit-level-2');
        final oldBb = int.parse(
          t.widget<TextField>(find.byKey(const Key('edit-bb-2'))).controller!.text,
        );
        await t.enterText(find.byKey(const Key('edit-bb-2')), '${oldBb * 2}');
        await t.enterText(find.byKey(const Key('edit-sb-2')), '$oldBb');
        await tapKey(t, 'save-level-2');

        expect(find.byKey(const Key('recalc-around-2')), findsOneWidget);
        expect(find.text('Recalculate around this'), findsOneWidget);
        expect(find.text('Use these blinds'), findsOneWidget);
        await tapKey(t, 'recalc-around-2');
        expect(find.byKey(const Key('recalc-around-2')), findsOneWidget);
        await unmount(t);
      },
    );
  });

  group('the rebuy-close marker', () {
    test('moving it moves the ante start and the add-on break', () {
      final c = _ctl(format: TournamentFormat.rebuy, players: 8);
      c.setAddOn(true);
      c.setAnteEnabled(true);
      int anteStart(TournamentStructure s) =>
          s.levels.indexWhere((l) => (l.ante ?? 0) > 0) + 1;
      int? addOnBreak(TournamentStructure s) {
        final close = s.rebuysCloseLevel;
        return s.breaks.where((b) => b.afterLevel == close).firstOrNull?.afterLevel;
      }

      final autoClose = c.rebuyCloseLevel;
      final planned = c.structure.effectivePlannedLevels;
      final target = autoClose == 3 ? 5 : 3;
      expect(target, lessThan(planned));
      final startBefore = anteStart(c.structure);
      c.setRebuyClose(target);
      final s = c.structure;
      expect(s.rebuysCloseLevel, target);
      expect(anteStart(s), target + 1,
          reason: 'the ante starts the level after rebuys close (§F1.8)');
      expect(anteStart(s), isNot(startBefore));
      expect(addOnBreak(s), target,
          reason: 'the add-on break sits at the end of the rebuy window');
      expect(c.rebuyCloseChosen, isTrue);
      expect(c.freshStackLabel, startsWith('Fresh stack at L$target:'));
      expect(c.freshStackLabel, contains('BB, M '));
    });

    test('a chosen close survives Recalculate (it is saved as the host\'s)', () {
      final c = StructureBuilderController.fromSettings(_eventSettings(players: 10));
      c.setRebuyClose(3);
      final app = _eventApp(_eventSettings(players: 10));
      app.applyBuilderResult(c.applyTo(app.currentGame!.settings), c.resolved());
      expect(app.currentGame!.settings.rebuyCloseChosenByOrganizer, isTrue);
      app.recalculateStructure();
      expect(app.currentGame!.structure.rebuysCloseLevel, 3);
      app.dispose();
    });

    testWidgets('the row marker moves and the fresh stack line is shown', (t) async {
      await mount(t, const ToolBlindsScreen());
      await tapKey(t, 'builder-next');
      await tapKey(t, 'approve-stack');
      expect(find.byKey(const Key('close-marker')), findsOneWidget);
      expect(find.text('Rebuys close after this level'), findsWidgets);
      await tapKey(t, 'close-here-3');
      expect(find.byKey(const Key('close-marker')), findsOneWidget);
      expect(
        find.descendant(
            of: find.byKey(const Key('level-row-3')),
            matching: find.byKey(const Key('close-marker'))),
        findsOneWidget,
      );
      expect(find.textContaining('Fresh stack at L3:'), findsOneWidget);
      await unmount(t);
    });
  });

  group('a blocked night cannot reach Confirm', () {
    final tiny = [
      const ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 500),
    ];

    test('Approve stack is refused and no level step is reachable', () {
      final c = _ctl(chips: tiny, players: 12);
      expect(c.isBlocked, isTrue);
      c.continueToStack();
      expect(c.approveStack(), isFalse);
      expect(c.step, BuilderStep.stack);
    });

    testWidgets('the blocked card shows; Approve is disabled; no Confirm', (t) async {
      final c = _ctl(
        chips: _homeSet,
        players: 100,
        format: TournamentFormat.rebuy,
      );
      await t.binding.setSurfaceSize(const Size(800, 4800));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructureBuilder(
              controller: c,
              confirmLabel: 'Go',
              onConfirm: (_) => fail('a blocked night must never confirm'),
            ),
          ),
        ),
      ));
      await tapKey(t, 'builder-next');
      expect(find.byKey(const Key('builder-step-stack')), findsOneWidget);
      expect(find.byKey(const Key('stack-bank')), findsOneWidget);
      expect(
        find.textContaining(
          'cannot give 100 players a playable stack (at least 20 big blinds)',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('It covers up to'), findsOneWidget);
      expect(find.text('Fewer rebuys'), findsOneWidget);
      expect(find.text('Play a freeze-out'), findsOneWidget);
      expect(find.textContaining('Reduce to '), findsOneWidget);
      final approve = t.widget<AppButton>(find.byKey(const Key('approve-stack')));
      expect(approve.onPressed, isNull);
      expect(find.byKey(const Key('builder-confirm')), findsNothing);
      await unmount(t);
    });

    test('the event cannot save a blocked structure', () {
      final c = _ctl(chips: tiny, players: 12);
      final app = _eventApp(_eventSettings(players: 12));
      final saved = app.applyBuilderResult(
          c.applyTo(app.currentGame!.settings), c.structure,
          confirm: true);
      expect(saved, isFalse);
      expect(app.currentGame!.structureConfirmed, isFalse);
      app.dispose();
    });
  });

  group('shallow card is wired into the builder (known gap closed)', () {
    test('Home Set, 10 players, rebuy: options exist and re-run the engine', () {
      final c = _ctl(format: TournamentFormat.rebuy, players: 10, chips: _homeSet);
      c.setRebuyLimit(null);
      expect(c.structure.isShallow, isTrue);
      final fixes = c.shallowFixes;
      expect(fixes, isNotEmpty);
      final skip = fixes.firstWhere((f) => f.kind == ShallowFixKind.skipAddOn);
      // Listing changed nothing.
      expect(c.addOn, isTrue);
      final before = c.structure.openingBBDepth!;
      c.applyShallowFix(skip);
      expect(c.addOn, isFalse);
      expect(c.structure.openingBBDepth, closeTo(skip.resultingDepthBB, 0.01));
      expect(c.structure.openingBBDepth!, greaterThan(before));
    });

    testWidgets('the card shows on the stack step; a tap deepens the stack',
        (t) async {
      final c = _ctl(format: TournamentFormat.rebuy, players: 10, chips: _homeSet);
      c.setRebuyLimit(null);
      await t.binding.setSurfaceSize(const Size(800, 4800));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructureBuilder(
                controller: c, confirmLabel: 'Go', onConfirm: (_) {}),
          ),
        ),
      ));
      await tapKey(t, 'builder-next');
      expect(find.textContaining('Shallow start'), findsOneWidget);
      final stackBefore = c.structure.startingStack;
      final skip = find.textContaining('Skip the add-on');
      expect(skip, findsOneWidget);
      expect(c.addOn, isTrue, reason: 'showing the option applied nothing');
      await t.ensureVisible(skip);
      await t.tap(skip);
      await t.pump();
      expect(c.addOn, isFalse, reason: 'the host\'s tap applied it');
      expect(c.structure.startingStack, greaterThan(stackBefore));
      await unmount(t);
    });
  });

  group('free tool → clock hand-off', () {
    testWidgets('"Use this structure in the tournament clock?" carries the levels',
        (t) async {
      Object? extra;
      await mount(t, const ToolBlindsScreen(), onClock: (e) => extra = e);
      await tapKey(t, 'builder-next');
      await tapKey(t, 'approve-stack');

      // Edit a level so the hand-off is provably THESE levels, not a rebuild.
      await tapKey(t, 'edit-level-3');
      final l3bb = int.parse(
          (t.widget<TextField>(find.byKey(const Key('edit-bb-3')))).controller!.text);
      final newBb = l3bb + 50;
      await t.enterText(find.byKey(const Key('edit-bb-3')), '$newBb');
      await t.enterText(find.byKey(const Key('edit-sb-3')), '${newBb ~/ 2}');
      await tapKey(t, 'save-level-3');
      await tapKey(t, 'recalc-around-3');

      await tapKey(t, 'builder-confirm');
      expect(find.text('Use this structure in the tournament clock?'),
          findsOneWidget);
      await t.tap(find.byKey(const Key('clock-yes')));
      await t.pumpAndSettle();

      expect(find.text('CLOCK'), findsOneWidget);
      final handoff = extra as ToolClockHandoff;
      expect(handoff.structure.levels[2].bb, newBb);
      expect(handoff.structure.levels[2].sb, newBb ~/ 2);
      expect(handoff.players, 9);
      expect(handoff.structure.isBlocked, isFalse);
      await unmount(t);
    });

    testWidgets('"No" stays on the structure and opens nothing', (t) async {
      Object? extra;
      await mount(t, const ToolBlindsScreen(), onClock: (e) => extra = e);
      await tapKey(t, 'builder-next');
      await tapKey(t, 'approve-stack');
      await tapKey(t, 'builder-confirm');
      await t.tap(find.byKey(const Key('clock-no')));
      await t.pumpAndSettle();
      expect(find.text('CLOCK'), findsNothing);
      expect(extra, isNull);
      expect(find.byKey(const Key('builder-step-structure')), findsOneWidget);
      await unmount(t);
    });

    testWidgets('the clock tool plays the handed-over levels', (t) async {
      final c = _ctl(players: 9, synthetic: true);
      final s = c.structure;
      await t.binding.setSurfaceSize(const Size(800, 4800));
      final app = AppProvider();
      await t.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp(
          home: ToolClockScreen(
            handoff: ToolClockHandoff(structure: s, players: 9, hours: 4),
          ),
        ),
      ));
      await t.pump();
      expect(find.textContaining('${s.levels.first.sb}'), findsWidgets);
      expect(find.textContaining('${s.levels.first.bb}'), findsWidgets);
      await unmount(t, app);
    });
  });

  group('quick game: the approved night is what runs', () {
    testWidgets('edited stack → confirm → the clock runs on that stack',
        (t) async {
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group);
      await mount(t, const QuickStartScreen(), app: app);
      await tapKey(t, 'builder-next');
      await tapKey(t, 'stack-plus');
      final forced = app.currentGame == null
          ? int.parse(t
              .widget<Text>(find.byKey(const Key('stack-value')))
              .data!
              .replaceAll(RegExp(r'[^0-9]'), ''))
          : 0;
      await tapKey(t, 'approve-stack');
      expect(app.currentGame, isNull, reason: 'nothing is created before confirm');
      await tapKey(t, 'builder-confirm');
      await t.pump(const Duration(milliseconds: 500));
      final game = app.currentGame;
      expect(game, isNotNull);
      expect(game!.settings.forceStack, forced);
      expect(game.structure.startingStack, forced,
          reason: 'the stack the host approved, not a regenerated one');
      expect(game.structureConfirmed, isTrue);
      await unmount(t, app);
    });
  });

  group('player names (quick game)', () {
    test('add / remove rows, never more than the player count', () {
      final c = StructureBuilderController(
        mode: BuilderMode.quick,
        chipSet: kToolChipSets.values.first,
        players: 3,
      );
      expect(c.playerNames, isEmpty);
      expect(c.addPlayerName(), isTrue);
      expect(c.addPlayerName(), isTrue);
      expect(c.addPlayerName(), isTrue);
      expect(c.addPlayerName(), isFalse, reason: 'a fourth name for 3 players');
      c.setPlayerName(0, ' Alex ');
      c.setPlayerName(2, 'Sam');
      expect(c.namesToSeat, ['Alex', 'Sam'], reason: 'trimmed, blanks skipped');
      c.removePlayerName(1);
      expect(c.playerNames.length, 2);
      c.setPlayers(3);
      c.addPlayerName();
      c.setPlayers(2);
      expect(c.playerNames.length, lessThanOrEqualTo(2),
          reason: 'shrinking the field trims the rows');
    });

    testWidgets('typed names reach the game; blank players stay "Player N"',
        (t) async {
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group);
      await mount(t, const QuickStartScreen(), app: app);
      expect(find.text('Player names (optional)'), findsOneWidget);
      await tapKey(t, 'add-name');
      await tapKey(t, 'add-name');
      await t.enterText(find.byKey(const Key('name-field-0-2')), 'Alex');
      await t.enterText(find.byKey(const Key('name-field-1-2')), 'Sam');
      await tapKey(t, 'builder-next');
      await tapKey(t, 'approve-stack');
      await tapKey(t, 'builder-confirm');
      await t.pump(const Duration(milliseconds: 500));
      final names = app.currentGame!.players.map((p) => p.name).toList();
      expect(names.take(2), ['Alex', 'Sam']);
      expect(names[2], startsWith('Player'));
      await unmount(t, app);
    });

    testWidgets('only the quick game shows the names section', (t) async {
      await mount(t, const ToolBlindsScreen());
      expect(find.text('Player names (optional)'), findsNothing);
      await unmount(t);
    });
  });

  group('every control of the old review screen is reachable', () {
    Future<void> openMore(WidgetTester t) async {
      final tile = find.byKey(const Key('more-options'));
      await t.ensureVisible(tile);
      await t.tap(tile);
      await t.pumpAndSettle();
    }

    Future<void> type(WidgetTester t, String key, String text) async {
      final f = find.byKey(Key(key));
      await t.ensureVisible(f);
      await t.enterText(f, text);
      await t.pump();
    }

    Future<void> pumpBuilder(
        WidgetTester t, StructureBuilderController c) async {
      await t.binding.setSurfaceSize(const Size(800, 6000));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructureBuilder(
                controller: c, confirmLabel: 'Go', onConfirm: (_) {}),
          ),
        ),
      ));
      await openMore(t);
    }

    testWidgets('buy-in, level length, organiser, table size, paid places',
        (t) async {
      final c = _ctl(players: 8);
      await pumpBuilder(t, c);
      await type(t, 'opt-buyin', '40');
      await type(t, 'opt-level-mins', '25');
      await type(t, 'opt-organiser', '10');
      await type(t, 'opt-max-per-table', '7');
      await type(t, 'opt-paid-places', '3');
      final s = c.applyTo(_eventSettings(players: 8, rebuys: false));
      expect(s.buyIn, 40);
      expect(s.levelDurationMins, 25);
      expect(s.organizerPct, 10);
      expect(s.tableSettingsOverride?.maxPerTable, 7);
      expect(s.forcePaidPlaces, 3);
      // Blank hands the decision back.
      await type(t, 'opt-paid-places', '');
      await type(t, 'opt-max-per-table', '');
      final back = c.applyTo(s);
      expect(back.forcePaidPlaces, isNull);
      expect(back.tableSettingsOverride, isNull);
      await unmount(t);
    });

    testWidgets('knockout bounty on / off and its amount', (t) async {
      final c = _ctl(players: 8);
      await pumpBuilder(t, c);
      expect(find.byKey(const Key('opt-ko-amount')), findsNothing);
      await t.ensureVisible(find.byKey(const Key('opt-ko-toggle')));
      await t.tap(find.byKey(const Key('opt-ko-toggle')));
      await t.pump();
      await type(t, 'opt-ko-amount', '8');
      final s = c.applyTo(_eventSettings(players: 8, rebuys: false));
      expect(s.koEnabled, isTrue);
      expect(s.koAmount, 8);
      await unmount(t);
    });

    testWidgets('rebuy + add-on: prices, expected counts and chip amounts',
        (t) async {
      final c = _ctl(format: TournamentFormat.rebuy, players: 8)..setAddOn(true);
      await pumpBuilder(t, c);
      await type(t, 'opt-rebuy-price', '15');
      await type(t, 'opt-addon-price', '10');
      await type(t, 'opt-exp-rebuys', '3');
      await type(t, 'opt-exp-addons', '5');
      await type(t, 'opt-rebuy-chips', '1000');
      await type(t, 'opt-addon-chips', '1500');
      final s = c.applyTo(_eventSettings(players: 8));
      expect(s.rebuyCost, 15);
      expect(s.addOnCost, 10);
      expect(s.expectedRebuys, 3);
      expect(s.expectedAddOns, 5);
      expect(s.rebuyChips, 1000);
      expect(s.addOnChips, 1500);
      // Cleared fields really clear (not "unchanged").
      await type(t, 'opt-rebuy-price', '');
      await type(t, 'opt-exp-rebuys', '');
      final back = c.applyTo(s);
      expect(back.rebuyCost, isNull);
      expect(back.expectedRebuys, isNull);
      await unmount(t);
    });

    testWidgets('re-entry: expected re-entries and re-entry chips', (t) async {
      final c = _ctl(format: TournamentFormat.reEntry, players: 8);
      await pumpBuilder(t, c);
      await type(t, 'opt-exp-reentries', '2');
      await type(t, 'opt-reentry-chips', '800');
      final s = c.applyTo(_eventSettings(players: 8, rebuys: false));
      expect(s.expectedReEntries, 2);
      expect(s.reEntryChips, 800);
      await unmount(t);
    });

    test('every option survives the codec and reopening', () {
      final c = StructureBuilderController.fromSettings(
          _eventSettings(players: 8, rebuys: false));
      c.updateOptions((o) {
        o.koEnabled = true;
        o.koAmount = 6;
        o.organizerPct = 5;
        o.paidPlaces = 2;
        o.maxPerTable = 6;
        o.rebuyCost = 12;
        o.addOnCost = 9;
      });
      c.updateOptions((o) => o.expectedAddOns = 4, ladder: true);
      final saved = c.applyTo(_eventSettings(players: 8, rebuys: false));
      final round = gameSettingsFromMap(gameSettingsToMap(saved));
      final again = StructureBuilderController.fromSettings(round);
      expect(again.options.koEnabled, isTrue);
      expect(again.options.koAmount, 6);
      expect(again.options.organizerPct, 5);
      expect(again.options.paidPlaces, 2);
      expect(again.options.maxPerTable, 6);
      expect(again.options.rebuyCost, 12);
      expect(again.options.addOnCost, 9);
      expect(again.options.expectedAddOns, 4);
    });

    test('money options never move the ladder; expectations do', () {
      final c = _ctl(format: TournamentFormat.rebuy, players: 8);
      c.approveStack();
      final l3 = c.structure.levels[2];
      c.editLevel(3, sb: l3.sb, bb: l3.bb, mins: l3.durationMins);
      c.updateOptions((o) => o.organizerPct = 10);
      c.setBuyIn(50);
      expect(c.isPinned(3), isTrue, reason: 'prizes are not a ladder input');
      c.updateOptions((o) => o.expectedRebuys = 6, ladder: true);
      expect(c.isPinned(3), isFalse,
          reason: 'expectations change the chips in play, so pins are dropped');
    });

    testWidgets('Fix chip count is on the stack step for a real chip case',
        (t) async {
      final c = _ctl(players: 8, chips: _homeSet);
      await t.binding.setSurfaceSize(const Size(800, 6000));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructureBuilder(
              controller: c,
              confirmLabel: 'Go',
              onConfirm: (_) {},
            ),
          ),
        ),
      ));
      await tapKey(t, 'builder-next');
      expect(find.byKey(const Key('fix-count')), findsOneWidget);
      await tapKey(t, 'fix-count');
      expect(find.text('Fix the count'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('the free tool has no Fix chip count (it has no chip case)',
        (t) async {
      await mount(t, const ToolBlindsScreen());
      await tapKey(t, 'builder-next');
      expect(find.byKey(const Key('fix-count')), findsNothing);
      await unmount(t);
    });
  });

  group('suggestions', () {
    test('rebuys: unlimited at a small table, limited above it', () {
      expect(StructureBuilderController.suggestRebuyLimit(6), isNull);
      expect(StructureBuilderController.suggestRebuyLimit(8), isNull);
      expect(StructureBuilderController.suggestRebuyLimit(9), 2);
      expect(StructureBuilderController.suggestRebuyLimit(14), 2);
      expect(StructureBuilderController.suggestRebuyLimit(15), 1);
    });

    test('the limit follows the player count until the host chooses', () {
      final c = _ctl(format: TournamentFormat.rebuy, players: 8);
      expect(c.rebuyLimit, isNull);
      c.setPlayers(12);
      expect(c.rebuyLimit, 2);
      c.setRebuyLimit(4);
      c.setPlayers(20);
      expect(c.rebuyLimit, 4, reason: 'the host\'s choice is not overwritten');
    });

    test('on-time bonus shows the chip amount next to the percent', () {
      final c = _ctl();
      expect(c.bonusChips, 0);
      c.setBonusPct(10);
      expect(c.bonusChips, (c.structure.startingStack * 0.10).round());
      expect(c.params.earlyArrivalBonusEnabled, isTrue);
      expect(c.params.earlyArrivalBonusPctOverride, 0.10);
    });

    test('finish time sets the duration from the start time', () {
      final c = _ctl(); // starts 19:00
      c.setFinishMinutes(23 * 60);
      expect(c.durationHours, 4);
      c.setFinishMinutes(1 * 60); // past midnight
      expect(c.durationHours, 6);
    });
  });
}

String _grouped(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
