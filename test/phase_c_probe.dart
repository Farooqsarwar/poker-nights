import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
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
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:poker_night/widgets/screen_shell.dart';
import 'package:provider/provider.dart';

import 'design_probe.dart' as design show loadRealFonts;

/// Phase C (host a tournament) camera: each tournament screen inside the real
/// [ScreenShell], against one seeded tournament put into the state that
/// screen is used in (published, check-in, running, final table, completed).
///
///   flutter test test/phase_c_probe.dart --update-goldens
///
/// Not a `*_test.dart`: a camera, not an assertion (see design_probe.dart).
void main() {
  setUpAll(design.loadRealFonts);
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterError.onError = (d) { if (const bool.fromEnvironment("PROBE_DEBUG")) debugPrint(d.toString()); };
  });
  tearDown(() => FlutterError.onError = FlutterError.presentError);

  const stats = UserStats(
    played: 34,
    wins: 6,
    podium: 11,
    avgFinish: 3.2,
    knockouts: 18,
  );
  const host = AppUser(
    id: 'u1',
    name: 'Alex Morgan',
    email: 'alex@poker.night',
    isAdmin: true,
    stats: stats,
  );
  const member = AppUser(
    id: 'u2',
    name: 'Marcus L.',
    email: 'marcus@poker.night',
    isAdmin: false,
    stats: stats,
  );
  const names = [
    'Alex Morgan', 'Marcus L.', 'Ava R.', 'Devi K.', 'Jordan P.', 'Sam T.',
    'Riley B.', 'Casey N.', 'Morgan F.', 'Quinn D.', 'Harper G.', 'Blake S.',
    'Rowan C.', 'Emery J.', 'Sage W.', 'Drew H.', 'Kai M.', 'Reese V.',
  ];

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
    rebuys: true,
    rebuysCloseLevel: 6,
    addOn: false,
    addOnCloseLevel: 8,
    anteEnabled: true,
    anteAfterLevel: 4,
    organizerPct: 0,
    breaks: const [],
  );
  final structure = TournamentEngine.generate(
    TournamentParams(
      players: 18,
      durationHours: 4,
      buyIn: 100,
      chipSet: MockData.defaultChipSet,
      rebuys: true,
      rebuysCloseLevel: 6,
      addOn: false,
      anteEnabled: true,
      anteAfterLevel: 4,
      koEnabled: false,
      koAmount: 0,
      organizerPct: 0,
    ),
  );

  /// [out] players (the last ones) are eliminated; the rest are seated at two
  /// tables. Everyone RSVPed going and is checked in unless [checkedIn] says
  /// otherwise.
  LiveGame game(LiveGameStatus status, {int out = 0, int checkedIn = 18}) {
    final players = [
      for (var i = 0; i < names.length; i++)
        Player(
          id: 'u${i + 1}',
          name: names[i],
          isGuest: false,
          rsvp: i == 16 ? Rsvp.maybe : Rsvp.going,
          checkedIn: i < checkedIn,
          confirmed: i < checkedIn,
          eliminated: i >= names.length - out,
          eliminationPos: i >= names.length - out ? names.length - i : null,
          rebuys: i == 4 ? 1 : 0,
          hasAddOn: false,
          knockouts: i == 1 ? 3 : 0,
          table: i.isEven ? 1 : 2,
          seat: i ~/ 2 + 1,
          stack: 26700 - i * 900,
          active: i < names.length - out,
        ),
    ];
    return LiveGame(
      id: 'live1',
      groupId: 'g1',
      settings: settings,
      structure: structure,
      status: status,
      publicCode: 'FP2608',
      tvCode: 'TV4821',
      currentLevel: 4,
      timerRunning: false,
      secondsRemaining: 872,
      players: players,
      chat: const [],
      announcements: const [],
      totalChipsInPlay: 480600,
      pendingGuests: const [],
      finishOrder: [
        for (var i = names.length - 1; i >= names.length - out; i--) 'u${i + 1}',
      ],
    );
  }

  Group group(LiveGame g) => Group(
    id: 'g1',
    name: 'Friday Poker Club',
    joinCode: 'FP2608',
    ownerId: 'u1',
    members: const [host, member],
    games: [g],
    chat: const [],
    polls: const [],
    notifications: const [],
  );

  Future<void> shoot(
    WidgetTester t,
    String name,
    String path,
    Widget screen,
    LiveGame g, {
    AppUser user = host,
    Size size = const Size(390, 844),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    final app = AppProvider()
      ..setUserForTesting(user)
      ..setCurrentGroupForTesting(group(g))
      ..setCurrentGame(g);
    final router = GoRouter(
      initialLocation: path,
      routes: [
        GoRoute(
          path: path,
          builder: (_, _) => ScreenShell(requiredPath: path, child: screen),
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
    for (Object? e = t.takeException(); e != null; e = t.takeException()) {
      if (const bool.fromEnvironment("PROBE_DEBUG") && !"$e".contains("google_fonts")) {
        debugPrint("PROBE EXCEPTION: $e");
      }
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/phase_c/$name.png'),
    );
    await t.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await t.pump();
    while (t.takeException() != null) {}
  }

  final shots = <String, (String, Widget, LiveGame, AppUser)>{
    'c1_create': (RoutePaths.createTournament, const CreateTournamentScreen(),
        game(LiveGameStatus.draft), host),
    'c2_structure': (RoutePaths.structureReview, const StructureReviewScreen(),
        game(LiveGameStatus.published), host),
    'c3_invitation': (RoutePaths.invitation, const InvitationScreen(),
        game(LiveGameStatus.published), host),
    // The member's RSVP view reads Firebase directly, which the test binding
    // does not have; the host view is the renderable one.
    'c4_checkin': (RoutePaths.checkIn, const CheckInScreen(),
        game(LiveGameStatus.checkin, checkedIn: 14), host),
    'c5_dashboard': (RoutePaths.adminDashboard, const AdminDashboardScreen(),
        game(LiveGameStatus.running, out: 6), host),
    'c6_rebuy': (RoutePaths.rebuySettlement, const RebuySettlementScreen(),
        game(LiveGameStatus.rebuypause, out: 2), host),
    'c7_final_table': (RoutePaths.finalTable, const FinalTableScreen(),
        game(LiveGameStatus.finaltable, out: 9), host),
    'c8_complete': (RoutePaths.completeTournament,
        const CompleteTournamentScreen(),
        game(LiveGameStatus.running, out: 14), host),
    'c9_podium': (RoutePaths.resultPodium, const ResultPodiumScreen(),
        game(LiveGameStatus.completed, out: 17), host),
    'c10_player_live': (RoutePaths.playerLive, const PlayerLiveScreen(),
        game(LiveGameStatus.running, out: 6), member),
  };

  for (final e in shots.entries) {
    testWidgets('${e.key} phone', (t) async {
      final (path, screen, g, user) = e.value;
      await shoot(t, '${e.key}_phone', path, screen, g, user: user);
    });
    testWidgets('${e.key} desktop', (t) async {
      final (path, screen, g, user) = e.value;
      await shoot(
        t,
        '${e.key}_desktop',
        path,
        screen,
        g,
        user: user,
        size: const Size(1280, 860),
      );
    });
  }
}
