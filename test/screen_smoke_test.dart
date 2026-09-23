import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/public/landing_screen.dart';
import 'package:poker_night/screens/public/privacy_screen.dart';
import 'package:poker_night/screens/public/support_screen.dart';
import 'package:poker_night/screens/public/terms_screen.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/screens/public/guest_flow_screen.dart';
import 'package:poker_night/screens/public/join_screen.dart';
import 'package:poker_night/screens/public/tv_mode_screen.dart';
import 'package:poker_night/screens/shell/chat_screen.dart';
import 'package:poker_night/screens/shell/chip_sets_screen.dart';
import 'package:poker_night/screens/shell/edit_chip_set_screen.dart';
import 'package:poker_night/screens/shell/group_screen.dart';
import 'package:poker_night/screens/shell/history_screen.dart';
import 'package:poker_night/screens/shell/home_screen.dart';
import 'package:poker_night/screens/shell/members_screen.dart';
import 'package:poker_night/screens/shell/notifications_screen.dart';
import 'package:poker_night/screens/shell/polls_screen.dart';
import 'package:poker_night/screens/shell/presets_screen.dart';
import 'package:poker_night/screens/shell/profile_screen.dart';
import 'package:poker_night/screens/shell/settings_screen.dart';
import 'package:poker_night/screens/shell/stats_screen.dart';
import 'package:poker_night/screens/premium/checkout_screen.dart';
import 'package:poker_night/screens/premium/upgrade_screen.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/screens/cash/cash_game_live_screen.dart';
import 'package:poker_night/screens/tournament/admin_dashboard_screen.dart';
import 'package:poker_night/screens/tournament/check_in_screen.dart';
import 'package:poker_night/screens/tournament/complete_tournament_screen.dart';
import 'package:poker_night/screens/tournament/create_tournament_screen.dart';
import 'package:poker_night/screens/tournament/final_table_screen.dart';
import 'package:poker_night/screens/tournament/invitation_screen.dart';
import 'package:poker_night/screens/tournament/player_live_screen.dart';
import 'package:poker_night/screens/tournament/rebuy_settlement_screen.dart';
import 'package:poker_night/screens/tournament/result_podium_screen.dart';
import 'package:poker_night/screens/tournament/structure_review_screen.dart';
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
  ///
  /// A failure here reports only the one-line message — "A RenderFlex
  /// overflowed by N pixels" — because that is all the exception object
  /// carries. To find the widget, install a `FlutterError.onError` around the
  /// `pumpWidget` below that `debugPrint`s `details.toString()`: the full
  /// report names the file and line of the offending Row/Column and the
  /// constraints it was given, which is what actually tells you whether the
  /// fix is a Flexible, a scroll view or a different layout at that width.
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

  Future<List<Object>> mount(
    WidgetTester t,
    Widget screen, {
    bool shelled = false,
  }) async {
    final app = AppProvider();

    // A real GoRouter, not `MaterialApp(home:)`. Several screens read route
    // state or call `context.go(...)` as they open; without a router those
    // throw a go_router assertion that looks exactly like a layout failure in
    // the report but is only a gap in the harness. Anything the screen
    // navigates to lands on a blank page — we are testing the screen under
    // test, not the destination.
    //
    // `shelled` mirrors `router.dart`'s `shell(...)` helper, which wraps ~27
    // routes in `ScreenShell` — and `ScreenShell` is what supplies their
    // `Scaffold`. Mounting those bare made every one of them fail with "No
    // Material widget found", which reads like a real defect and is purely an
    // artifact of the harness not matching the router.
    //
    // It is a plain Scaffold rather than the real `ScreenShell` on purpose:
    // `ScreenShell` is also the route guard, and a fresh `AppProvider` has no
    // user, so the real shell would render its signed-out `_Gate` and the
    // screen under test would never build at all. A transparent Scaffold is
    // exactly the Material ancestor the shell contributes, minus the guard.
    //
    // The public screens stay bare (`shelled: false`) because that is how they
    // really mount — no shell, no Scaffold unless they build their own. That
    // is the missing-Material defect this file was written to catch, and it
    // still catches it.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => shelled
              ? Scaffold(backgroundColor: Colors.transparent, body: screen)
              : screen,
        ),
      ],
      errorBuilder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    );

    await t.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(routerConfig: router),
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

  /// Every screen in the app, keyed by the name a failure should report.
  ///
  /// This used to list only the nine public screens, and only those were ever
  /// checked at phone width. That left the screens the organiser actually runs
  /// a tournament on — the admin dashboard, the live player view, the create
  /// form — verified at desktop width and nowhere else, which is the exact
  /// opposite of how the app is used.
  /// `shelled` records whether `router.dart` mounts the screen through its
  /// `shell(...)` helper. Keep this in step with the router: a screen listed
  /// here as bare but shelled there will fail for a reason the app does not
  /// have, and one listed as shelled but mounted bare in the router will pass
  /// here while throwing in production.
  Map<String, ({Widget widget, bool shelled})> allScreens() =>
      <String, ({Widget widget, bool shelled})>{
    // Public / marketing — mounted straight off their GoRoute, no shell.
    'Landing': (widget: const LandingScreen(), shelled: false),
    'Tools index': (widget: const ToolsScreen(), shelled: false),
    'Blind Structure Generator': (widget: const ToolBlindsScreen(), shelled: false),
    'Tournament Clock': (widget: const ToolClockScreen(), shelled: false),
    'ICM Calculator': (widget: const ToolIcmScreen(), shelled: false),
    'Payout Calculator': (widget: const ToolPayoutsScreen(), shelled: false),
    'Privacy': (widget: const PrivacyScreen(), shelled: false),
    'Terms': (widget: const TermsScreen(), shelled: false),
    'Support': (widget: const SupportScreen(), shelled: false),
    'Guest flow': (widget: const GuestFlowScreen(), shelled: false),
    'Join': (widget: const JoinScreen(), shelled: false),
    'TV mode': (widget: const TVModeScreen(), shelled: false),
    // Shell
    'Home': (widget: const HomeScreen(), shelled: true),
    'Group': (widget: const GroupScreen(), shelled: true),
    'Members': (widget: const MembersScreen(), shelled: true),
    'Chat': (widget: const ChatScreen(), shelled: true),
    'Polls': (widget: const PollsScreen(), shelled: true),
    'History': (widget: const HistoryScreen(), shelled: true),
    'Stats': (widget: const StatsScreen(), shelled: true),
    'Profile': (widget: const ProfileScreen(), shelled: true),
    'Settings': (widget: const SettingsScreen(), shelled: true),
    'Notifications': (widget: const NotificationsScreen(), shelled: true),
    'Presets': (widget: const PresetsScreen(), shelled: true),
    'Chip sets': (widget: const ChipSetsScreen(), shelled: true),
    'Edit chip set': (widget: const EditChipSetScreen(), shelled: true),
    // Tournament
    'Create tournament': (widget: const CreateTournamentScreen(), shelled: true),
    'Structure review': (widget: const StructureReviewScreen(), shelled: true),
    'Check-in': (widget: const CheckInScreen(), shelled: true),
    'Invitation': (widget: const InvitationScreen(), shelled: true),
    'Admin dashboard': (widget: const AdminDashboardScreen(), shelled: true),
    'Player live': (widget: const PlayerLiveScreen(), shelled: true),
    'Rebuy settlement': (widget: const RebuySettlementScreen(), shelled: true),
    'Final table': (widget: const FinalTableScreen(), shelled: true),
    'Complete tournament': (widget: const CompleteTournamentScreen(), shelled: true),
    'Result podium': (widget: const ResultPodiumScreen(), shelled: true),
    // Cash
    'Cash game': (widget: const CashGameScreen(), shelled: true),
    'Cash game live': (widget: const CashGameLiveScreen(), shelled: true),
    // Premium
    'Upgrade': (widget: const UpgradeScreen(), shelled: true),
    'Checkout': (widget: const CheckoutScreen(), shelled: true),
  };

  /// The viewports every screen has to survive.
  ///
  /// 320x720 is the iPhone SE / older Android floor. 844x390 is a phone held
  /// LANDSCAPE — the worst case for this app, because `minTextAdapt: true`
  /// sizes text off the smaller of the two scale factors, so a 390px height
  /// used to shrink every label to under half its design size. 1920x1080 is
  /// the other end, where a fixed max-width or an unscrolled Row overflows the
  /// other way.
  const viewports = <String, Size>{
    '320px (iPhone SE)': Size(320, 720),
    '400px (phone)': Size(400, 900),
    '844x390 (phone landscape)': Size(844, 390),
    '768px (tablet)': Size(768, 1024),
    '1200px (desktop)': Size(1200, 2000),
    '1920px (large desktop)': Size(1920, 1080),
  };

  viewports.forEach((label, size) {
    group('every screen survives $label', () {
      allScreens().forEach((name, entry) {
        testWidgets('$name at $label', (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1.0;
          addTearDown(t.view.reset);

          final errors = await mount(t, entry.widget, shelled: entry.shelled);
          expect(
            errors,
            isEmpty,
            reason: '$name broke at $label: ${errors.join(' | ')}',
          );
        });
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
