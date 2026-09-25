import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/screens/cash/cash_game_live_screen.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/screens/public/tv_mode_screen.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/screen_shell.dart';
import 'package:provider/provider.dart';

import 'design_probe.dart' as design show loadRealFonts;

/// Phase D (cash game & TV) camera. Cash screens run inside the real
/// [ScreenShell] with a session started through the provider's own API; TV
/// mode is a bare public route showing a running tournament.
///
///   flutter test test/phase_d_probe.dart --update-goldens
///
/// Not a `*_test.dart`: a camera, not an assertion (see design_probe.dart).
void main() {
  setUpAll(design.loadRealFonts);
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterError.onError = (_) {};
  });
  tearDown(() => FlutterError.onError = FlutterError.presentError);

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

  LiveGame runningGame() {
    final settings = GameSettings(
      name: 'Friday Night Freezeout',
      date: 'Fri, Mar 14',
      time: '8:00 PM',
      location: "Marcus's place",
      durationHours: 4,
      players: 18,
      buyIn: 100,
      chipSet: MockData.defaultChipSet,
      chipSetName: 'Home set',
      koEnabled: false,
      koAmount: 0,
      rebuys: false,
      rebuysCloseLevel: 6,
      addOn: false,
      addOnCloseLevel: 8,
      anteEnabled: true,
      anteAfterLevel: 4,
      organizerPct: 0,
      breaks: const [],
    );
    return LiveGame(
      id: 'live1',
      groupId: 'g1',
      settings: settings,
      structure: TournamentEngine.generate(
        TournamentParams(
          players: 18,
          durationHours: 4,
          buyIn: 100,
          chipSet: MockData.defaultChipSet,
          rebuys: false,
          rebuysCloseLevel: 6,
          addOn: false,
          anteEnabled: true,
          anteAfterLevel: 4,
          koEnabled: false,
          koAmount: 0,
          organizerPct: 0,
        ),
      ),
      status: LiveGameStatus.running,
      publicCode: 'FP2608',
      tvCode: 'TV4821',
      currentLevel: 4,
      timerRunning: false,
      secondsRemaining: 872,
      players: const [],
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 480600,
      pendingGuests: const [],
      finishOrder: const [],
    );
  }

  Future<void> shoot(
    WidgetTester t,
    String name,
    String path,
    Widget screen, {
    bool shelled = true,
    bool withCash = false,
    bool withGame = false,
    Size size = const Size(390, 844),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final game = runningGame();
    final app = AppProvider()
      ..setUserForTesting(host)
      ..setCurrentGroupForTesting(
        Group(
          id: 'g1',
          name: 'Friday Poker Club',
          joinCode: 'FP2608',
          ownerId: 'u1',
          members: const [host],
          games: [game],
          chat: const [],
          polls: const [],
          notifications: const [],
        ),
      );
    if (withGame) app.setCurrentGame(game);
    if (withCash) {
      app.startCashGame(
        const CashSessionSettings(
          name: 'Friday cash',
          date: 'Fri, Mar 14',
          location: "Marcus's place",
          smallBlind: 1,
          bigBlind: 2,
          minBuyIn: 100,
          maxBuyIn: 500,
          maxPlayers: 9,
        ),
        const ['Alex M.', 'Marcus L.', 'Ava R.'],
      );
      final ids = [for (final p in app.cashSession!.players) p.id];
      app.cashBuyIn(ids[0], 200);
      app.cashBuyIn(ids[2], 300);
    }

    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: path,
          builder: (_, _) => shelled
              ? ScreenShell(requiredPath: path, child: screen)
              : screen,
        ),
      ],
      errorBuilder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    );
    await t.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: app,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.forPalette(ThemePalettes.forId('red')),
          routerConfig: router,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 700));
    while (t.takeException() != null) {}
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phase_d/$name.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await t.pump();
    while (t.takeException() != null) {}
  }

  testWidgets('d1 cash setup phone', (t) async {
    await shoot(t, 'd1_cash_setup_phone', RoutePaths.cashGame,
        const CashGameScreen());
  });
  testWidgets('d1 cash setup desktop', (t) async {
    await shoot(t, 'd1_cash_setup_desktop', RoutePaths.cashGame,
        const CashGameScreen(), size: const Size(1280, 860));
  });
  testWidgets('d2 cash live phone', (t) async {
    await shoot(t, 'd2_cash_live_phone', RoutePaths.cashGameLive,
        const CashGameLiveScreen(), withCash: true);
  });
  testWidgets('d2 cash live desktop', (t) async {
    await shoot(t, 'd2_cash_live_desktop', RoutePaths.cashGameLive,
        const CashGameLiveScreen(), withCash: true,
        size: const Size(1280, 860));
  });
  testWidgets('d3 tv wide', (t) async {
    await shoot(t, 'd3_tv_wide', RoutePaths.tvMode, const TVModeScreen(),
        shelled: false, withGame: true, size: const Size(1280, 720));
  });
  testWidgets('d3 tv phone', (t) async {
    await shoot(t, 'd3_tv_phone', RoutePaths.tvMode, const TVModeScreen(),
        shelled: false, withGame: true);
  });
}
