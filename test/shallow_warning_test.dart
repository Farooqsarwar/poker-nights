import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/tournament_format.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/quick_start_screen.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/app_button.dart';
import 'package:poker_night/widgets/structure_feasibility_card.dart';
import 'package:provider/provider.dart';

/// Decision (WP1 review): MIN_PLAYABLE_DEPTH stays 20 BB as the hard floor, but a
/// structure that opens below SHALLOW_WARN_BB (50) gets a plain warning — the
/// reason (chips set aside for rebuys / add-ons) and one-tap options. Each option
/// re-runs the engine and shows the new depth. NOTHING is ever applied silently.
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

TournamentParams _homeSet({
  required int players,
  bool rebuy = true,
  bool addOn = true,
  double? rate,
  int? limit,
}) =>
    TournamentParams(
      players: players,
      durationHours: 4,
      buyIn: 20,
      chipSet: TournamentEngine.getPreset('Home Set (4 colour)'),
      rebuys: rebuy,
      rebuysCloseLevel: 0,
      reEntry: false,
      addOn: rebuy && addOn,
      anteEnabled: true,
      anteAfterLevel: 6,
      koEnabled: false,
      koAmount: 0,
      organizerPct: 0,
      format: rebuy ? TournamentFormat.rebuy : TournamentFormat.freezeOut,
      expectedRebuyRate: rate ?? (rebuy ? 0.35 : 0),
      rebuyLimit: limit,
      addOnMultiplier: 1.25,
      pace: PaceMode.regular,
    );

double _depth(TournamentStructure s) => s.startingStack / s.levels.first.bb;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    RecoveryService.enabled = false;
    AppColors.currentPalette = ThemePalettes.forId('red');
  });
  tearDown(() => RecoveryService.enabled = true);

  group('the constant and the flag', () {
    test('SHALLOW_WARN_BB is 50 and sits above the 20 BB hard floor', () {
      expect(kShallowWarnBB, 50);
      expect(kShallowWarnBB, greaterThan(TournamentEngine.kMinPlayableDepthBB));
    });

    test('Home Set, 10 players, rebuy: 25 BB, feasible, and flagged shallow', () {
      final s = TournamentEngine.generate(_homeSet(players: 10));
      expect(s.feasible, isTrue, reason: '25 BB is above the hard floor');
      expect(_depth(s), closeTo(25, 0.01));
      expect(s.isShallow, isTrue);
    });

    test('a deep night is not flagged (Home Set, 8 players, rebuy: 100 BB)', () {
      final s = TournamentEngine.generate(_homeSet(players: 8));
      expect(_depth(s), closeTo(100, 0.01));
      expect(s.isShallow, isFalse);
      expect(s.explanationFor('shallow'), isNull);
    });

    test('exactly 50 BB is NOT shallow (the threshold is "below 50")', () {
      // Home Set 9p rebuy opens at exactly 500 @ 5/10 = 50 BB.
      final s = TournamentEngine.generate(_homeSet(players: 9));
      expect(_depth(s), closeTo(50, 0.01));
      expect(s.isShallow, isFalse);
    });

    test('an infeasible structure is "blocked", not "shallow"', () {
      final s = TournamentEngine.generate(_homeSet(players: 200));
      expect(s.feasible, isFalse);
      expect(s.isShallow, isFalse);
    });
  });

  group('explain[] says why, in plain words', () {
    test('rebuy night: the reason is the chips set aside for rebuys/add-ons', () {
      final s = TournamentEngine.generate(_homeSet(players: 10));
      final e = s.explanationFor('shallow');
      expect(e, isNotNull);
      expect(e!.text, contains('25'), reason: 'states the depth');
      expect(e.text.toLowerCase(), contains('rebuy'));
      expect(e.text.toLowerCase(), contains('add-on'));
      expect(e.text.toLowerCase(), contains('set aside'));
      expect(e.numbers['depthBB'], closeTo(25, 0.01));
      expect(e.numbers['warnBB'], 50);
    });

    test('freeze-out: no rebuy/add-on reason is invented', () {
      // A box this small is short even without rebuys.
      final tiny = _homeSet(players: 14, rebuy: false)
          .copyWith(chipSet: TournamentEngine.getPreset('Standard 300'));
      final s = TournamentEngine.generate(tiny);
      if (s.isShallow) {
        final e = s.explanationFor('shallow')!;
        expect(e.text.toLowerCase(), isNot(contains('set aside')));
        expect(e.text.toLowerCase(), contains('chip case'));
      } else {
        // Not shallow on this box: the property below is vacuous, so make the
        // assertion about the absence of the entry instead of skipping silently.
        expect(s.explanationFor('shallow'), isNull);
      }
    });
  });

  group('rebuyLimit caps the busy-night rebuy reserve (§F1.5 pt 1)', () {
    test('the cap is maxRebuys x N, and only when it is below the forecast', () {
      // Poisson-90 of 9 expected rebuys is 13; a limit of 1 each caps it at 10.
      expect(TournamentEngine.poissonQuantile90(9), 13);
      expect(TournamentEngine.busyNightRebuys(_homeSet(players: 10, rate: 0.9)),
          13);
      expect(
          TournamentEngine.busyNightRebuys(
              _homeSet(players: 10, rate: 0.9, limit: 1)),
          10);
      // A cap above the forecast changes nothing (0.35 x 10 -> Poisson-90 = 6).
      expect(
          TournamentEngine.busyNightRebuys(_homeSet(players: 10, limit: 2)), 6);
      // 0 means "unlimited" in the presets UI, so it must not cap to nothing.
      expect(
          TournamentEngine.busyNightRebuys(_homeSet(players: 10, limit: 0)), 6);
      expect(TournamentEngine.busyNightRebuys(_homeSet(players: 10, rebuy: false)),
          0);
    });

    test('a tight limit never makes a night worse, and can make it dealable', () {
      final free = TournamentEngine.generate(_homeSet(players: 10, rate: 0.9));
      final capped =
          TournamentEngine.generate(_homeSet(players: 10, rate: 0.9, limit: 1));
      // Feasibility first: an infeasible structure's "depth" is a placeholder.
      expect(capped.feasible, isTrue);
      expect(!free.feasible || capped.startingStack >= free.startingStack, isTrue,
          reason: 'fewer reserved rebuy stacks can only help');
      if (free.feasible) {
        expect(_depth(capped), greaterThanOrEqualTo(_depth(free)));
      }
    });

    test('the stack search and the exposed bankOk use the same reserve', () {
      // If only one applied the cap they would disagree about a capped night.
      final capped =
          TournamentEngine.generate(_homeSet(players: 10, rate: 0.9, limit: 1));
      expect(capped.feasible, isTrue);
      expect(capped.bankOk, isTrue);
    });
  });

  group('shallowFixes — options that each re-run the engine', () {
    final base = _homeSet(players: 10);
    final before = TournamentEngine.generate(base);
    final fixes = TournamentEngine.shallowFixes(base);

    test('there is at least one, and "skip the add-on" is among them', () {
      expect(fixes, isNotEmpty);
      expect(fixes.map((f) => f.kind), contains(ShallowFixKind.skipAddOn));
    });

    test('every offered fix strictly improves the opening depth', () {
      for (final f in fixes) {
        expect(f.resultingDepthBB, greaterThan(_depth(before) + 0.5),
            reason: '${f.kind} must be worth offering');
      }
    });

    test('the depth a fix advertises is what the engine actually produces', () {
      for (final f in fixes) {
        final applied = TournamentEngine.generate(f.applyTo(base));
        expect(_depth(applied), closeTo(f.resultingDepthBB, 0.01),
            reason: '${f.kind}: the label must not lie');
        expect(applied.startingStack, f.resultingStack);
        expect(applied.feasible, f.feasible);
      }
    });

    test('computing the options changes nothing (never applied silently)', () {
      final again = TournamentEngine.generate(base);
      expect(again.startingStack, before.startingStack);
      expect(base.addOn, isTrue);
      expect(base.expectedRebuyRate, 0.35);
      expect(base.rebuyLimit, isNull);
    });

    test('a night that is not shallow has no options', () {
      expect(TournamentEngine.shallowFixes(_homeSet(players: 8)), isEmpty);
    });

    test('a freeze-out has no rebuy/add-on options to offer', () {
      final fz = _homeSet(players: 10, rebuy: false);
      for (final f in TournamentEngine.shallowFixes(fz)) {
        expect(f.kind, isNot(ShallowFixKind.skipAddOn));
        expect(f.kind, isNot(ShallowFixKind.lowerRebuyRate));
        expect(f.kind, isNot(ShallowFixKind.limitRebuys));
      }
    });
  });

  group('the levers reach the engine through GameSettings', () {
    GameSettings settings({double? rate, int? limit, bool addOn = true}) =>
        GameSettings(
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
          rebuysCloseLevel: 0,
          rebuyLimit: limit,
          expectedRebuyRate: rate,
          addOn: addOn,
          anteEnabled: true,
          anteAfterLevel: 6,
          organizerPct: 0,
          chipSet: TournamentEngine.getPreset('Home Set (4 colour)'),
          chipSetName: 'Home Set',
          pace: PaceMode.regular,
        );

    test('expectedRebuyRate and rebuyLimit survive a settings round trip', () {
      final s = settings(rate: 0.15, limit: 2);
      final back = gameSettingsFromMap(gameSettingsToMap(s));
      expect(back.expectedRebuyRate, 0.15);
      expect(back.rebuyLimit, 2);
    });

    test('settings saved before the field existed read as "no override"', () {
      final map = gameSettingsToMap(settings())..remove('expectedRebuyRate');
      expect(gameSettingsFromMap(map).expectedRebuyRate, isNull);
    });

    LiveGame game(GameSettings s) => LiveGame(
          id: 'g1',
          groupId: 'grp1',
          settings: s,
          structure: TournamentEngine.generate(_homeSet(players: 10)),
          status: LiveGameStatus.ready,
          publicCode: 'ABC123',
          tvCode: 'TV7890',
          currentLevel: 1,
          timerRunning: false,
          secondsRemaining: 900,
          players: [
            for (var i = 0; i < 10; i++)
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

    test('generateFinalStructure honours a lowered rebuy rate', () {
      final def = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        ..setCurrentGame(game(settings()));
      def.generateFinalStructure(10, force: true);
      final low = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        ..setCurrentGame(game(settings(rate: 0.05)));
      low.generateFinalStructure(10, force: true);
      expect(low.currentGame!.structure.startingStack,
          greaterThan(def.currentGame!.structure.startingStack));
      def.dispose();
      low.dispose();
    });

    test('generateFinalStructure honours skipping the add-on', () {
      final withAddOn = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        ..setCurrentGame(game(settings()));
      withAddOn.generateFinalStructure(10, force: true);
      final without = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        ..setCurrentGame(game(settings(addOn: false)));
      without.generateFinalStructure(10, force: true);
      expect(without.currentGame!.structure.startingStack,
          greaterThan(withAddOn.currentGame!.structure.startingStack));
      withAddOn.dispose();
      without.dispose();
    });
  });

  group('applying a fix through the provider (the host\'s tap)', () {
    GameSettings settings({bool addOn = true}) => GameSettings(
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
          rebuysCloseLevel: 0,
          addOn: addOn,
          anteEnabled: true,
          anteAfterLevel: 6,
          organizerPct: 0,
          chipSet: TournamentEngine.getPreset('Home Set (4 colour)'),
          chipSetName: 'Home Set',
          pace: PaceMode.regular,
        );

    LiveGame game({LiveGameStatus status = LiveGameStatus.ready}) => LiveGame(
          id: 'g1',
          groupId: 'grp1',
          settings: settings(),
          structure: TournamentEngine.generate(_homeSet(players: 10)),
          status: status,
          publicCode: 'ABC123',
          tvCode: 'TV7890',
          currentLevel: 1,
          timerRunning: false,
          secondsRemaining: 900,
          players: [
            for (var i = 0; i < 10; i++)
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

    AppProvider providerWith(LiveGame g) => AppProvider()
      ..setUserForTesting(_host)
      ..setCurrentGroupForTesting(_group)
      ..setCurrentGame(g);

    test('the game starts shallow and the provider lists real options', () {
      final app = providerWith(game());
      expect(app.currentGame!.structure.isShallow, isTrue);
      final fixes = app.shallowFixesForCurrentGame();
      expect(fixes, isNotEmpty);
      expect(fixes.map((f) => f.kind), contains(ShallowFixKind.skipAddOn));
      app.dispose();
    });

    test('LISTING the options changes nothing (never applied silently)', () {
      final app = providerWith(game());
      final before = app.currentGame!;
      app.shallowFixesForCurrentGame();
      app.shallowFixesForCurrentGame();
      final after = app.currentGame!;
      expect(after.settings.addOn, before.settings.addOn);
      expect(after.settings.expectedRebuyRate, before.settings.expectedRebuyRate);
      expect(after.structure.startingStack, before.structure.startingStack);
      app.dispose();
    });

    test('tapping a fix delivers EXACTLY the stack and depth it advertised', () {
      final app = providerWith(game());
      final fix = app
          .shallowFixesForCurrentGame()
          .firstWhere((f) => f.kind == ShallowFixKind.skipAddOn);
      app.applyShallowFix(fix);

      final g = app.currentGame!;
      expect(g.settings.addOn, isFalse);
      expect(g.structure.startingStack, fix.resultingStack,
          reason: 'a stored stack must NOT silently survive the fix');
      expect(g.structure.startingStack / g.structure.levels.first.bb,
          closeTo(fix.resultingDepthBB, 0.01));
      expect(g.structure.startingStack,
          greaterThan(TournamentEngine.generate(_homeSet(players: 10)).startingStack));
      app.dispose();
    });

    test('a lowered rebuy rate fix is carried into the settings and the plan', () {
      final app = providerWith(game());
      final fixes = app.shallowFixesForCurrentGame();
      final rate = fixes.where((f) => f.kind == ShallowFixKind.lowerRebuyRate);
      if (rate.isEmpty) {
        // Not every night improves with a lower rate; then it must not be
        // offered, which the "every offered fix improves" test above covers.
        return;
      }
      app.applyShallowFix(rate.first);
      expect(app.currentGame!.settings.expectedRebuyRate,
          rate.first.expectedRebuyRate);
      expect(app.currentGame!.structure.startingStack, rate.first.resultingStack);
      app.dispose();
    });

    test('once play has started the stacks are physical: no options, no change',
        () {
      final app = providerWith(game(status: LiveGameStatus.running));
      expect(app.shallowFixesForCurrentGame(), isEmpty);
      final stack = app.currentGame!.structure.startingStack;
      app.applyShallowFix(const ShallowFix(
        kind: ShallowFixKind.skipAddOn,
        label: 'Skip the add-on',
        detail: '',
        resultingDepthBB: 99,
        resultingStack: 999,
        feasible: true,
        addOn: false,
      ));
      expect(app.currentGame!.structure.startingStack, stack);
      expect(app.currentGame!.settings.addOn, isTrue);
      app.dispose();
    });
  });

  group('the card', () {
    Future<void> pumpCard(
      WidgetTester t, {
      required TournamentStructure structure,
      List<ShallowFix> fixes = const [],
      void Function(ShallowFix)? onApply,
      VoidCallback? onEditChips,
    }) async {
      await t.binding.setSurfaceSize(const Size(700, 1200));
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StructureFeasibilityCard(
              structure: structure,
              players: 10,
              shallowFixes: fixes,
              onApplyShallowFix: onApply,
              onEditChips: onEditChips,
            ),
          ),
        ),
      ));
      await t.pump();
    }

    final shallow = TournamentEngine.generate(_homeSet(players: 10));
    final fixes = TournamentEngine.shallowFixes(_homeSet(players: 10));

    testWidgets('shows the depth, the reason, and each option with its new depth',
        (t) async {
      await pumpCard(t, structure: shallow, fixes: fixes, onApply: (_) {});
      expect(find.textContaining('25 big blinds'), findsOneWidget);
      expect(find.textContaining('set aside'), findsOneWidget);
      for (final f in fixes) {
        expect(find.textContaining('${f.resultingDepthBB.round()} BB'),
            findsWidgets,
            reason: '${f.kind} shows where it lands');
      }
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('tapping an option reports THAT option and nothing else',
        (t) async {
      final applied = <ShallowFix>[];
      await pumpCard(t, structure: shallow, fixes: fixes, onApply: applied.add);
      expect(applied, isEmpty, reason: 'nothing is applied on display');
      await t.tap(find.byType(AppButton).first);
      await t.pump();
      expect(applied, hasLength(1));
      expect(fixes, contains(applied.single));
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('no callback => no dead buttons for the options', (t) async {
      await pumpCard(t, structure: shallow, fixes: fixes, onApply: null);
      expect(find.textContaining('25 big blinds'), findsOneWidget);
      expect(find.byType(AppButton), findsNothing);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('Edit chips is offered when a handler is given', (t) async {
      var edited = 0;
      await pumpCard(t,
          structure: shallow, fixes: fixes, onApply: (_) {}, onEditChips: () => edited++);
      await t.tap(find.text('Edit chips'));
      expect(edited, 1);
      await t.binding.setSurfaceSize(null);
    });

    testWidgets('a deep structure shows nothing', (t) async {
      await pumpCard(t, structure: TournamentEngine.generate(_homeSet(players: 8)));
      expect(find.textContaining('big blinds'), findsNothing);
      expect(find.byType(AppButton), findsNothing);
      await t.binding.setSurfaceSize(null);
    });
  });

  group('quick start: the card appears, nothing changes until the tap', () {
    Future<void> mount(WidgetTester t, AppProvider app) async {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            backgroundColor: Colors.transparent,
            body: QuickStartScreen(),
          ),
        ),
      ]);
      await t.binding.setSurfaceSize(const Size(800, 3200));
      await t.pumpWidget(ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pump(const Duration(milliseconds: 100));
    }

    Future<void> unmount(WidgetTester t, AppProvider app) async {
      await t.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await t.pump();
      await t.binding.setSurfaceSize(null);
    }

    testWidgets('10 players on rebuy: shallow card, then Skip the add-on deepens it',
        (t) async {
      final app = AppProvider()
        ..setUserForTesting(_host)
        ..setCurrentGroupForTesting(_group)
        // The free plan stops at one table (9), so 10 players needs Premium.
        ..premiumTier = PremiumTier.premium;
      await mount(t, app);

      // 8 freeze-out on the default Home Set is a normal 100 BB night: no card.
      expect(find.textContaining('Shallow start'), findsNothing);

      // Step the player count up to 10 (the stepper is the first 'Increase').
      for (var i = 0; i < 6 && find.text('10 players').evaluate().isEmpty; i++) {
        await t.tap(find.byTooltip('Increase').first);
        await t.pump();
      }
      expect(find.text('10 players'), findsOneWidget);
      await t.tap(find.text('Rebuy'));
      await t.pump();

      expect(find.textContaining('Shallow start'), findsOneWidget);
      expect(find.textContaining('Rebuys and one add-on.'), findsOneWidget);
      final skip = find.textContaining('Skip the add-on');
      expect(skip, findsOneWidget);

      // Showing the option must not have applied it.
      expect(find.textContaining('Rebuys, no add-on.'), findsNothing);

      await t.tap(skip);
      await t.pump();

      expect(find.textContaining('Rebuys, no add-on.'), findsOneWidget,
          reason: 'the host\'s tap changed the plan');
      expect(find.textContaining('Rebuys and one add-on.'), findsNothing);
      await unmount(t, app);
    });
  });
}
