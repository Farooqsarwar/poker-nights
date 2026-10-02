/// Spec-board capture harness (v2): screenshots the REAL widgets, SEEDED with a
/// realistic Friday-night session, at two viewports.
///
/// Mobile  = 390x844 logical @2x  -> spec_boards/mobile/captures/<id>.png
/// Desktop = 1440x900 logical @1x -> spec_boards/desktop/captures/<id>.png
///
/// Never fails: per-screen exceptions go to spec_boards/capture_log.txt for
/// review. Run explicitly: flutter test test/capture_boards_test.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart'
    show pendingFontFutures;
import 'package:poker_night/app/colors.dart';
import 'package:poker_night/app/theme.dart';
import 'package:poker_night/models/app_notification.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/services/recovery_service.dart';
import 'package:poker_night/theme/theme_palette.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';
import 'package:provider/provider.dart';

import 'package:poker_night/screens/public/splash_screen.dart';
import 'package:poker_night/screens/public/landing_screen.dart';
import 'package:poker_night/screens/public/auth_screen.dart';
import 'package:poker_night/screens/public/guest_flow_screen.dart';
import 'package:poker_night/screens/public/join_screen.dart';
import 'package:poker_night/screens/shell/join_group_screen.dart';
import 'package:poker_night/screens/shell/home_screen.dart';
import 'package:poker_night/screens/shell/group_screen.dart';
import 'package:poker_night/screens/shell/members_screen.dart';
import 'package:poker_night/screens/shell/chat_screen.dart';
import 'package:poker_night/screens/shell/polls_screen.dart';
import 'package:poker_night/screens/shell/notifications_screen.dart';
import 'package:poker_night/screens/shell/history_screen.dart';
import 'package:poker_night/screens/tournament/quick_start_screen.dart';
import 'package:poker_night/screens/tournament/create_tournament_screen.dart';
import 'package:poker_night/screens/tournament/structure_review_screen.dart';
import 'package:poker_night/screens/tournament/invitation_screen.dart';
import 'package:poker_night/screens/tournament/check_in_screen.dart';
import 'package:poker_night/screens/tournament/admin_dashboard_screen.dart';
import 'package:poker_night/screens/tournament/rebuy_settlement_screen.dart';
import 'package:poker_night/screens/tournament/final_table_screen.dart';
import 'package:poker_night/screens/tournament/complete_tournament_screen.dart';
import 'package:poker_night/screens/tournament/result_podium_screen.dart';
import 'package:poker_night/screens/tournament/player_live_screen.dart';
import 'package:poker_night/screens/cash/cash_game_screen.dart';
import 'package:poker_night/screens/cash/cash_game_live_screen.dart';
import 'package:poker_night/screens/public/tv_mode_screen.dart';
import 'package:poker_night/screens/public/tools_screen.dart';
import 'package:poker_night/screens/public/privacy_screen.dart';
import 'package:poker_night/screens/public/terms_screen.dart';
import 'package:poker_night/screens/public/support_screen.dart';
import 'package:poker_night/screens/shell/profile_screen.dart';
import 'package:poker_night/screens/shell/settings_screen.dart';
import 'package:poker_night/screens/shell/stats_screen.dart';
import 'package:poker_night/screens/shell/chip_sets_screen.dart';
import 'package:poker_night/screens/shell/edit_chip_set_screen.dart';
import 'package:poker_night/screens/shell/presets_screen.dart';
import 'package:poker_night/screens/premium/upgrade_screen.dart';
import 'package:poker_night/screens/premium/checkout_screen.dart';

// ---------------------------------------------------------------- fixtures ---

const _users = [
  ('u1', 'Alice', true),
  ('u2', 'Bob', false),
  ('u3', 'Carol', false),
  ('u4', 'Dave', false),
  ('u5', 'Eve', false),
  ('u6', 'Frank', false),
];

AppUser _user(String id, String name, bool admin) => AppUser(
      id: id,
      name: name,
      email: '$id@example.com',
      isAdmin: admin,
      stats: const UserStats(
        played: 24,
        wins: 5,
        podium: 9,
        avgFinish: 4.2,
        knockouts: 31,
      ),
    );

const _stacks = [42000, 33500, 28000, 25000, 21000, 18000, 15000, 12000, 9500];
const _names9 = [
  'Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi', 'Ivan'
];

List<Player> _players({bool eliminated = false}) => [
      for (var i = 0; i < 9; i++)
        Player(
          id: 'u${i + 1}',
          name: _names9[i],
          isGuest: false,
          rsvp: i < 6 ? Rsvp.going : (i < 8 ? Rsvp.maybe : Rsvp.cant),
          checkedIn: i < 6,
          confirmed: true,
          eliminated: eliminated,
          eliminationPos: eliminated ? 9 - i : null,
          rebuys: i == 1 ? 2 : 0,
          hasAddOn: i == 3,
          knockouts: (i * 7) % 5,
          table: i.isEven ? 1 : 2,
          seat: i + 1,
          stack: _stacks[i],
          active: !eliminated,
        ),
    ];

GameSettings _settings() => GameSettings(
      name: 'Friday Night Freezeout',
      date: 'Fri, Mar 14',
      time: '8:00 PM',
      location: "Marcus's place",
      durationHours: 4,
      players: 9,
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

TournamentStructure _structure() => TournamentEngine.generate(
      TournamentParams(
        players: 9,
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

LiveGame _game(LiveGameStatus status, {List<Player>? players}) {
  final ps = players ?? _players();
  return LiveGame(
    id: 'live1',
    groupId: 'g1',
    settings: _settings(),
    structure: _structure(),
    status: status,
    publicCode: 'FP2608',
    tvCode: 'TV4821',
    currentLevel: 5,
    timerRunning: false,
    secondsRemaining: 800,
    players: ps,
    chat: const [],
    announcements: [
      Announcement(
        id: 'a1',
        text: 'Level 5 started: 200 / 400',
        timestamp: DateTime(2026, 3, 14, 21, 40),
      ),
    ],
    totalChipsInPlay: ps.fold<int>(0, (s, p) => s + (p.stack ?? 0).toInt()),
    pendingGuests: const [],
    finishOrder: status == LiveGameStatus.completed
        ? [for (var i = 0; i < 9; i++) 'u${i + 1}']
        : const [],
  );
}

Group _group(LiveGame live, LiveGame done) => Group(
      id: 'g1',
      name: 'Friday Poker Club',
      joinCode: 'FP2608',
      ownerId: 'u1',
      members: [for (final u in _users) _user(u.$1, u.$2, u.$3)],
      games: [live, done],
      chat: [
        ChatMessage(
          id: 'm1',
          authorId: 'u1',
          authorName: 'Alice',
          body: 'Dealer ready, cards in the air at 8!',
          timestamp: DateTime(2026, 3, 14, 19, 52),
          deleted: false,
        ),
        ChatMessage(
          id: 'm2',
          authorId: 'u2',
          authorName: 'Bob',
          body: 'Running 10 late, save me a seat',
          timestamp: DateTime(2026, 3, 14, 19, 58),
          deleted: false,
        ),
      ],
      polls: [
        Poll(
          id: 'p1',
          question: 'Friday game — what time?',
          options: const ['8:00 PM', '8:30 PM', "Can't make it"],
          votes: const {
            'u1': ['8:00 PM'],
            'u2': ['8:00 PM'],
            'u3': ['8:30 PM'],
          },
          closed: false,
          createdAt: DateTime(2026, 3, 10, 12, 0),
        ),
      ],
      notifications: [
        AppNotification(
          id: 'n1',
          title: 'Game starts in 1 hour',
          body: 'Friday Night Freezeout at Marcus\u2019s place',
          type: NotificationType.game,
          link: null,
          read: false,
          timestamp: DateTime(2026, 3, 14, 19, 0),
        ),
        AppNotification(
          id: 'n2',
          title: 'Bob finished 2nd',
          body: 'Last Sunday deepstack results are in',
          type: NotificationType.result,
          link: null,
          read: true,
          timestamp: DateTime(2026, 3, 8, 22, 15),
        ),
      ],
    );

CashSession _cash() => CashSession(
      id: 'cash1',
      settings: const CashSessionSettings(
        name: 'Friday Cash 1/2',
        date: 'Fri, Mar 14',
        location: "Marcus's place",
        smallBlind: 1,
        bigBlind: 2,
        minBuyIn: 40,
        maxBuyIn: 200,
        maxPlayers: 9,
      ),
      startTime: DateTime(2026, 3, 14, 20, 0),
      players: const [
        CashPlayer(
          id: 'u1', name: 'Alice', stack: 187.5,
          totalBuyIns: 200, buyInCount: 2, cashedOut: 0,
        ),
        CashPlayer(
          id: 'u2', name: 'Bob', stack: 320,
          totalBuyIns: 300, buyInCount: 2, cashedOut: 0,
        ),
        CashPlayer(
          id: 'u3', name: 'Carol', stack: 0,
          totalBuyIns: 200, buyInCount: 1, cashedOut: 250,
          hasCashedOut: true,
        ),
        CashPlayer(
          id: 'u4', name: 'Dave', stack: 95.5,
          totalBuyIns: 100, buyInCount: 1, cashedOut: 0,
        ),
        CashPlayer(
          id: 'u5', name: 'Eve', stack: 410,
          totalBuyIns: 400, buyInCount: 3, cashedOut: 0,
        ),
      ],
    );

// ---------------------------------------------------------------- harness ---

typedef Entry = ({
  Widget Function() build,
  bool shelled,
  LiveGameStatus? game,
  bool cash,
});

/// Registers the app's REAL typeface (Space Grotesk, all 5 bundled weights)
/// under every family name google_fonts asks for, so captures render the
/// shipped letter shapes instead of the test fallback. google_fonts names
/// each weight its own family (`SpaceGrotesk_700`, ...), hence the table.
/// Set --dart-define=NOFONTS=true to skip registration (proves the real
/// fonts take effect when captures differ from the NOFONTS run).
const _noFonts = bool.fromEnvironment('NOFONTS');

Future<void> _registerAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  if (_noFonts) return;
  Future<ByteData> bytes(String file) async {
    try {
      return await rootBundle.load('assets/google_fonts/$file');
    } catch (_) {
      final raw = await File('assets/google_fonts/$file').readAsBytes();
      return ByteData.view(raw.buffer);
    }
  }

  const table = {
    'SpaceGrotesk': 'SpaceGrotesk-Regular.ttf',
    'Space Grotesk': 'SpaceGrotesk-Regular.ttf',
    'SpaceGrotesk_regular': 'SpaceGrotesk-Regular.ttf',
    'SpaceGrotesk_300': 'SpaceGrotesk-Light.ttf',
    'SpaceGrotesk_400': 'SpaceGrotesk-Regular.ttf',
    'SpaceGrotesk_500': 'SpaceGrotesk-Medium.ttf',
    'SpaceGrotesk_600': 'SpaceGrotesk-SemiBold.ttf',
    'SpaceGrotesk_700': 'SpaceGrotesk-Bold.ttf',
    'SpaceGrotesk_800': 'SpaceGrotesk-Bold.ttf',
    'SpaceGrotesk_bold': 'SpaceGrotesk-Bold.ttf',
    'Roboto': 'SpaceGrotesk-Regular.ttf',
  };
  for (final e in table.entries) {
    final loader = FontLoader(e.key)..addFont(bytes(e.value));
    await loader.load();
  }
}

void main() {
  setUp(() {
    AppColors.currentPalette = ThemePalettes.forId('red');
    RecoveryService.enabled = false;
    GoogleFonts.config.allowRuntimeFetching = false;
    // Captures, not assertions: async environment noise (connectivity
    // channel, font fetch) is logged per screen, never thrown.
    FlutterError.onError = (_) {};
  });
  tearDown(() {
    RecoveryService.enabled = true;
    FlutterError.onError = FlutterError.presentError;
  });

  setUpAll(() async {
    await _registerAppFonts();
    for (final f in ['mobile', 'desktop']) {
      Directory('spec_boards/$f/captures').createSync(recursive: true);
    }
    File('spec_boards/capture_log.txt')
        .writeAsStringSync('capture log\n', mode: FileMode.write);
  });

  const r = LiveGameStatus.running;
  final entries = <String, Entry>{
    '01_01_splash': (build: () => const SplashScreen(), shelled: false, game: null, cash: false),
    '01_02_landing': (build: () => const LandingScreen(), shelled: false, game: null, cash: false),
    '01_03_sign_in': (build: () => const AuthScreen(mode: AuthMode.login), shelled: false, game: null, cash: false),
    '01_04_register': (build: () => const AuthScreen(mode: AuthMode.register), shelled: false, game: null, cash: false),
    '01_05_forgot_password': (build: () => const AuthScreen(mode: AuthMode.forgotPassword), shelled: false, game: null, cash: false),
    '01_06_guest_flow': (build: () => const GuestFlowScreen(), shelled: false, game: null, cash: false),
    '01_07_join_by_code': (build: () => const JoinScreen(), shelled: false, game: null, cash: false),
    '01_08_join_group': (build: () => const JoinGroupScreen(code: 'FP2608'), shelled: true, game: null, cash: false),
    '02_01_home': (build: () => const HomeScreen(), shelled: true, game: null, cash: false),
    '02_02_group_games': (build: () => const GroupScreen(), shelled: true, game: null, cash: false),
    '02_03_members': (build: () => const MembersScreen(), shelled: true, game: null, cash: false),
    '02_04_chat': (build: () => const ChatScreen(), shelled: true, game: null, cash: false),
    '02_05_polls': (build: () => const PollsScreen(), shelled: true, game: null, cash: false),
    '02_06_notifications': (build: () => const NotificationsScreen(), shelled: true, game: null, cash: false),
    '02_07_history': (build: () => const HistoryScreen(), shelled: true, game: null, cash: false),
    '03_00_quick_start': (build: () => const QuickStartScreen(), shelled: true, game: null, cash: false),
    '03_01_create_tournament': (build: () => const CreateTournamentScreen(), shelled: true, game: null, cash: false),
    '03_02_structure_review': (build: () => const StructureReviewScreen(), shelled: true, game: LiveGameStatus.published, cash: false),
    '03_03_invitation': (build: () => const InvitationScreen(), shelled: true, game: LiveGameStatus.published, cash: false),
    '03_04_check_in': (build: () => const CheckInScreen(), shelled: true, game: LiveGameStatus.checkin, cash: false),
    '03_05_admin_dashboard': (build: () => const AdminDashboardScreen(), shelled: true, game: r, cash: false),
    '03_06_rebuy_settlement': (build: () => const RebuySettlementScreen(), shelled: true, game: LiveGameStatus.rebuypause, cash: false),
    '03_07_final_table': (build: () => const FinalTableScreen(), shelled: true, game: LiveGameStatus.finaltable, cash: false),
    '03_08_complete_tournament': (build: () => const CompleteTournamentScreen(), shelled: true, game: LiveGameStatus.completed, cash: false),
    '03_09_result_podium': (build: () => const ResultPodiumScreen(), shelled: true, game: LiveGameStatus.completed, cash: false),
    '03_10_player_list': (build: () => const PlayerLiveScreen(), shelled: true, game: r, cash: false),
    '04_01_cash_game_setup': (build: () => const CashGameScreen(), shelled: true, game: null, cash: false),
    '04_02_cash_game_live': (build: () => const CashGameLiveScreen(), shelled: true, game: null, cash: true),
    '04_03_tv_mode': (build: () => const TVModeScreen(), shelled: false, game: null, cash: false),
    '05_01_tools_hub': (build: () => const ToolsScreen(), shelled: false, game: null, cash: false),
    '05_02_blind_structure': (build: () => const ToolBlindsScreen(), shelled: false, game: null, cash: false),
    '05_03_tournament_clock': (build: () => const ToolClockScreen(), shelled: false, game: null, cash: false),
    '05_04_icm_calculator': (build: () => const ToolIcmScreen(), shelled: false, game: null, cash: false),
    '05_05_payouts': (build: () => const ToolPayoutsScreen(), shelled: false, game: null, cash: false),
    '05_06_quick_blind': (build: () => const ToolQuickBlindScreen(), shelled: false, game: null, cash: false),
    '06_01_profile': (build: () => const ProfileScreen(), shelled: true, game: null, cash: false),
    '06_02_settings': (build: () => const SettingsScreen(), shelled: true, game: null, cash: false),
    '06_03_stats': (build: () => const StatsScreen(), shelled: true, game: null, cash: false),
    '06_04_chip_sets': (build: () => const ChipSetsScreen(), shelled: true, game: null, cash: false),
    '06_05_edit_chip_set': (build: () => const EditChipSetScreen(), shelled: true, game: null, cash: false),
    '06_06_presets': (build: () => const PresetsScreen(), shelled: true, game: null, cash: false),
    '07_01_upgrade': (build: () => const UpgradeScreen(), shelled: true, game: null, cash: false),
    '07_02_checkout': (build: () => const CheckoutScreen(planId: 'demo-monthly'), shelled: true, game: null, cash: false),
    '08_01_privacy': (build: () => const PrivacyScreen(), shelled: false, game: null, cash: false),
    '08_02_terms': (build: () => const TermsScreen(), shelled: false, game: null, cash: false),
    '08_03_support': (build: () => const SupportScreen(), shelled: false, game: null, cash: false),
  };

  const factors = {
    'mobile': (Size(390, 844), 2.0),
    'desktop': (Size(1440, 900), 1.0),
  };

  for (final factor in factors.entries) {
    group('capture ${factor.key}', () {
      for (final entry in entries.entries) {
        testWidgets('${entry.key} @ ${factor.key}', (t) async {
          final logical = factor.value.$1;
          final dpr = factor.value.$2;
          t.view.physicalSize =
              Size(logical.width * dpr, logical.height * dpr);
          t.view.devicePixelRatio = dpr;
          addTearDown(t.view.reset);

          final app = AppProvider();
          app.setUserForTesting(_user('u1', 'Alice', true));
          final live = _game(r);
          final done = _game(
            LiveGameStatus.completed,
            players: _players(eliminated: true),
          );
          app.setCurrentGroupForTesting(_group(live, done));
          final want = entry.value.game;
          if (want != null) {
            app.setCurrentGameForTesting(
              want == LiveGameStatus.completed
                  ? _game(want, players: _players(eliminated: true))
                  : _game(want),
            );
          }
          if (entry.value.cash) app.setCashSessionForTesting(_cash());

          final shotKey = GlobalKey();
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => RepaintBoundary(
                  key: shotKey,
                  child: entry.value.shelled
                      ? Scaffold(
                          // ScreenShell's own ground (§B1 bg #0A0A0A).
                          backgroundColor: const Color(0xFF0A0A0A),
                          body: entry.value.build(),
                        )
                      : entry.value.build(),
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
                theme: AppTheme.forPalette(
                  ThemePalettes.forId('red'),
                  brightness: Brightness.dark,
                ),
                routerConfig: router,
              ),
            ),
          );
          await t.pump();
          if (entry.key == '01_01_splash') {
            // Settle on the wordmark face: past the flip, before exit fade.
            await t.pump(const Duration(milliseconds: 3200));
          } else {
            await t.pump(const Duration(milliseconds: 800));
          }
          // Same font settle as the responsive audit: capture final metrics.
          await t.runAsync(() async {
            for (final f in List.of(pendingFontFutures)) {
              try {
                await f.timeout(const Duration(seconds: 5));
              } catch (_) {}
            }
          });
          await t.pump();

          final problems = <String>[];
          Object? e;
          while ((e = t.takeException()) != null) {
            problems.add(e.toString().split('\n').first);
          }

          await t.runAsync(() async {
            final obj = shotKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
            final img = await obj.toImage(
                pixelRatio: t.view.devicePixelRatio);
            final bytes =
                await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              'spec_boards/${factor.key}/captures/${entry.key}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
            final line =
                '${entry.key} @ ${factor.key}: ${problems.isEmpty ? 'clean' : problems.join(' | ')}';
            await File('spec_boards/capture_log.txt')
                .writeAsString('$line\n', mode: FileMode.append);
          });
          print('captured ${entry.key} @ ${factor.key}');

          await t.pumpWidget(const SizedBox.shrink());
          app.dispose();
          await t.pump();
          while (t.takeException() != null) {}
        });
      }
    });
  }
}
