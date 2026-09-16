import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/public/landing_screen.dart';
import 'package:poker_night/screens/public/privacy_screen.dart';
import 'package:poker_night/screens/public/support_screen.dart';
import 'package:poker_night/screens/public/terms_screen.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/widgets/ai_insights_panel.dart';
import 'package:poker_night/widgets/cash_settlement_panel.dart';
import 'package:poker_night/widgets/structure_audit_banner.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/services/payment_service.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:provider/provider.dart';

/// Does each screen actually render?
///
/// Every other test in this suite exercises the engine, the models or the
/// rules — none of them mount a widget, so for a long time nothing here could
/// tell whether a screen threw on open. The first run of this file found
/// exactly that: the public tools pages used `InkWell` with no `Material`
/// ancestor, because `AppPage` is a `ColoredBox` and they were the only public
/// screens missing a `Scaffold`. Live, and asserting on open.
///
/// These are smoke tests, not golden tests. They answer "does it build without
/// throwing", which is cheap, portable and catches the failure that matters
/// most — a screen nobody can open.
void main() {
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
  });

  /// google_fonts cannot fetch in the sandbox and throws per text style.
  /// Those are environment noise; anything else is a real failure, so they are
  /// separated rather than all swallowed.
  List<Object> realExceptions(WidgetTester t) {
    final kept = <Object>[];
    while (true) {
      final e = t.takeException();
      if (e == null) break;
      final text = e.toString();
      if (text.contains('google_fonts') ||
          text.contains('Failed to load font')) {
        continue;
      }
      kept.add(e);
    }
    return kept;
  }

  Future<List<Object>> mount(WidgetTester t, Widget screen) async {
    final app = AppProvider();
    await t.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp(home: screen),
      ),
    );
    await t.pump(const Duration(milliseconds: 50));
    final errors = realExceptions(t);

    // Unmount first, then dispose. AppProvider runs a periodic ticker for the
    // live clock; a tearDown that disposes after the framework has already
    // checked for pending timers fails every test with "A Timer is still
    // pending", which says nothing about the screen under test.
    await t.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await t.pump();
    return errors;
  }

  group('public screens open without throwing', () {
    final screens = <String, Widget>{
      'Landing': const LandingScreen(),
      'Tools index': const ToolsScreen(),
      'Blind Structure Generator': const ToolBlindsScreen(),
      'Tournament Clock': const ToolClockScreen(),
      'ICM Calculator': const ToolIcmScreen(),
      'Payout Calculator': const ToolPayoutsScreen(),
      'Privacy': const PrivacyScreen(),
      'Terms': const TermsScreen(),
      'Support': const SupportScreen(),
    };

    screens.forEach((name, screen) {
      testWidgets(name, (t) async {
        // Wide enough that a desktop layout is exercised rather than only the
        // narrow one.
        t.view.physicalSize = const Size(1200, 2000);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final errors = await mount(t, screen);
        expect(
          errors,
          isEmpty,
          reason: '$name threw on open: ${errors.join(' | ')}',
        );
      });
    });
  });

  group('public screens survive a phone-width layout', () {
    // §8 asks for one-handed live operation; the floor for that is that the
    // page renders at all on a phone without overflowing. Every public
    // screen is covered now, not just the three that happened to be built
    // when this group was written — the tools pages that were skipped are
    // exactly the kind of screen that hid the missing-Scaffold defect above.
    final screens = <String, Widget>{
      'Landing': const LandingScreen(),
      'Tools index': const ToolsScreen(),
      'Blind Structure Generator': const ToolBlindsScreen(),
      'Tournament Clock': const ToolClockScreen(),
      'ICM Calculator': const ToolIcmScreen(),
      'Payout Calculator': const ToolPayoutsScreen(),
      'Privacy': const PrivacyScreen(),
      'Terms': const TermsScreen(),
      'Support': const SupportScreen(),
    };

    screens.forEach((name, screen) {
      testWidgets('$name at 400px', (t) async {
        t.view.physicalSize = const Size(400, 900);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final errors = await mount(t, screen);
        expect(
          errors,
          isEmpty,
          reason: '$name threw at phone width: ${errors.join(' | ')}',
        );
      });
    });
  });

  group('public screens survive the smallest common phone width', () {
    // 320px (iPhone SE / older Android) is the floor below which nothing
    // reasonably needs to fit — but this app should not throw even there.
    // A screen that only breaks between 320 and 400px is exactly what a
    // single fixed width would miss.
    final screens = <String, Widget>{
      'Landing': const LandingScreen(),
      'Tools index': const ToolsScreen(),
      'Blind Structure Generator': const ToolBlindsScreen(),
      'Tournament Clock': const ToolClockScreen(),
      'ICM Calculator': const ToolIcmScreen(),
      'Payout Calculator': const ToolPayoutsScreen(),
      'Privacy': const PrivacyScreen(),
      'Terms': const TermsScreen(),
      'Support': const SupportScreen(),
    };

    screens.forEach((name, screen) {
      testWidgets('$name at 320px', (t) async {
        t.view.physicalSize = const Size(320, 720);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final errors = await mount(t, screen);
        expect(
          errors,
          isEmpty,
          reason: '$name threw at 320px: ${errors.join(' | ')}',
        );
      });
    });
  });

  group('public screens survive a large / desktop layout', () {
    // The desktop group above uses 1200px; ultra-wide monitors and maximised
    // browser windows go well past that. This is the width where a fixed
    // max-width assumption or an un-scrolled Row of many children would
    // overflow the other way.
    final screens = <String, Widget>{
      'Landing': const LandingScreen(),
      'Tools index': const ToolsScreen(),
      'Blind Structure Generator': const ToolBlindsScreen(),
      'Tournament Clock': const ToolClockScreen(),
      'ICM Calculator': const ToolIcmScreen(),
      'Payout Calculator': const ToolPayoutsScreen(),
    };

    screens.forEach((name, screen) {
      testWidgets('$name at 1920px', (t) async {
        t.view.physicalSize = const Size(1920, 1080);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        final errors = await mount(t, screen);
        expect(
          errors,
          isEmpty,
          reason: '$name threw at 1920px: ${errors.join(' | ')}',
        );
      });
    });
  });

  group('the panels built for sections 3 and 7 render', () {
    const chips = [
      ChipColor(color: 'White', hex: 0xFFE8E4D9, value: 1, quantity: 100),
      ChipColor(color: 'Red', hex: 0xFFC0392B, value: 5, quantity: 100),
      ChipColor(color: 'Blue', hex: 0xFF2980B9, value: 25, quantity: 50),
      ChipColor(color: 'Black', hex: 0xFF2C2C2C, value: 100, quantity: 30),
    ];

    final settings = GameSettings(
      name: 'Friday',
      date: '2026-09-18',
      time: '20:00',
      location: 'Kitchen',
      durationHours: 4,
      players: 9,
      buyIn: 20,
      chipSet: chips,
      chipSetName: 'Standard 300',
      koEnabled: false,
      koAmount: 0,
      rebuys: true,
      rebuysCloseLevel: 6,
      addOn: true,
      addOnCloseLevel: 8,
      anteEnabled: false,
      anteAfterLevel: 7,
      organizerPct: 10,
      breaks: const [ScheduledBreak(afterLevel: 6, durationMins: 10)],
    );

    final structure = TournamentEngine.generate(
      TournamentParams(
        players: settings.players,
        durationHours: settings.durationHours,
        buyIn: settings.buyIn,
        chipSet: settings.chipSet,
        rebuys: settings.rebuys,
        rebuysCloseLevel: settings.rebuysCloseLevel,
        reEntry: false,
        addOn: settings.addOn,
        anteEnabled: settings.anteEnabled,
        anteAfterLevel: settings.anteAfterLevel,
        koEnabled: false,
        koAmount: 0,
        organizerPct: settings.organizerPct,
        breaks: settings.breaks,
      ),
    );

    testWidgets('AI insights, free tier', (t) async {
      final errors = await mount(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: AiInsightsPanel(
              structure: structure,
              settings: settings,
              tier: PremiumTier.free,
            ),
          ),
        ),
      );
      expect(errors, isEmpty, reason: errors.join(' | '));
    });

    testWidgets('AI insights, premium tier', (t) async {
      final errors = await mount(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: AiInsightsPanel(
              structure: structure,
              settings: settings,
              tier: PremiumTier.premium,
            ),
          ),
        ),
      );
      expect(errors, isEmpty, reason: errors.join(' | '));
    });

    testWidgets('cash settlement, premium tier', (t) async {
      final errors = await mount(
        t,
        Scaffold(
          body: SingleChildScrollView(
            child: CashSettlementPanel(
              tier: PremiumTier.premium,
              players: const [
                CashPlayer(
                  id: 'a',
                  name: 'Ann',
                  stack: 150,
                  totalBuyIns: 100,
                  buyInCount: 1,
                  cashedOut: 0,
                ),
                CashPlayer(
                  id: 'b',
                  name: 'Ben',
                  stack: 50,
                  totalBuyIns: 100,
                  buyInCount: 1,
                  cashedOut: 0,
                ),
              ],
            ),
          ),
        ),
      );
      expect(errors, isEmpty, reason: errors.join(' | '));
    });

    testWidgets('cash settlement with nobody at the table', (t) async {
      final errors = await mount(
        t,
        const Scaffold(
          body: CashSettlementPanel(
            tier: PremiumTier.premium,
            players: [],
          ),
        ),
      );
      expect(errors, isEmpty, reason: errors.join(' | '));
    });

    testWidgets('the structure audit banner is silent when verified',
        (t) async {
      final game = LiveGame(
        id: 'g1',
        groupId: 'grp1',
        settings: settings,
        structure: structure,
        status: LiveGameStatus.running,
        publicCode: 'ABC123',
        tvCode: 'TV1234',
        currentLevel: 1,
        timerRunning: false,
        secondsRemaining: 600,
        players: const [],
        chat: const [],
        announcements: const [],
        totalChipsInPlay: 0,
        pendingGuests: const [],
        finishOrder: const [],
      );
      final errors = await mount(
        t,
        Scaffold(body: StructureAuditBanner(game: game)),
      );
      expect(errors, isEmpty, reason: errors.join(' | '));
      // Silent means silent — an honest structure must not put a red box on
      // every player's screen.
      expect(find.textContaining('does not match'), findsNothing);
    });
  });
}
