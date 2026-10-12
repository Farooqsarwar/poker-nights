import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/screens/tournament/quick_start_screen.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:poker_night/widgets/structure_feasibility_card.dart';
import 'package:provider/provider.dart';

/// WP1 — a night the chip case cannot deal (§F1.5 point 7: `feasible == false`)
/// only has a PLACEHOLDER ladder. No code path may start a clock from it, post
/// it, or open the dashboard on it; the screens show the bank/depth card.
///
/// Each guard has a control (a feasible night that DOES start) so a passing
/// "refuses" test can't be a harness that never starts anything.
const _host = AppUser(
  id: 'u1',
  name: 'Host',
  email: 'host@example.com',
  isAdmin: true,
  stats: UserStats(played: 0, wins: 0, podium: 0, avgFinish: 0, knockouts: 0),
);

const _group = Group(
  id: 'grp1',
  name: 'Friday Poker Club',
  joinCode: 'FP2608',
  ownerId: 'u1',
  members: [_host],
  games: [],
  chat: [],
  polls: [],
  notifications: [],
);

const _box500 = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 150),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
  ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 100),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 100),
];
const _base25 = [
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 100),
  ChipColor(color: 'Green', hex: 0xFF27AE60, value: 100, quantity: 100),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 500, quantity: 80),
  ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 1000, quantity: 50),
  ChipColor(color: 'Yellow', hex: 0xFFF1C40F, value: 5000, quantity: 30),
];
const _demo = [
  ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 120),
  ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 150),
  ChipColor(color: 'Green', hex: 0xFF27AE60, value: 25, quantity: 80),
  ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 40),
];

GameSettings _settings({
  required List<ChipColor> chips,
  required int players,
  required bool rebuy,
}) => GameSettings(
  name: 'Friday',
  date: '2026-10-12',
  time: '20:00',
  location: 'Basement',
  players: players,
  durationHours: 4,
  buyIn: 20,
  koEnabled: false,
  koAmount: 0,
  rebuys: rebuy,
  rebuysCloseLevel: 0,
  addOn: rebuy,
  anteEnabled: true,
  anteAfterLevel: 6,
  organizerPct: 0,
  chipSet: chips,
  chipSetName: 'Test',
  pace: PaceMode.regular,
);

TournamentParams _paramsFor(GameSettings s) => TournamentParams(
  players: s.players,
  durationHours: s.durationHours,
  buyIn: s.buyIn,
  chipSet: s.chipSet,
  rebuys: s.rebuys,
  rebuysCloseLevel: s.rebuysCloseLevel,
  addOn: s.addOn,
  anteEnabled: s.anteEnabled,
  anteAfterLevel: s.anteAfterLevel,
  koEnabled: false,
  koAmount: 0,
  organizerPct: 0,
  pace: s.pace,
);

/// A game at the check-in desk: [players] checked in, seating confirmed, with
/// the structure the host would have generated for [s].
LiveGame _gameAtStart(GameSettings s) {
  final structure = TournamentEngine.generate(_paramsFor(s));
  return LiveGame(
    id: 'g1',
    groupId: 'grp1',
    settings: s,
    structure: structure,
    status: LiveGameStatus.ready,
    publicCode: 'ABC123',
    tvCode: 'TV7890',
    currentLevel: 1,
    timerRunning: false,
    secondsRemaining: structure.levelDuration * 60,
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    RecoveryService.enabled = false;
    AppColors.currentPalette = ThemePalettes.forId('red');
  });
  tearDown(() => RecoveryService.enabled = true);

  AppProvider providerWith(LiveGame g) => AppProvider()
    ..setUserForTesting(_host)
    ..setCurrentGroupForTesting(_group)
    ..setCurrentGame(g);

  // The three cases the 3,840-run audit found infeasible: 20 players with
  // rebuys + add-on on a base25 / demo box. (base100 behaves like base25.)
  final infeasible = {
    'base25 20p rebuy': _settings(chips: _base25, players: 20, rebuy: true),
    'demo 20p rebuy': _settings(chips: _demo, players: 20, rebuy: true),
  };
  final feasible = _settings(chips: _box500, players: 9, rebuy: false);

  group('preconditions (so the guards below are not vacuous)', () {
    for (final e in infeasible.entries) {
      test('${e.key} really is infeasible', () {
        final s = TournamentEngine.generate(_paramsFor(e.value));
        expect(s.feasible, isFalse);
        expect(
          s.isBlocked,
          isTrue,
          reason: 'a ladder exists (placeholder) but must be blocked',
        );
        expect(s.levels, isNotEmpty);
      });
    }
    test('the control night really is feasible', () {
      final s = TournamentEngine.generate(_paramsFor(feasible));
      expect(s.feasible, isTrue);
      expect(s.isBlocked, isFalse);
    });
    test('an event with no ladder yet is not "blocked"', () {
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group);
      final created = app.createGame(feasible);
      expect(
        created.structure.levels,
        isEmpty,
        reason: 'posting an event carries no ladder at all',
      );
      expect(created.structure.isBlocked, isFalse);
      app.dispose();
    });
  });

  group('start: the clock never starts on a placeholder ladder', () {
    for (final e in infeasible.entries) {
      test('${e.key}: startTournament refuses, nothing runs', () async {
        final app = providerWith(_gameAtStart(e.value));
        expect(
          app.startBlockedReason,
          AppProviderGame.kChipCaseBlockedReason,
          reason: 'the start button is already off before pressing it',
        );

        final started = await app.startTournament();

        expect(started, isFalse);
        final g = app.currentGame!;
        expect(g.timerRunning, isFalse);
        expect(g.status, isNot(LiveGameStatus.running));
        expect(g.structureConfirmed, isFalse);
        app.dispose();
      });

      test('${e.key}: startTimer called directly is refused too', () {
        final app = providerWith(_gameAtStart(e.value));
        app.startTimer();
        expect(app.currentGame!.timerRunning, isFalse);
        expect(app.currentGame!.status, isNot(LiveGameStatus.running));
        app.dispose();
      });

      test('${e.key}: confirmStructure refuses', () {
        final app = providerWith(_gameAtStart(e.value));
        app.confirmStructure();
        expect(app.currentGame!.structureConfirmed, isFalse);
        app.dispose();
      });
    }

    test('CONTROL: a dealable night does start (the harness works)', () async {
      final app = providerWith(_gameAtStart(feasible));
      expect(app.startBlockedReason, isNull);
      final started = await app.startTournament();
      expect(started, isTrue);
      expect(app.currentGame!.timerRunning, isTrue);
      expect(app.currentGame!.status, LiveGameStatus.running);
      app.dispose();
    });

    test('CONTROL: a dealable night confirms its structure', () {
      final app = providerWith(_gameAtStart(feasible));
      app.confirmStructure();
      expect(app.currentGame!.structureConfirmed, isTrue);
      app.dispose();
    });

    test('a stored dealable structure that becomes undealable at the final '
        'headcount is refused at start (the authoritative check)', () async {
      // The host reviewed a structure for 9 players (fine), but 20 checked in
      // with rebuys + add-on on a base25 box. startBlockedReason (stored
      // structure) says nothing — startTimer regenerates and must refuse.
      final okSettings = _settings(chips: _base25, players: 9, rebuy: true);
      final seeded = _gameAtStart(okSettings);
      expect(seeded.structure.isBlocked, isFalse, reason: '9p is dealable');
      final crowded = seeded.copyWith(
        players: _gameAtStart(
          _settings(chips: _base25, players: 20, rebuy: true),
        ).players,
      );
      final app = providerWith(crowded);
      expect(
        app.startBlockedReason,
        isNull,
        reason: 'the stored (9p) structure looked fine',
      );

      final started = await app.startTournament();

      expect(started, isFalse);
      expect(app.currentGame!.timerRunning, isFalse);
      expect(app.currentGame!.structureConfirmed, isFalse);
      app.dispose();
    });
  });

  group('a blocked structure stays blocked after a save and reload', () {
    // The guards key off `feasible`; if the codec dropped it, the first reload
    // (cloud sync, crash recovery, a second device) would turn a placeholder
    // back into a startable structure. The T6 split (depthOk / bankOk /
    // bankShortfall) must survive too — it's what says WHICH colour is short.
    for (final e in infeasible.entries) {
      test('${e.key}: isBlocked and the diagnosis survive a round trip', () {
        final before = TournamentEngine.generate(_paramsFor(e.value));
        final after = tournamentStructureFromMap(
          tournamentStructureToMap(before),
        );
        expect(after.isBlocked, isTrue);
        expect(after.feasible, before.feasible);
        expect(after.depthOk, before.depthOk);
        expect(after.bankOk, before.bankOk);
        expect(after.maxPlayersSupported, before.maxPlayersSupported);
        expect(after.depthShortfallNote, before.depthShortfallNote);
      });
    }

    test('a bank shortfall (colour, needed, owned) survives a round trip', () {
      // forceStack 2,000 on the 500-piece box with rebuys: the box can't fund
      // it, so the engine reports exactly which colours run short.
      final before = TournamentEngine.generate(
        _paramsFor(
          _settings(chips: _box500, players: 9, rebuy: true),
        ).copyWith(forceStack: 2000),
      );
      expect(before.bankOk, isFalse);
      expect(before.bankShortfall, isNotEmpty);
      final after = tournamentStructureFromMap(
        tournamentStructureToMap(before),
      );
      expect(after.bankOk, isFalse);
      expect(after.bankShortfall.length, before.bankShortfall.length);
      for (var i = 0; i < before.bankShortfall.length; i++) {
        expect(after.bankShortfall[i].colour, before.bankShortfall[i].colour);
        expect(after.bankShortfall[i].value, before.bankShortfall[i].value);
        expect(after.bankShortfall[i].needed, before.bankShortfall[i].needed);
        expect(after.bankShortfall[i].owned, before.bankShortfall[i].owned);
      }
    });

    test('a structure saved before these fields existed reads as fine', () {
      final legacy =
          tournamentStructureToMap(
              TournamentEngine.generate(_paramsFor(feasible)),
            )
            ..remove('depthOk')
            ..remove('bankOk')
            ..remove('bankShortfall');
      final read = tournamentStructureFromMap(legacy);
      expect(read.depthOk, isTrue);
      expect(read.bankOk, isTrue);
      expect(read.bankShortfall, isEmpty);
    });
  });

  group('the card: maxPlayersSupported is honest ("Reduce to N" works)', () {
    for (final e in infeasible.entries) {
      test('${e.key}: reducing to the advertised N is dealable', () {
        final s = TournamentEngine.generate(_paramsFor(e.value));
        final n = s.maxPlayersSupported;
        expect(n, isNotNull, reason: 'the card needs a number to offer');
        expect(n, lessThan(e.value.players));
        final reduced = TournamentEngine.generate(
          _paramsFor(e.value.copyWith(players: n!)),
        );
        expect(
          reduced.feasible,
          isTrue,
          reason: 'the card offers "Reduce to $n players"; that must work',
        );
      });
    }
  });

  group('quick start: card shown, start disabled, nothing created', () {
    AppButton generate(WidgetTester t) => t.widget<AppButton>(
      find.widgetWithText(AppButton, 'Generate & start the clock'),
    );

    // Chips tiny enough that even the default 8-player freeze-out can't be
    // dealt a playable stack, so the screen's first render is the blocked one.
    const tiny = [
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 25, quantity: 4),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 4),
      ChipColor(color: 'Purple', hex: 0xFF8E44AD, value: 500, quantity: 2),
    ];

    testWidgets('blocked: card visible and Generate is disabled', (t) async {
      // Precondition on the engine, with the params quick start itself builds
      // (8 players, 4 h, freeze-out, regular pace).
      final pre = TournamentEngine.generate(
        TournamentParams(
          players: 8,
          durationHours: 4,
          buyIn: 15,
          chipSet: tiny,
          rebuys: false,
          rebuysCloseLevel: 0,
          addOn: false,
          anteEnabled: true,
          anteAfterLevel: 6,
          koEnabled: false,
          koAmount: 0,
          organizerPct: 0,
          pace: PaceMode.regular,
        ),
      );
      expect(pre.isBlocked, isTrue, reason: 'precondition for the widget test');

      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        ..saveChipSet('tiny', 'Tiny box', tiny)
        ..setDefaultChipSet('tiny');
      await _mount(t, app, const QuickStartScreen());

      expect(find.byType(StructureFeasibilityCard), findsOneWidget);
      expect(
        find.text('Your chip case is too small for this field'),
        findsOneWidget,
      );
      expect(
        generate(t).onPressed,
        isNull,
        reason: 'no clock can be started from a placeholder ladder',
      );
      expect(app.currentGame, isNull, reason: 'no game was created');

      await _unmount(t, app);
    });

    testWidgets('CONTROL: dealable chips → no card and Generate is enabled', (
      t,
    ) async {
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        ..saveChipSet('box', 'Box', _box500)
        ..setDefaultChipSet('box');
      await _mount(t, app, const QuickStartScreen());

      expect(
        find.text('Your chip case is too small for this field'),
        findsNothing,
      );
      expect(generate(t).onPressed, isNotNull);

      await _unmount(t, app);
    });
  });

  group('free tools: the generator and the clock show the card', () {
    // The tools deal from a fixed 300-chip box and allow 2-100 players with
    // rebuys + add-on, so from 14 players the box can't deal the night (17 for
    // the four-colour box). The default of 9 is fine. These pin that the tools
    // handle the large fields instead of presenting a placeholder as a
    // structure, a schedule, something to share, or a running clock.
    const card = 'Your chip case is too small for this field';

    Future<void> tapIncrease(WidgetTester t, int times) async {
      // The first stepper on both tools is the player count (9 -> 9 + times).
      for (var i = 0; i < times; i++) {
        await t.tap(find.byTooltip('Increase').first);
        await t.pump();
      }
    }

    AppProvider app() => AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group);

    testWidgets('blind generator, 14 players: card, no schedule, no Share', (
      t,
    ) async {
      final a = app();
      await _mount(t, a, const ToolBlindsScreen());
      await tapIncrease(t, 5);
      await t.tap(find.text('Generate structure'));
      await t.pump();

      expect(find.text(card), findsOneWidget);
      expect(
        find.text('Share'),
        findsNothing,
        reason: 'nothing to share from a placeholder',
      );
      expect(
        find.text('Starting stack'),
        findsNothing,
        reason: 'the placeholder\'s stack must not be shown as the answer',
      );
      await _unmount(t, a);
    });

    testWidgets(
      'CONTROL blind generator, 9 players: structure shown, no card',
      (t) async {
        final a = app();
        await _mount(t, a, const ToolBlindsScreen());
        await t.tap(find.text('Generate structure'));
        await t.pump();

        expect(find.text(card), findsNothing);
        expect(find.text('Share'), findsOneWidget);
        expect(find.text('Starting stack'), findsOneWidget);
        await _unmount(t, a);
      },
    );

    testWidgets('tool clock, 14 players: card shown and NO clock is built', (
      t,
    ) async {
      final a = app();
      await _mount(t, a, const ToolClockScreen());
      await tapIncrease(t, 5);
      await t.tap(find.text('Start a clock'));
      await t.pump();

      expect(find.text(card), findsOneWidget);
      expect(
        find.text('Start a clock'),
        findsOneWidget,
        reason: 'still on the setup view — no clock display was built',
      );
      await _unmount(t, a);
    });

    testWidgets('CONTROL tool clock, 9 players: the clock is built', (t) async {
      final a = app();
      await _mount(t, a, const ToolClockScreen());
      await t.tap(find.text('Start a clock'));
      await t.pump();

      expect(find.text(card), findsNothing);
      expect(
        find.text('Start a clock'),
        findsNothing,
        reason: 'setup is replaced by the running clock view',
      );
      await _unmount(t, a);
    });
  });
}

/// Mounts [screen] under a real router + provider on a tall surface (these
/// screens scroll, and the controls under test sit well below the fold).
Future<void> _mount(WidgetTester t, AppProvider app, Widget screen) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            Scaffold(backgroundColor: Colors.transparent, body: screen),
      ),
    ],
  );
  await t.binding.setSurfaceSize(const Size(800, 3000));
  await t.pumpWidget(
    ChangeNotifierProvider<AppProvider>.value(
      value: app,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await t.pump(const Duration(milliseconds: 100));
}

Future<void> _unmount(WidgetTester t, AppProvider app) async {
  await t.pumpWidget(const SizedBox.shrink());
  app.dispose();
  await t.pump();
  await t.binding.setSurfaceSize(null);
}
