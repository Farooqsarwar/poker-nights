import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/route_paths.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/chip_color.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';

// Screens
import 'package:poker_night/screens/cash/cash_game_live_screen.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/screens/premium/checkout_screen.dart';
import 'package:poker_night/screens/premium/upgrade_screen.dart';
import 'package:poker_night/screens/public/auth_screen.dart';
import 'package:poker_night/screens/public/guest_flow_screen.dart';
import 'package:poker_night/screens/public/join_screen.dart';
import 'package:poker_night/screens/public/landing_screen.dart';
import 'package:poker_night/screens/public/privacy_screen.dart';
import 'package:poker_night/screens/public/support_screen.dart';
import 'package:poker_night/screens/public/terms_screen.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/screens/public/tv_mode_screen.dart';
import 'package:poker_night/screens/shell/chat_screen.dart';
import 'package:poker_night/screens/shell/chip_sets_screen.dart';
import 'package:poker_night/screens/shell/edit_chip_set_screen.dart';
import 'package:poker_night/screens/shell/group_screen.dart';
import 'package:poker_night/screens/shell/history_screen.dart';
import 'package:poker_night/screens/shell/home_screen.dart';
import 'package:poker_night/screens/shell/join_group_screen.dart';
import 'package:poker_night/screens/shell/members_screen.dart';
import 'package:poker_night/screens/shell/notifications_screen.dart';
import 'package:poker_night/screens/shell/polls_screen.dart';
import 'package:poker_night/screens/shell/presets_screen.dart';
import 'package:poker_night/screens/shell/profile_screen.dart';
import 'package:poker_night/screens/shell/settings_screen.dart';
import 'package:poker_night/screens/shell/stats_screen.dart';
import 'package:poker_night/screens/tournament/admin_dashboard_screen.dart';
import 'package:poker_night/screens/tournament/check_in_screen.dart';
import 'package:poker_night/screens/tournament/complete_tournament_screen.dart';
import 'package:poker_night/screens/tournament/create_tournament_screen.dart';
import 'package:poker_night/screens/tournament/deal_screen.dart';
import 'package:poker_night/screens/tournament/final_table_screen.dart';
import 'package:poker_night/screens/tournament/invitation_screen.dart';
import 'package:poker_night/screens/tournament/player_live_screen.dart';
import 'package:poker_night/screens/tournament/quick_start_screen.dart';
import 'package:poker_night/screens/tournament/rebuy_settlement_screen.dart';
import 'package:poker_night/screens/tournament/result_podium_screen.dart';
import 'package:poker_night/screens/tournament/structure_review_screen.dart';

Future<void> registerGoogleFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final fontFile = File(r'C:\Windows\Fonts\arial.ttf');
  final boldFile = File(r'C:\Windows\Fonts\arialbd.ttf');
  if (!fontFile.existsSync()) return;

  final regBytes = fontFile.readAsBytesSync();
  final boldBytes = boldFile.existsSync() ? boldFile.readAsBytesSync() : regBytes;

  final fontNames = [
    'SpaceGrotesk',
    'Space Grotesk',
    'SpaceGrotesk_regular',
    'SpaceGrotesk_bold',
    'SpaceGrotesk_400',
    'SpaceGrotesk_500',
    'SpaceGrotesk_600',
    'SpaceGrotesk_700',
    'SpaceGrotesk_300',
    'Roboto',
    'sans-serif',
  ];

  for (final name in fontNames) {
    final loader = FontLoader(name);
    final bytes = name.contains('bold') || name.contains('700') || name.contains('600') ? boldBytes : regBytes;
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

AppProvider createMockProvider() {
  const stats = UserStats(played: 14, wins: 4, podium: 8, avgFinish: 2.8, knockouts: 12);
  const host = AppUser(id: 'u1', name: 'Alex Morgan', email: 'alex@pokernight.app', isAdmin: true, stats: stats);

  final names = ['Alex M.', 'Marcus L.', 'Ava R.', 'Devi K.', 'Jordan P.', 'Chris T.', 'Sam B.', 'Taylor W.'];
  final players = [
    for (var i = 0; i < names.length; i++)
      Player(
        id: 'u${i + 1}',
        name: names[i],
        isGuest: false,
        rsvp: Rsvp.going,
        checkedIn: true,
        confirmed: true,
        eliminated: i >= 6,
        eliminationPos: i >= 6 ? i + 1 : null,
        rebuys: i == 1 ? 1 : 0,
        hasAddOn: false,
        knockouts: i == 0 ? 2 : 0,
        table: 1,
        seat: i + 1,
        stack: i == 0 ? 45000 : 25000 - (i * 2000),
        active: i < 6,
      ),
  ];

  final settings = GameSettings(
    name: 'Friday Night Freezeout',
    date: 'Fri, Oct 2',
    time: '8:00 PM',
    location: "Marcus's place",
    durationHours: 4,
    players: 8,
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
      players: 8,
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

  final game = LiveGame(
    id: 'live1',
    groupId: 'g1',
    settings: settings,
    structure: structure,
    status: LiveGameStatus.finaltable,
    publicCode: 'FP2608',
    tvCode: 'TV4821',
    currentLevel: 5,
    timerRunning: false,
    secondsRemaining: 742,
    players: players,
    chat: const [],
    announcements: const [],
    totalChipsInPlay: 200000,
    pendingGuests: const [],
    finishOrder: const [],
  );

  final group = Group(
    id: 'g1',
    name: 'Friday Poker Club',
    joinCode: 'FP2608',
    ownerId: 'u1',
    members: [
      host,
      const AppUser(id: 'u2', name: 'Marcus L.', email: 'marcus@test.com', isAdmin: false, stats: stats),
      const AppUser(id: 'u3', name: 'Ava R.', email: 'ava@test.com', isAdmin: false, stats: stats),
    ],
    games: [game],
    chat: const [],
    polls: const [],
    notifications: const [],
  );

  final cashSession = CashSession(
    id: 'cash1',
    settings: const CashSessionSettings(
      name: 'Friday Cash Game',
      date: 'Today',
      location: "Marcus's place",
      smallBlind: 1,
      bigBlind: 2,
      minBuyIn: 100,
      maxBuyIn: 500,
      maxPlayers: 9,
      chipValue: 1,
      trackSettlement: true,
    ),
    isCompleted: false,
    startTime: DateTime.now(),
    players: const [
      CashPlayer(id: 'u1', name: 'Alex M.', stack: 200, totalBuyIns: 200, buyInCount: 1, cashedOut: 0),
      CashPlayer(id: 'u2', name: 'Marcus L.', stack: 300, totalBuyIns: 200, buyInCount: 1, cashedOut: 0),
      CashPlayer(id: 'u3', name: 'Ava R.', stack: 100, totalBuyIns: 200, buyInCount: 1, cashedOut: 0),
    ],
  );

  return AppProvider()
    ..setUserForTesting(host)
    ..setCurrentGroupForTesting(group)
    ..setCurrentGameForTesting(game)
    ..setCashSessionForTesting(cashSession);
}

void main() {
  setUpAll(() async {
    await registerGoogleFonts();
    final outDir = Directory(r'D:\StudioProjects\poker_night\doc\spec_mappings\code_screens');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.navigation, (MethodCall methodCall) async => null);
    AppColors.currentPalette = ThemePalettes.forId('red');
    RecoveryService.enabled = false;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('google_fonts') ||
          text.contains('Failed to load font') ||
          text.contains('allowRuntimeFetching')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  tearDown(() {
    RecoveryService.enabled = true;
  });

  List<Object> drainExceptions(WidgetTester t) {
    final kept = <Object>[];
    while (true) {
      final e = t.takeException();
      if (e == null) break;
      final text = e.toString();
      if (text.contains('google_fonts') ||
          text.contains('Failed to load font') ||
          text.contains('allowRuntimeFetching is false')) {
        continue;
      }
      kept.add(e);
    }
    return kept;
  }

  // All 40 remaining screens
  final screens = <String, Widget Function()>{
    // Flow A
    '01_07_join_by_code': () => const JoinScreen(),
    '01_08_join_group': () => const JoinGroupScreen(code: 'FP2608'),

    // Flow B
    '02_01_home': () => const HomeScreen(),
    '02_02_group_games': () => const GroupScreen(),
    '02_03_members': () => const MembersScreen(),
    '02_04_chat': () => const ChatScreen(),
    '02_05_polls': () => const PollsScreen(),
    '02_06_notifications': () => const NotificationsScreen(),
    '02_07_history': () => const HistoryScreen(),

    // Flow C
    '03_00_quick_start': () => const QuickStartScreen(),
    '03_01_create_tournament': () => const CreateTournamentScreen(),
    '03_02_structure_review': () => const StructureReviewScreen(),
    '03_03_invitation': () => const InvitationScreen(),
    '03_04_check_in': () => const CheckInScreen(),
    '03_05_admin_dashboard': () => const AdminDashboardScreen(),
    '03_06_rebuy_settlement': () => const RebuySettlementScreen(),
    '03_07_final_table': () => const FinalTableScreen(),
    '03_08_complete_tournament': () => const CompleteTournamentScreen(),
    '03_09_result_podium': () => const ResultPodiumScreen(),
    '03_10_player_list': () => const PlayerLiveScreen(),

    // Flow D
    '04_01_cash_game_setup': () => const CashGameScreen(),
    '04_02_cash_game_live': () => const CashGameLiveScreen(),
    '04_03_tv_mode': () => const TVModeScreen(),

    // Flow E
    '05_01_tools_hub': () => const ToolsScreen(),
    '05_02_blind_structure': () => const ToolBlindsScreen(),
    '05_03_tournament_clock': () => const ToolClockScreen(),
    '05_04_icm_calculator': () => const ToolIcmScreen(),
    '05_05_payouts': () => const ToolPayoutsScreen(),
    '05_06_quick_blind': () => const ToolQuickBlindScreen(),

    // Flow F
    '06_01_profile': () => const ProfileScreen(),
    '06_02_settings': () => const SettingsScreen(),
    '06_03_stats': () => const StatsScreen(),
    '06_04_chip_sets': () => const ChipSetsScreen(),
    '06_05_edit_chip_set': () => const EditChipSetScreen(),
    '06_06_presets': () => const PresetsScreen(),
    '07_01_upgrade': () => const UpgradeScreen(),
    '07_02_checkout': () => const CheckoutScreen(planId: 'pro-annual'),
    '08_01_privacy': () => const PrivacyScreen(),
    '08_02_terms': () => const TermsScreen(fromSignUp: false),
    '08_03_support': () => const SupportScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('Export ${entry.key}', (t) async {
      final key = entry.key;
      final builder = entry.value;

      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1.0;

      final app = createMockProvider();
      final repaintKey = GlobalKey();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => RepaintBoundary(
              key: repaintKey,
              child: Scaffold(
                backgroundColor: const Color(0xFF0A0A0A),
                body: SafeArea(child: builder()),
              ),
            ),
          ),
        ],
        errorBuilder: (_, _) => const Scaffold(body: SizedBox.shrink()),
      );

      await t.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Space Grotesk',
              scaffoldBackgroundColor: const Color(0xFF0A0A0A),
            ),
            routerConfig: router,
          ),
        ),
      );

      await t.pump(const Duration(milliseconds: 100));

      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 1.0);
        await t.runAsync(() async {
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          if (byteData != null) {
            final pngBytes = byteData.buffer.asUint8List();
            final outFile = File('D:/StudioProjects/poker_night/doc/spec_mappings/code_screens/$key.png');
            outFile.writeAsBytesSync(pngBytes);
            print('  [CODE TO PNG] $key.png (${pngBytes.length} bytes)');
          }
        });
      }

      await t.pumpWidget(const SizedBox.shrink());
      app.dispose();
      await t.pump();
      drainExceptions(t);
      print('  -> test complete for $key');
    });
  }
}
