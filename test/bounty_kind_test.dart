import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/tournament/create_tournament_screen.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/model_codec.dart';
import 'package:poker_night/widgets/app_toggle.dart';
import 'package:poker_night/widgets/count_stepper.dart';

/// §C1 step 1 — the KO bounty. Off by default; a toggle, then an amount
/// (5–50, step  5) and a type, of which Fixed is free and the other two carry
/// a PREMIUM pill and open G1 when tapped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The recovery store is shared between AppProviders and writes into the real
  // project directory; leaving it on lets one test's save fail the next with a
  // file-lock error that has nothing to do with bounties.
  setUp(() => RecoveryService.enabled = false);
  tearDown(() => RecoveryService.enabled = true);

  const structure = TournamentStructure(
    startingStack: 0,
    chipPlan: [],
    rebuyStack: 0,
    rebuyChipPlan: [],
    addOnStack: 0,
    addOnChipPlan: [],
    levels: [],
    levelDuration: 15,
    expectedFinishMins: 0,
    prizes: [],
    prizePool: 0,
    organizerAmount: 0,
    colorUpInstructions: [],
    warnings: [],
  );

  GameSettings settings({
    bool koEnabled = true,
    int koAmount = 5,
    BountyKind koKind = BountyKind.fixed,
  }) {
    return GameSettings(
      name: 'Friday',
      date: '2026-09-25',
      time: '20:00',
      location: '',
      players: 9,
      durationHours: 4,
      buyIn: 20,
      koEnabled: koEnabled,
      koAmount: koAmount,
      koKind: koKind,
      rebuys: true,
      rebuysCloseLevel: 6,
      addOn: true,
      anteEnabled: false,
      anteAfterLevel: 6,
      organizerPct: 0,
      chipSet: const [
        ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
      ],
      chipSetName: 'Test',
    );
  }

  /// A settings map exactly as a build from before bounty kinds wrote it: the
  /// KO pair and nothing at all about a kind.
  Map<String, dynamic> legacySettingsMap() =>
      gameSettingsToMap(settings())..remove('koKind');

  LiveGame game(GameSettings s) => LiveGame(
        id: 'g1',
        groupId: 'grp1',
        settings: s,
        structure: structure,
        status: LiveGameStatus.draft,
        publicCode: 'ABC123',
        tvCode: 'TV7890',
        currentLevel: 1,
        timerRunning: false,
        secondsRemaining: 0,
        players: const [],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 0,
        pendingGuests: const [],
        finishOrder: const [],
      );

  group('model', () {
    test('a kind is never null, and the default is Fixed', () {
      final s = settings();
      expect(s.koKind, BountyKind.fixed);
      expect(
        gameSettingsFromMap(gameSettingsToMap(s)).koKind,
        isNotNull,
      );
    });

    test('copyWith changes the kind and preserves it when omitted', () {
      final mystery = settings().copyWith(koKind: BountyKind.mystery);
      expect(mystery.koKind, BountyKind.mystery);
      // `x ?? this.x`: a partial update must not quietly drop the choice.
      expect(mystery.copyWith(koAmount: 10).koKind, BountyKind.mystery);
    });

    test('only the two Premium kinds are marked Premium', () {
      expect(BountyKind.fixed.isPremium, isFalse);
      expect(BountyKind.progressive.isPremium, isTrue);
      expect(BountyKind.mystery.isPremium, isTrue);
    });

    test('the bounty collects nothing while it is off', () {
      expect(settings(koEnabled: false).effectiveKoAmount, 0);
      // On, the stored figure is charged, in the same whole units as the
      // buy-in rather than a second money convention.
      expect(settings(koAmount: 15).effectiveKoAmount, 15);
    });

    test('the bounty range is 5-50 in steps of 5', () {
      expect(GameSettings.minBounty, 5);
      expect(GameSettings.maxBounty, 50);
      expect(GameSettings.bountyStep, 5);
    });
  });

  group('codec', () {
    test('every kind round-trips through the map', () {
      for (final kind in BountyKind.values) {
        final map = gameSettingsToMap(settings(koKind: kind));
        // The stored value is the spec's wire name, not the enum index.
        expect(map['koKind'], kind.name);
        expect(gameSettingsFromMap(map).koKind, kind);
      }
    });

    test('a legacy map with no kind decodes to Fixed', () {
      final back = gameSettingsFromMap(legacySettingsMap());
      expect(back.koKind, BountyKind.fixed);
      expect(back.koKind, isNotNull);
    });

    test('a kind this build does not know degrades to Fixed', () {
      final m = legacySettingsMap()..['koKind'] = 'jackpot';
      expect(gameSettingsFromMap(m).koKind, BountyKind.fixed);
    });

    test('a whole legacy game document still decodes', () {
      // The field lives inside `settings`, so the guarantee is worth nothing
      // unless it holds through the full document a restored game takes.
      final current = liveGameToMap(game(settings(koKind: BountyKind.progressive)));
      expect((current['settings'] as Map)['koKind'], 'progressive');
      expect(
        liveGameFromMap(current).settings.koKind,
        BountyKind.progressive,
      );

      final legacy = liveGameToMap(game(settings()))
        ..['settings'] = legacySettingsMap();
      expect(
        liveGameFromMap(legacy).settings.koKind,
        BountyKind.fixed,
      );
    });
  });

  group('wizard', () {
    const host = AppUser(
      id: 'u1',
      name: 'Alex Morgan',
      email: 'alex@poker.night',
      isAdmin: true,
      stats: UserStats(
        played: 34,
        wins: 6,
        podium: 11,
        avgFinish: 3.2,
        knockouts: 18,
      ),
    );

    AppProvider provider({PremiumTier tier = PremiumTier.free}) => AppProvider()
      ..setUserForTesting(host)
      ..setCurrentGroupForTesting(Group(
        id: 'g1',
        name: 'Friday Poker Club',
        joinCode: 'FP2608',
        ownerId: 'u1',
        members: const [host],
        games: const [],
        chat: const [],
        polls: const [],
        notifications: const [],
      ))
      ..premiumTier = tier;

    /// Mounts the wizard's first step and runs [body], then always unmounts and
    /// disposes.
    ///
    /// AppProvider starts a periodic ticker in its constructor, and the
    /// framework checks for pending timers after the test body but *before* any
    /// tearDown, so a provider left running fails with "A Timer is still
    /// pending" — an error that says nothing about the bounty card.
    /// `try/finally` keeps that from masking a real assertion failure.
    Future<void> screen(
      WidgetTester tester,
      AppProvider app,
      ValueNotifier<bool> paywallOpened,
      Future<void> Function() body,
    ) async {
      // A real router: a Premium kind navigates with `context.push`. The
      // destination is a sentinel so a test can tell "opened the paywall" apart
      // from "stayed put".
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: CreateTournamentScreen()),
          ),
          GoRoute(
            path: RoutePaths.upgrade,
            builder: (_, _) {
              paywallOpened.value = true;
              return const Scaffold(body: Text('Upgrade'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(paywallOpened.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      try {
        await body();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        app.dispose();
        await tester.pump();
      }
    }

    /// Turns the KO bounty on and waits for the amount + type rows it reveals.
    Future<void> turnBountyOn(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(AppToggle));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
    }

    testWidgets('the control is there on a night with no payouts', (
      tester,
    ) async {
      // §C1 step 1: "The KO bounty stays available when Payouts is None — the
      // bounty pot is separate from the prize pool." The pot funds knockouts
      // and nothing else, so a night with no prize pool is exactly when the
      // bounty is still worth offering; the control must not be gated on a
      // prize pool existing.
      final paywall = ValueNotifier<bool>(false);
      await screen(tester, provider(), paywall, () async {
        await turnBountyOn(tester);

        expect(find.text('KO bounty'), findsOneWidget);
        expect(
          find.text('On top of the buy-in, a separate pot'),
          findsOneWidget,
        );
        expect(find.text('Bounty amount'), findsOneWidget);
        expect(find.text('Bounty type'), findsOneWidget);
        expect(find.text('Fixed'), findsOneWidget);
        expect(find.text('Progressive'), findsOneWidget);
        expect(find.text('Mystery'), findsOneWidget);
      });
    });

    testWidgets('the amount stepper stays 5-50 in steps of 5', (tester) async {
      final paywall = ValueNotifier<bool>(false);
      await screen(tester, provider(), paywall, () async {
        await turnBountyOn(tester);

        expect(find.byType(CountStepper), findsOneWidget);
        expect(find.text('5'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        expect(find.text('10'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        expect(find.text('15'), findsOneWidget);

        // The top of the range is a hard stop, not a hint: twenty more taps
        // leave the value on 50.
        for (var i = 0; i < 20; i++) {
          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();
        }
        expect(find.text('50'), findsOneWidget);

        // And the bottom of it is 5, not 0 — a bounty is never free money
        // nobody is paying into.
        for (var i = 0; i < 20; i++) {
          await tester.tap(find.byIcon(Icons.remove));
          await tester.pumpAndSettle();
        }
        expect(find.text('5'), findsOneWidget);
      });
    });

    testWidgets('the amount is shown as buy-in plus bounty', (tester) async {
      final paywall = ValueNotifier<bool>(false);
      await screen(tester, provider(), paywall, () async {
        await turnBountyOn(tester);
        // The stepper's 5 against the draft's untouched buy-in of 0.
        expect(find.text('Shown as "0 + 5"'), findsOneWidget);
      });
    });

    testWidgets('Fixed is free; the other two carry the PREMIUM pill', (
      tester,
    ) async {
      final paywall = ValueNotifier<bool>(false);
      await screen(tester, provider(), paywall, () async {
        await turnBountyOn(tester);

        // The pill rides on the two Premium cards and nowhere else: two of the
        // three, not three of the three.
        expect(find.text('PREMIUM'), findsNWidgets(2));
        expect(find.text('Free'), findsOneWidget);
      });
    });

    testWidgets('tapping a Premium kind opens the paywall on the free tier', (
      tester,
    ) async {
      final paywall = ValueNotifier<bool>(false);
      await screen(tester, provider(), paywall, () async {
        await turnBountyOn(tester);

        await tester.ensureVisible(find.text('Mystery'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mystery'));
        await tester.pumpAndSettle();

        // G1 — `/premium`, the same route PremiumGate and PremiumLock push.
        expect(paywall.value, isTrue);
        expect(find.text('Upgrade'), findsOneWidget);
      });
    });

    testWidgets('a Premium kind is selectable once the tier allows it', (
      tester,
    ) async {
      final paywall = ValueNotifier<bool>(false);
      await screen(
        tester,
        provider(tier: PremiumTier.premium),
        paywall,
        () async {
          await turnBountyOn(tester);

          await tester.ensureVisible(find.text('Progressive'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Progressive'));
          await tester.pumpAndSettle();

          // Stayed on the wizard rather than bouncing to the paywall.
          expect(paywall.value, isFalse);
          expect(find.text('Upgrade'), findsNothing);
          expect(find.text('Progressive'), findsOneWidget);
        },
      );
    });
  });
}
