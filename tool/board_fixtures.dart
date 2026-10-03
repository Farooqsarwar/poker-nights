/// Shared fixtures for the spec-board tooling (capture, content probe, audit).
///
/// Seeded Friday-night session: 9 players, live + finished games, chat, poll,
/// notifications, 5-player cash session. Imported by tool/capture_boards_test.dart
/// and tool/content_probe_test.dart (both run via `flutter test <path>`).
library;

// The @visibleForTesting provider setters are the supported seam this fixture
// exists to use; tool/ is not a test/ directory, so the analyzer cannot see
// that.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:poker_night/models/app_notification.dart';
import 'package:poker_night/models/cash_game.dart';
import 'package:poker_night/models/game.dart';
import 'package:poker_night/models/group.dart';
import 'package:poker_night/models/live_game.dart';
import 'package:poker_night/models/tournament.dart';
import 'package:poker_night/models/user.dart';
import 'package:poker_night/providers/app_provider.dart';
import 'package:poker_night/utils/mock_data.dart';
import 'package:poker_night/utils/tournament_engine.dart';

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

const fixtureUsers = [
  ('u1', 'Alice', true),
  ('u2', 'Bob', false),
  ('u3', 'Carol', false),
  ('u4', 'Dave', false),
  ('u5', 'Eve', false),
  ('u6', 'Frank', false),
];

AppUser fixtureUser(String id, String name, bool admin) => AppUser(
      id: id,
      name: name,
      email: '$id@example.com',
      isAdmin: admin,
      stats: const UserStats(
        played: 24, wins: 5, podium: 9, avgFinish: 4.2, knockouts: 31,
      ),
    );

const fixtureStacks = [
  42000, 33500, 28000, 25000, 21000, 18000, 15000, 12000, 9500
];
const fixtureNames9 = [
  'Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi', 'Ivan'
];

List<Player> fixturePlayers({bool eliminated = false}) => [
      for (var i = 0; i < 9; i++)
        Player(
          id: 'u${i + 1}',
          name: fixtureNames9[i],
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
          stack: fixtureStacks[i],
          active: !eliminated,
        ),
    ];

GameSettings fixtureSettings() => GameSettings(
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

TournamentStructure fixtureStructure() => TournamentEngine.generate(
      TournamentParams(
        players: 9, durationHours: 4, buyIn: 100,
        chipSet: MockData.defaultChipSet,
        rebuys: true, rebuysCloseLevel: 6, addOn: false,
        anteEnabled: true, anteAfterLevel: 4,
        koEnabled: false, koAmount: 0, organizerPct: 0,
      ),
    );

LiveGame fixtureGame(LiveGameStatus status, {List<Player>? players}) {
  final ps = players ?? fixturePlayers();
  return LiveGame(
    id: 'live1', groupId: 'g1',
    settings: fixtureSettings(), structure: fixtureStructure(),
    status: status, publicCode: 'FP2608', tvCode: 'TV4821',
    currentLevel: 5, timerRunning: false, secondsRemaining: 800,
    players: ps, chat: const [],
    announcements: [
      Announcement(
        id: 'a1', text: 'Level 5 started: 200 / 400',
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

Group fixtureGroup(LiveGame live, LiveGame done) => Group(
      id: 'g1', name: 'Friday Poker Club', joinCode: 'FP2608', ownerId: 'u1',
      members: [for (final u in fixtureUsers) fixtureUser(u.$1, u.$2, u.$3)],
      games: [live, done],
      chat: [
        ChatMessage(
          id: 'm1', authorId: 'u1', authorName: 'Alice',
          body: 'Dealer ready, cards in the air at 8!',
          timestamp: DateTime(2026, 3, 14, 19, 52), deleted: false,
        ),
        ChatMessage(
          id: 'm2', authorId: 'u2', authorName: 'Bob',
          body: 'Running 10 late, save me a seat',
          timestamp: DateTime(2026, 3, 14, 19, 58), deleted: false,
        ),
      ],
      polls: [
        Poll(
          id: 'p1', question: 'Friday game — what time?',
          options: const ['8:00 PM', '8:30 PM', "Can't make it"],
          votes: const {
            'u1': ['8:00 PM'], 'u2': ['8:00 PM'], 'u3': ['8:30 PM']
          },
          closed: false, createdAt: DateTime(2026, 3, 10, 12, 0),
        ),
      ],
      notifications: [
        AppNotification(
          id: 'n1', title: 'Game starts in 1 hour',
          body: 'Friday Night Freezeout at Marcus\u2019s place',
          type: NotificationType.game, link: null, read: false,
          timestamp: DateTime(2026, 3, 14, 19, 0),
        ),
        AppNotification(
          id: 'n2', title: 'Bob finished 2nd',
          body: 'Last Sunday deepstack results are in',
          type: NotificationType.result, link: null, read: true,
          timestamp: DateTime(2026, 3, 8, 22, 15),
        ),
      ],
    );

CashSession fixtureCash() => CashSession(
      id: 'cash1',
      settings: const CashSessionSettings(
        name: 'Friday Cash 1/2', date: 'Fri, Mar 14',
        location: "Marcus's place",
        smallBlind: 1, bigBlind: 2, minBuyIn: 40, maxBuyIn: 200, maxPlayers: 9,
      ),
      startTime: DateTime(2026, 3, 14, 20, 0),
      players: const [
        CashPlayer(id: 'u1', name: 'Alice', stack: 187.5,
            totalBuyIns: 200, buyInCount: 2, cashedOut: 0),
        CashPlayer(id: 'u2', name: 'Bob', stack: 320,
            totalBuyIns: 300, buyInCount: 2, cashedOut: 0),
        CashPlayer(id: 'u3', name: 'Carol', stack: 0,
            totalBuyIns: 200, buyInCount: 1, cashedOut: 250,
            hasCashedOut: true),
        CashPlayer(id: 'u4', name: 'Dave', stack: 95.5,
            totalBuyIns: 100, buyInCount: 1, cashedOut: 0),
        CashPlayer(id: 'u5', name: 'Eve', stack: 410,
            totalBuyIns: 400, buyInCount: 3, cashedOut: 0),
      ],
    );

typedef BoardEntry = ({
  Widget Function() build, bool shelled, LiveGameStatus? game, bool cash,
});

const _r = LiveGameStatus.running;

final Map<String, BoardEntry> boardEntries = {
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
  '03_05_admin_dashboard': (build: () => const AdminDashboardScreen(), shelled: true, game: _r, cash: false),
  '03_06_rebuy_settlement': (build: () => const RebuySettlementScreen(), shelled: true, game: LiveGameStatus.rebuypause, cash: false),
  '03_07_final_table': (build: () => const FinalTableScreen(), shelled: true, game: LiveGameStatus.finaltable, cash: false),
  '03_08_complete_tournament': (build: () => const CompleteTournamentScreen(), shelled: true, game: LiveGameStatus.completed, cash: false),
  '03_09_result_podium': (build: () => const ResultPodiumScreen(), shelled: true, game: LiveGameStatus.completed, cash: false),
  '03_10_player_list': (build: () => const PlayerLiveScreen(), shelled: true, game: _r, cash: false),
  '04_01_cash_game_setup': (build: () => const CashGameScreen(), shelled: true, game: null, cash: false),
  '04_02_cash_game_live': (build: () => const CashGameLiveScreen(), shelled: true, game: null, cash: true),
  '04_03_tv_mode': (build: () => const TVModeScreen(), shelled: false, game: _r, cash: false),
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

/// Seeds [app] with the Friday-night session. Pass the entry's game/cash flags.
///
/// Inbox notifications go through [AppProvider.pushNotification], which
/// prepends locally with no backend (repo fan-out is backend-guarded), so the
/// notifications board shows real content. Push oldest-first: prepend order.
void seedBoardProvider(AppProvider app,
    {LiveGameStatus? game, bool cash = false}) {
  app.setUserForTesting(fixtureUser('u1', 'Alice', true));
  final live = fixtureGame(LiveGameStatus.running);
  final done = fixtureGame(LiveGameStatus.completed,
      players: fixturePlayers(eliminated: true));
  app.setCurrentGroupForTesting(fixtureGroup(live, done));
  app.pushNotification(AppNotification(
    id: 'n2', title: 'Bob finished 2nd',
    body: 'Last Sunday deepstack results are in',
    type: NotificationType.result, link: null, read: true,
    timestamp: DateTime(2026, 3, 8, 22, 15),
  ));
  app.pushNotification(AppNotification(
    id: 'n1', title: 'Game starts in 1 hour',
    body: 'Friday Night Freezeout at Marcus\u2019s place',
    type: NotificationType.game, link: null, read: false,
    timestamp: DateTime(2026, 3, 14, 19, 0),
  ));
  if (game != null) {
    app.setCurrentGameForTesting(
      game == LiveGameStatus.completed
          ? fixtureGame(game, players: fixturePlayers(eliminated: true))
          : fixtureGame(game),
    );
  }
  if (cash) app.setCashSessionForTesting(fixtureCash());
}

/// Dummy input for the auth boards: fills every field top-to-bottom and ticks
/// the register consent boxes, so captures show a completed form. Never
/// submits (no backend touch). Needs flutter_test; called from the harnesses.
Future<void> fillAuthForms(WidgetTester t, String key) async {
  final values = switch (key) {
    '01_03_sign_in' => ['alex@pokernight.app', 'Demo1234!'],
    '01_04_register' => [
        'Alex Morgan',
        'alex@pokernight.app',
        'Demo1234!',
        'Demo1234!'
      ],
    '01_05_forgot_password' => ['alex@pokernight.app'],
    _ => const <String>[],
  };
  if (values.isEmpty) return;
  final boxes = find.byType(TextField).evaluate().toList();
  boxes.sort((a, b) {
    final da = (a.renderObject as RenderBox).localToGlobal(Offset.zero).dy;
    final db = (b.renderObject as RenderBox).localToGlobal(Offset.zero).dy;
    return da.compareTo(db);
  });
  for (var i = 0; i < values.length && i < boxes.length; i++) {
    await t.enterText(find.byWidget(boxes[i].widget), values[i]);
    await t.pump();
  }
  if (key == '01_04_register') {
    final checks = find.byType(Checkbox).evaluate().toList();
    for (final c in checks) {
      await t.tap(find.byWidget(c.widget));
      await t.pump();
    }
  }
  await t.pump(const Duration(milliseconds: 600));
}

/// Registers the app's REAL typeface (Space Grotesk, all 5 bundled weights)
/// under every family name google_fonts asks for. Set --dart-define=NOFONTS=true to skip.
const noBoardFonts = bool.fromEnvironment('NOFONTS');

Future<void> registerBoardFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  if (noBoardFonts) return;
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
